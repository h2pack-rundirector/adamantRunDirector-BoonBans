-- luacheck: globals TestHexFilteringLogic lib GetTotalLootChoices

local lu = require("luaunit")

TestHexFilteringLogic = {}

function TestHexFilteringLogic:setUp()
    self.wraps = {}
    lib = {}
    GetTotalLootChoices = function()
        return 3
    end
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
    self.runtime = {
        data = {
            get = function()
                return {
                    read = function()
                        return true
                    end,
                }
            end,
        },
    }
    self.traitInfo = {
        isBanned = function(name)
            return name == "BannedSpell"
        end,
    }
    self.paddingCalls = {}
    self.padding = {
        fillSpellList = function(allowed, banned, runtime, opts)
            self.paddingCalls[#self.paddingCalls + 1] = {
                allowed = allowed,
                banned = banned,
                runtime = runtime,
                opts = opts,
            }
            allowed[#allowed + 1] = banned[1]
        end,
    }

    assert(loadfile("src/mods/logic/filtering_hex.lua"))({
        module = self.host,
        traitInfo = self.traitInfo,
        padding = self.padding,
    })
end

function TestHexFilteringLogic:testSpellFilteringReturnsAllowedWhenAnyRemain()
    local result = self.wraps.GetEligibleSpells(self.host, self.runtime, function()
        return { "AllowedSpell", "BannedSpell" }
    end, {}, {})

    lu.assertEquals(result, { "AllowedSpell", "BannedSpell" })
    lu.assertEquals(#self.paddingCalls, 1)
    lu.assertEquals(self.paddingCalls[1].banned, { "BannedSpell" })
end

function TestHexFilteringLogic:testSpellFilteringKeepsVanillaWhenAllAreBanned()
    local vanilla = { "BannedSpell" }
    local result = self.wraps.GetEligibleSpells(self.host, self.runtime, function()
        return vanilla
    end, {}, {})

    lu.assertEquals(result, vanilla)
end
