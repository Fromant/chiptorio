-- Data stage: everything that defines *what exists*.
-- Order matters: items and fluids before recipes, machines before the
-- recipes that use their categories.

require("scripts.items")
require("scripts.node_items")
require("scripts.fluids")
require("scripts.machines")
require("scripts.labs")
require("scripts.metrology")
require("scripts.providers")
require("scripts.memory")
require("scripts.network")
require("scripts.silicon")
require("scripts.chips")
require("scripts.era5")
require("scripts.era7")
require("scripts.node_recipes")
require("scripts.endgame")
require("scripts.workloads")
require("scripts.technology")
