---
description: Arena Competition System (N=1) - 3チームで並列競争
---

# Arena Competition System 起動

以下のコマンドを実行してArena Competition Systemを起動します：

!`~/.config/opencode/tools/arena-launcher.sh -n 1 "$ARGUMENTS" 2>&1`

## 構成

- **N = 1**（3チーム）
- comp-A-1（コア機能実装）
- comp-B-1（データ層・インフラ）
- comp-C-1（API設計・統合）
- qa-gate（品質評価）
- integrator（最終統合）

## 確認方法

別のターミナルで：
```bash
tmux attach -t arena
```

## ステータス確認

```bash
~/.config/opencode/tools/arena-recover.sh status
```

## エージェント復旧

```bash
# 待機中のエージェントを起こす
~/.config/opencode/tools/arena-recover.sh wake comp-A-1

# エラー状態のエージェントを再起動
~/.config/opencode/tools/arena-recover.sh restart comp-B-1
```
