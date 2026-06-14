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

function TestPaddingLogic:testSafetyFillLootQueueAddsDistinctMarkedFillers()
    local queue = {
        { ItemName = "Allowed" },
    }

    local safetyNames = self.padding.safetyFillLootQueue(queue, {
        banned = {
            { ItemName = "Allowed" },
            { ItemName = "BannedA" },
            { ItemName = "BannedB" },
        },
        queueMaxSize = 3,
        sourceCount = 3,
        minSourceCount = 3,
    })

    lu.assertEquals(queue, {
        { ItemName = "Allowed" },
        { ItemName = "BannedA", BoonBansSafetyFiller = true },
        { ItemName = "BannedB", BoonBansSafetyFiller = true },
    })
    lu.assertEquals(safetyNames, {
        BannedA = true,
        BannedB = true,
    })
end

function TestPaddingLogic:testSafetyFillLootQueueKeepsNaturalShortPoolsShort()
    local queue = {
        { ItemName = "Allowed" },
    }

    local safetyNames = self.padding.safetyFillLootQueue(queue, {
        banned = {
            { ItemName = "Banned" },
        },
        queueMaxSize = 3,
        sourceCount = 2,
        minSourceCount = 3,
    })

    lu.assertEquals(queue, {
        { ItemName = "Allowed" },
    })
    lu.assertNil(safetyNames)
end

function TestPaddingLogic:testReplaceSafetyFillersWithFallbackGold()
    local options = {
        { ItemName = "Allowed" },
        { ItemName = "BannedA", BoonBansSafetyFiller = true },
        { ItemName = "BannedB" },
    }

    local replaced = self.padding.replaceSafetyFillersWithFallbackGold(options, {
        BannedB = true,
    })

    lu.assertEquals(replaced, 2)
    lu.assertEquals(options, {
        { ItemName = "Allowed" },
        { ItemName = "FallbackGold", Type = "Trait", Rarity = "Common" },
        { ItemName = "FallbackGold", Type = "Trait", Rarity = "Common" },
    })
end

function TestPaddingLogic:testSafetyFillChoiceListUsesFallbackGold()
    local allowed = {
        { ItemName = "Allowed" },
    }

    local added = self.padding.safetyFillChoiceListWithFallbackGold(allowed, {
        { ItemName = "Banned" },
    }, {
        maxSize = 3,
    })

    lu.assertEquals(added, 2)
    lu.assertEquals(allowed, {
        { ItemName = "Allowed" },
        { ItemName = "FallbackGold", Type = "Trait", Rarity = "Common" },
        { ItemName = "FallbackGold", Type = "Trait", Rarity = "Common" },
    })
end

function TestPaddingLogic:testCreatedChoicePaddingUsesFallbackGoldWithoutPrivatePadding()
    local service = self.padding.create({ privatePadding = false })
    local allowed = {
        { ItemName = "Allowed" },
    }

    service.fillChoiceList(allowed, {
        { ItemName = "Banned" },
    }, makeRuntime({}), {
        maxSize = 3,
    })

    lu.assertEquals(allowed, {
        { ItemName = "Allowed" },
        { ItemName = "FallbackGold", Type = "Trait", Rarity = "Common" },
        { ItemName = "FallbackGold", Type = "Trait", Rarity = "Common" },
    })
end

function TestPaddingLogic:testCreatedChoicePaddingUsesRealPaddingBeforeFallbackGold()
    local service = self.padding.create({ privatePadding = true })
    local allowed = {
        { ItemName = "Allowed" },
    }

    service.fillChoiceList(allowed, {
        { ItemName = "Banned" },
    }, makeRuntime({
        EnablePadding = true,
    }), {
        maxSize = 3,
    })

    lu.assertEquals(allowed, {
        { ItemName = "Allowed" },
        { ItemName = "Banned" },
        { ItemName = "FallbackGold", Type = "Trait", Rarity = "Common" },
    })
end

function TestPaddingLogic:testCreatedSpellPaddingDoesNotUseFallbackGold()
    local service = self.padding.create({ privatePadding = false })
    local allowed = {
        "AllowedSpell",
    }

    service.fillSpellList(allowed, {
        "BannedSpell",
    }, makeRuntime({}), {
        maxSize = 3,
    })

    lu.assertEquals(allowed, {
        "AllowedSpell",
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
