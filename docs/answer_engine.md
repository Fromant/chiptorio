# Chiptorio — Answer Engine

The Answer Engine is the endgame: a 5×5 machine that computes for 42 minutes to answer one question. It is the mod's victory condition.

## Behaviour

- It is a lab clone with no inputs; its 42-minute clock, GUI, scoring, and victory screen live in `scripts/answer_engine.lua`, not ordinary research.
- It consumes its item draw from QLN storage through `qln.consume`, never from its own inventory.
- The Question fails at stability 0. A pre-flight gate check runs at ~90% of every target; stability drains while any gate is unmet; stability 0 resets the run and loses part of the corpus.

## Debug commands (`chiptorio-answer`)

| Command | Description |
|---------|-------------|
| `status` | Logs engine state |
| `debug_complete` | Exercises victory and score path |
| `evaluate <tech>` | Returns gate, score, victory as a table |
| `boot` | Starts the 42-minute clock |
| `step <seconds>` | Advances the clock without waiting for ticks |

## Tick order

`answer_engine.tick()` runs first in the single `script.on_nth_tick(60)` dispatcher, so the 42-minute clock, GUI, scoring, and victory are updated before network, qualification, QLN, research, and AI.
