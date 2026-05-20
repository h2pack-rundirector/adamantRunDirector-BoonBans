-- luacheck: globals TestNpcLogic MetaUpgradeData GameState CurrentRun lib
-- luacheck: globals IsGameStateEligible GetTotalHeroTraitValue

local lu = require("luaunit")

TestNpcLogic = {}

function TestNpcLogic:setUp()
    self.wraps = {}
    lib = {}
    MetaUpgradeData = {
        VowA = { IneligibleForCirceRemoval = false },
        VowB = { IneligibleForCirceRemoval = false },
    }
    GameState = {
        MetaUpgradeState = {
            CardA = { Equipped = false },
            CardB = { Equipped = false },
            JudgeA = { Equipped = false },
        },
    }
    CurrentRun = {
        ClearedBiomes = 2,
    }
    IsGameStateEligible = function(_, requirements)
        return requirements ~= "blocked"
    end
    GetTotalHeroTraitValue = function(name)
        return name == "PostBossCards" and 3 or 0
    end

    self.data = {
        catalog = {
            entries = {
                CirceBNB = {
                    boons = {
                        { Key = "VowA", Mask = 1 },
                        { Key = "VowB", Mask = 2 },
                    },
                },
                CirceCRD = {
                    boons = {
                        { Key = "CardA", Mask = 1 },
                        { Key = "CardB", Mask = 2 },
                    },
                },
                Judgement2 = {
                    boons = {
                        { Key = "JudgeA", Mask = 1 },
                    },
                },
            },
        },
        banConfig = {
            GetBanMask = function(key)
                return ({
                    CirceBNB = 1,
                    CirceCRD = 1,
                    Judgement2 = 1,
                })[key] or 0
            end,
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
    self.banResolver = {
        isTraitBanned = function(name)
            return name == "Banned" or name == "BannedSpell"
        end,
    }

    local npcLogic = dofile("src/mods/logic/npc_logic.lua").bind(self.data)
    npcLogic.registerHooks(self.host, {}, self.banResolver)
end

function TestNpcLogic:testNpcChoiceFiltersBannedAndIneligibleOptions()
    local args = {
        UpgradeOptions = {
            { ItemName = "Allowed" },
            { ItemName = "Banned" },
            { ItemName = "BlockedByReq", GameStateRequirements = "blocked" },
        },
    }
    local baseArgs

    self.wraps.ArachneCostumeChoice(function(_, baseReceivedArgs)
        baseArgs = baseReceivedArgs
    end, {}, args, {})

    lu.assertEquals(baseArgs.UpgradeOptions, {
        { ItemName = "Allowed" },
    })
end

function TestNpcLogic:testSpellFilteringReturnsAllowedWhenAnyRemain()
    local result = self.wraps.GetEligibleSpells(function()
        return { "AllowedSpell", "BannedSpell" }
    end, {}, {})

    lu.assertEquals(result, { "AllowedSpell" })
end

function TestNpcLogic:testSpellFilteringKeepsVanillaWhenAllAreBanned()
    local vanilla = { "BannedSpell" }
    local result = self.wraps.GetEligibleSpells(function()
        return vanilla
    end, {}, {})

    lu.assertEquals(result, vanilla)
end

function TestNpcLogic:testCirceRemovalTemporarilyMarksBannedVowsThenRestores()
    local duringBase = nil

    self.wraps.CirceRemoveShrineUpgrades(function()
        duringBase = {
            VowA = MetaUpgradeData.VowA.IneligibleForCirceRemoval,
            VowB = MetaUpgradeData.VowB.IneligibleForCirceRemoval,
        }
    end, {})

    lu.assertEquals(duringBase, {
        VowA = true,
        VowB = false,
    })
    lu.assertFalse(MetaUpgradeData.VowA.IneligibleForCirceRemoval)
    lu.assertFalse(MetaUpgradeData.VowB.IneligibleForCirceRemoval)
end

function TestNpcLogic:testCirceRandomMetaUpgradeTemporarilyEquipsBannedCardThenRestores()
    local duringBase = nil

    self.wraps.CirceRandomMetaUpgrade(function()
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

function TestNpcLogic:testJudgementTemporarilyEquipsCurrentBiomeBannedCardThenRestores()
    local duringBase = nil

    self.wraps.AddRandomMetaUpgrades(function()
        duringBase = GameState.MetaUpgradeState.JudgeA.Equipped
    end, nil, {})

    lu.assertTrue(duringBase)
    lu.assertFalse(GameState.MetaUpgradeState.JudgeA.Equipped)
end
