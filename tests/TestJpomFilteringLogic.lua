-- luacheck: globals TestJpomFilteringLogic lib

local lu = require("luaunit")

TestJpomFilteringLogic = {}

function TestJpomFilteringLogic:setUp()
    self.wraps = {}
    lib = {}
    self.host = {
        hooks = {
            wrap = function(funcName, callback)
                self.wraps[funcName] = callback
            end,
        },
    }
    self.context = {
        isJpomOffering = false,
    }

    assert(loadfile("src/mods/logic/filtering_jpom.lua"))({
        module = self.host,
        context = self.context,
    })
end

function TestJpomFilteringLogic:testJpomMarksKeepsakeOfferingDuringBaseCallThenRestores()
    local duringBase = nil

    self.wraps.GiveRandomHadesBoonAndBoostBoons(self.host, {}, function()
        duringBase = self.context.isJpomOffering
        return "result"
    end, {})

    lu.assertTrue(duringBase)
    lu.assertFalse(self.context.isJpomOffering)
end
