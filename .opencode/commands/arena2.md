---
description: Arena Competition System (N=2) - 6チームで並列競争
---

# Arena Competition System 起動

以下のコマンドを実行してArena Competition Systemを起動します：

!`~/.config/opencode/tools/arena-launcher.sh -n 2 "$ARGUMENTS" 2>&1`

## 構成

- **N = 2**（6チーム）
- comp-A-1, comp-A-2（コア機能実装）
- comp-B-1, comp-B-2（データ層・インフラ）
- comp-C-1, comp-C-2（API設計・統合）
- qa-gate（品質評価）
- integrator（最終統合）

## レイアウト

N=2以上では、各comp-A/B/Cが1ウィンドウにまとめられ、ペイン分割で表示されます。

```
┌───────────────────────────────────────────────────────────────┐
│                         planner                               │
├───────────────────────────────────────────────────────────────┤
│ Window: comp-A          │ Window: comp-B      │ Window: comp-C│
│ ┌─────────────────────┐ │ ┌─────────────────┐ │ ┌───────────┐ │
│ │     comp-A-1        │ │ │    comp-B-1     │ │ │ comp-C-1  │ │
│ ├─────────────────────┤ │ ├─────────────────┤ │ ├───────────┤ │
│ │     comp-A-2        │ │ │    comp-B-2     │ │ │ comp-C-2  │ │
│ └─────────────────────┘ │ └─────────────────┘ │ └───────────┘ │
├───────────────────────────────────────────────────────────────┤
│           qa-gate                   │        integrator        │
└─────────────────────────────────────┴───────────────────────────┘
```

## 確認方法

別のターミナルで：
```bash
tmux attach -t arena
```

## ペイン切り替え

```
Ctrl+b, ↑↓    ペイン間移動
Ctrl+b, o     次のペインへ
```

## ステータス確認

```bash
~/.config/opencode/tools/arena-recover.sh status
```
