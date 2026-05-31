-- luacheck: globals TestUiRoots import

local lu = require("luaunit")

require("tests/TestUtils")

TestUiRoots = {}

import = function(path, _, ...)
    return assert(loadfile("src/" .. path))(...)
end

local UI_STYLE = {
    DEFAULT_GOD_COLOR = { 1, 1, 1, 1 },
    MUTED_TEXT_COLOR = { 0.6, 0.6, 0.6, 1 },
    ROOT_NAV_WIDTH = 220,
}

local function LoadRoots()
    return assert(loadfile("src/mods/ui/ui_roots.lua"))({
        style = UI_STYLE,
    })
end

local function MakeSource(opts)
    opts = opts or {}
    local name = opts.name or "Source"
    return {
        name = function()
            return name
        end,
        group = function()
            return opts.group
        end,
        maxTiers = function()
            return opts.maxTiers or 1
        end,
        label = function()
            return opts.label or name
        end,
        color = function()
            return opts.color
        end,
        tierCount = function()
            return opts.tierCount or 1
        end,
        hasRarity = function()
            return opts.hasRarity == true
        end,
        isCustomized = function()
            return opts.customized == true
        end,
        tierKey = function(_, tierIndex)
            if opts.tierKey then
                return opts.tierKey(tierIndex)
            end
            if tierIndex <= 1 then
                return name
            end
            return name .. tostring(tierIndex)
        end,
        tierLabel = function(_, tierIndex)
            if opts.tierLabel then
                return opts.tierLabel(tierIndex)
            end
            if (opts.maxTiers or 1) <= 1 then
                return "Bans"
            end
            if tierIndex == 1 then return "1st" end
            if tierIndex == 2 then return "2nd" end
            if tierIndex == 3 then return "3rd" end
            return tostring(tierIndex) .. "th"
        end,
    }
end

local function MakeControls(sources)
    return {
        get = function(name)
            return sources[name] or MakeSource()
        end,
    }
end

function TestUiRoots:setUp()
    self.roots = LoadRoots()
end

function TestUiRoots:testBuildTraitSourceRootUsesControlMetadata()
    local root = self.roots.buildTraitSourceRoot(MakeSource({
        name = "Apollo",
        label = "Apollo",
        group = "Core",
        color = { 1, 0, 0, 1 },
        tierCount = 2,
        maxTiers = 3,
        hasRarity = true,
    }), {
        hasBridalGlow = true,
    })

    lu.assertEquals(root.id, "Apollo")
    lu.assertEquals(root.label, "Apollo")
    lu.assertEquals(root.group, "Core")
    lu.assertEquals(root.color, { 1, 0, 0, 1 })
    lu.assertEquals(root.primaryGodKey, "Apollo")
    lu.assertEquals(root.controlName, "Apollo")
    lu.assertEquals(root.maxBanPools, 3)
    lu.assertTrue(root.hasRarity)
    lu.assertTrue(root.hasBridalGlow)
    lu.assertEquals(#root.banPools, 2)
    lu.assertEquals(root.banPools[1], {
        key = "Apollo",
        label = "1st",
    })
    lu.assertEquals(root.banPools[2], {
        key = "Apollo2",
        label = "2nd",
    })
end

function TestUiRoots:testBuildTraitSourceRootUsesSinglePoolLabel()
    local root = self.roots.buildTraitSourceRoot(MakeSource({
        name = "Circe",
        label = "Circe",
        tierCount = 1,
        maxTiers = 1,
        hasRarity = true,
    }))

    lu.assertEquals(root.label, "Circe")
    lu.assertEquals(root.maxBanPools, 1)
    lu.assertEquals(root.banPools, {
        {
            key = "Circe",
            label = "Bans",
        },
    })
end

function TestUiRoots.testOtherGodsSetupTabUsesMaxPoolCapability()
    local seenTabItems = {}
    local otherGods = assert(loadfile("src/mods/ui/ui_other_gods.lua"))({
        state = {},
        style = UI_STYLE,
        roots = LoadRoots(),
    })

    local ui = {
        controls = MakeControls({
            Hermes = MakeSource({
                name = "Hermes",
                tierCount = 1,
                maxTiers = 5,
            }),
        }),
        draw = {
            imgui = {
                BeginChild = function() end,
                EndChild = function() end,
                BeginTabBar = function()
                    return true
                end,
                EndTabBar = function() end,
                BeginTabItem = function(label)
                    seenTabItems[label] = true
                    return false
                end,
            },
            nav = {
                verticalTabs = function(opts)
                    return opts.activeKey
                end,
            },
            control = function() end,
        },
    }

    otherGods.draw({}, ui)

    lu.assertTrue(seenTabItems.Setup)
end

function TestUiRoots.testOlympianRootsAreCachedByConfiguredPoolCount()
    local buildCounts = {}
    local configuredCounts = {}
    local availabilityReadCount = 0
    local realRoots = LoadRoots()
    local olympians = assert(loadfile("src/mods/ui/ui_olympians.lua"))({
        state = {},
        style = UI_STYLE,
        roots = {
            buildTraitSourceRoot = function(source, opts)
                local name = source:name()
                buildCounts[name] = (buildCounts[name] or 0) + 1
                return realRoots.buildTraitSourceRoot(source, opts)
            end,
        },
    })

    local ui = {
        data = {
            shared = {
                read = function(name)
                    lu.assertEquals(name, "GodAvailability")
                    availabilityReadCount = availabilityReadCount + 1
                    return {
                        active = false,
                        available = {},
                    }
                end,
            },
        },
        controls = {
            get = function(name)
                return MakeSource({
                    name = name,
                    tierCount = configuredCounts[name] or 1,
                    maxTiers = 5,
                })
            end,
        },
        draw = {
            imgui = {
                BeginChild = function() end,
                EndChild = function() end,
                BeginTabBar = function()
                    return false
                end,
            },
            nav = {
                verticalTabs = function(opts)
                    return opts.activeKey
                end,
            },
            widgets = {
                text = function() end,
            },
        },
    }

    olympians.draw({}, ui)
    lu.assertEquals(buildCounts.Apollo, 1)
    lu.assertEquals(buildCounts.Hera, 1)
    lu.assertEquals(availabilityReadCount, 1)

    olympians.draw({}, ui)
    lu.assertEquals(buildCounts.Apollo, 1)
    lu.assertEquals(buildCounts.Hera, 1)
    lu.assertEquals(availabilityReadCount, 2)

    configuredCounts.Apollo = 2
    olympians.draw({}, ui)
    lu.assertEquals(buildCounts.Apollo, 2)
    lu.assertEquals(buildCounts.Hera, 1)
    lu.assertEquals(availabilityReadCount, 3)
end
