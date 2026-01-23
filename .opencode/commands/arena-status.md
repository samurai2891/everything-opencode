---
description: Arena Competition System - ステータス確認
---

# Arena Status

現在のArenaセッションのステータスを確認します：

!`~/.config/opencode/tools/arena-recover.sh status 2>&1`

## 復旧コマンド

### 待機中のエージェントを起こす

```bash
~/.config/opencode/tools/arena-recover.sh wake <agent-name>
```

例：
```bash
~/.config/opencode/tools/arena-recover.sh wake comp-A-1
~/.config/opencode/tools/arena-recover.sh wake qa-gate
```

### エラー状態のエージェントを再起動

```bash
~/.config/opencode/tools/arena-recover.sh restart <agent-name>
```

### ステータスをリセット

```bash
~/.config/opencode/tools/arena-recover.sh reset <agent-name> [new-status]
```

### キックメッセージを送信

```bash
~/.config/opencode/tools/arena-recover.sh kick <agent-name> "メッセージ"
```
