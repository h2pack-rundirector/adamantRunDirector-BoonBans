-- luacheck: globals TestTraitInfoLogic bit32

local lu = require("luaunit")

TestTraitInfoLogic = {}

local function MakeTraitInfo(opts)
    opts = opts or {}
    local sourceResolver = {}

    function sourceResolver.fromLootName(lootName)
        return (opts.lootLookup or {})[lootName]
    end

    function sourceResolver.primarySourceName(sourceName)
        return (opts.primaryLookup or {})[sourceName] or sourceName
    end

    function sourceResolver.fromTraitName(traitName, query)
        query = query or {}
        local list = (opts.traitLookup or {})[traitName]
        if not list then
            return nil
        end
        for _, entry in ipairs(list) do
            local controlName = (opts.groups or {})[entry.god] or entry.god
            local tierIndex = (opts.banPoolIndexes or {})[entry.god] or 1
            if (not query.controlName or query.controlName == controlName)
                and (not query.tierIndex or query.tierIndex == tierIndex) then
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

function TestTraitInfoLogic.testControlFromLootUsesSourceIndex()
    local traitInfo = MakeTraitInfo({
        lootLookup = {
            ApolloUpgrade = "Apollo",
        },
    })

    lu.assertEquals(traitInfo.controlFromLoot("ApolloUpgrade"), "Apollo")
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

function TestTraitInfoLogic.testBanChecksRouteThroughRuntimeControlsAndCacheSource()
    local traitInfo = MakeTraitInfo({
        traitLookup = {
            Strike = {
                { god = "Apollo", bit = 1, mask = 2 },
            },
        },
    })
    local cache = {}
    local source = MakeSource({
        banned = {
            ["Strike:1"] = true,
        },
    })

    local isBanned, info = traitInfo.isBanned("Strike", MakeRuntime({
        Apollo = source,
    }), { cache = cache })

    lu.assertTrue(isBanned)
    lu.assertEquals(info.controlName, "Apollo")
    lu.assertEquals(cache.Apollo, source)
end
