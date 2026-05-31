-- luacheck: globals TestTraitInfoLogic bit32

local lu = require("luaunit")

TestTraitInfoLogic = {}

local function MakeTraitInfo(opts)
    opts = opts or {}
    local sourceResolver = {}

    function sourceResolver.infoFromLoot(lootName)
        return (opts.lootLookup or {})[lootName]
    end

    function sourceResolver.primarySourceName(sourceName)
        return (opts.primaryLookup or {})[sourceName] or sourceName
    end

    function sourceResolver.infoFromTrait(traitName, requestedControlName, requestedTierIndex)
        local list = (opts.traitLookup or {})[traitName]
        if not list then
            return nil
        end
        for _, entry in ipairs(list) do
            local controlName = (opts.groups or {})[entry.god] or entry.god
            local tierIndex = (opts.banPoolIndexes or {})[entry.god] or 1
            if (not requestedControlName or requestedControlName == controlName)
                and (not requestedTierIndex or requestedTierIndex == tierIndex) then
                return {
                    controlName = controlName,
                    sourceName = controlName,
                    tierKey = entry.god,
                    tierIndex = tierIndex,
                    traitName = traitName,
                }
            end
        end
        return nil
    end

    function sourceResolver.specialSource(sourceRole)
        return (opts.specialSources or {})[sourceRole]
    end

    function sourceResolver.judgementSource(clearedBiomes)
        return (opts.judgementSources or {})[clearedBiomes]
    end

    local runState = {
        getBanPoolIndex = function(_, godKey)
            return (opts.runBanPoolIndexes or {})[godKey] or 1
        end,
    }
    return assert(loadfile("src/mods/logic/trait_info.lua"))({
        sourceResolver = sourceResolver,
        runState = runState,
    })
end

local function MakeRuntime(sources)
    return {
        controls = {
            get = function(name)
                return sources and sources[name] or nil
            end,
        },
    }
end

local function MakeSource(opts)
    opts = opts or {}
    return {
        isBanned = function(_, traitName, tierIndex)
            local key = tostring(traitName) .. ":" .. tostring(tierIndex or 1)
            return opts.banned and opts.banned[key] == true
        end,
    }
end

function TestTraitInfoLogic.testSpecialSourcesResolveThroughRuntimeControls()
    local traitInfo = MakeTraitInfo({
        specialSources = {
            blackNightBanishment = {
                controlName = "CirceBNB",
                sourceName = "CirceBNB",
                tierKey = "CirceBNB",
                tierIndex = 1,
            },
            hadesKeepsake = {
                controlName = "HadesKeepsake",
                sourceName = "HadesKeepsake",
                tierKey = "HadesKeepsake",
                tierIndex = 1,
            },
            redCitrineDivination = {
                controlName = "CirceCRD",
                sourceName = "CirceCRD",
                tierKey = "CirceCRD",
                tierIndex = 1,
            },
        },
    })
    local bnb = MakeSource()
    local hadesKeepsake = MakeSource()
    local crd = MakeSource()

    local bnbSource, bnbInfo = traitInfo.blackNightBanishment(MakeRuntime({
        CirceBNB = bnb,
    }))
    local hadesKeepsakeSource, hadesKeepsakeInfo = traitInfo.hadesKeepsake(MakeRuntime({
        HadesKeepsake = hadesKeepsake,
    }))
    local crdSource, crdInfo = traitInfo.redCitrineDivination(MakeRuntime({
        CirceCRD = crd,
    }))

    lu.assertEquals(bnbSource, bnb)
    lu.assertEquals(bnbInfo.controlName, "CirceBNB")
    lu.assertEquals(hadesKeepsakeSource, hadesKeepsake)
    lu.assertEquals(hadesKeepsakeInfo.controlName, "HadesKeepsake")
    lu.assertEquals(crdSource, crd)
    lu.assertEquals(crdInfo.controlName, "CirceCRD")
end

function TestTraitInfoLogic.testJudgementSourceResolvesThroughRuntimeControls()
    local traitInfo = MakeTraitInfo({
        judgementSources = {
            [2] = {
                controlName = "Judgement2",
                sourceName = "Judgement2",
                tierKey = "Judgement2",
                tierIndex = 1,
            },
        },
    })
    local judgement = MakeSource()

    local source, info = traitInfo.judgement(MakeRuntime({
        Judgement2 = judgement,
    }), 2)

    lu.assertEquals(source, judgement)
    lu.assertEquals(info.controlName, "Judgement2")
end

function TestTraitInfoLogic.testLookupLootUsesSourceIndex()
    local traitInfo = MakeTraitInfo({
        lootLookup = {
            ApolloUpgrade = {
                controlName = "Apollo",
                sourceName = "Apollo",
                tierKey = "Apollo",
                tierIndex = 1,
            },
        },
    })

    lu.assertEquals(traitInfo.lookupLoot("ApolloUpgrade"), {
        controlName = "Apollo",
        sourceName = "Apollo",
        tierKey = "Apollo",
        tierIndex = 1,
    })
end

function TestTraitInfoLogic.testResolveLootResolvesThroughRuntimeControls()
    local traitInfo = MakeTraitInfo({
        lootLookup = {
            ApolloUpgrade = {
                controlName = "Apollo",
                sourceName = "Apollo",
                tierKey = "Apollo",
                tierIndex = 1,
            },
        },
    })
    local source = MakeSource()

    local resolvedSource, info = traitInfo.resolveLoot(MakeRuntime({
        Apollo = source,
    }), "ApolloUpgrade")

    lu.assertEquals(resolvedSource, source)
    lu.assertEquals(info.controlName, "Apollo")
end

function TestTraitInfoLogic.testPrimarySourceNameUsesSourceIndex()
    local traitInfo = MakeTraitInfo({
        primaryLookup = {
            Apollo2 = "Apollo",
        },
    })

    lu.assertEquals(traitInfo.primarySourceName("Apollo2"), "Apollo")
    lu.assertEquals(traitInfo.primarySourceName("Unknown"), "Unknown")
end

function TestTraitInfoLogic.testBanChecksUseCurrentBanPoolForDuplicateSource()
    local traitInfo = MakeTraitInfo({
        groups = { Apollo2 = "Apollo" },
        banPoolIndexes = { Apollo = 1, Apollo2 = 2 },
        runBanPoolIndexes = { Apollo = 2 },
        traitLookup = {
            Strike = {
                { god = "Apollo", bit = 0, mask = 1 },
                { god = "Apollo2", bit = 0, mask = 1 },
            },
        },
    })
    local source = MakeSource({
        banned = {
            ["Strike:2"] = true,
        },
    })

    local isBanned, info = traitInfo.isBanned("Strike", MakeRuntime({
        Apollo = source,
    }))

    lu.assertTrue(isBanned)
    lu.assertEquals(info.tierKey, "Apollo2")
end

function TestTraitInfoLogic.testBanChecksCanUseExplicitSourceInfo()
    local traitInfo = MakeTraitInfo({
        groups = { Apollo2 = "Apollo" },
        banPoolIndexes = { Apollo = 1, Apollo2 = 2 },
        runBanPoolIndexes = { Apollo = 1 },
        traitLookup = {
            Strike = {
                { god = "Apollo", bit = 0, mask = 1 },
                { god = "Apollo2", bit = 0, mask = 1 },
            },
        },
    })
    local source = MakeSource({
        banned = {
            ["Strike:2"] = true,
        },
    })

    local isBanned, info = traitInfo.isBanned("Strike", MakeRuntime({
        Apollo = source,
    }), {
        controlName = "Apollo",
        sourceName = "Apollo",
    }, 2)

    lu.assertTrue(isBanned)
    lu.assertEquals(info.tierKey, "Apollo2")
end

function TestTraitInfoLogic.testBanChecksRouteThroughRuntimeControlsAndCacheSource()
    local traitInfo = MakeTraitInfo({
        traitLookup = {
            Strike = {
                { god = "Apollo", bit = 1, mask = 2 },
            },
        },
    })
    local getCount = 0
    local source = MakeSource({
        banned = {
            ["Strike:1"] = true,
        },
    })
    local runtime = {
        controls = {
            get = function(name)
                getCount = getCount + 1
                return name == "Apollo" and source or nil
            end,
        },
    }

    local isBanned, info = traitInfo.isBanned("Strike", runtime)
    local isBannedAgain = traitInfo.isBanned("Strike", runtime)

    lu.assertTrue(isBanned)
    lu.assertTrue(isBannedAgain)
    lu.assertEquals(info.controlName, "Apollo")
    lu.assertEquals(getCount, 1)
end
