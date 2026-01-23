---
description: Arena Competition System (N=3) - 9チームで並列競争
---

# Arena Competition System 起動

以下のコマンドを実行してArena Competition Systemを起動します：

!`~/.config/opencode/tools/arena-launcher.sh -n 3 "$ARGUMENTS" 2>&1`

## 構成

- **N = 3**（9チーム）
- comp-A-1, comp-A-2, comp-A-3（コア機能実装）
- comp-B-1, comp-B-2, comp-B-3（データ層・インフラ）
- comp-C-1, comp-C-2, comp-C-3（API設計・統合）
- qa-gate（品質評価）
- integrator（最終統合）

## レイアウト

各comp-A/B/Cが1ウィンドウにまとめられ、3つのペインで表示されます。

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
