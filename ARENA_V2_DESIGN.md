# Arena Competition System v2 設計書

## 概要

Arena Competition Systemは、複数のLLMエージェントを並列で動作させ、競争的に開発を行うシステムです。v2では以下の機能を追加しました：

- **N数管理**: チーム数を柔軟に設定可能
- **ペイン分割**: N≥2の場合、同じ役割のチームを1ウィンドウにまとめて表示
- **同期機能**: ステータスファイルによるエージェント間の同期
- **監視機能**: monitorウィンドウでリアルタイムにステータスを確認
- **復旧機能**: 待機中・エラー状態のエージェントを復旧

## コマンド一覧

| コマンド | N数 | チーム数 | 説明 |
|---------|-----|---------|------|
| `/arena` | 1 | 3 | 基本構成 |
| `/arena2` | 2 | 6 | 2倍構成 |
| `/arena3` | 3 | 9 | 3倍構成 |
| `/arena4` | 4 | 12 | 4倍構成 |
| `/arena5` | 5 | 15 | 5倍構成 |
| `/arena-status` | - | - | ステータス確認 |
| `/arena-wake` | - | - | エージェント復旧 |

## アーキテクチャ

### N=1の場合

```
┌─────────────────────────────────────────────────────────────┐
│                         planner                             │
├─────────────────────────────────────────────────────────────┤
│    comp-A-1    │    comp-B-1    │    comp-C-1              │
├─────────────────────────────────────────────────────────────┤
│         qa-gate         │         integrator               │
├─────────────────────────────────────────────────────────────┤
│                         monitor                             │
└─────────────────────────────────────────────────────────────┘
```

### N≥2の場合（ペイン分割）

```
┌─────────────────────────────────────────────────────────────┐
│                         planner                             │
├─────────────────────────────────────────────────────────────┤
│ Window: comp-A  │ Window: comp-B  │ Window: comp-C         │
│ ┌─────────────┐ │ ┌─────────────┐ │ ┌─────────────┐        │
│ │  comp-A-1   │ │ │  comp-B-1   │ │ │  comp-C-1   │        │
│ ├─────────────┤ │ ├─────────────┤ │ ├─────────────┤        │
│ │  comp-A-2   │ │ │  comp-B-2   │ │ │  comp-C-2   │        │
│ ├─────────────┤ │ ├─────────────┤ │ ├─────────────┤        │
│ │    ...      │ │ │    ...      │ │ │    ...      │        │
│ └─────────────┘ │ └─────────────┘ │ └─────────────┘        │
├─────────────────────────────────────────────────────────────┤
│         qa-gate         │         integrator               │
├─────────────────────────────────────────────────────────────┤
│                         monitor                             │
└─────────────────────────────────────────────────────────────┘
```

## ディレクトリ構造

```
.arena/
├── requirements.md          # 要件
├── status/                  # ステータスファイル
│   ├── planner.status
│   ├── comp-A-1.status
│   ├── comp-A-2.status
│   ├── comp-B-1.status
│   ├── comp-B-2.status
│   ├── comp-C-1.status
│   ├── comp-C-2.status
│   ├── qa-gate.status
│   └── integrator.status
├── tasks/                   # タスク定義
│   ├── task-A.md
│   ├── task-B.md
│   └── task-C.md
├── submissions/             # 各チームの提出物
│   ├── comp-A-1/
│   ├── comp-A-2/
│   ├── comp-B-1/
│   ├── comp-B-2/
│   ├── comp-C-1/
│   └── comp-C-2/
├── evaluations/             # QA評価結果
│   └── evaluation.md
├── final/                   # 最終成果物
│   └── integrated/
└── prompts/                 # 各エージェントのプロンプト
    ├── planner.txt
    ├── comp-A-1.txt
    ├── comp-A-2.txt
    ├── comp-B-1.txt
    ├── comp-B-2.txt
    ├── comp-C-1.txt
    ├── comp-C-2.txt
    ├── qa-gate.txt
    └── integrator.txt
```

## ステータス遷移

### Planner
```
initializing → ready
```

### Competitor (comp-A/B/C)
```
waiting → working → submitted
                  → error
```

### QA Gate
```
waiting → evaluating → done
```

### Integrator
```
waiting → integrating → done
```

## 同期メカニズム

各エージェントはステータスファイルを監視して、適切なタイミングで動作を開始します：

1. **Planner**: 起動後すぐにタスク分解を開始
2. **Competitor**: `planner.status` が `ready` になるまで待機
3. **QA Gate**: 全 `comp-*.status` が `submitted` になるまで待機
4. **Integrator**: `qa-gate.status` が `done` になるまで待機

## 復旧機能

### arena-recover.sh

```bash
# ステータス確認
~/.config/opencode/tools/arena-recover.sh status

# 待機中のエージェントを起こす
~/.config/opencode/tools/arena-recover.sh wake comp-A-1

# エラー状態のエージェントを再起動
~/.config/opencode/tools/arena-recover.sh restart comp-B-2

# ステータスをリセット
~/.config/opencode/tools/arena-recover.sh reset comp-C-1 waiting

# キックメッセージを送信
~/.config/opencode/tools/arena-recover.sh kick qa-gate "評価を開始してください"
```

## 使用方法

### 基本的な使い方

```bash
# Opencodeを起動
opencode

# /arenaコマンドを実行（N=1）
/arena 3Dブロック崩しゲームを作成してください

# N=2で実行
/arena2 3Dブロック崩しゲームを作成してください
```

### tmuxセッションの確認

```bash
# セッションにアタッチ
tmux attach -t arena

# ウィンドウ切り替え
Ctrl+b, n     # 次のウィンドウ
Ctrl+b, p     # 前のウィンドウ
Ctrl+b, 0-9   # 番号でウィンドウ選択

# ペイン切り替え（N≥2の場合）
Ctrl+b, ↑↓    # ペイン間移動
Ctrl+b, o     # 次のペインへ
```

## ファイル一覧

| ファイル | 説明 |
|---------|------|
| `tools/arena-launcher.sh` | メインランチャースクリプト |
| `tools/arena-recover.sh` | 復旧・監視ツール |
| `.opencode/commands/arena.md` | /arenaコマンド（N=1） |
| `.opencode/commands/arena2.md` | /arena2コマンド（N=2） |
| `.opencode/commands/arena3.md` | /arena3コマンド（N=3） |
| `.opencode/commands/arena4.md` | /arena4コマンド（N=4） |
| `.opencode/commands/arena5.md` | /arena5コマンド（N=5） |
| `.opencode/commands/arena-status.md` | /arena-statusコマンド |
| `.opencode/commands/arena-wake.md` | /arena-wakeコマンド |

## 注意事項

1. **リソース**: N数が増えると、同時に動作するエージェント数も増えます。十分なリソースを確保してください。
2. **API制限**: 多数のエージェントが同時に動作すると、API制限に達する可能性があります。
3. **ネットワーク**: 安定したネットワーク環境で実行してください。
