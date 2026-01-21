#!/usr/bin/env python3
"""tools/gen_tmuxp.py

Ubuntu 24 + Ghostty + tmux + tmuxp + Git worktree + OpenCode(opencode) で、
図の「品質ゲート→ランキング→勝者統合」までを tmux 上で一気に回すための 1 ファイル。

このスクリプトは 5 つのサブコマンドを持ちます：

  - generate : worktree 作成 + tmuxp 設定生成（.tmuxp/arena.json）
  - gate     : Quality Gate（自動テスト）を全チームへ実行し結果を保存
  - rank     : gate 結果からランキング/勝者を算出し保存
  - integrate: 勝者ブランチを統合ブランチへマージし、最終ゲートも実行
  - pipeline : gate→rank→integrate を順に実行（Enter待ちも可能）

特徴:
  - 旧仕様互換: `python3 tools/gen_tmuxp.py --n 5` のようにサブコマンド無しでも generate 扱い。
  - worktree を大量生成しても、ゲートは「コミットが変わったチームだけ」再実行（watch向き）。
  - OpenCode(opencode) のCLIオプションが環境差で変わっても落ちにくいように、
    pane では `opencode --help` を見て `--agent/--model` を付けられる時だけ付ける。

生成される tmux セッションの主なウィンドウ:
  - planner       : 中央プランナー（opencode）
  - comp-A/B/C... : 第1レベル競争層（opencode）
  - quality-gate  : gateのwatch実行 + QAエージェント（opencode）
  - ranking       : rankのwatch実行 + winners.json表示
  - integration   : 統合手順シェル + integratorエージェント（opencode）
  - pipeline      : Enter一発で gate→rank→integrate(final gate) 実行

注意:
  - Gate(自動テスト)コマンドは `generate --gate-cmd "..."` で明示推奨です。
    省略した場合は Makefile/package.json/pyproject.toml などから推測を試みます。

モデル設定:
  - デフォルトモデル: openai/gpt-5.2-codex (Codex中心)
  - 環境変数 OPENCODE_MODEL で上書き可能
"""

from __future__ import annotations

import argparse
import dataclasses
import json
import os
import re
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


# ---------------------------
# small utils
# ---------------------------

def now_iso() -> str:
    # lightweight ISO-ish timestamp
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")


def human_sec(sec: float) -> str:
    if sec >= 60:
        m = int(sec // 60)
        s = sec - m * 60
        return f"{m}m{s:0.1f}s"
    return f"{sec:0.1f}s"


def sh(cmd: List[str], cwd: Path, check: bool) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=str(cwd), text=True, capture_output=True, check=check)


def git_out(args: List[str], cwd: Path) -> str:
    cp = sh(["git"] + args, cwd=cwd, check=True)
    return cp.stdout.strip()


def in_git_repo(start: Path) -> Optional[Path]:
    cp = subprocess.run(["git", "rev-parse", "--show-toplevel"], cwd=str(start), text=True, capture_output=True)
    if cp.returncode != 0:
        return None
    return Path(cp.stdout.strip())


def ensure_dir(p: Path) -> None:
    p.mkdir(parents=True, exist_ok=True)


def is_dirty(repo: Path) -> bool:
    cp = subprocess.run(["git", "status", "--porcelain"], cwd=str(repo), text=True, capture_output=True)
    return bool(cp.stdout.strip())


def branch_exists(branch: str, repo_root: Path) -> bool:
    cp = subprocess.run(
        ["git", "show-ref", "--verify", "--quiet", f"refs/heads/{branch}"],
        cwd=str(repo_root),
        text=True,
        capture_output=True,
    )
    return cp.returncode == 0


def config_path(repo_root: Path) -> Path:
    return repo_root / ".arena" / "arena_config.json"


def results_dir(repo_root: Path) -> Path:
    return repo_root / ".arena" / "results"


def logs_dir(repo_root: Path) -> Path:
    return repo_root / ".arena" / "logs"


def result_path(repo_root: Path, team: str) -> Path:
    return results_dir(repo_root) / f"{team}.json"


def read_result(repo_root: Path, team: str) -> Optional[Dict[str, Any]]:
    p = result_path(repo_root, team)
    if not p.exists():
        return None
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return None


def write_result(repo_root: Path, team: str, data: Dict[str, Any]) -> None:
    ensure_dir(results_dir(repo_root))
    result_path(repo_root, team).write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def load_config(repo_root: Path) -> Dict[str, Any]:
    p = config_path(repo_root)
    if not p.exists():
        raise FileNotFoundError(f"missing config: {p} (run generate first)")
    return json.loads(p.read_text(encoding="utf-8"))


def save_config(repo_root: Path, cfg: Dict[str, Any]) -> None:
    ensure_dir(repo_root / ".arena")
    config_path(repo_root).write_text(json.dumps(cfg, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


# ---------------------------
# worktree helpers
# ---------------------------

def team_ids(track_key: str, count: int) -> List[str]:
    return [f"{track_key}{i:02d}" for i in range(1, count + 1)]


def ensure_worktree(team_id: str, repo_root: Path, worktrees_dir: Path, base_ref: str) -> Path:
    """
    Create worktree if missing:
      - dir:  worktrees/<team_id>
      - branch: arena/<team_id>
    """
    wt_path = worktrees_dir / team_id
    branch = f"arena/{team_id}"

    if wt_path.exists():
        return wt_path

    ensure_dir(wt_path.parent)

    if branch_exists(branch, repo_root):
        sh(["git", "worktree", "add", str(wt_path), branch], cwd=repo_root, check=True)
    else:
        sh(["git", "worktree", "add", "-b", branch, str(wt_path), base_ref], cwd=repo_root, check=True)

    return wt_path


def ensure_integration_worktree(repo_root: Path, worktrees_dir: Path, base_ref: str, integration_branch: str) -> Path:
    """
    Ensure dedicated integration worktree exists:
      - dir: worktrees/INTEGRATION
      - branch: arena/integration (default)
    """
    wt_path = (worktrees_dir / "INTEGRATION").resolve()

    if wt_path.exists():
        return wt_path

    if branch_exists(integration_branch, repo_root):
        sh(["git", "worktree", "add", str(wt_path), integration_branch], cwd=repo_root, check=True)
    else:
        sh(["git", "worktree", "add", "-b", integration_branch, str(wt_path), base_ref], cwd=repo_root, check=True)

    return wt_path


# ---------------------------
# Gate detection (best-effort)
# ---------------------------

def detect_gate_cmd(repo_root: Path) -> Optional[str]:
    """
    Very simple auto-detection. Prefer explicit --gate-cmd.
    """
    mk = repo_root / "Makefile"
    if mk.exists():
        try:
            text = mk.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            text = ""
        if re.search(r"(?m)^gate\s*:", text):
            return "make gate"
        if re.search(r"(?m)^test\s*:", text):
            return "make test"

    if (repo_root / "package.json").exists():
        return "npm test"

    if (repo_root / "pyproject.toml").exists() or (repo_root / "pytest.ini").exists():
        return "python3 -m pytest -q"

    if (repo_root / "go.mod").exists():
        return "go test ./..."

    if (repo_root / "Cargo.toml").exists():
        return "cargo test"

    return None


# ---------------------------
# Gate / Rank / Integrate
# ---------------------------

def run_gate_one(
    repo_root: Path,
    team_id: str,
    wt_path: Path,
    gate_cmd: str,
    timeout_sec: int,
    force: bool,
) -> Dict[str, Any]:
    """Run gate for a single team worktree, capturing logs and returning result dict."""

    # Gather metadata
    branch = git_out(["rev-parse", "--abbrev-ref", "HEAD"], wt_path)
    commit = git_out(["rev-parse", "HEAD"], wt_path)
    dirty = is_dirty(wt_path)

    prev = read_result(repo_root, team_id)
    if prev and (not force) and (prev.get("commit") == commit) and (prev.get("dirty") == dirty):
        # Nothing changed; reuse.
        return prev

    result: Dict[str, Any] = {
        "team": team_id,
        "branch": branch,
        "commit": commit,
        "dirty": dirty,
        "gate_cmd": gate_cmd,
        "timestamp": now_iso(),
    }

    ensure_dir(logs_dir(repo_root))
    log_path = logs_dir(repo_root) / f"{team_id}.log"

    if dirty:
        result.update(
            {
                "status": "dirty",
                "exit_code": None,
                "elapsed_sec": None,
                "note": "Worktree has uncommitted changes. Commit first to be eligible for gate/rank.",
            }
        )
        log_path.write_text("[DIRTY] Uncommitted changes exist. Commit before running gate.\n", encoding="utf-8")
        write_result(repo_root, team_id, result)
        return result

    start = time.monotonic()
    # Run gate command using bash -lc to support compound commands.
    proc = subprocess.run(
        ["bash", "-lc", gate_cmd],
        cwd=str(wt_path),
        text=True,
        capture_output=True,
        timeout=timeout_sec,
    )
    elapsed = time.monotonic() - start

    log_text = (
        f"# Gate Result: {team_id}\n"
        f"timestamp: {result['timestamp']}\n"
        f"branch: {branch}\n"
        f"commit: {commit}\n"
        f"cmd: {gate_cmd}\n"
        f"exit: {proc.returncode}\n"
        f"elapsed: {elapsed:.3f}s\n\n"
        "--- STDOUT ---\n"
        + (proc.stdout or "")
        + "\n--- STDERR ---\n"
        + (proc.stderr or "")
        + "\n"
    )
    log_path.write_text(log_text, encoding="utf-8")

    status = "pass" if proc.returncode == 0 else "fail"

    result.update(
        {
            "status": status,
            "exit_code": proc.returncode,
            "elapsed_sec": round(elapsed, 3),
        }
    )

    write_result(repo_root, team_id, result)
    return result


def run_gate_all(repo_root: Path, cfg: Dict[str, Any], watch: bool, interval: int, force: bool) -> int:
    gate_cmd = cfg.get("gate_cmd")
    if not gate_cmd:
        auto = detect_gate_cmd(repo_root)
        if not auto:
            print("[gate] ERROR: gate_cmd not set and could not auto-detect.")
            print("[gate]       Re-run generate with --gate-cmd '...' (e.g., make gate / make test / pytest -q)")
            return 2
        gate_cmd = auto

    timeout_sec = int(cfg.get("gate_timeout_sec", 1800))

    tracks = cfg["tracks"]
    all_team_ids: List[str] = []
    for t in tracks:
        all_team_ids.extend(team_ids(t["key"], int(t["count"])))

    ensure_dir(results_dir(repo_root))
    ensure_dir(logs_dir(repo_root))

    def once() -> None:
        print(f"[gate] gate_cmd: {gate_cmd}")
        print(f"[gate] timeout_sec: {timeout_sec}")
        print(f"[gate] teams: {', '.join(all_team_ids)}")
        print("")

        rows: List[Tuple[str, str, str, str]] = []
        for team in all_team_ids:
            wt = (repo_root / cfg["worktrees_dir"] / team).resolve()
            if not wt.exists():
                rows.append((team, "missing", "-", "-"))
                continue
            r = run_gate_one(repo_root, team, wt, gate_cmd, timeout_sec=timeout_sec, force=force)
            st = r.get("status", "?")
            el = r.get("elapsed_sec")
            el_s = human_sec(float(el)) if el is not None else "-"
            commit = (r.get("commit") or "")[:7]
            rows.append((team, st, el_s, commit))

        # Print table
        print("TEAM  STATUS  TIME   COMMIT")
        print("----- ------  -----  -------")
        for team, st, el_s, commit in rows:
            print(f"{team:<5} {st:<6}  {el_s:<5}  {commit}")
        print("")
        print(f"[gate] logs: {logs_dir(repo_root)}")
        print(f"[gate] results: {results_dir(repo_root)}")

    if not watch:
        once()
        return 0

    print("[gate] WATCH mode. Press Ctrl+C to stop.")
    while True:
        try:
            once()
            time.sleep(interval)
        except KeyboardInterrupt:
            print("\n[gate] stopped.")
            return 0


def score_result(r: Dict[str, Any]) -> Tuple[int, float]:
    """Score: pass > dirty > fail/pending/missing, then faster is better.

    Returns tuple usable for sorting: (-tier, elapsed)
    """
    st = r.get("status")
    if st == "pass":
        tier = 3
    elif st == "dirty":
        tier = 2
    else:
        tier = 1

    elapsed = r.get("elapsed_sec")
    if elapsed is None:
        elapsed_f = 1e9
    else:
        elapsed_f = float(elapsed)

    # Sort: tier desc, elapsed asc
    return (-tier, elapsed_f)


def run_rank(repo_root: Path, cfg: Dict[str, Any], watch: bool, interval: int) -> int:
    tracks_cfg = cfg["tracks"]
    wt_dir = repo_root / cfg["worktrees_dir"]

    def once() -> int:
        winners: Dict[str, Optional[str]] = {}
        ranking: Dict[str, List[Dict[str, Any]]] = {}

        for t in tracks_cfg:
            key = t["key"]
            ids = team_ids(key, int(t["count"]))
            results: List[Dict[str, Any]] = []
            for team in ids:
                r = read_result(repo_root, team)
                if r is None:
                    # If worktree exists but no result yet, mark as pending
                    wt = wt_dir / team
                    if wt.exists():
                        results.append({"team": team, "status": "pending", "elapsed_sec": None, "commit": None})
                    else:
                        results.append({"team": team, "status": "missing", "elapsed_sec": None, "commit": None})
                else:
                    results.append(r)

            results_sorted = sorted(results, key=score_result)
            ranking[key] = results_sorted

            # winner: best PASS only
            win = None
            for r in results_sorted:
                if r.get("status") == "pass":
                    win = r.get("team")
                    break
            winners[key] = win

        ensure_dir(repo_root / ".arena")
        (repo_root / ".arena" / "ranking.json").write_text(
            json.dumps(ranking, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        (repo_root / ".arena" / "winners.json").write_text(
            json.dumps(winners, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )

        # human-readable markdown
        md_lines = [f"# Arena Ranking ({now_iso()})", ""]
        for key in [t["key"] for t in tracks_cfg]:
            md_lines.append(f"## Track {key}")
            md_lines.append("| rank | team | status | time | commit |")
            md_lines.append("|---:|---|---|---:|---|")
            for i, r in enumerate(ranking[key], start=1):
                team = r.get("team")
                st = r.get("status")
                el = r.get("elapsed_sec")
                el_s = human_sec(float(el)) if el is not None else "-"
                commit = (r.get("commit") or "")[:7] if r.get("commit") else "-"
                md_lines.append(f"| {i} | {team} | {st} | {el_s} | {commit} |")
            md_lines.append("")
            md_lines.append(f"**Winner:** {winners[key] or 'N/A (no PASS)'}")
            md_lines.append("")

        (repo_root / ".arena" / "ranking.md").write_text("\n".join(md_lines) + "\n", encoding="utf-8")

        # Print summary
        print(f"[rank] updated: {repo_root / '.arena' / 'ranking.md'}")
        for key, win in winners.items():
            print(f"[rank] Track {key} winner: {win or 'N/A'}")
        return 0

    if not watch:
        return once()

    print("[rank] WATCH mode. Press Ctrl+C to stop.")
    while True:
        try:
            once()
            time.sleep(interval)
        except KeyboardInterrupt:
            print("\n[rank] stopped.")
            return 0


def integrate_winners(repo_root: Path, cfg: Dict[str, Any], reset: bool, final_gate: bool) -> int:
    winners_path = repo_root / ".arena" / "winners.json"
    if not winners_path.exists():
        print("[integrate] winners.json not found. Run rank first (or pipeline).")
        return 2

    winners = json.loads(winners_path.read_text(encoding="utf-8"))
    tracks_cfg = cfg["tracks"]

    integration_branch = cfg.get("integration_branch", "arena/integration")
    wt_dir = repo_root / cfg["worktrees_dir"]
    base_ref = cfg["base_ref"]

    int_wt = ensure_integration_worktree(repo_root, wt_dir, base_ref=base_ref, integration_branch=integration_branch)

    # Integration worktree must be clean
    if is_dirty(int_wt):
        print(f"[integrate] ERROR: integration worktree is dirty: {int_wt}")
        print("[integrate] Commit/stash/clean it first.")
        return 3

    # Checkout integration branch
    sh(["git", "checkout", integration_branch], cwd=int_wt, check=True)

    if reset:
        # Reset integration branch to base_ref
        sh(["git", "fetch", "--all"], cwd=int_wt, check=False)
        sh(["git", "reset", "--hard", base_ref], cwd=int_wt, check=True)
        sh(["git", "clean", "-fd"], cwd=int_wt, check=True)

    # Merge winners
    merged: List[Dict[str, Any]] = []
    for t in tracks_cfg:
        key = t["key"]
        win = winners.get(key)
        if not win:
            print(f"[integrate] Track {key}: no PASS winner. Integration aborted.")
            return 4

        branch = f"arena/{win}"
        if not branch_exists(branch, repo_root):
            print(f"[integrate] ERROR: branch not found: {branch}")
            return 5

        print(f"[integrate] merging winner {win} ({branch}) into {integration_branch}...")
        # Merge with no-ff to keep traceability
        cp = sh(["git", "merge", "--no-ff", "--no-edit", branch], cwd=int_wt, check=False)
        if cp.returncode != 0:
            print("[integrate] MERGE CONFLICT or merge failed.")
            print(f"[integrate] Worktree: {int_wt}")
            print("[integrate] Resolve conflicts manually, then run:")
            print(f"            cd '{int_wt}' && git status")
            print("            git add -A && git commit")
            return 6

        merged.append({"track": key, "team": win, "branch": branch})

    int_commit = git_out(["rev-parse", "HEAD"], int_wt)

    integration_record: Dict[str, Any] = {
        "timestamp": now_iso(),
        "integration_branch": integration_branch,
        "base_ref": base_ref,
        "merged": merged,
        "integration_commit": int_commit,
    }

    # Final gate on integrated branch
    if final_gate:
        gate_cmd = cfg.get("gate_cmd") or detect_gate_cmd(repo_root)
        if not gate_cmd:
            print("[integrate] WARNING: final_gate requested but gate_cmd is not set and auto-detect failed.")
            integration_record["final_gate"] = {"status": "skipped", "reason": "gate_cmd missing"}
        else:
            timeout_sec = int(cfg.get("gate_timeout_sec", 1800))
            print(f"[integrate] running final gate: {gate_cmd}")
            start = time.monotonic()
            proc = subprocess.run(
                ["bash", "-lc", gate_cmd],
                cwd=str(int_wt),
                text=True,
                capture_output=True,
                timeout=timeout_sec,
            )
            elapsed = time.monotonic() - start
            st = "pass" if proc.returncode == 0 else "fail"
            ensure_dir(logs_dir(repo_root))
            (logs_dir(repo_root) / "INTEGRATION.log").write_text(
                f"# Final Gate (INTEGRATION)\ncommit: {int_commit[:7]}\ncmd: {gate_cmd}\nexit: {proc.returncode}\nelapsed: {elapsed:.3f}s\n\n--- STDOUT ---\n"
                + (proc.stdout or "")
                + "\n--- STDERR ---\n"
                + (proc.stderr or "")
                + "\n",
                encoding="utf-8",
            )
            integration_record["final_gate"] = {
                "cmd": gate_cmd,
                "status": st,
                "exit_code": proc.returncode,
                "elapsed_sec": round(elapsed, 3),
                "log": str(logs_dir(repo_root) / "INTEGRATION.log"),
            }

    ensure_dir(repo_root / ".arena")
    (repo_root / ".arena" / "integration.json").write_text(
        json.dumps(integration_record, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    print(f"[integrate] done. integration worktree: {int_wt}")
    print(f"[integrate] record: {repo_root / '.arena' / 'integration.json'}")

    fg = integration_record.get("final_gate")
    if fg and fg.get("status") == "pass":
        print("[integrate] ✅ Final gate PASS. Candidate is ready (Final Product candidate).")
    elif fg and fg.get("status") == "fail":
        print("[integrate] ❌ Final gate FAIL. See INTEGRATION.log and fix in integration worktree.")
    else:
        print("[integrate] (final gate not run)")

    return 0


def pipeline(repo_root: Path, cfg: Dict[str, Any], wait: bool, interval: int) -> int:
    if wait:
        print("[pipeline] Ready. Press Enter to run: gate → rank → integrate(final_gate). Ctrl+C to cancel.")
        try:
            input()
        except KeyboardInterrupt:
            print("\n[pipeline] canceled.")
            return 130

    # gate once
    rc = run_gate_all(repo_root, cfg, watch=False, interval=interval, force=False)
    if rc != 0:
        return rc

    # rank once
    rc = run_rank(repo_root, cfg, watch=False, interval=interval)
    if rc != 0:
        return rc

    # integrate with final gate
    rc = integrate_winners(repo_root, cfg, reset=True, final_gate=True)
    return rc


# ---------------------------
# tmuxp generation
# ---------------------------

def chunk(items: List[str], size: int) -> List[List[str]]:
    return [items[i : i + size] for i in range(0, len(items), size)]


def opencode_shell_snippet(agent: str, model: str, repo_root: Path) -> str:
    """
    Runtime detection of flags (robust to CLI changes).
    - Always export OPENCODE_CONFIG so worktree uses the root config (opencode.json).
    - Use environment variable OPENCODE_MODEL if set, otherwise use provided model.
    """
    return (
        "set -e\n"
        "export PATH=\"$HOME/.local/bin:$HOME/.npm-global/bin:$PATH\"\n"
        f"export OPENCODE_CONFIG=\"{repo_root / 'opencode.json'}\"\n"
        f"MODEL=\"${{OPENCODE_MODEL:-{model}}}\"\n"
        "HELP=$(opencode --help 2>/dev/null || true)\n"
        "CMD=\"opencode\"\n"
        f"if echo \"$HELP\" | grep -q -- '--agent'; then CMD=\"$CMD --agent {agent}\"; fi\n"
        "if echo \"$HELP\" | grep -q -- '--model'; then CMD=\"$CMD --model $MODEL\"; fi\n"
        "echo \"[opencode] $CMD\"\n"
        "eval $CMD\n"
    )


def pane(title: str, commands: List[str]) -> Dict[str, Any]:
    # tmux pane title is best-effort
    cmd0 = f"tmux select-pane -T '{title}' 2>/dev/null || true"
    return {"shell_command": [cmd0] + commands}


def generate_tmuxp(repo_root: Path, cfg: Dict[str, Any], session: str, out_path: Path, per_window: int) -> None:
    wt_dir = repo_root / cfg["worktrees_dir"]

    windows: List[Dict[str, Any]] = []

    # Planner window (central planner agent)
    windows.append(
        {
            "window_name": "planner",
            "layout": "even-horizontal",
            "panes": [
                pane(
                    "planner",
                    [
                        f"cd '{repo_root}'",
                        opencode_shell_snippet(cfg["planner_agent"], cfg["model_codex"], repo_root),
                    ],
                )
            ],
        }
    )

    # Competition windows per track
    for t in cfg["tracks"]:
        key = t["key"]
        ids = team_ids(key, int(t["count"]))
        groups = chunk(ids, max(1, per_window))

        for gi, group in enumerate(groups, start=1):
            wname = f"comp-{key}" if len(groups) == 1 else f"comp-{key}-{gi}"
            panes = []
            for tid in group:
                wt = (wt_dir / tid).resolve()
                panes.append(
                    pane(
                        tid,
                        [
                            f"cd '{wt}'",
                            opencode_shell_snippet(t["agent"], t["model"], repo_root),
                        ],
                    )
                )
            windows.append({"window_name": wname, "layout": "tiled", "panes": panes})

    # Quality Gate window: watch gate results + QA agent
    windows.append(
        {
            "window_name": "quality-gate",
            "layout": "even-horizontal",
            "panes": [
                pane(
                    "gate-watch",
                    [
                        f"cd '{repo_root}'",
                        "export PATH=\"$HOME/.local/bin:$PATH\"",
                        "python3 tools/gen_tmuxp.py gate --watch --interval 20",
                    ],
                ),
                pane(
                    "qa-agent",
                    [
                        f"cd '{repo_root}'",
                        opencode_shell_snippet(cfg.get("qa_agent", "qa-gate"), cfg["model_codex"], repo_root),
                    ],
                ),
            ],
        }
    )

    # Ranking window: watch ranking + show winners
    windows.append(
        {
            "window_name": "ranking",
            "layout": "even-horizontal",
            "panes": [
                pane(
                    "rank-watch",
                    [
                        f"cd '{repo_root}'",
                        "export PATH=\"$HOME/.local/bin:$PATH\"",
                        "python3 tools/gen_tmuxp.py rank --watch --interval 20",
                    ],
                ),
                pane(
                    "winners",
                    [
                        f"cd '{repo_root}'",
                        "echo '[winners] .arena/winners.json (updates when rank runs)'",
                        "while true; do clear; date; echo; test -f .arena/winners.json && cat .arena/winners.json || echo '(no winners yet)'; sleep 5; done",
                    ],
                ),
            ],
        }
    )

    # Integration window: integration worktree + integrator agent
    int_wt = (wt_dir / "INTEGRATION").resolve()
    windows.append(
        {
            "window_name": "integration",
            "layout": "even-horizontal",
            "panes": [
                pane(
                    "integrate",
                    [
                        f"cd '{repo_root}'",
                        "export PATH=\"$HOME/.local/bin:$PATH\"",
                        "echo '[integrate] Run when winners are ready:'",
                        "echo '  python3 tools/gen_tmuxp.py integrate --reset --final-gate'",
                        "echo ''",
                        "echo '[pipeline] Or run full pipeline:'",
                        "echo '  python3 tools/gen_tmuxp.py pipeline --wait'",
                        "bash",
                    ],
                ),
                pane(
                    "integrator-agent",
                    [
                        f"cd '{int_wt}'",
                        opencode_shell_snippet(cfg.get("integrator_agent", "integrator"), cfg["model_codex"], repo_root),
                    ],
                ),
            ],
        }
    )

    # Pipeline window: Enter to run everything
    windows.append(
        {
            "window_name": "pipeline",
            "layout": "even-horizontal",
            "panes": [
                pane(
                    "pipeline",
                    [
                        f"cd '{repo_root}'",
                        "export PATH=\"$HOME/.local/bin:$PATH\"",
                        "python3 tools/gen_tmuxp.py pipeline --wait",
                    ],
                )
            ],
        }
    )

    tmuxp_conf: Dict[str, Any] = {
        "session_name": session,
        "start_directory": str(repo_root),
        "windows": windows,
    }

    ensure_dir(out_path.parent)
    out_path.write_text(json.dumps(tmuxp_conf, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


# ---------------------------
# CLI
# ---------------------------

@dataclass
class Track:
    key: str
    count: int
    model: str
    agent: str


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(add_help=True)
    sub = p.add_subparsers(dest="cmd")

    # generate
    g = sub.add_parser("generate", help="create worktrees + tmuxp config")
    g.add_argument("--session", default="arena")
    g.add_argument("--out", default=".tmuxp/arena.json")
    g.add_argument("--worktrees-dir", default="worktrees")
    g.add_argument("--per-window", type=int, default=5)

    g.add_argument("--n", type=int, default=3, help="default agents per competition")
    g.add_argument("--nA", type=int, default=None)
    g.add_argument("--nB", type=int, default=None)
    g.add_argument("--nC", type=int, default=None)
    g.add_argument("--nN", type=int, default=None, help="optional: tests track N")
    g.add_argument("--enable-N", action="store_true", help="include track N (tests) in tmux and gating")

    g.add_argument("--base-ref", default=None, help="base ref for new branches (default: current branch)")

    g.add_argument("--gate-cmd", default=None, help="Quality Gate command (e.g., 'make gate', 'pytest -q')")
    g.add_argument("--gate-timeout", type=int, default=1800)

    # Model settings - Codex中心
    g.add_argument("--model-codex", default=os.environ.get("OPENCODE_MODEL", "openai/gpt-5.2-codex"))
    g.add_argument("--model-glm", default=os.environ.get("OPENCODE_MODEL", "openai/gpt-5.2-codex"))

    g.add_argument("--planner-agent", default="central-planner")
    g.add_argument("--agent-a", default="comp-a")
    g.add_argument("--agent-b", default="comp-b")
    g.add_argument("--agent-c", default="comp-c")
    g.add_argument("--agent-n", default="comp-n")
    g.add_argument("--qa-agent", default="qa-gate")
    g.add_argument("--integrator-agent", default="integrator")

    # gate
    gate_p = sub.add_parser("gate", help="run Quality Gate on all teams")
    gate_p.add_argument("--watch", action="store_true")
    gate_p.add_argument("--interval", type=int, default=20)
    gate_p.add_argument("--force", action="store_true", help="re-run gate even if commit unchanged")

    # rank
    rank_p = sub.add_parser("rank", help="rank teams and write winners.json")
    rank_p.add_argument("--watch", action="store_true")
    rank_p.add_argument("--interval", type=int, default=20)

    # integrate
    int_p = sub.add_parser("integrate", help="merge winners into integration branch and run final gate")
    int_p.add_argument("--reset", action="store_true", help="reset integration branch to base_ref before merging")
    int_p.add_argument("--final-gate", action="store_true", help="run final gate on integrated branch")

    # pipeline
    pipe_p = sub.add_parser("pipeline", help="gate→rank→integrate(final) sequentially")
    pipe_p.add_argument("--wait", action="store_true", help="wait for Enter before starting")
    pipe_p.add_argument("--interval", type=int, default=20)

    return p


def main(argv: List[str]) -> int:
    # Backward compatibility:
    # - if no subcommand is specified, treat as generate
    known = {"generate", "gate", "rank", "integrate", "pipeline"}
    if len(argv) == 0:
        argv = ["generate"]
    elif argv[0] not in known:
        # If user passed options like --n 5, insert generate
        if argv[0].startswith("-"):
            argv = ["generate"] + argv
        else:
            # Unknown word; keep help
            pass

    repo_root = in_git_repo(Path.cwd())
    if not repo_root:
        print("ERROR: run inside a Git repository.", file=sys.stderr)
        return 2

    parser = build_parser()
    args = parser.parse_args(argv)

    if args.cmd == "generate":
        base_ref = args.base_ref
        if not base_ref:
            base_ref = git_out(["rev-parse", "--abbrev-ref", "HEAD"], repo_root) or "main"
            if base_ref == "HEAD":
                base_ref = "main"

        nA = args.nA if args.nA is not None else args.n
        nB = args.nB if args.nB is not None else args.n
        nC = args.nC if args.nC is not None else args.n
        nN = args.nN if args.nN is not None else args.n

        # All tracks use Codex model by default
        tracks: List[Track] = [
            Track("A", nA, args.model_codex, args.agent_a),
            Track("B", nB, args.model_codex, args.agent_b),
            Track("C", nC, args.model_codex, args.agent_c),
        ]
        if args.enable_N:
            tracks.append(Track("N", nN, args.model_codex, args.agent_n))

        wt_dir = (repo_root / args.worktrees_dir).resolve()
        ensure_dir(wt_dir)

        # Create worktrees for all teams
        sh(["git", "worktree", "prune"], cwd=repo_root, check=False)
        for t in tracks:
            for tid in team_ids(t.key, t.count):
                ensure_worktree(tid, repo_root, wt_dir, base_ref)

        # Create integration worktree
        integration_branch = "arena/integration"
        ensure_integration_worktree(repo_root, wt_dir, base_ref=base_ref, integration_branch=integration_branch)

        # Build config
        cfg: Dict[str, Any] = {
            "repo_root": str(repo_root),
            "base_ref": base_ref,
            "worktrees_dir": args.worktrees_dir,
            "gate_cmd": args.gate_cmd,
            "gate_timeout_sec": int(args.gate_timeout),
            "model_codex": args.model_codex,
            "model_glm": args.model_glm,
            "planner_agent": args.planner_agent,
            "qa_agent": args.qa_agent,
            "integrator_agent": args.integrator_agent,
            "integration_branch": integration_branch,
            "tracks": [
                {"key": t.key, "count": t.count, "model": t.model, "agent": t.agent}
                for t in tracks
            ],
            "generated_at": now_iso(),
        }

        # If gate_cmd not provided, store auto-detected suggestion (best effort)
        if cfg["gate_cmd"] is None:
            auto = detect_gate_cmd(repo_root)
            if auto:
                cfg["gate_cmd"] = auto

        save_config(repo_root, cfg)

        # Generate tmuxp
        out_path = (repo_root / args.out).resolve()
        generate_tmuxp(repo_root, cfg, session=args.session, out_path=out_path, per_window=int(args.per_window))

        print(f"[generate] wrote tmuxp: {out_path}")
        print(f"[generate] wrote arena config: {config_path(repo_root)}")
        print(f"[generate] worktrees: {wt_dir}")
        print("[generate] next:")
        print(f"  tmuxp load {out_path}")
        return 0

    # The remaining subcommands require config
    cfg = load_config(repo_root)

    if args.cmd == "gate":
        return run_gate_all(repo_root, cfg, watch=bool(args.watch), interval=int(args.interval), force=bool(args.force))

    if args.cmd == "rank":
        return run_rank(repo_root, cfg, watch=bool(args.watch), interval=int(args.interval))

    if args.cmd == "integrate":
        return integrate_winners(repo_root, cfg, reset=bool(args.reset), final_gate=bool(args.final_gate))

    if args.cmd == "pipeline":
        return pipeline(repo_root, cfg, wait=bool(args.wait), interval=int(args.interval))

    parser.print_help()
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
