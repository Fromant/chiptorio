-- Technologies with a *sustained throughput* requirement.
--
-- `item` is measured as production (not consumption) over a rolling window.
-- `rate` is items per second the factory must keep producing while the
-- research is running. This is read by both the data stage (for tooltips)
-- and the runtime (for enforcement), so keep it pure data.

return {
  ["photolithography"] = {
    item = "logistic-science-pack", -- punched tape
    rate = 3,
    note = "A single wafer stepper cannot feed a fab. Build a tape line first.",
  },
  ["planar-process"] = {
    item = "military-science-pack", -- magnetic tape
    rate = 6,
    note = "Planar processing needs a steady stream of magnetic media.",
  },
  ["microarchitecture"] = {
    item = "chemical-science-pack", -- disk packs
    rate = 10,
    note = "Modern CPUs are designed on computers. Feed the design cluster.",
  },
  ["vlsi-process"] = {
    item = "utility-science-pack", -- mainframe modules
    rate = 2,
    note = "A VLSI line needs a datacenter-sized research programme behind it.",
  },
  ["datacenter"] = {
    item = "utility-science-pack", -- mainframe modules
    rate = 3,
    note = "The Datacenter is designed on mainframes you have not built yet.",
  },
  ["advanced-packaging"] = {
    item = "system-on-chip",
    rate = 0.5,
    note = "Advanced packaging is a production problem, not a science-pack problem. Keep the SoC line running.",
  },
  ["heterogeneous-compute"] = {
    item = "gpu",
    rate = 0.2,
    note = "You cannot design the next GPU without a GPU line that is actually producing.",
  },
  ["quantum-computing"] = {
    item = "multi-core-cpu",
    rate = 0.2,
    note = "A cryostat is an appliance. The control electronics come off a multi-core line that is still running.",
  },
  ["quantum-error-correction"] = {
    item = "qubit",
    rate = 0.25,
    note = "Error correction is a throughput problem. Keep the physical-qubit line producing.",
  },
  ["quantum-advantage"] = {
    item = "error-corrected-qubit",
    rate = 0.1,
    note = "A logical qubit is nine physical qubits and a correction cycle. The gate measures the corrected ones.",
  },
}
