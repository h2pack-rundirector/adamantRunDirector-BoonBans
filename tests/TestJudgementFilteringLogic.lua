-- luacheck: globals TestJudgementFilteringLogic GameState CurrentRun lib
-- luacheck: globals GetTotalHeroTraitValue

local lu = require("luaunit")

TestJudgementFilteringLogic = {}

local function MakeSource(bannedNames)
    return {
        forEachBanned = function(_, _, callback)
            for _, name in ipairs(bannedNames) do
                callback(name, { key = name })
            end
        end,
    }
end

function TestJudgementFilteringLogic:setUp()
    self.wraps = {}
    lib = {}
    GameState = {
        MetaUpgradeState = {
            JudgeA = { Equipped = false },
        },
    }
    CurrentRun = {
        ClearedBiomes = 2,
    }
    GetTotalHeroTraitValue = function(name)
        return name == "PostBossCards" and 3 or 0
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
        controls = {
            get = function(name)
                return name == "Judgement2" and MakeSource({ "JudgeA" }) or nil
            end,
        },
    }
    self.traitInfo = {
        judgement = function(runtime, clearedBiomes)
            return clearedBiomes == 2 and runtime.controls.get("Judgement2") or nil
        end,
    }

    assert(loadfile("src/mods/logic/filtering_judgement.lua"))({
        module = self.host,
        traitInfo = self.traitInfo,
    })
end

function TestJudgementFilteringLogic:testJudgementTemporarilyEquipsCurrentBiomeBannedCardThenRestores()
    local duringBase = nil

    self.wraps.AddRandomMetaUpgrades(self.host, self.runtime, function()
        duringBase = GameState.MetaUpgradeState.JudgeA.Equipped
    end, nil, {})

    lu.assertTrue(duringBase)
    lu.assertFalse(GameState.MetaUpgradeState.JudgeA.Equipped)
end
