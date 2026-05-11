-- luacheck: globals TestBanResolverLogic bit32

local lu = require("luaunit")

TestBanResolverLogic = {}

local function MakeResolver(opts)
    opts = opts or {}
    local catalog = {
        entries = opts.entries or {},
        findTraitEntries = function(traitName)
            return (opts.traitLookup or {})[traitName]
        end,
        getGodFromLootsource = function(lootKey)
            return (opts.lootSources or {})[lootKey]
        end,
    }
    local banPools = {
        getBanPoolIndex = function(godKey)
            return (opts.banPoolIndexes or {})[godKey] or 1
        end,
        getBanPoolKey = function(godKey, index)
            if index <= 1 then return godKey end
            return godKey .. tostring(index)
        end,
    }
    local banConfig = {
        ResolveGodKey = function(key)
            return (opts.duplicates or {})[key] or key
        end,
        GetBanMask = function(key)
            return (opts.banMasks or {})[key] or 0
        end,
        IsBanPoolConfigured = function(_, index)
            local configured = opts.configured
            if configured == nil then return true end
            return index <= configured
        end,
        GetRarityValue = function(_, bit)
            return (opts.rarityValues or {})[bit] or 0
        end,
    }
    local runState = {
        getBanPoolIndex = function(godKey)
            return (opts.runBanPoolIndexes or {})[godKey] or 1
        end,
    }
    local module = dofile("src/mods/logic/ban_resolver.lua")
    return module.create(catalog, banPools, banConfig, {}, runState, opts.godDefs or {})
end

function TestBanResolverLogic.testFindTraitInfoUsesCurrentBanPoolForDuplicateGod()
    local resolver = MakeResolver({
        duplicates = { Apollo2 = "Apollo" },
        banPoolIndexes = { Apollo = 1, Apollo2 = 2 },
        runBanPoolIndexes = { Apollo = 2 },
        traitLookup = {
            Strike = {
                { god = "Apollo", bit = 0, mask = 1 },
                { god = "Apollo2", bit = 0, mask = 1 },
            },
        },
    })

    lu.assertEquals(resolver.findTraitInfo("Strike", "Apollo").god, "Apollo2")
    lu.assertEquals(resolver.getTraitGodKey("Strike"), "Apollo")
end

function TestBanResolverLogic.testBanChecksUseMasksAndCache()
    local resolver = MakeResolver({
        traitLookup = {
            Strike = {
                { god = "Apollo", bit = 1, mask = 2 },
            },
        },
        banMasks = {
            Apollo = 2,
        },
    })
    local cache = {}

    local isBanned, info = resolver.isTraitBanned("Strike", { cache = cache })

    lu.assertTrue(isBanned)
    lu.assertEquals(info.god, "Apollo")
    lu.assertEquals(cache.Apollo, 2)
end

function TestBanResolverLogic.testRarityOverrideRequiresUnbannedConfiguredRarityGod()
    local resolver = MakeResolver({
        traitLookup = {
            Strike = {
                { god = "Apollo", bit = 1, mask = 2 },
            },
        },
        godDefs = {
            Apollo = { rarityVar = "PackedApolloRarity" },
        },
        rarityValues = {
            [1] = 3,
        },
    })

    lu.assertEquals(resolver.getTraitRarityOverride("Strike", {
        currentGodKey = "Apollo",
        banPoolIndex = 1,
    }), "Epic")

    local bannedResolver = MakeResolver({
        traitLookup = {
            Strike = {
                { god = "Apollo", bit = 1, mask = 2 },
            },
        },
        godDefs = {
            Apollo = { rarityVar = "PackedApolloRarity" },
        },
        banMasks = {
            Apollo = 2,
        },
        rarityValues = {
            [1] = 3,
        },
    })

    lu.assertNil(bannedResolver.getTraitRarityOverride("Strike", {
        currentGodKey = "Apollo",
        banPoolIndex = 1,
    }))
end

function TestBanResolverLogic.testKeepsakeEligibilityUsesKeepsakeMask()
    local resolver = MakeResolver({
        entries = {
            HadesKeepsake = {},
        },
        traitLookup = {
            AshenGift = {
                { god = "Hades", bit = 0, mask = 1 },
            },
        },
        godDefs = {
            Hades = {},
        },
        banMasks = {
            HadesKeepsake = 1,
        },
    })

    lu.assertTrue(resolver.shouldBlockTraitEligibility("AshenGift", {
        isKeepsakeOffering = true,
    }))
end
