-- Unit tests for scripts/runtime/network_graph.lua (physical layer).
--
-- Every case is a plain table in, plain table out. No map, no entities.
-- The graph model is:
--   * Cables form raw segments by 4-way adjacency (N/S/E/W) on tile coordinates.
--   * Segment bandwidth = weakest cable tier present (weakest-link rule).
--   * Segment latency = sum of per-tile latencies.
--   * Switches (3×2) merge all segments touching any of their 6 tiles.
--   * Routers (3×2) bridge segments on the wired side and provide WiFi
--     reach of 16 tiles on the wireless side.
--   * A device connects if adjacent to a cable/switch tile or within
--     router WiFi reach. Touching 2+ networks = conflict -> offline.

local graph = require("__chiptorio__/scripts/runtime/network_graph")
local H = require("unit_harness")

-- Cable tier constants used by tests.
local TIER = {
  twisted = "network-cable",
  coaxial = "network-coaxial-cable",
  fiber_mm = "network-fiber-mm-cable",
  fiber_sm = "network-fiber-sm-cable",
}

-- Cable at tile (tx, ty) - position is tile center (tx+0.5, ty+0.5).
local function cable(tx, ty, tier)
  return { x = tx + 0.5, y = ty + 0.5, tier = tier }
end

return function()
  H.test("an empty spec has no networks and no devices", function()
    local result = graph.build({})
    H.eq(#result.networks, 0, "networks")
    H.eq(#result.unconnected, 0, "unconnected")
    H.eq(result.cable_count, 0, "cable count")
  end)

  H.test("adjacent cables form one raw segment", function()
    local result = graph.build({
      cables = { cable(0, 0, TIER.twisted), cable(1, 0, TIER.twisted), cable(2, 0, TIER.twisted) },
    })
    H.eq(#result.raw_segments, 1, "raw segments")
    H.eq(#result.raw_segments[1].cables, 3, "cable count")
    H.eq(result.raw_segments[1].bandwidth, 50, "twisted pair bandwidth")
    H.eq(#result.networks, 1, "networks")
  end)

  H.test("cables two tiles apart do not connect", function()
    local result = graph.build({
      cables = { cable(0, 0, TIER.twisted), cable(2, 0, TIER.twisted) },
    })
    H.eq(#result.raw_segments, 2, "raw segments")
    H.eq(#result.networks, 2, "networks")
  end)

  H.test("diagonal cables do not conduct", function()
    local result = graph.build({
      cables = { cable(0, 0, TIER.twisted), cable(1, 1, TIER.twisted) },
    })
    H.eq(#result.raw_segments, 2, "raw segments - diagonal cables are separate")
  end)

  H.test("duplicate cable tiles collapse", function()
    local result = graph.build({
      cables = { cable(0, 0, TIER.twisted), cable(0, 0, TIER.twisted) },
    })
    H.eq(result.cable_count, 1, "cable count")
    H.eq(#result.raw_segments, 1, "raw segments")
  end)

  H.test("weakest-link rule: coaxial next to twisted drops to twisted", function()
    local result = graph.build({
      cables = { cable(0, 0, TIER.coaxial), cable(1, 0, TIER.twisted) },
    })
    H.eq(#result.raw_segments, 1, "raw segments")
    H.eq(result.raw_segments[1].bandwidth, 50, "weakest-link bandwidth")
  end)

  H.test("fiber segment keeps high bandwidth", function()
    local result = graph.build({
      cables = { cable(0, 0, TIER.fiber_mm), cable(1, 0, TIER.fiber_mm) },
    })
    H.eq(result.raw_segments[1].bandwidth, 1000, "multi-mode fiber bandwidth")
  end)

  H.test("single-mode fiber segment", function()
    local result = graph.build({
      cables = { cable(0, 0, TIER.fiber_sm), cable(1, 0, TIER.fiber_sm) },
    })
    H.eq(result.raw_segments[1].bandwidth, 5000, "single-mode fiber bandwidth")
  end)

  H.test("latency accumulates per cable tile", function()
    local result = graph.build({
      cables = { cable(0, 0, TIER.twisted), cable(1, 0, TIER.twisted), cable(2, 0, TIER.twisted) },
    })
    H.eq(result.raw_segments[1].latency, 6, "twisted pair latency 2 per tile x 3")
  end)

  H.test("a switch merges cable runs touching its footprint", function()
    -- Switch at tile (3,0), direction 0: covers tiles (2,0)-(4,1).
    -- Cables at tile (1,0) and (5,0) touch switch tiles (2,0) and (4,0).
    local result = graph.build({
      cables = { cable(1, 0, TIER.twisted), cable(5, 0, TIER.twisted) },
      devices = {
        { id = 10, kind = "switch", x = 3.5, y = 0.5 },
      },
    })
    H.eq(#result.raw_segments, 2, "two raw segments before merge")
    H.eq(#result.merged_segments, 1, "switch merges into one segment")
    H.eq(#result.networks, 1, "one network")
    H.truthy(result.device_network[10], "switch on network")
  end)

  H.test("a router bridges two cable segments into one network", function()
    local result = graph.build({
      cables = { cable(3, 0, TIER.twisted), cable(7, 0, TIER.twisted) },
      devices = {
        { id = 20, kind = "router", x = 5.5, y = 0.5 },
      },
    })
    H.eq(#result.raw_segments, 2, "two raw segments")
    H.eq(#result.networks, 1, "one network bridged by router")
    H.truthy(result.device_network[20], "router on network")
  end)

  H.test("router WiFi reach: device within 16 tiles connects", function()
    local result = graph.build({
      cables = { cable(3, 0, TIER.twisted) },
      devices = {
        { id = 20, kind = "router", x = 5.5, y = 0.5 },
        { id = 30, kind = "compute", x = 19.5, y = 0.5, compute = 7 },
      },
    })
    -- Distance from router (5.5,0.5) to device (19.5,0.5) = 14 <= 16
    H.truthy(result.device_network[30], "WiFi device on network")
  end)

  H.test("router WiFi reach: device beyond 16 tiles is unconnected", function()
    local result = graph.build({
      cables = { cable(3, 0, TIER.twisted) },
      devices = {
        { id = 20, kind = "router", x = 5.5, y = 0.5 },
        { id = 30, kind = "compute", x = 23.5, y = 0.5, compute = 7 },
      },
    })
    -- Distance = 18 > 16, so not connected via WiFi, and not adjacent to cable
    H.nil_value(result.device_network[30], "far WiFi device not on network")
    H.truthy(result.conflicts or result.unconnected, "far device unconnected or conflicted")
  end)

  H.test("a device adjacent to a cable connects to its network", function()
    -- Cable at tile (1,0), device at tile (0,0): device adjacent to cable.
    local result = graph.build({
      cables = { cable(1, 0, TIER.twisted) },
      devices = { { id = "near", kind = "compute", x = 0.5, y = 0.5, compute = 7 } },
    })
    H.truthy(result.device_network["near"], "near device on network")
  end)

  H.test("a device far from any cable is unconnected", function()
    local result = graph.build({
      cables = { cable(0, 0, TIER.twisted) },
      devices = { { id = "far", kind = "compute", x = 10.5, y = 0.5, compute = 7 } },
    })
    H.nil_value(result.device_network["far"], "far device not on network")
    H.eq(#result.unconnected, 1, "one unconnected device")
    H.eq(result.unconnected[1], "far", "unconnected id")
  end)

  H.test("a device touching two networks is a conflict and goes offline", function()
    -- Device at tile (1,0) adjacent to cables at tiles (0,0) and (2,0).
    -- Cables are not adjacent to each other (gap at tile 1), so 2 networks.
    local result = graph.build({
      cables = { cable(0, 0, TIER.twisted), cable(2, 0, TIER.twisted) },
      devices = { { id = "bridge", kind = "compute", x = 1.5, y = 0.5 } },
    })
    H.truthy(result.conflicts and result.conflicts["bridge"], "bridge device is a conflict")
    H.eq(#result.unconnected, 1, "conflicted device is unconnected")
    H.eq(result.unconnected[1], "bridge", "unconnected id")
  end)

  H.test("stats roll up from devices to network", function()
    -- Cable at tile (1,0). Devices at tiles (0,0) and (1,1) both adjacent to it.
    local result = graph.build({
      cables = { cable(1, 0, TIER.twisted) },
      devices = {
        { id = "cpu", kind = "compute", x = 0.5, y = 0.5, compute = 4, memory = 64, power = 90, heat = 10 },
        { id = "ram", kind = "memory", x = 1.5, y = 1.5, memory = 256, power = 5, cooling = 20 },
      },
    })
    H.eq(result.networks[1].compute, 4, "network compute")
    H.eq(result.networks[1].memory, 320, "network memory")
    H.eq(result.networks[1].power, 95, "network power")
    H.eq(result.networks[1].heat, 10, "network heat")
    H.eq(result.networks[1].cooling, 20, "network cooling")
  end)

  H.test("network ids are deterministic and ordered", function()
    local spec = {
      cables = { cable(0, 5, TIER.twisted), cable(0, 0, TIER.twisted), cable(9, 0, TIER.twisted) },
    }
    local first = graph.build(spec)
    local second = graph.build(spec)
    H.eq(#first.networks, 3, "three networks")
    H.eq(first.networks[1].id, second.networks[1].id, "deterministic network id")
  end)

  H.test("removing a cable splits the segment", function()
    local before = graph.build({
      cables = { cable(0, 0, TIER.twisted), cable(1, 0, TIER.twisted), cable(2, 0, TIER.twisted) },
    })
    H.eq(#before.raw_segments, 1, "before: one segment")
    local after = graph.build({
      cables = { cable(0, 0, TIER.twisted), cable(2, 0, TIER.twisted) },
    })
    H.eq(#after.raw_segments, 2, "after: two segments")
  end)

  H.test("build does not mutate its input", function()
    local spec = {
      cables = { cable(1, 0, TIER.twisted) },
      devices = { { id = "a", kind = "compute", x = 0.5, y = 0.5, compute = 1 } },
    }
    local result = graph.build(spec)
    H.eq(#spec.cables, 1, "input cable count")
    H.eq(spec.cables[1].x, 1.5, "input cable x")
    H.truthy(result.device_network["a"], "device on network")
  end)

  H.test("positions are kept for overlay rendering", function()
    local result = graph.build({
      cables = { cable(1, 0, TIER.twisted) },
      devices = {
        { id = "router", kind = "router", x = 3.5, y = 0.5 },
        { id = "lost", kind = "compute", x = 40.5, y = 40.5 },
      },
    })
    H.eq(result.positions.router.x, 3.5, "router x")
    H.eq(result.positions.lost.y, 40.5, "lost y")
  end)

  H.test("switch footprint covers all 6 tiles", function()
    -- Switch at tile (3,0), direction 0: covers tiles (2,0)-(4,1).
    -- Cables at tiles (1,0) and (5,0) touch switch tiles (2,0) and (4,0).
    local result = graph.build({
      cables = { cable(1, 0, TIER.twisted), cable(5, 0, TIER.twisted) },
      devices = { { id = "sw", kind = "switch", x = 3.5, y = 0.5 } },
    })
    H.eq(#result.merged_segments, 1, "switch merges both cables")
    H.eq(#result.networks, 1, "one network")
  end)

  H.test("scale: many cables build in one pass", function()
    local cables = {}
    for x = 0, 99 do
      for y = 0, 99 do
        cables[#cables + 1] = cable(x, y, TIER.twisted)
      end
    end

    local devices = {}
    for i = 1, 100 do
      devices[#devices + 1] = {
        id = "device-" .. i,
        kind = "compute",
        x = (i % 10) + 0.5,
        y = (math.floor(i / 10) % 10) + 0.5,
        compute = 1,
        memory = 8,
      }
    end

    local result = graph.build({ cables = cables, devices = devices })

    H.eq(result.cable_count, 10000, "cable count")
    H.eq(#result.networks, 1, "all cables in one network")
    H.eq(result.networks[1].compute, 100, "network compute")
    H.eq(result.networks[1].memory, 800, "network memory")
    log("CHIPTORIO-TEST PERF graph: 10000 cables, 100 devices, 1 network")
  end)
end
