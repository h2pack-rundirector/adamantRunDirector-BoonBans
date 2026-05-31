-- luacheck: globals TestHexFilteringLogic lib

local lu = require("luaunit")

TestHexFilteringLogic = {}

function TestHexFilteringLogic:setUp()
    self.wraps = {}
    lib = {}
    self.host = {
        hooks = {
            wrap = function(funcName, callback)
                self.wraps[funcName] = callback
            end,
        },
        isEnabled = function()
            return true
        end,
        logIf = function() end,
    }
    self.runtime = {}
    self.traitInfo = {
        isBanned = function(name)
            return name == "BannedSpell"
        end,
    }

    assert(loadfile("src/mods/logic/filtering_hex.lua"))({
        module = self.host,
        traitInfo = self.traitInfo,
    })
end

function TestHexFilteringLogic:testSpellFilteringReturnsAllowedWhenAnyRemain()
    local result = self.wraps.GetEligibleSpells(self.host, self.runtime, function()
        return { "AllowedSpell", "BannedSpell" }
    end, {}, {})

    lu.assertEquals(result, { "AllowedSpell" })
end

function TestHexFilteringLogic:testSpellFilteringKeepsVanillaWhenAllAreBanned()
    local vanilla = { "BannedSpell" }
    local result = self.wraps.GetEligibleSpells(self.host, self.runtime, function()
        return vanilla
    end, {}, {})

    lu.assertEquals(result, vanilla)
end
