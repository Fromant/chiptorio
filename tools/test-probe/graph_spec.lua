-- Unit tests for scripts/runtime/network_graph.lua.
--
-- Every case is a plain table in, plain table out. No map, no entities.

local graph = require("__chiptorio__/scripts/runtime/network_graph")
local H = require("unit_harness")

return function()
  H.test("an empty spec has no subnets and no networks", function()
    local result = graph.build({})
    H.eq(#result.subnets, 0, "subnets")
    H.eq(#result.networks, 0, "networks")
    H.eq(#result.unconnected, 0, "unconnected")
    H.eq(result.cable_count, 0, "cable count")
  end)

  H.test("adjacent cables form one subnet", function()
    local result = graph.build({
      cables = { { x = 0, y = 0 }, { x = 1, y = 0 }, { x = 2, y = 0 } },
    })
    H.eq(#result.subnets, 1, "subnets")
    H.eq(result.subnets[1].cable_count, 3, "cable count")
    H.eq(#result.networks, 1, "networks")
  end)

  H.test("cables two tiles apart do not connect", function()
    local result = graph.build({
      cables = { { x = 0, y = 0 }, { x = 2, y = 0 } },
    })
    H.eq(#result.subnets, 2, "subnets")
    H.eq(#result.networks, 2, "networks")
  end)

  H.test("diagonal cables conduct", function()
    local result = graph.build({
      cables = { { x = 0, y = 0 }, { x = 1, y = 1 } },
    })
    H.eq(#result.subnets, 1, "subnets")
  end)

  H.test("duplicate cable tiles collapse", function()
    local result = graph.build({
      cables = { { x = 0.5, y = 0.5 }, { x = 0.5, y = 0.5 } },
    })
    H.eq(result.cable_count, 1, "cable count")
    H.eq(#result.subnets, 1, "subnets")
  end)

  H.test("a switch merges the cable runs it can reach", function()
    local result = graph.build({
      cables = { { x = 1.5, y = 0.5 }, { x = 5.5, y = 0.5 } },
      devices = {
        { id = 10, kind = "switch", x = 3.5, y = 0.5, bandwidth = 100 },
      },
    })
    H.eq(#result.subnets, 1, "subnets")
    H.eq(#result.subnets[1].switches, 1, "switches")
    H.eq(result.subnets[1].bandwidth, 100 + graph.CABLE_BANDWIDTH, "bandwidth")
    H.eq(result.device_subnet[10], 1, "switch subnet")
  end)

  H.test("a router joins subnets into one network without merging them", function()
    local result = graph.build({
      cables = { { x = 3.5, y = 0.5 }, { x = 7.5, y = 0.5 } },
      devices = {
        { id = 20, kind = "router", x = 5.5, y = 0.5, bandwidth = 250 },
      },
    })
    H.eq(#result.subnets, 2, "subnets")
    H.eq(#result.networks, 1, "networks")
    H.eq(#result.networks[1].routers, 1, "routers")
    H.eq(result.networks[1].router_bandwidth, 250, "router bandwidth")
    H.eq(result.networks[1].latency, 2 * graph.CABLE_LATENCY + graph.ROUTER_LATENCY, "latency")
    H.eq(result.device_network[20], 1, "router network")
  end)

  H.test("a router with no reachable cable is unconnected", function()
    local result = graph.build({
      cables = { { x = 0, y = 0 } },
      devices = {
        { id = 21, kind = "router", x = 20.5, y = 20.5 },
      },
    })
    H.eq(#result.networks, 1, "networks")
    H.eq(#result.unconnected, 1, "unconnected")
    H.eq(result.unconnected[1], 21, "unconnected id")
    H.nil_value(result.device_network[21], "router network")
  end)

  H.test("a device attaches within two tiles and not further", function()
    local near = graph.build({
      cables = { { x = 0, y = 0 } },
      devices = { { id = "near", kind = "compute", x = 1.5, y = 0.5, compute = 7 } },
    })
    H.eq(near.device_subnet["near"], 1, "near subnet")
    H.eq(near.subnets[1].compute, 7, "near compute")
    H.eq(near.device_network["near"], 1, "near network")

    local far = graph.build({
      cables = { { x = 0, y = 0 } },
      devices = { { id = "far", kind = "compute", x = 5.5, y = 0.5, compute = 7 } },
    })
    H.nil_value(far.device_subnet["far"], "far subnet")
    H.eq(#far.unconnected, 1, "far unconnected")
    H.eq(far.subnets[1].compute, 0, "far compute")
  end)

  H.test("stats roll up from devices to subnet and network", function()
    local result = graph.build({
      cables = { { x = 0, y = 0 }, { x = 1, y = 0 } },
      devices = {
        { id = "cpu", kind = "compute", x = 0.5, y = 0.5, compute = 4, memory = 64, power = 90, heat = 10 },
        { id = "ram", kind = "memory", x = 1.5, y = 0.5, memory = 256, power = 5, cooling = 20 },
      },
    })
    H.eq(result.subnets[1].compute, 4, "subnet compute")
    H.eq(result.subnets[1].memory, 320, "subnet memory")
    H.eq(result.subnets[1].power, 95, "subnet power")
    H.eq(result.networks[1].memory, 320, "network memory")
    H.eq(result.networks[1].heat, 10, "network heat")
    H.eq(result.networks[1].cooling, 20, "network cooling")
    H.eq(#result.networks[1].subnets, 1, "network subnets")
  end)

  H.test("a device within reach of two subnets is flagged as contested", function()
    local result = graph.build({
      cables = { { x = 0.5, y = 0.5 }, { x = 4.5, y = 0.5 } },
      devices = { { id = "bridge", kind = "compute", x = 2.5, y = 0.5 } },
    })
    H.truthy(result.contested["bridge"], "contested device")
    H.eq(result.contested["bridge"][1], 1, "first contested subnet")
    H.eq(result.contested["bridge"][2], 2, "second contested subnet")
  end)

  H.test("subnet ids are deterministic and ordered top-left first", function()
    local spec = {
      cables = { { x = 0, y = 5 }, { x = 0, y = 0 }, { x = 9, y = 0 } },
    }
    local first = graph.build(spec)
    local second = graph.build(spec)
    H.eq(first.subnets[1].y, 0, "first subnet y")
    H.eq(first.subnets[1].x, 0, "first subnet x")
    H.eq(first.subnets[2].y, 0, "second subnet y")
    H.eq(first.subnets[2].x, 9, "second subnet x")
    H.eq(first.subnets[3].y, 5, "third subnet y")
    for id = 1, #first.subnets do
      H.eq(first.subnets[id].x, second.subnets[id].x, "deterministic x " .. id)
      H.eq(first.subnets[id].y, second.subnets[id].y, "deterministic y " .. id)
    end
  end)

  H.test("removing a cable splits the subnet", function()
    local before = graph.build({
      cables = { { x = 0, y = 0 }, { x = 1, y = 0 }, { x = 2, y = 0 } },
    })
    H.eq(#before.subnets, 1, "before")
    local after = graph.build({
      cables = { { x = 0, y = 0 }, { x = 2, y = 0 } },
    })
    H.eq(#after.subnets, 2, "after")
  end)

  H.test("build does not mutate its input", function()
    local spec = {
      cables = { { x = 0, y = 0 } },
      devices = { { id = "a", kind = "compute", x = 0.5, y = 0.5, compute = 1 } },
    }
    local result = graph.build(spec)
    H.eq(#spec.cables, 1, "input cable count")
    H.eq(spec.cables[1].x, 0, "input cable x")
    H.eq(#result.subnets[1].devices, 1, "subnet device count")
    result.subnets[1].compute = 99
    H.eq(spec.devices[1].compute, 1, "input device compute")
  end)

  H.test("subnet_at and network_for resolve positions and ids", function()
    local result = graph.build({
      cables = { { x = 4, y = 4 } },
      devices = { { id = 30, kind = "monitor", x = 4.5, y = 4.5 } },
    })
    H.eq(graph.subnet_at(result, 4.5, 4.5), 1, "subnet at tile")
    H.nil_value(graph.subnet_at(result, 20, 20), "subnet off the grid")
    H.eq(graph.network_for(result, 30), 1, "network for device")
    H.nil_value(graph.network_for(result, 999), "network for unknown device")
  end)

  H.test("the graph keeps device positions and router reaches for the overlay", function()
    local result = graph.build({
      cables = { { x = 1.5, y = 0.5 }, { x = 5.5, y = 0.5 } },
      devices = {
        { id = "router", kind = "router", x = 3.5, y = 0.5 },
        { id = "lost", kind = "compute", x = 40.5, y = 40.5 },
      },
    })
    H.eq(result.positions.router.x, 3.5, "router x")
    H.eq(result.positions.lost.y, 40.5, "lost y")
    H.eq(#result.router_subnets.router, 2, "router reaches two subnets")
    H.eq(result.unconnected[1], "lost", "unconnected device")
  end)

  H.test("a repeater carries a cable run over a wider gap", function()
    local result = graph.build({
      cables = { { x = 0.5, y = 0.5 }, { x = 8.5, y = 0.5 } },
      devices = { { id = 30, kind = "switch", x = 4.5, y = 0.5, reach = 8 } },
    })
    H.eq(#result.subnets, 1, "repeater subnets")
    H.eq(result.subnets[1].switches[1], 30, "repeater switch id")
  end)

  H.test("a repeater cannot reach beyond its own range", function()
    local result = graph.build({
      cables = { { x = 0.5, y = 0.5 }, { x = 18.5, y = 0.5 } },
      devices = {
        { id = 31, kind = "switch", x = 2.5, y = 0.5, reach = 8 },
        { id = 32, kind = "switch", x = 16.5, y = 0.5, reach = 8 },
      },
    })
    H.eq(#result.subnets, 2, "distant subnets")
  end)

  H.test("two wireless access points join their cable runs", function()
    local result = graph.build({
      cables = { { x = 0.5, y = 0.5 }, { x = 12.5, y = 0.5 } },
      devices = {
        { id = 40, kind = "switch", x = 0.5, y = 2.5, wireless_range = 16 },
        { id = 41, kind = "switch", x = 12.5, y = 2.5, wireless_range = 16 },
      },
    })
    H.eq(#result.subnets, 1, "wireless subnets")
    H.eq(#result.networks, 1, "wireless networks")
  end)

  H.test("wireless access points outside their range stay separate", function()
    local result = graph.build({
      cables = { { x = 0.5, y = 0.5 }, { x = 20.5, y = 0.5 } },
      devices = {
        { id = 42, kind = "switch", x = 0.5, y = 2.5, wireless_range = 16 },
        { id = 43, kind = "switch", x = 20.5, y = 2.5, wireless_range = 16 },
      },
    })
    H.eq(#result.subnets, 2, "out-of-range subnets")
  end)

  -- DESIGN §16.4 scale target: 10,000 cables, 1,000 providers, 200 labs and
  -- 100 routers. The time is logged, not asserted, because a shared CI machine
  -- varies; structural correctness is the hard contract.
  H.test("a 10,000-cable network builds in one pass", function()
    local cables = {}
    for x = 0, 99 do
      for y = 0, 99 do
        cables[#cables + 1] = { x = x + 0.5, y = y + 0.5 }
      end
    end

    local devices = {}
    for i = 1, 1000 do
      devices[#devices + 1] = {
        id = "provider-" .. i,
        kind = "provider",
        x = (i % 100) + 0.5,
        y = (math.floor(i / 100) % 100) + 0.5,
        compute = 1,
        memory = 8,
      }
    end
    for i = 1, 200 do
      devices[#devices + 1] = {
        id = "lab-" .. i,
        kind = "lab",
        x = (i % 100) + 0.5,
        y = ((i * 7) % 100) + 0.5,
        compute = 2,
      }
    end
    -- Each router bridges the main grid to its own one-cable stub, so the
    -- network keeps 101 subnets and a single joined network.
    for i = 1, 100 do
      local x = i * 2 + 0.5
      cables[#cables + 1] = { x = x, y = 101.5 }
      devices[#devices + 1] = {
        id = "router-" .. i,
        kind = "router",
        x = x,
        y = 100.5,
      }
    end

    local result = graph.build({ cables = cables, devices = devices })

    H.eq(result.cable_count, 10100, "cable count")
    H.eq(#result.subnets, 101, "subnets")
    H.eq(#result.networks, 1, "networks")
    H.eq(result.networks[1].compute, 1400, "network compute")
    H.eq(result.networks[1].memory, 8000, "network memory")
    H.eq(#result.networks[1].subnets, 101, "network subnet count")
    log("CHIPTORIO-TEST PERF graph: 10100 cables, 1300 devices, 101 subnets")
  end)
end
