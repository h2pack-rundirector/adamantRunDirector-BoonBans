-- luacheck: globals TestBnbFilteringLogic MetaUpgradeData lib

local lu = require("luaunit")

TestBnbFilteringLogic = {}

local function MakeSource(bannedNames)
    return {
        forEachBanned = function(_, _, callback)
            for _, name in ipairs(bannedNames) do
                callback(name, { key = name })
            end
        end,
    }
end

function TestBnbFilteringLogic:setUp()
    self.wraps = {}
    lib = {}
    MetaUpgradeData = {
        VowA = { IneligibleForCirceRemoval = false },
        VowB = { IneligibleForCirceRemoval = false },
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
                return name == "CirceBNB" and MakeSource({ "VowA" }) or nil
            end,
        },
    }
    self.traitInfo = {
        blackNightBanishment = function(runtime)
            return runtime.controls.get("CirceBNB")
        end,
    }

    assert(loadfile("src/mods/logic/filtering_bnb.lua"))({
        module = self.host,
        traitInfo = self.traitInfo,
    })
end

function TestBnbFilteringLogic:testCirceRemovalTemporarilyMarksBannedVowsThenRestores()
    local duringBase = nil

    self.wraps.CirceRemoveShrineUpgrades(self.host, self.runtime, function()
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
