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
    self.paddingCalls = {}
    self.padding = {
        readConfig = function()
            return {
                enabled = true,
            }
        end,
        extendChoiceList = function(allowed, banned, opts)
            self.paddingCalls[#self.paddingCalls + 1] = {
                allowed = allowed,
                banned = banned,
                opts = opts,
            }
            allowed[#allowed + 1] = banned[1]
        end,
    }

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
    })
    lu.assertEquals(#self.paddingCalls, 1)
    lu.assertFalse(self.paddingCalls[1].opts.force)
end

function TestNpcFilteringLogic:testCirceChoiceForcesPadding()
    local args = {
        UpgradeOptions = {
            { ItemName = "Allowed" },
            { ItemName = "Banned" },
        },
    }

    self.wraps.CirceBlessingChoice(self.host, self.runtime, function() end, {}, args, {})

    lu.assertEquals(#self.paddingCalls, 1)
    lu.assertTrue(self.paddingCalls[1].opts.force)
end
