-- luacheck: globals TestNpcFilteringLogic lib GetTotalLootChoices
-- luacheck: globals IsGameStateEligible

local lu = require("luaunit")

TestNpcFilteringLogic = {}

function TestNpcFilteringLogic:setUp()
    self.wraps = {}
    lib = {}
    IsGameStateEligible = function(_, requirements)
        return requirements ~= "blocked"
    end
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
            return name == "Banned"
        end,
    }
    self.paddingModule = assert(loadfile("src/mods/logic/padding.lua"))()
    self.padding = self.paddingModule.create({ privatePadding = true })

    assert(loadfile("src/mods/logic/filtering_npc.lua"))({
        module = self.host,
        traitInfo = self.traitInfo,
        padding = self.padding,
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
        { ItemName = "Banned" },
        { ItemName = "FallbackGold", Type = "Trait", Rarity = "Common" },
    })
end

function TestNpcFilteringLogic:testNpcChoiceUsesFallbackGoldWithoutPrivatePadding()
    self.wraps = {}
    self.padding = self.paddingModule.create({ privatePadding = false })
    assert(loadfile("src/mods/logic/filtering_npc.lua"))({
        module = self.host,
        traitInfo = self.traitInfo,
        padding = self.padding,
    })

    local args = {
        UpgradeOptions = {
            { ItemName = "Allowed" },
            { ItemName = "Banned" },
        },
    }
    local baseArgs

    self.wraps.ArachneCostumeChoice(self.host, self.runtime, function(_, receivedArgs)
        baseArgs = receivedArgs
    end, {}, args, {})

    lu.assertEquals(baseArgs.UpgradeOptions, {
        { ItemName = "Allowed" },
        { ItemName = "FallbackGold", Type = "Trait", Rarity = "Common" },
        { ItemName = "FallbackGold", Type = "Trait", Rarity = "Common" },
    })
end
