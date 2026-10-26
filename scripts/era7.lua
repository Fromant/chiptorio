-- Era 7: superconductors, cryogenics, qubits, error correction and quantum
-- processors.
--
-- The chain is intentionally a supply chain, not a science-pack reskin:
--   Chemistry      copper + steel + acid -> superconductor
--   Cooling Tower  water + steam + coolant -> cryogen
--   Quantum Fab    qubit -> error-corrected qubit -> quantum processor
--   Quantum Fab    qubit + cryogen -> qubit array (the seventh workload)
--
-- The Qubit Array recipe uses only *physical* qubits. Error correction is
-- unlocked by a technology that costs Qubit Arrays, so it must not require
-- error-corrected qubits or the tech would be circular.

local M = require("scripts.util")

-- Niobium-titanium is not a Factorio material, so the recipe abstracts the
-- whole class of low-temperature superconductors as copper, steel and acid.
M.recipe({
  name = "superconductor",
  enabled = false,
  category = "chemistry",
  energy_required = 10,
  ingredients = {
    M.item("copper-plate", 4),
    M.item("steel-plate", 1),
    M.fluid("sulfuric-acid", 10),
  },
  results = { M.item("superconductor", 2) },
})

-- Coolant chilled below the point where the qubits stop arguing with the
-- room. The Cooling Tower is already part of the Era 5 line, so this is a
-- second use for the same building. Two fluid inputs at most: the chemical
-- plant shell only has two input boxes.
M.recipe({
  name = "cryogen",
  enabled = false,
  category = "chiptorio-cooling",
  energy_required = 6,
  ingredients = {
    M.fluid("coolant", 50),
    M.fluid("water", 50),
  },
  results = { M.fluid("cryogen", 50) },
})

-- A physical qubit: one superconducting loop, one VLSI die to control it.
M.recipe({
  name = "qubit",
  enabled = false,
  category = "chiptorio-quantum",
  energy_required = 20,
  ingredients = {
    M.item("superconductor", 2),
    M.item("vlsi-die", 2),
    M.fluid("cryogen", 10),
  },
  results = { M.item("qubit", 1) },
})

-- Nine physical qubits per logical qubit is the surface-code rule of thumb.
M.recipe({
  name = "error-corrected-qubit",
  enabled = false,
  category = "chiptorio-quantum",
  energy_required = 30,
  ingredients = {
    M.item("qubit", 9),
    M.item("superconductor", 2),
    M.fluid("cryogen", 20),
  },
  results = { M.item("error-corrected-qubit", 1) },
})

-- Several logical qubits plus their control electronics in one package.
M.recipe({
  name = "quantum-processor",
  enabled = false,
  category = "chiptorio-quantum",
  energy_required = 40,
  ingredients = {
    M.item("error-corrected-qubit", 4),
    M.item("superconductor", 4),
    M.item("low-k-dielectric", 2),
    M.fluid("cryogen", 20),
  },
  results = { M.item("quantum-processor", 1) },
})

-- The seventh workload. Four physical qubits become four research units;
-- the Cryostat consumes them while it works.
M.recipe({
  name = "quantum-science-pack",
  enabled = false,
  category = "chiptorio-quantum",
  energy_required = 16,
  ingredients = {
    M.item("qubit", 4),
    M.fluid("cryogen", 10),
  },
  results = { M.item("quantum-science-pack", 4) },
})
