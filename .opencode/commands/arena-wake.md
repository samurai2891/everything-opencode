---
description: Arena Competition System - 待機中のエージェントを起こす
---

# Arena Wake

待機中またはエラー状態のエージェントを起こします：

!`~/.config/opencode/tools/arena-recover.sh wake "$ARGUMENTS" 2>&1`

## 使用方法

```
/arena-wake <agent-name>
```

## 例

```
/arena-wake comp-A-1
/arena-wake comp-B-2
/arena-wake qa-gate
/arena-wake integrator
```

## エージェント名一覧

- planner
- comp-A-1, comp-A-2, ... (N数に応じて)
- comp-B-1, comp-B-2, ...
- comp-C-1, comp-C-2, ...
- qa-gate
- integrator
