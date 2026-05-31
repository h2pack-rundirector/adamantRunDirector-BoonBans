-- luacheck: globals TestNpcFilteringLogic lib
-- luacheck: globals IsGameStateEligible

local lu = require("luaunit")

TestNpcFilteringLogic = {}

function TestNpcFilteringLogic:setUp()
    self.wraps = {}
    lib = {}
    IsGameStateEligible = function(_, requirements)
        return requirements ~= "blocked"
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
    self.runtime = {}
    self.traitInfo = {
        isBanned = function(name)
            return name == "Banned"
        end,
    }

    assert(loadfile("src/mods/logic/filtering_npc.lua"))({
        module = self.host,
        traitInfo = self.traitInfo,
    })
end

function TestNpcFilteringLogic:testNpcChoiceFiltersBannedAndIneligibleOptions()
    local args = {
        UpgradeOptions = {
            { ItemName = "Allowed" },
            { ItemName = "Banned" },
            { ItemName = "BlockedByReq", GameStateRequirements = "blocked" },
        },
    }
    local baseArgs

    self.wraps.ArachneCostumeChoice(self.host, self.runtime, function(_, baseReceivedArgs)
        baseArgs = baseReceivedArgs
    end, {}, args, {})

    lu.assertEquals(baseArgs.UpgradeOptions, {
        { ItemName = "Allowed" },
    })
end
