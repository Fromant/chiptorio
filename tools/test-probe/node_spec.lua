-- Unit tests for scripts/process_nodes.lua.
--
-- The node table is pure data and the single source of truth for the process
-- ladder: item names, technology names, die yields and half-node bonuses all
-- derive from it. If this table drifts, the data contract will still pass for
-- the items it happens to generate, so the invariants are checked here.

local nodes = require("__chiptorio__/scripts/process_nodes")
local H = require("unit_harness")

local function find(list, key)
  for _, entry in ipairs(list) do
    if entry.key == key then
      return entry
    end
  end
  return nil
end

return function()
  H.test("there are twelve major process nodes in roadmap order", function()
    H.eq(#nodes.NODES, 12, "major node count")
    local expected = {
      "10um",
      "3um",
      "1um",
      "350nm",
      "180nm",
      "90nm",
      "45nm",
      "22nm",
      "14nm",
      "7nm",
      "3nm",
      "1-4nm",
    }
    for index, key in ipairs(expected) do
      H.eq(nodes.NODES[index].key, key, "node order")
    end
  end)

  H.test("node keys and technology names are unique", function()
    local seen = {}
    for _, node in ipairs(nodes.NODES) do
      H.eq(seen[node.key], nil, "duplicate node key " .. node.key)
      seen[node.key] = true
      H.eq(nodes.tech_name(node.key), "process-" .. node.key, "technology name")
    end
  end)

  H.test("die yield rises with every node", function()
    local previous = 0
    for _, node in ipairs(nodes.NODES) do
      H.truthy(node.dies > previous, "dies must rise at " .. node.key)
      previous = node.dies
    end
  end)

  H.test("node items follow the node-<key> naming scheme", function()
    for _, node in ipairs(nodes.NODES) do
      local names = nodes.items(node.key)
      H.eq(names.mask, "node-" .. node.key .. "-mask", "mask name")
      H.eq(names.wafer, "node-" .. node.key .. "-wafer", "wafer name")
      H.eq(names.die, "node-" .. node.key .. "-die", "die name")
      H.truthy(names.mask:find("[%.:]") == nil, "item names must be prototype-safe: " .. names.mask)
    end
  end)

  H.test("every node packages at least one architecture and costs science", function()
    local architectures = {
      ["integrated-circuit"] = true,
      ["microprocessor"] = true,
      ["system-on-chip"] = true,
      ["gpu"] = true,
      ["multi-core-cpu"] = true,
      ["quantum-processor"] = true,
    }
    for _, node in ipairs(nodes.NODES) do
      H.truthy(#node.chips > 0, "no chips at " .. node.key)
      for _, chip in ipairs(node.chips) do
        H.truthy(architectures[chip], "unknown architecture " .. chip .. " at " .. node.key)
      end
      H.truthy(next(node.science) ~= nil, "no science cost at " .. node.key)
      H.truthy(node.mask and node.mask[1] and node.mask[2], "no mask input at " .. node.key)
    end
  end)

  H.test("the first three nodes are fab-tier and the rest are VLSI", function()
    for index, node in ipairs(nodes.NODES) do
      if index <= 3 then
        H.eq(node.extra, nil, node.key .. " must not need coolant")
      else
        H.truthy(node.extra and node.extra.name == "coolant", node.key .. " must need coolant")
      end
    end
  end)

  H.test("there are ten half-node refinements between adjacent majors", function()
    H.eq(#nodes.HALF_NODES, 10, "half-node count")
    local major = {}
    for index, node in ipairs(nodes.NODES) do
      major[node.key] = index
    end
    for _, half in ipairs(nodes.HALF_NODES) do
      local from = major[half.between[1]]
      local to = major[half.between[2]]
      H.truthy(from and to, "unknown node in half-node " .. half.key)
      H.eq(to, from + 1, "half-node " .. half.key .. " must sit between adjacent majors")
      H.truthy(half.yield > 1, "half-node " .. half.key .. " must raise yield")
      H.truthy(half.compute >= 1, "half-node " .. half.key .. " must not lower compute")
      H.truthy(half.power <= 1, "half-node " .. half.key .. " must not raise power")
    end
  end)

  H.test("half-node bonuses are monotonic and accumulate", function()
    local previous = 1
    for _, half in ipairs(nodes.HALF_NODES) do
      H.truthy(half.yield >= previous, "yield bonus must not fall at " .. half.key)
      previous = half.yield
    end
    -- One half-node sits before each node from 3 um to 1.4 nm.
    local total = 1
    for _, half in ipairs(nodes.HALF_NODES) do
      total = total * half.yield
    end
    H.truthy(total > 2, "ten half-nodes should more than double total yield")
    local first = nodes.half_bonus("10um")
    local last = nodes.half_bonus("1-4nm")
    H.eq(first, 1, "no half-node qualifies 10 um")
    H.eq(last, total, "1.4 nm accumulates every half-node")
  end)

  H.test("lookups return nil for unknown nodes", function()
    H.eq(nodes.node("nope"), nil, "unknown major node")
    H.eq(nodes.half_node("nope"), nil, "unknown half-node")
  end)
end
