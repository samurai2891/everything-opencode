---
description: Arena Competition System (N=4) - 12チームで並列競争
---

# Arena Competition System 起動

以下のコマンドを実行してArena Competition Systemを起動します：

!`~/.config/opencode/tools/arena-launcher.sh -n 4 "$ARGUMENTS" 2>&1`

## 構成

- **N = 4**（12チーム）
- comp-A-1〜4（コア機能実装）
- comp-B-1〜4（データ層・インフラ）
- comp-C-1〜4（API設計・統合）
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
