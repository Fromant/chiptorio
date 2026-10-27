-- QLN tuning. Pure: required by the data stage, the runtime and the probe.
--
-- DESIGN §9. Pre-quantum Data Bus: memory modules installed in Storage Drives
-- are item storage. The network's memory capacity is the QLN pool size, while
-- the transport rate comes from the connected network. Quantum Entanglement
-- Cores join two pools into one global pool. Everything here is a share or a
-- rate, not a prototype.

local M = {}

-- Memory module -> storage cells. One cell stores one item. The ladder starts
-- at the 1k module and ends at the 256k bulk module; DESIGN §8.2 names the
-- 1k / 4k / 16k / 64k / 256k milestones. DDR3 is the cheap middle of the
-- ladder and 3D NAND is the dense, slow end.
M.DRIVE_CELLS = {
  ["sram-module"] = 1024,
  ["dram-module"] = 4096,
  ["sdram-module"] = 8192,
  ["ddr-module"] = 12288,
  ["ddr2-module"] = 16384,
  ["ddr3-module"] = 24576,
  ["ddr4-module"] = 32768,
  ["ddr5-module"] = 49152,
  ["hbm-module"] = 65536,
  ["hbm3-module"] = 98304,
  ["3d-nand-module"] = 262144,
}

-- A Storage Drive is a lab clone with four memory slots. Keeping the slot
-- count here means the data stage and the runtime cannot disagree.
M.DRIVE_SLOTS = 4

-- Items per second, per node. A node moves at most this many items per second
-- when it is attached to a network with storage. Import and provider pull;
-- export and requester push.
M.NODE_RATE = 60
M.PROVIDER_RATE = 120

-- QLN transport is capped by the network backplane as well. A network with
-- very little bandwidth moves fewer items; the minimum keeps a bare cable
-- useful. This is applied per network, not per node.
M.BANDWIDTH_ITEMS_PER_UNIT = 4

-- Construction Core. Range is measured in tiles around the core.
M.CONSTRUCTION_RANGE = 32
M.CONSTRUCTION_BATCH = 8
-- The core is an accumulator clone: an accumulator has a real battery that
-- refills from the grid while idle, whereas a lab only holds energy while it
-- researches. The battery is sized to one action, so a connected core is
-- limited by `input_flow_limit` and the 60-tick dispatcher rather than by a
-- large reserve.
M.CONSTRUCTION_POWER = "500kW"
M.CONSTRUCTION_BUFFER = "9200J"
M.CONSTRUCTION_ENERGY = 8000

-- FOUP. One sealed carrier holds this many wafers of a single process node.
M.FOUP_BATCH = 25
M.FOUP_SLOTS = 10

-- Advanced networking. Wireless APs join other APs within this many tiles;
-- repeaters extend a cable run by carrying it over a wider gap.
M.WIRELESS_RANGE = 16
M.REPEATER_REACH = 8

-- A requester keeps its filter item stocked to this many in the adjacent
-- inventories. The filter itself is the single item in the requester's own
-- one-slot inventory and is never consumed.
M.REQUESTER_TARGET = 50

-- Technology names. The data stage unlocks the pre-quantum nodes from QLN and
-- the phase-six nodes from QLN_QUANTUM.
M.TECH_QLN = "qln"
M.TECH_QUANTUM = "qln-quantum"

-- Quantum cores are paired in build order. This is the maximum number of
-- cores one force can pair; the rest wait for another core.
M.QUANTUM_PAIRS = 16

return M
