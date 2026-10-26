-- Minimal assertion harness for pure-Lua unit tests.
--
-- These tests run in the data stage, so every module under test must be pure:
-- no `game`, no `storage`, no prototypes. That restriction is the reason the
-- graph and allocation modules are separate files.

local H = {
  cases = 0,
  failures = {},
}

function H.test(name, fn)
  H.cases = H.cases + 1
  local ok, err = pcall(fn)
  if not ok then
    H.failures[#H.failures + 1] = name .. ": " .. tostring(err)
  end
end

function H.eq(actual, expected, label)
  if actual ~= expected then
    error((label or "value") .. " expected " .. tostring(expected) .. " but got " .. tostring(actual), 2)
  end
end

function H.truthy(value, label)
  if not value then
    error((label or "value") .. " expected truthy but was " .. tostring(value), 2)
  end
end

function H.nil_value(value, label)
  if value ~= nil then
    error((label or "value") .. " expected nil but got " .. tostring(value), 2)
  end
end

function H.finish(suite)
  if #H.failures > 0 then
    error("CHIPTORIO-TEST FAIL " .. suite .. ": " .. table.concat(H.failures, "; "))
  end
  log(string.format("CHIPTORIO-TEST PASS %s (%d cases)", suite, H.cases))
end

return H
