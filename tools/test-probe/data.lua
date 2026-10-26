-- Probe data stage.
--
-- Unit tests run here, before the contract assertions in data-updates.lua.
-- They reach directly into chiptorio's pure modules from another mod, which is
-- exactly why those modules must never touch `game` or `storage`.

require("graph_spec")()
require("research_spec")()
