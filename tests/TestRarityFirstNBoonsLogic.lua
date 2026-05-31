-- luacheck: globals TestRarityFirstNBoonsLogic lib

local lu = require("luaunit")

TestRarityFirstNBoonsLogic = {}

function TestRarityFirstNBoonsLogic:setUp()
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
    }
    self.runtime = {}
    self.runState = {
        shouldForceRarity = function()
            return true
        end,
    }

    assert(loadfile("src/mods/logic/rarity_first_n_boons.lua"))({
        module = self.host,
        runState = self.runState,
    })
end

function TestRarityFirstNBoonsLogic:testRarityChancesCanForceEpic()
    local chances = self.wraps.GetRarityChances(self.host, self.runtime, function()
        return { Common = 0.5, Rare = 0.4, Epic = 0.1 }
    end, { GodLoot = true })

    lu.assertEquals(chances, {
        Common = 0.0,
        Rare = 0.0,
        Epic = 1.0,
    })
end
