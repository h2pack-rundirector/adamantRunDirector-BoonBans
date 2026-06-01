-- luacheck: globals TestActionsLogic bit32
-- luacheck: no unused args

local lu = require("luaunit")

TestActionsLogic = {}

local function MakeSource(rows, rarity, defaultTierCount)
    defaultTierCount = defaultTierCount or 1
    local source = {}

    function source:tierCount()
        return #rows
    end

    function source:resetAllTiers()
        local changed = false
        for index = 1, #rows do
            if rows[index] ~= 0 then
                rows[index] = 0
                changed = true
            end
        end
        return changed
    end

    function source:hasRarity()
        return rarity ~= nil
    end

    function source:resetRarity()
        if rarity == nil or rarity.value == 0 then
            return false
        end
        rarity.value = 0
        return true
    end

    function source:resetAll()
        local changed = self:resetAllTiers()
        while #rows > defaultTierCount do
            rows[#rows] = nil
            changed = true
        end
        while #rows < defaultTierCount do
            rows[#rows + 1] = 0
            changed = true
        end
        if self:resetRarity() then
            changed = true
        end
        return changed
    end

    return source
end

local function MakeControls(sources)
    return {
        get = function(name)
            return sources[name]
        end,
    }
end

function TestActionsLogic:setUp()
    self.rows = { 1 }
    self.rarity = { value = 9 }
    self.sources = {
        Apollo = MakeSource(self.rows, self.rarity),
        Hera = MakeSource({ 0 }, { value = 6 }),
    }
    self.controls = MakeControls(self.sources)
    self.state = {
        controls = {
            Apollo = {},
            Hera = {},
        },
    }
    self.actions = dofile("src/mods/actions.lua").create(self.state)
    self.host = {
        logIf = function() end,
    }
    self.actionContext = {
        controls = self.controls,
    }
end

function TestActionsLogic:testResetAllRarityClearsUniqueSources()
    lu.assertTrue(self.actions.resetAllRarity(nil, nil, nil, nil, self.actionContext))
    lu.assertEquals(self.rarity.value, 0)

    lu.assertFalse(self.actions.resetAllRarity(nil, nil, nil, nil, self.actionContext))
end

function TestActionsLogic:testResetAllBansClearsConfiguredSources()
    self.rows[2] = 3
    lu.assertTrue(self.actions.resetAllBans(self.host, nil, nil, nil, self.actionContext))
    lu.assertEquals(self.rows[1], 0)
    lu.assertEquals(self.rows[2], 0)
end

function TestActionsLogic:testResetAllControlsRestoresDefaultTierCount()
    self.rows[2] = 3
    lu.assertTrue(self.actions.resetAllControls(self.host, nil, nil, nil, self.actionContext))
    lu.assertEquals(self.rows, { 0 })
    lu.assertEquals(self.rarity.value, 0)

    lu.assertFalse(self.actions.resetAllControls(self.host, nil, nil, nil, self.actionContext))
end

function TestActionsLogic:testSetBridalGlowTargetWritesOnlyOnChange()
    local values = {
        BridalGlowTargetBoon = "",
    }
    local dataRefs = {
        get = function(alias)
            return {
                read = function()
                    return values[alias]
                end,
                write = function(_, value)
                    values[alias] = value
                end,
            }
        end,
    }

    lu.assertTrue(self.actions.setBridalGlowTarget(nil, dataRefs, nil, "Strike"))
    lu.assertEquals(values.BridalGlowTargetBoon, "Strike")

    lu.assertFalse(self.actions.setBridalGlowTarget(nil, dataRefs, nil, "Strike"))

    lu.assertTrue(self.actions.setBridalGlowTarget(nil, dataRefs, nil, ""))
    lu.assertEquals(values.BridalGlowTargetBoon, "")
end
