-- luacheck: globals TestPaddingLogic TraitData

local lu = require("luaunit")

TestPaddingLogic = {}

local function makeConfig(overrides)
    local config = {
        enabled = true,
        prioritizeCoreForFirstN = 0,
        avoidFutureAllowed = true,
        allowDuos = false,
    }
    for key, value in pairs(overrides or {}) do
        config[key] = value
    end
    return config
end

local function makeRuntime(values)
    values = values or {}
    return {
        data = {
            get = function(alias)
                return {
                    read = function()
                        return values[alias]
                    end,
                }
            end,
        },
    }
end

function TestPaddingLogic:setUp()
    math.randomseed(1)
    TraitData = {
        Duo = { IsDuoBoon = true },
        FutureAllowed = {},
        Filler = {},
        Priority = {},
    }
    self.padding = dofile("src/mods/logic/padding.lua")
end

function TestPaddingLogic:testReadConfigUsesRuntimeData()
    local config = self.padding.readConfig(makeRuntime({
        EnablePadding = true,
        Padding_PrioritizeCoreForFirstN = 2,
        Padding_AvoidFutureAllowed = false,
        Padding_AllowDuos = true,
    }))

    lu.assertEquals(config, {
        enabled = true,
        prioritizeCoreForFirstN = 2,
        avoidFutureAllowed = false,
        allowDuos = true,
    })
end

function TestPaddingLogic:testExtendLootQueueNoopsWhenDisabledOrAlreadyFull()
    local queue = { { ItemName = "Allowed" } }
    self.padding.extendLootQueue(queue, {
        config = makeConfig({ enabled = false }),
        banned = { { ItemName = "Filler" } },
        queueMaxSize = 3,
    })
    lu.assertEquals(#queue, 1)

    self.padding.extendLootQueue(queue, {
        config = makeConfig(),
        banned = { { ItemName = "Filler" } },
        queueMaxSize = 1,
    })
    lu.assertEquals(#queue, 1)
end

function TestPaddingLogic:testExtendLootQueueSkipsDuosAndFutureAllowedByDefault()
    local source = {
        tierCount = function()
            return 2
        end,
        isTierConfigured = function(_, tierIndex)
            return tierIndex == 2
        end,
        isBanned = function()
            return false
        end,
    }
    local traitInfo = {
        resolveTrait = function(_, traitName, _, tierIndex)
            if traitName == "FutureAllowed" and tierIndex == 2 then
                return source, { tierIndex = tierIndex }
            end
            return nil, nil
        end,
    }
    local queue = { { ItemName = "Allowed" } }

    self.padding.extendLootQueue(queue, {
        config = makeConfig(),
        banned = {
            { ItemName = "Duo" },
            { ItemName = "FutureAllowed" },
            { ItemName = "Filler" },
        },
        queueMaxSize = 3,
        source = source,
        sourceInfo = { controlName = "Apollo" },
        tierIndex = 1,
        runtime = {},
        traitInfo = traitInfo,
    })

    lu.assertEquals(queue, {
        { ItemName = "Allowed" },
        { ItemName = "Filler" },
    })
end

function TestPaddingLogic:testExtendLootQueueCanAllowDuosAndFutureAllowed()
    local queue = {}
    self.padding.extendLootQueue(queue, {
        config = makeConfig({
            allowDuos = true,
            avoidFutureAllowed = false,
        }),
        banned = {
            { ItemName = "Duo" },
            { ItemName = "FutureAllowed" },
        },
        queueMaxSize = 2,
    })

    lu.assertEquals(#queue, 2)
end

function TestPaddingLogic:testExtendLootQueuePrioritizesCoreBoonsBeforeFirstNAcquisitions()
    local queue = {}
    self.padding.extendLootQueue(queue, {
        config = makeConfig({
            prioritizeCoreForFirstN = 2,
            avoidFutureAllowed = false,
            allowDuos = true,
        }),
        banned = {
            { ItemName = "Filler" },
            { ItemName = "Priority" },
        },
        priorityList = { "Priority" },
        pickCount = 0,
        queueMaxSize = 1,
    })

    lu.assertEquals(queue, {
        { ItemName = "Priority" },
    })
end

function TestPaddingLogic:testExtendChoiceListPadsWhenEnabledOrForced()
    local allowed = { { ItemName = "Allowed" } }
    self.padding.extendChoiceList(allowed, {
        { ItemName = "Banned" },
    }, {
        config = makeConfig(),
        maxSize = 2,
    })
    lu.assertEquals(#allowed, 2)

    local forced = { { ItemName = "Allowed" } }
    self.padding.extendChoiceList(forced, {
        { ItemName = "Banned" },
    }, {
        config = makeConfig({ enabled = false }),
        maxSize = 2,
        force = true,
    })
    lu.assertEquals(#forced, 2)
end
