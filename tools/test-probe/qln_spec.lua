-- Unit tests for scripts/runtime/qln_transport.lua, the pure QLN storage
-- maths. Plain tables only: no map, no entities, no storage.

local transport = require("__chiptorio__/scripts/runtime/qln_transport")
local qmeta = require("__chiptorio__/scripts/qln_meta")
local H = require("unit_harness")

local function close(actual, expected, label)
  if math.abs(actual - expected) > 1e-9 then
    error((label or "value") .. " expected " .. tostring(expected) .. " but got " .. tostring(actual), 2)
  end
end

return function()
  H.test("used sums every pool entry", function()
    close(transport.used({}), 0, "empty pool")
    close(transport.used({ ["iron-plate"] = 3, copper = 4 }), 7, "mixed pool")
  end)

  H.test("capacity reads only known memory modules", function()
    local modules = {
      { name = "sram-module", count = 2 },
      { name = "dram-module", count = 1 },
      { name = "3d-nand-module", count = 1 },
      { name = "integrated-circuit", count = 9 },
    }
    local expected = qmeta.DRIVE_CELLS["sram-module"] * 2
      + qmeta.DRIVE_CELLS["dram-module"]
      + qmeta.DRIVE_CELLS["3d-nand-module"]
    close(transport.capacity(modules, qmeta.DRIVE_CELLS), expected, "module cells")
    close(transport.capacity(nil, qmeta.DRIVE_CELLS), 0, "no modules")
  end)

  H.test("every memory generation carries both research and QLN values", function()
    local rmeta = require("__chiptorio__/scripts/research_meta")
    local generations = 0
    for name, cells in pairs(qmeta.DRIVE_CELLS) do
      generations = generations + 1
      local profile = rmeta.MEMORY_PROFILES[name]
      H.truthy(profile, "missing research profile for " .. name)
      if profile then
        H.truthy(profile.capacity > 0, "zero research capacity for " .. name)
        H.truthy(profile.bandwidth > 0, "zero research bandwidth for " .. name)
      end
      H.truthy(cells > 0, "zero QLN cells for " .. name)
    end
    H.eq(generations, 11, "DESIGN 8.3 has eleven memory generations")
    for name in pairs(rmeta.MEMORY_PROFILES) do
      H.truthy(qmeta.DRIVE_CELLS[name], "missing QLN cells for " .. name)
    end
  end)

  H.test("insert is clamped to free capacity", function()
    local pool = {}
    H.eq(transport.insert(pool, 10, "iron-plate", 4), 4, "partial insert")
    H.eq(pool["iron-plate"], 4, "stored after insert")
    H.eq(transport.insert(pool, 10, "copper", 9), 6, "clamped insert")
    H.eq(pool.copper, 6, "clamped amount")
    H.eq(transport.insert(pool, 10, "coal", 1), 0, "full pool")
    H.eq(transport.insert(pool, 10, "coal", 0), 0, "zero insert")
  end)

  H.test("remove is clamped to what is stored and deletes empty entries", function()
    local pool = { ["iron-plate"] = 5 }
    H.eq(transport.remove(pool, "iron-plate", 2), 2, "partial remove")
    H.eq(pool["iron-plate"], 3, "remaining")
    H.eq(transport.remove(pool, "iron-plate", 99), 3, "clamped remove")
    H.eq(pool["iron-plate"], nil, "empty entry removed")
    H.eq(transport.remove(pool, "iron-plate", 1), 0, "remove from empty")
  end)

  H.test("transfer rolls back what the target cannot hold", function()
    local source = { ["iron-plate"] = 10 }
    local target = {}
    H.eq(transport.transfer(source, target, 4, "iron-plate", 10), 4, "transfer to capacity")
    H.eq(target["iron-plate"], 4, "target contents")
    H.eq(source["iron-plate"], 6, "source remainder")
  end)

  H.test("merge moves everything into the first pool", function()
    local pools = {
      { items = { ["iron-plate"] = 1 } },
      { items = { ["iron-plate"] = 2, copper = 3 } },
    }
    local merged = transport.merge(pools)
    H.eq(merged["iron-plate"], 3, "merged plate")
    H.eq(merged.copper, 3, "merged copper")
    H.eq(next(pools[2].items), nil, "second pool emptied")
  end)

  H.test("rate scales with bandwidth and keeps a floor of one", function()
    H.eq(transport.rate(0, 0, 4), 1, "bare cable floor")
    H.eq(transport.rate(60, 0, 4), 60, "base rate")
    H.eq(transport.rate(0, 10, 4), 40, "bandwidth bonus")
    H.eq(transport.rate(10, -10, 4), 10, "negative bandwidth is ignored")
  end)

  H.test("share distributes the remainder to the first nodes", function()
    local shares = transport.share(10, { 4, 5, 6 })
    H.eq(shares[4], 4, "first share")
    H.eq(shares[5], 3, "second share")
    H.eq(shares[6], 3, "third share")
    local total = shares[4] + shares[5] + shares[6]
    H.eq(total, 10, "shares never exceed the budget")
    H.eq(next(transport.share(10, {})), nil, "no nodes")
  end)

  H.test("sorted_names is stable and ignores empty entries", function()
    local names = transport.sorted_names({ copper = 1, ["iron-plate"] = 0, coal = 2 })
    H.eq(#names, 2, "zero-count entries are skipped")
    H.eq(names[1], "coal", "first name")
    H.eq(names[2], "copper", "second name")
  end)
end
