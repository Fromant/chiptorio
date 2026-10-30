# Chiptorio — Debug Hooks

## Remote interfaces

| Interface | Command | Description |
|-----------|---------|-------------|
| `chiptorio-answer` | `status` | Logs engine state |
| | `debug_complete` | Exercises victory and score path |
| | `evaluate <tech>` | Returns gate, score, victory as a table |
| | `boot` | Starts the 42-minute clock |
| | `step <seconds>` | Advances the clock without waiting for ticks |
| `chiptorio-network` | `status` | Logs per-surface cable, segment, network counts |
| | `topology <surface>` | Returns the same numbers as a table |
| | `overlay <bool>` | Sets the overlay without a keypress |
| `chiptorio-research` | `status` | Logs current tech's gate, decay, active labs |
| | `evaluate <tech>` | Returns gate/decay/active labs as a table; applies lab pausing |
| | `step <seconds>` | Advances decay without waiting for ticks |
| | `infinite <force>` | Returns infinite-research levels for a force |
| | `multipliers <force>` | Returns allocator multiplier table for a force |
| `chiptorio-qualification` | `status` | Logs every researched half-node's batch, support, reason |
| | `state` | Returns qualified keys and sample counts |
| | `evaluate <key>` | Inspects one half-node without changing it |
| | `step <seconds>` | Advances qualification without waiting for ticks |
| `chiptorio-qln` | `status` | Logs every group's drives, items, capacity, nodes |
| | `state <force>` | Returns the same as a table |
| | `deposit <force> <surface> <network> <item> <count>` | Moves items without a node |
| | `withdraw ...` | Moves items without a node |
| | `step <seconds>` | Runs the transfer loop |
| | `group_status <entity>` | Inspects one entity's pool |
| | `set_foup_mode <entity> <seal\|unseal>` | Switches a dock for headless tests |

## In-game shortcuts

- `ALT + N` — toggles the network overlay
- Monitor shortcut — opens the same window as a placed monitor

## Custom inputs

Custom inputs cannot be raised from script, so the network overlay and other
debug hooks go through remote interfaces instead of faking a keypress.
