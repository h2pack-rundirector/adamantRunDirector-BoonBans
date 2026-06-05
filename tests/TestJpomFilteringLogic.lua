-- luacheck: globals TestJpomFilteringLogic lib

local lu = require("luaunit")

TestJpomFilteringLogic = {}

function TestJpomFilteringLogic:setUp()
    self.wraps = {}
    self.contextWraps = {}
    lib = {}
    self.host = {
        hooks = {
            wrap = function(funcName, callback)
                self.wraps[funcName] = callback
            end,
            contextWrap = function(funcName, callback)
                self.contextWraps[funcName] = callback
            end,
        },
        isEnabled = function()
            return true
        end,
        logIf = function() end,
    }
    self.sources = {
        HadesKeepsake = {
            isBanned = function(_, traitName)
                return traitName == "AshenGift"
            end,
        },
    }
    self.runtime = {
        controls = {
            get = function(name)
                return self.sources[name]
            end,
        },
    }
    self.traitInfo = {
        resolveCurrentTrait = function(runtimeContext, traitName)
            if runtimeContext.controls == nil then return nil, nil end
            if traitName ~= "AshenGift" then
                return nil, nil
            end
            return nil, {
                controlName = "Hades",
                tierKey = "Hades",
                tierIndex = 1,
                traitName = traitName,
            }
        end,
        hadesKeepsake = function(runtimeContext)
            return runtimeContext.controls.get("HadesKeepsake")
        end,
    }

    assert(loadfile("src/mods/logic/filtering_jpom.lua"))({
        module = self.host,
        traitInfo = self.traitInfo,
    })
end

local function MakeContext()
    local wraps = {}
    return {
        wraps = wraps,
        wrap = function(funcName, callback)
            wraps[funcName] = callback
        end,
    }
end

function TestJpomFilteringLogic:testJpomContextBlocksBannedKeepsakeTrait()
    local context = MakeContext()
    self.contextWraps.GiveRandomHadesBoonAndBoostBoons(self.host, self.runtime, context)

    local result = context.wraps.IsTraitEligible(function()
        return true
    end, {
        Name = "AshenGift",
    }, {})

    lu.assertFalse(result)
end

function TestJpomFilteringLogic:testJpomContextAllowsUnbannedKeepsakeTrait()
    local context = MakeContext()
    self.contextWraps.GiveRandomHadesBoonAndBoostBoons(self.host, self.runtime, context)

    local result = context.wraps.IsTraitEligible(function()
        return true
    end, {
        Name = "OtherTrait",
    }, {})

    lu.assertTrue(result)
end

function TestJpomFilteringLogic:testJpomContextNilTraitUsesVanilla()
    local context = MakeContext()
    self.contextWraps.GiveRandomHadesBoonAndBoostBoons(self.host, self.runtime, context)

    local result = context.wraps.IsTraitEligible(function(traitData)
        lu.assertNil(traitData)
        return false
    end, nil, {})

    lu.assertFalse(result)
end
