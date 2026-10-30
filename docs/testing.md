# Chiptorio — Testing

There is no build, lint, typecheck, or test-runner step. Verification is
headless Factorio.

## Test log markers

All probe output uses these markers in `factorio-current.log`:

```
CHIPTORIO-TEST PASS <suite>
CHIPTORIO-TEST FAIL <suite>
CHIPTORIO-TEST SKIP <suite>
```

The PowerShell wrappers scan the log for `PASS` markers and fail on `FAIL`.
A new suite must add a marker and a matching assertion in the PowerShell
wrapper. Keep `unit_harness.finish` after all unit specs: calling it inside one
spec hides later failures.

## Test scripts

| Script | Purpose | Notes |
|--------|---------|-------|
| `tools\test-mod.ps1` | Smoke test: load, create map, run benchmark | Fastest check |
| `tools\test-contract.ps1` | Data contract + runtime probe | Benchmark, no player |
| `tools\test-save-load.ps1` | P1.2 save/load | Hosted server + reload benchmark |
| `tools\test-power-grid.ps1` | P1.7 Construction Core on a real grid | Hosted server only |
| `tools\test-perf.ps1` | P1.5 tick-time performance harness | Benchmark with timing parse |
| `tools\test-registration.ps1` | P1.8 static registration audit | No Factorio needed |
| `tools\test-all.ps1` | All of the above | Aggregate runner |

## Benchmark limitations

`--benchmark` raises all `on_nth_tick`/`on_tick` handlers only at tick 0 and
does not dispatch script events for later ticks. Therefore multi-tick checks
(power grid, save/load build phase) must run on a real headless server
(`--start-server`), not a benchmark.

A `--create` map has no player and Factorio 2.1 has no `game.create_player`,
so GUI paths are not automatable in benchmarks. The probe logs
`CHIPTORIO-TEST SKIP qln-gui` and `CHIPTORIO-TEST SKIP computer-gui` and skips
those checks. To exercise them, enable `tools/test-probe` as a second mod in a
normal save that has a character.

## Probe structure

`tools/test-probe/` is a separate mod that loads after chiptorio:

- `data.lua` — requires all unit specs, calls `unit_harness.finish("unit")`
- `data-updates.lua` — data-stage contract assertions (icons, locale,
  reachable techs, no softlock, infinite prereqs, QLN cells, cable shapes)
- `control.lua` — runtime suites: force-isolation, power-grid, qualification,
  QLN, answer, AI, computer GUI, playthrough
- `unit_harness.lua` — minimal assertion harness for pure-Lua unit tests

Every `scripts/*.lua` module must be explicitly required from a load-stage
entrypoint; the directory is not auto-loaded.

## Required PASS markers

The wrapper (`test-all.ps1`) requires:

- `PASS unit` — unit specs (93 cases)
- `PASS data` — data contract
- `PASS runtime` — runtime integration
- `PASS force-isolation` — force isolation
- `PASS power-grid` — Construction Core on a real grid
- `PASS playthrough` — scripted playthrough

## Suggested verification order

All P0 mechanics are implemented. Remaining P1 work:

1. **P1.2 save/load** — automated via `test-save-load.ps1`
2. **P1.4 determinism** — code review (no non-deterministic `pairs()` in render/state paths)
3. **P1.5 perf** — automated via `test-perf.ps1`
4. **P1.6 player/GUI** — not automatable (no `game.create_player` in 2.1)
5. **P1.7 power grid** — automated via `test-power-grid.ps1`
6. **P1.8 registration audit** — automated via `test-registration.ps1`
7. **P1.9 locale translations** — automated via `data-updates.lua`

P2 items (documentation drift, naming consistency) are tracked separately.
