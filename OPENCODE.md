# Arena Competition System - Opencode Agent Instructions

このドキュメントは、Arena Competition System で動作する Opencode エージェントのための指示書です。
[Tmux-Orchestrator](https://github.com/Jedward23/Tmux-Orchestrator) の CLAUDE.md を参考に作成しました。

## 概要

Arena Competition System は、複数の Opencode エージェントが並列で競争しながらタスクを実行するシステムです。

### アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                    Arena Session (tmux)                      │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐        │
│  │ Planner │  │ comp-A  │  │ comp-B  │  │ comp-C  │        │
│  │         │  │         │  │         │  │         │        │
│  │ タスク  │  │ コア    │  │ データ  │  │ API     │        │
│  │ 分解    │  │ 機能    │  │ 層      │  │ 設計    │        │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘        │
│                                                              │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐                     │
│  │ QA Gate │  │Integrator│  │ Monitor │                     │
│  │         │  │         │  │         │                     │
│  │ 品質    │  │ 統合    │  │ 監視    │                     │
│  │ 評価    │  │ 担当    │  │         │                     │
│  └─────────┘  └─────────┘  └─────────┘                     │
└─────────────────────────────────────────────────────────────┘
```

## エージェントの役割

### Planner（中央プランナー）
- 要件を分析してタスクを分解
- 3つのタスクファイルを作成（task-A.md, task-B.md, task-C.md）
- 完了後に `planner.status` を `ready` に更新

### Competitors（競争チーム）
- **comp-A**: コア機能実装
- **comp-B**: データ層・インフラ
- **comp-C**: API設計・統合
- Plannerの準備完了を待ってから作業開始
- 完了後に自身のステータスを `submitted` に更新

### QA Gate（品質評価）
- 全チームの提出を待機
- 各チームの実装を評価
- 最優秀チームを選定
- 完了後に `qa-gate.status` を `done` に更新

### Integrator（統合担当）
- QA Gateの評価完了を待機
- 最終成果物を作成
- 完了後に `integrator.status` を `done` に更新

## ディレクトリ構造

```
.arena/
├── requirements.md          # 元の要件
├── status/                  # ステータスファイル
│   ├── planner.status
│   ├── comp-A-1.status
│   ├── comp-B-1.status
│   ├── comp-C-1.status
│   ├── qa-gate.status
│   └── integrator.status
├── tasks/                   # タスク定義
│   ├── task-A.md
│   ├── task-B.md
│   └── task-C.md
├── submissions/             # 各チームの提出物
│   ├── comp-A-1/
│   ├── comp-B-1/
│   └── comp-C-1/
├── evaluations/             # 評価結果
│   └── evaluation.md
├── final/                   # 最終成果物
│   └── integrated/
├── prompts/                 # プロンプトファイル
└── logs/                    # ログファイル
```

## ステータス遷移

### Planner
```
initializing → ready
```

### Competitors
```
waiting → working → submitted
```

### QA Gate
```
waiting → evaluating → done
```

### Integrator
```
waiting → integrating → done
```

## 重要なルール

### 1. 自律的に進行する
- ユーザーに質問しない
- 不明点は合理的に推測して進める
- エラーが発生したら自分で解決を試みる

### 2. ステータスファイルを必ず更新する
```bash
# 作業開始時
echo "working" > .arena/status/comp-A-1.status

# 完了時
echo "submitted" > .arena/status/comp-A-1.status
```

### 3. 他のエージェントの完了を待つ
```bash
# Plannerの準備完了を確認
cat .arena/status/planner.status
# "ready" になるまで待機

# 全チームの提出完了を確認
for f in .arena/status/comp-*.status; do cat $f; done
# 全て "submitted" になるまで待機
```

### 4. 指定されたディレクトリで作業する
- Competitors: `.arena/submissions/comp-X-N/`
- Integrator: `.arena/final/integrated/`

## トラブルシューティング

### エージェントが動かない場合

1. **ウィンドウに移動**
   ```
   Ctrl+b, 番号
   ```

2. **出力を確認**
   - エラーメッセージがないか確認
   - Opencodeが正しく起動しているか確認

3. **手動でコマンドを入力**
   ```bash
   cat .arena/status/planner.status
   ```

4. **メッセージを送信**
   ```bash
   ~/.config/opencode/tools/send-opencode-message.sh arena:comp-A-1 "続行してください"
   ```

### ステータスが更新されない場合

1. **ステータスファイルを確認**
   ```bash
   cat .arena/status/エージェント名.status
   ```

2. **手動で更新**
   ```bash
   echo "ready" > .arena/status/planner.status
   ```

### タイムアウトした場合

1. **エージェントを起こす**
   ```bash
   ~/.config/opencode/tools/send-opencode-message.sh arena:エージェント名 "タイムアウトしました。続行してください。"
   ```

## ベストプラクティス

### Tmux操作

```bash
# セッションにアタッチ
tmux attach -t arena

# ウィンドウ切り替え
Ctrl+b, n     # 次のウィンドウ
Ctrl+b, p     # 前のウィンドウ
Ctrl+b, 0-9   # 番号でウィンドウ選択

# ペイン切り替え（N>=2の場合）
Ctrl+b, ↑↓    # ペイン間移動
Ctrl+b, o     # 次のペインへ

# ウィンドウの出力をキャプチャ
tmux capture-pane -t arena:planner -p | tail -50
```

### メッセージ送信

```bash
# 専用スクリプトを使用（推奨）
~/.config/opencode/tools/send-opencode-message.sh arena:planner "メッセージ"

# 手動で送信する場合（非推奨）
tmux send-keys -t arena:planner -- "メッセージ"
sleep 0.5
tmux send-keys -t arena:planner Enter
```

### ステータス監視

```bash
# 全ステータスを表示
for f in .arena/status/*.status; do
    printf "%-20s: %s\n" "$(basename $f .status)" "$(cat $f)"
done

# 特定のステータスを持つエージェント数をカウント
grep -l "submitted" .arena/status/comp-*.status | wc -l
```

## 参考リンク

- [Tmux-Orchestrator](https://github.com/Jedward23/Tmux-Orchestrator)
- [Opencode Documentation](https://opencode.ai/docs/)
- [everything-opencode Repository](https://github.com/samurai2891/everything-opencode)
