# Chiptorio — Runtime Architecture

## Runtime entry point (`control.lua`)

`control.lua` owns the single `script.on_nth_tick(60)` dispatcher and the
`on_init` / `on_configuration_changed` handlers. Modules expose plain
functions; they must not register `script.on_event`, `script.on_nth_tick`,
`script.on_init`, `script.on_configuration_changed`, or `remote.add_interface`
themselves — Factorio keeps one handler per event, so a later registration
silently replaces an earlier one.

Remote interfaces are registered once in `control.lua`:
- `chiptorio-network` — status, topology, overlay
- `chiptorio-research` — status, evaluate, step, infinite, multipliers
- `chiptorio-qualification` — status, state, evaluate, step
- `chiptorio-ai` — status, set_model, install_model, uninstall_model, tick, insight

`answer_engine` and `qln_runtime` register their own interfaces
(`chiptorio-answer`, `chiptorio-qln`); `control.lua` guards those with
`if not remote.interfaces[...]` so it never replaces them.

## Tick dispatcher

```lua
script.on_nth_tick(60, function()
  answer_engine.tick()      -- 42-minute clock, GUI, scoring, victory
  network.tick()            -- graph rebuild (max once/sec), module polling
  qualification.tick()      -- per-force half-node qualification
  qln.tick()                -- QLN transport loop (once/sec per group)
  research.tick()           -- pure allocator, lab pausing, decay
  ai.tick()                 -- training/inference, consume from QLN
end)
```

Network runs first so qualification, QLN and the allocator read the freshly
rebuilt graph. Qualification can complete a half-node and mark the graph dirty,
so it runs before research. QLN runs after the graph. AI runs last so it can
consume from QLN storage and read final network capacities.

## Module responsibilities

| Module | Pure? | Touches entities/storage? | Notes |
|--------|-------|---------------------------|-------|
| `scripts/runtime/network_graph.lua` | Yes | No | Pure topology maths; unit-tested across mods |
| `scripts/runtime/network_runtime.lua` | No | Yes | Chunk index, cached graph, polling, overlay, monitor |
| `scripts/runtime/research_alloc.lua` | Yes | No | Pure allocator |
| `scripts/runtime/research_runtime.lua` | No | Yes | Only research module touching entities/storage |
| `scripts/runtime/qualification_alloc.lua` | Yes | No | Pure qualification allocator |
| `scripts/runtime/qualification_runtime.lua` | No | Yes | Only qualification module touching entities/storage |
| `scripts/runtime/qln_transport.lua` | Yes | No | Pure storage maths |
| `scripts/runtime/qln_runtime.lua` | No | Yes | Only QLN module touching entities/storage |
| `scripts/runtime/ai_runtime.lua` | No | Yes | Training/inference, consumes from QLN |
| `scripts/answer_engine.lua` | No | Yes | 42-minute clock, GUI, scoring, victory |

## Network

- A machine connects only if adjacent to a cable/switch tile or within a
  router's 16-tile wireless reach.
- Cables form raw segments by 4-way adjacency; switches merge segments;
  routers bridge segments.
- Segment bandwidth is the weakest cable tier present (weakest-link rule).
- Cables collide with everything (`collision_layer = object`,
  `collision_mask = object`).
- `network_runtime` rebuilds at most once per second. Provider module polling
  uses signature comparison once per second.

## Research

- Labs are paused with `disabled_by_script`, never deleted.
- Compute, memory and bandwidth are network-level capacities; chip and cooling
  efficiency are provider properties (folded into provider descriptors).
- Decay is at most 2% of `LuaForce.research_progress` per minute.
- Memory, bandwidth and cooling shortfalls are hard stops. Pure compute or
  power shortfall decays proportionally.
- Profiles are shares — surplus of one compute kind cannot cover another.

## Qualification

- Per-force state in `storage.qualification.forces[force_index]`
  (`qualified`, `samples`).
- A qualified yield bonus is an absolute `force.recipes[name].productivity_bonus`
  on the refined node's wafer and die recipes (`allow_productivity = true`).
- Compute and power bonuses go through `network.set_chip_multipliers`, which
  must mark the graph dirty. Memory capacity and backplane bandwidth are
  hardware and must never be scaled by a refinement.

## QLN

- Storage is per Storage Drive (`storage.qln.drives[unit_number]`); capacity
  comes from memory modules in drives.
- Quantum Entanglement Cores pair in unit-number order and union their
  networks into one storage group.
- The Construction Core is an **accumulator clone**, not a lab clone: an idle
  lab core sits at zero energy, while an accumulator's charge refills from the
  grid and `entity.energy` is writable as the work budget.
- `LuaEntity.mine` in 2.1 takes `force` as a boolean — call it with
  `{ inventory = inventory }` only.

## Answer Engine

- Lab clone with no inputs; its 42-minute clock, GUI, scoring, and victory
  screen live in `scripts/answer_engine.lua`, not ordinary research.
- Consumes its item draw from QLN storage through `qln.consume`, never from
  its own inventory.

## Persistence

Persist runtime state in `storage`, initialized from `on_init` and
`on_configuration_changed`, never in module globals.
