#!/usr/bin/env python3
"""tools/gen_tmuxp.py

Ubuntu 24 + Ghostty + tmux + tmuxp + Git worktree + OpenCode(opencode) で、
図の「品質ゲート→ランキング→勝者統合」までを tmux 上で一気に回すための 1 ファイル。

このスクリプトは 6 つのサブコマンドを持ちます：

  - generate : worktree 作成 + tmuxp 設定生成（.tmuxp/arena.json）
  - gate     : Quality Gate（自動テスト）を全チームへ実行し結果を保存
  - rank     : gate 結果からランキング/勝者を算出し保存
  - integrate: 勝者ブランチを統合ブランチへマージし、最終ゲートも実行
  - pipeline : gate→rank→integrate を順に実行（Enter待ちも可能）
  - start    : 要件ファイルを受け取り、generate + tmuxp load を自動実行

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
import json
import os
import re
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


def now_iso() -> str:
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
        cwd=str(repo_root), text=True, capture_output=True,
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


def team_ids(track_key: str, count: int) -> List[str]:
    return [f"{track_key}{i:02d}" for i in range(1, count + 1)]


def ensure_worktree(team_id: str, repo_root: Path, worktrees_dir: Path, base_ref: str) -> Path:
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
    wt_path = (worktrees_dir / "INTEGRATION").resolve()
    if wt_path.exists():
        return wt_path
    if branch_exists(integration_branch, repo_root):
        sh(["git", "worktree", "add", str(wt_path), integration_branch], cwd=repo_root, check=True)
    else:
        sh(["git", "worktree", "add", "-b", integration_branch, str(wt_path), base_ref], cwd=repo_root, check=True)
    return wt_path


def detect_gate_cmd(repo_root: Path) -> Optional[str]:
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


def run_gate_one(repo_root: Path, team_id: str, wt_path: Path, gate_cmd: str, timeout_sec: int, force: bool) -> Dict[str, Any]:
    branch = git_out(["rev-parse", "--abbrev-ref", "HEAD"], wt_path)
    commit = git_out(["rev-parse", "HEAD"], wt_path)
    dirty = is_dirty(wt_path)
    prev = read_result(repo_root, team_id)
    if prev and (not force) and (prev.get("commit") == commit) and (prev.get("dirty") == dirty):
        return prev
    result: Dict[str, Any] = {"team": team_id, "branch": branch, "commit": commit, "dirty": dirty, "gate_cmd": gate_cmd, "timestamp": now_iso()}
    ensure_dir(logs_dir(repo_root))
    log_path = logs_dir(repo_root) / f"{team_id}.log"
    if dirty:
        result.update({"status": "dirty", "exit_code": None, "elapsed_sec": None, "note": "Worktree has uncommitted changes."})
        log_path.write_text("[DIRTY] Uncommitted changes exist.\n", encoding="utf-8")
        write_result(repo_root, team_id, result)
        return result
    start = time.monotonic()
    proc = subprocess.run(["bash", "-lc", gate_cmd], cwd=str(wt_path), text=True, capture_output=True, timeout=timeout_sec)
    elapsed = time.monotonic() - start
    log_text = f"# Gate Result: {team_id}\ntimestamp: {result['timestamp']}\nbranch: {branch}\ncommit: {commit}\ncmd: {gate_cmd}\nexit: {proc.returncode}\nelapsed: {elapsed:.3f}s\n\n--- STDOUT ---\n{proc.stdout or ''}\n--- STDERR ---\n{proc.stderr or ''}\n"
    log_path.write_text(log_text, encoding="utf-8")
    status = "pass" if proc.returncode == 0 else "fail"
    result.update({"status": status, "exit_code": proc.returncode, "elapsed_sec": round(elapsed, 3)})
    write_result(repo_root, team_id, result)
    return result


def run_gate_all(repo_root: Path, cfg: Dict[str, Any], watch: bool, interval: int, force: bool) -> int:
    gate_cmd = cfg.get("gate_cmd")
    if not gate_cmd:
        auto = detect_gate_cmd(repo_root)
        if not auto:
            print("[gate] ERROR: gate_cmd not set and could not auto-detect.")
            return 2
        gate_cmd = auto
    timeout_sec = int(cfg.get("gate_timeout_sec", 1800))
    tracks = cfg["tracks"]
    all_team_ids: List[str] = []
    for t in tracks:
        all_team_ids.extend(team_ids(t["key"], int(t["count"])))
    ensure_dir(results_dir(repo_root))
    wt_dir = Path(cfg["worktrees_dir"])
    if not wt_dir.is_absolute():
        wt_dir = repo_root / wt_dir

    def run_once() -> None:
        for tid in all_team_ids:
            wt = wt_dir / tid
            if not wt.exists():
                print(f"[gate] WARN: worktree missing: {wt}")
                continue
            res = run_gate_one(repo_root, tid, wt, gate_cmd, timeout_sec, force)
            st = res.get("status", "?")
            elapsed = res.get("elapsed_sec")
            elapsed_str = human_sec(elapsed) if elapsed else "-"
            print(f"[gate] {tid}: {st.upper()} ({elapsed_str})")

    if not watch:
        run_once()
        return 0
    print(f"[gate] watching every {interval}s. Ctrl+C to stop.")
    while True:
        run_once()
        print(f"[gate] sleeping {interval}s...")
        time.sleep(interval)


def run_rank(repo_root: Path, cfg: Dict[str, Any], watch: bool, interval: int) -> int:
    tracks = cfg["tracks"]

    def rank_once() -> Dict[str, Any]:
        winners: Dict[str, str] = {}
        ranking: Dict[str, List[Dict[str, Any]]] = {}
        for t in tracks:
            key = t["key"]
            ids = team_ids(key, int(t["count"]))
            results: List[Dict[str, Any]] = []
            for tid in ids:
                r = read_result(repo_root, tid)
                if r:
                    results.append(r)

            def sort_key(r: Dict[str, Any]) -> Tuple[int, float]:
                st = r.get("status", "fail")
                order = {"pass": 0, "dirty": 1, "fail": 2}.get(st, 3)
                elapsed = r.get("elapsed_sec") or 9999999
                return (order, elapsed)

            results.sort(key=sort_key)
            ranking[key] = results
            for r in results:
                if r.get("status") == "pass":
                    winners[key] = r["team"]
                    break
        out = {"timestamp": now_iso(), "winners": winners, "ranking": ranking}
        ensure_dir(repo_root / ".arena")
        (repo_root / ".arena" / "winners.json").write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        return out

    def print_rank(out: Dict[str, Any]) -> None:
        print(f"\n[rank] {out['timestamp']}")
        for key, results in out["ranking"].items():
            print(f"  Track {key}:")
            for i, r in enumerate(results, 1):
                st = r.get("status", "?").upper()
                elapsed = r.get("elapsed_sec")
                elapsed_str = human_sec(elapsed) if elapsed else "-"
                mark = "★" if out["winners"].get(key) == r["team"] else " "
                print(f"    {mark} {i}. {r['team']}: {st} ({elapsed_str})")
        print(f"  Winners: {out['winners']}")

    if not watch:
        out = rank_once()
        print_rank(out)
        return 0
    print(f"[rank] watching every {interval}s. Ctrl+C to stop.")
    while True:
        out = rank_once()
        print_rank(out)
        print(f"[rank] sleeping {interval}s...")
        time.sleep(interval)


def integrate_winners(repo_root: Path, cfg: Dict[str, Any], reset: bool, final_gate: bool) -> int:
    winners_path = repo_root / ".arena" / "winners.json"
    if not winners_path.exists():
        print("[integrate] ERROR: winners.json not found. Run rank first.")
        return 1
    winners_data = json.loads(winners_path.read_text(encoding="utf-8"))
    winners: Dict[str, str] = winners_data.get("winners", {})
    tracks_cfg = cfg["tracks"]
    integration_branch = cfg.get("integration_branch", "arena/integration")
    base_ref = cfg.get("base_ref", "main")
    wt_dir = Path(cfg["worktrees_dir"])
    if not wt_dir.is_absolute():
        wt_dir = repo_root / wt_dir
    int_wt = wt_dir / "INTEGRATION"
    if not int_wt.exists():
        print(f"[integrate] ERROR: integration worktree not found: {int_wt}")
        return 2
    if is_dirty(int_wt):
        print(f"[integrate] ERROR: integration worktree is dirty: {int_wt}")
        return 3
    sh(["git", "checkout", integration_branch], cwd=int_wt, check=True)
    if reset:
        sh(["git", "fetch", "--all"], cwd=int_wt, check=False)
        sh(["git", "reset", "--hard", base_ref], cwd=int_wt, check=True)
        sh(["git", "clean", "-fd"], cwd=int_wt, check=True)
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
        cp = sh(["git", "merge", "--no-ff", "--no-edit", branch], cwd=int_wt, check=False)
        if cp.returncode != 0:
            print("[integrate] MERGE CONFLICT or merge failed.")
            print(f"[integrate] Worktree: {int_wt}")
            return 6
        merged.append({"track": key, "team": win, "branch": branch})
    int_commit = git_out(["rev-parse", "HEAD"], int_wt)
    integration_record: Dict[str, Any] = {"timestamp": now_iso(), "integration_branch": integration_branch, "base_ref": base_ref, "merged": merged, "integration_commit": int_commit}
    if final_gate:
        gate_cmd = cfg.get("gate_cmd") or detect_gate_cmd(repo_root)
        if not gate_cmd:
            integration_record["final_gate"] = {"status": "skipped", "reason": "gate_cmd missing"}
        else:
            timeout_sec = int(cfg.get("gate_timeout_sec", 1800))
            print(f"[integrate] running final gate: {gate_cmd}")
            start = time.monotonic()
            proc = subprocess.run(["bash", "-lc", gate_cmd], cwd=str(int_wt), text=True, capture_output=True, timeout=timeout_sec)
            elapsed = time.monotonic() - start
            st = "pass" if proc.returncode == 0 else "fail"
            ensure_dir(logs_dir(repo_root))
            (logs_dir(repo_root) / "INTEGRATION.log").write_text(f"# Final Gate\ncommit: {int_commit[:7]}\ncmd: {gate_cmd}\nexit: {proc.returncode}\nelapsed: {elapsed:.3f}s\n\n--- STDOUT ---\n{proc.stdout or ''}\n--- STDERR ---\n{proc.stderr or ''}\n", encoding="utf-8")
            integration_record["final_gate"] = {"cmd": gate_cmd, "status": st, "exit_code": proc.returncode, "elapsed_sec": round(elapsed, 3)}
    ensure_dir(repo_root / ".arena")
    (repo_root / ".arena" / "integration.json").write_text(json.dumps(integration_record, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"[integrate] done. integration worktree: {int_wt}")
    fg = integration_record.get("final_gate")
    if fg and fg.get("status") == "pass":
        print("[integrate] ✅ Final gate PASS.")
    elif fg and fg.get("status") == "fail":
        print("[integrate] ❌ Final gate FAIL.")
    return 0


def pipeline(repo_root: Path, cfg: Dict[str, Any], wait: bool, interval: int) -> int:
    if wait:
        print("[pipeline] Ready. Press Enter to run: gate → rank → integrate. Ctrl+C to cancel.")
        try:
            input()
        except KeyboardInterrupt:
            print("\n[pipeline] canceled.")
            return 130
    rc = run_gate_all(repo_root, cfg, watch=False, interval=interval, force=False)
    if rc != 0:
        return rc
    rc = run_rank(repo_root, cfg, watch=False, interval=interval)
    if rc != 0:
        return rc
    rc = integrate_winners(repo_root, cfg, reset=True, final_gate=True)
    return rc


def chunk(items: List[str], size: int) -> List[List[str]]:
    return [items[i : i + size] for i in range(0, len(items), size)]


def opencode_shell_snippet(agent: str, model: str, repo_root: Path, initial_prompt: Optional[str] = None) -> str:
    snippet = f'''set -e
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
export OPENCODE_CONFIG="{repo_root / 'opencode.json'}"
MODEL="${{OPENCODE_MODEL:-{model}}}"
HELP=$(opencode --help 2>/dev/null || true)
CMD="opencode"
if echo "$HELP" | grep -q -- '--agent'; then CMD="$CMD --agent {agent}"; fi
if echo "$HELP" | grep -q -- '--model'; then CMD="$CMD --model $MODEL"; fi
'''
    if initial_prompt:
        escaped = initial_prompt.replace("'", "'\\''").replace("\n", "\\n")
        snippet += f'''if echo "$HELP" | grep -q -- '--prompt'; then
  CMD="$CMD --prompt '{escaped}'"
fi
'''
    snippet += '''echo "[opencode] $CMD"
eval $CMD
'''
    return snippet


def pane(title: str, commands: List[str]) -> Dict[str, Any]:
    cmd0 = f"tmux select-pane -T '{title}' 2>/dev/null || true"
    return {"shell_command": [cmd0] + commands}


def generate_tmuxp(repo_root: Path, cfg: Dict[str, Any], session: str, out_path: Path, per_window: int, requirements_file: Optional[Path] = None) -> None:
    wt_dir = repo_root / cfg["worktrees_dir"]
    windows: List[Dict[str, Any]] = []
    planner_prompt = None
    if requirements_file and requirements_file.exists():
        req_content = requirements_file.read_text(encoding="utf-8")
        planner_prompt = f"以下の要件に基づいてアリーナ競争を開始してください。各チームにタスクを割り当て、最後まで自動で完走させてください。\\n\\n{req_content}"
    windows.append({"window_name": "planner", "layout": "even-horizontal", "panes": [pane("planner", [f"cd '{repo_root}'", opencode_shell_snippet(cfg["planner_agent"], cfg["model_codex"], repo_root, planner_prompt)])]})
    for t in cfg["tracks"]:
        key = t["key"]
        ids = team_ids(key, int(t["count"]))
        groups = chunk(ids, max(1, per_window))
        team_prompt = None
        if requirements_file and requirements_file.exists():
            req_content = requirements_file.read_text(encoding="utf-8")
            track_desc = {"A": "コア機能", "B": "データ層", "C": "API統合", "N": "テスト"}.get(key, "実装")
            team_prompt = f"あなたはTrack {key}（{track_desc}）の競争チームです。以下の要件から担当部分を実装してください。\\n\\n{req_content}"
        for gi, group in enumerate(groups, start=1):
            wname = f"comp-{key}" if len(groups) == 1 else f"comp-{key}-{gi}"
            panes = []
            for tid in group:
                wt = (wt_dir / tid).resolve()
                panes.append(pane(tid, [f"cd '{wt}'", opencode_shell_snippet(t["agent"], t["model"], repo_root, team_prompt)]))
            windows.append({"window_name": wname, "layout": "tiled", "panes": panes})
    windows.append({"window_name": "quality-gate", "layout": "even-horizontal", "panes": [pane("gate-watch", [f"cd '{repo_root}'", "export PATH=\"$HOME/.local/bin:$PATH\"", "python3 tools/gen_tmuxp.py gate --watch --interval 20"]), pane("qa-agent", [f"cd '{repo_root}'", opencode_shell_snippet(cfg.get("qa_agent", "qa-gate"), cfg["model_codex"], repo_root)])]})
    windows.append({"window_name": "ranking", "layout": "even-horizontal", "panes": [pane("rank-watch", [f"cd '{repo_root}'", "export PATH=\"$HOME/.local/bin:$PATH\"", "python3 tools/gen_tmuxp.py rank --watch --interval 20"]), pane("winners", [f"cd '{repo_root}'", "echo '[winners] .arena/winners.json'", "while true; do clear; date; echo; test -f .arena/winners.json && cat .arena/winners.json || echo '(no winners yet)'; sleep 5; done"])]})
    int_wt = (wt_dir / "INTEGRATION").resolve()
    windows.append({"window_name": "integration", "layout": "even-horizontal", "panes": [pane("integrate", [f"cd '{repo_root}'", "export PATH=\"$HOME/.local/bin:$PATH\"", "echo '[integrate] Run: python3 tools/gen_tmuxp.py integrate --reset --final-gate'", "bash"]), pane("integrator-agent", [f"cd '{int_wt}'", opencode_shell_snippet(cfg.get("integrator_agent", "integrator"), cfg["model_codex"], repo_root)])]})
    windows.append({"window_name": "pipeline", "layout": "even-horizontal", "panes": [pane("pipeline", [f"cd '{repo_root}'", "export PATH=\"$HOME/.local/bin:$PATH\"", "python3 tools/gen_tmuxp.py pipeline --wait"])]})
    tmuxp_conf: Dict[str, Any] = {"session_name": session, "start_directory": str(repo_root), "windows": windows}
    ensure_dir(out_path.parent)
    out_path.write_text(json.dumps(tmuxp_conf, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def start_arena(repo_root: Path, requirements: Optional[str], requirements_file: Optional[Path], n: int, gate_cmd: Optional[str], auto_pipeline: bool, model: str) -> int:
    ensure_dir(repo_root / ".arena")
    req_path = repo_root / ".arena" / "requirements.md"
    if requirements:
        req_path.write_text(f"# 要件定義\\n\\n{requirements}\\n", encoding="utf-8")
        print(f"[start] wrote requirements: {req_path}")
    elif requirements_file and requirements_file.exists():
        req_path.write_text(requirements_file.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"[start] copied requirements from: {requirements_file}")
    else:
        print("[start] WARNING: No requirements provided.")
        req_path = None
    base_ref = git_out(["rev-parse", "--abbrev-ref", "HEAD"], repo_root) or "main"
    if base_ref == "HEAD":
        base_ref = "main"

    @dataclass
    class Track:
        key: str
        count: int
        model: str
        agent: str

    tracks: List[Track] = [Track("A", n, model, "comp-a"), Track("B", n, model, "comp-b"), Track("C", n, model, "comp-c")]
    wt_dir = (repo_root / "worktrees").resolve()
    ensure_dir(wt_dir)
    sh(["git", "worktree", "prune"], cwd=repo_root, check=False)
    for t in tracks:
        for tid in team_ids(t.key, t.count):
            ensure_worktree(tid, repo_root, wt_dir, base_ref)
    integration_branch = "arena/integration"
    ensure_integration_worktree(repo_root, wt_dir, base_ref=base_ref, integration_branch=integration_branch)
    if not gate_cmd:
        gate_cmd = detect_gate_cmd(repo_root)
    cfg: Dict[str, Any] = {"repo_root": str(repo_root), "base_ref": base_ref, "worktrees_dir": "worktrees", "gate_cmd": gate_cmd, "gate_timeout_sec": 1800, "model_codex": model, "model_glm": model, "planner_agent": "central-planner", "qa_agent": "qa-gate", "integrator_agent": "integrator", "integration_branch": integration_branch, "tracks": [{"key": t.key, "count": t.count, "model": t.model, "agent": t.agent} for t in tracks], "generated_at": now_iso()}
    save_config(repo_root, cfg)
    out_path = (repo_root / ".tmuxp" / "arena.json").resolve()
    generate_tmuxp(repo_root, cfg, session="arena", out_path=out_path, per_window=5, requirements_file=req_path)
    print(f"[start] wrote tmuxp: {out_path}")
    print("[start] loading tmuxp session...")
    result = subprocess.run(["tmuxp", "load", "-d", str(out_path)], cwd=str(repo_root), text=True, capture_output=True)
    if result.returncode != 0:
        print(f"[start] WARNING: tmuxp load failed: {result.stderr}")
        print(f"[start] You can manually run: tmuxp load {out_path}")
    else:
        print("[start] ✅ tmuxp session 'arena' started. Attach with: tmux attach -t arena")
    if auto_pipeline:
        print("[start] auto-pipeline enabled. Running pipeline...")
        return pipeline(repo_root, cfg, wait=False, interval=20)
    return 0


@dataclass
class Track:
    key: str
    count: int
    model: str
    agent: str


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(add_help=True)
    sub = p.add_subparsers(dest="cmd")
    g = sub.add_parser("generate", help="create worktrees + tmuxp config")
    g.add_argument("--session", default="arena")
    g.add_argument("--out", default=".tmuxp/arena.json")
    g.add_argument("--worktrees-dir", default="worktrees")
    g.add_argument("--per-window", type=int, default=5)
    g.add_argument("--n", type=int, default=3)
    g.add_argument("--nA", type=int, default=None)
    g.add_argument("--nB", type=int, default=None)
    g.add_argument("--nC", type=int, default=None)
    g.add_argument("--nN", type=int, default=None)
    g.add_argument("--enable-N", action="store_true")
    g.add_argument("--base-ref", default=None)
    g.add_argument("--gate-cmd", default=None)
    g.add_argument("--gate-timeout", type=int, default=1800)
    g.add_argument("--model-codex", default=os.environ.get("OPENCODE_MODEL", "openai/gpt-5.2-codex"))
    g.add_argument("--model-glm", default=os.environ.get("OPENCODE_MODEL", "openai/gpt-5.2-codex"))
    g.add_argument("--planner-agent", default="central-planner")
    g.add_argument("--agent-a", default="comp-a")
    g.add_argument("--agent-b", default="comp-b")
    g.add_argument("--agent-c", default="comp-c")
    g.add_argument("--agent-n", default="comp-n")
    g.add_argument("--qa-agent", default="qa-gate")
    g.add_argument("--integrator-agent", default="integrator")
    g.add_argument("--requirements", default=None)
    g.add_argument("--auto-start", action="store_true")
    s = sub.add_parser("start", help="start arena with requirements")
    s.add_argument("--requirements", "-r", default=None)
    s.add_argument("--requirements-file", "-f", default=None)
    s.add_argument("--n", type=int, default=3)
    s.add_argument("--gate-cmd", default=None)
    s.add_argument("--auto-pipeline", action="store_true")
    s.add_argument("--model", default=os.environ.get("OPENCODE_MODEL", "openai/gpt-5.2-codex"))
    gate_p = sub.add_parser("gate", help="run Quality Gate")
    gate_p.add_argument("--watch", action="store_true")
    gate_p.add_argument("--interval", type=int, default=20)
    gate_p.add_argument("--force", action="store_true")
    rank_p = sub.add_parser("rank", help="rank teams")
    rank_p.add_argument("--watch", action="store_true")
    rank_p.add_argument("--interval", type=int, default=20)
    int_p = sub.add_parser("integrate", help="merge winners")
    int_p.add_argument("--reset", action="store_true")
    int_p.add_argument("--final-gate", action="store_true")
    pipe_p = sub.add_parser("pipeline", help="gate→rank→integrate")
    pipe_p.add_argument("--wait", action="store_true")
    pipe_p.add_argument("--interval", type=int, default=20)
    return p


def main(argv: List[str]) -> int:
    known = {"generate", "gate", "rank", "integrate", "pipeline", "start"}
    if len(argv) == 0:
        argv = ["generate"]
    elif argv[0] not in known:
        if argv[0].startswith("-"):
            argv = ["generate"] + argv
    repo_root = in_git_repo(Path.cwd())
    if not repo_root:
        print("ERROR: run inside a Git repository.", file=sys.stderr)
        return 2
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.cmd == "start":
        req_file = Path(args.requirements_file) if args.requirements_file else None
        return start_arena(repo_root, requirements=args.requirements, requirements_file=req_file, n=args.n, gate_cmd=args.gate_cmd, auto_pipeline=args.auto_pipeline, model=args.model)
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
        tracks: List[Track] = [Track("A", nA, args.model_codex, args.agent_a), Track("B", nB, args.model_codex, args.agent_b), Track("C", nC, args.model_codex, args.agent_c)]
        if args.enable_N:
            tracks.append(Track("N", nN, args.model_codex, args.agent_n))
        wt_dir = (repo_root / args.worktrees_dir).resolve()
        ensure_dir(wt_dir)
        sh(["git", "worktree", "prune"], cwd=repo_root, check=False)
        for t in tracks:
            for tid in team_ids(t.key, t.count):
                ensure_worktree(tid, repo_root, wt_dir, base_ref)
        integration_branch = "arena/integration"
        ensure_integration_worktree(repo_root, wt_dir, base_ref=base_ref, integration_branch=integration_branch)
        cfg: Dict[str, Any] = {"repo_root": str(repo_root), "base_ref": base_ref, "worktrees_dir": args.worktrees_dir, "gate_cmd": args.gate_cmd, "gate_timeout_sec": int(args.gate_timeout), "model_codex": args.model_codex, "model_glm": args.model_glm, "planner_agent": args.planner_agent, "qa_agent": args.qa_agent, "integrator_agent": args.integrator_agent, "integration_branch": integration_branch, "tracks": [{"key": t.key, "count": t.count, "model": t.model, "agent": t.agent} for t in tracks], "generated_at": now_iso()}
        if cfg["gate_cmd"] is None:
            auto = detect_gate_cmd(repo_root)
            if auto:
                cfg["gate_cmd"] = auto
        save_config(repo_root, cfg)
        req_path = Path(args.requirements) if args.requirements else None
        out_path = (repo_root / args.out).resolve()
        generate_tmuxp(repo_root, cfg, session=args.session, out_path=out_path, per_window=int(args.per_window), requirements_file=req_path)
        print(f"[generate] wrote tmuxp: {out_path}")
        print(f"[generate] wrote arena config: {config_path(repo_root)}")
        if args.auto_start:
            print("[generate] auto-start enabled. Loading tmuxp...")
            result = subprocess.run(["tmuxp", "load", "-d", str(out_path)], cwd=str(repo_root), text=True, capture_output=True)
            if result.returncode != 0:
                print(f"[generate] WARNING: tmuxp load failed: {result.stderr}")
            else:
                print("[generate] ✅ tmuxp session started. Attach with: tmux attach -t arena")
        else:
            print(f"[generate] next: tmuxp load {out_path}")
        return 0
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
