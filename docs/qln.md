# Chiptorio — QLN (Quantum Logistics Network)

QLN is an AE2-like item logistics network that replaces robots and the vanilla logistic system. It is built from entities, cables, switches, routers, storage drives, and import/export/provider/requester nodes.

## Entities

- **QLN Import Node** — pulls items from the network into the local system (direction: IN).
- **QLN Export Node** — pushes items from the local system into the network (direction: OUT).
- **QLN Provider Node** — supplies items to the network; outgoing arcs on the right.
- **QLN Requester Node** — requests items from the network; incoming arcs on the left.
- **QLN Terminal** — kiosk for inspecting and moving items; card reader on the right.
- **QLN Storage Drive** — rack-mount drive; capacity comes from memory modules installed in it.
- **FOUP Dock** — container with seal/unseal mode; deliberately absent from `QLN_NODE_NAMES` in `qln_runtime.lua`; uses `dock_accepts` / `dock_outputs` for mode-aware direction.

## Architecture

- `scripts/runtime/qln_transport.lua` is pure: storage maths only, no `game`, no `storage`, no prototypes.
- `scripts/runtime/qln_runtime.lua` is the only QLN module that touches entities and `storage`.
- Storage is per Storage Drive (`storage.qln.drives[unit_number]`); capacity comes from installed memory modules.
- Quantum Entanglement Cores pair in unit-number order and union their networks into one storage group.
- The Construction Core is an accumulator clone, not a lab clone: an idle lab core sits at zero energy, while an accumulator's charge refills from the grid and `entity.energy` is writable as the work budget.

## Debug commands (`chiptorio-qln`)

| Command | Description |
|---------|-------------|
| `status` | Logs every group's drives, items, capacity, nodes |
| `state <force>` | Returns the same as a table |
| `deposit <force> <surface> <network> <item> <count>` | Moves items without a node |
| `withdraw ...` | Moves items without a node |
| `step <seconds>` | Runs the transfer loop |
| `group_status <entity>` | Inspects one entity's pool |
| `set_foup_mode <entity> <seal\|unseal>` | Switches a dock for headless tests |

## Constraints

- Cables collide with everything; they cannot be placed on machines or belts, and nothing can be placed on them.
- Switches merge cable segments; routers bridge segments and act as WiFi access points with 16-tile reach.
- Segment bandwidth is the weakest cable tier present (weakest-link rule).
- `LuaEntity.mine` in 2.1 takes `force` as a boolean — call it with `{ inventory = inventory }` only.
