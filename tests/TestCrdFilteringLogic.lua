-- luacheck: globals TestCrdFilteringLogic GameState lib

local lu = require("luaunit")

TestCrdFilteringLogic = {}

local function MakeSource(bannedNames)
    return {
        forEachBanned = function(_, _, callback)
            for _, name in ipairs(bannedNames) do
                callback(name, { key = name })
            end
        end,
    }
end

function TestCrdFilteringLogic:setUp()
    self.wraps = {}
    lib = {}
    GameState = {
        MetaUpgradeState = {
            CardA = { Equipped = false },
            CardB = { Equipped = false },
        },
    }
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
        controls = {
            get = function(name)
                return name == "CirceCRD" and MakeSource({ "CardA" }) or nil
            end,
        },
    }

    assert(loadfile("src/mods/logic/filtering_crd.lua"))({
        module = self.host,
    })
end

function TestCrdFilteringLogic:testCirceRandomMetaUpgradeTemporarilyEquipsBannedCardThenRestores()
    local duringBase = nil

    self.wraps.CirceRandomMetaUpgrade(self.host, self.runtime, function()
        duringBase = {
            CardA = GameState.MetaUpgradeState.CardA.Equipped,
            CardB = GameState.MetaUpgradeState.CardB.Equipped,
        }
    end, {})

    lu.assertEquals(duringBase, {
        CardA = true,
        CardB = false,
    })
    lu.assertFalse(GameState.MetaUpgradeState.CardA.Equipped)
    lu.assertFalse(GameState.MetaUpgradeState.CardB.Equipped)
end
