-- luacheck: globals TestUiModel ResetBoonBansUiHarness

local lu = require("luaunit")

require("tests/TestUtils")

TestUiModel = {}

function TestUiModel:setUp()
    self.ui, self.uiData, self.state = ResetBoonBansUiHarness()
end

function TestUiModel:testBuildPackedBanDisplayValuesUsesSpecialLabels()
    local displayValues = self.ui.BuildPackedBanDisplayValues("Apollo")

    lu.assertEquals(displayValues.Bans__Strike, "Strike")
    lu.assertEquals(displayValues["Bans__Wave Pair"], "[D] Wave Pair")
    lu.assertEquals(displayValues["Bans__Sun Glory"], "[L] Sun Glory")
    lu.assertEquals(displayValues.Bans__Infusion, "[I] Infusion")
end

function TestUiModel:testBuildPackedBanValueColorsIncludesOnlySpecialBoons()
    local colors = self.ui.BuildPackedBanValueColors("Apollo")

    lu.assertNil(colors.Bans__Strike)
    lu.assertEquals(colors["Bans__Wave Pair"], { 0.82, 1.0, 0.38, 1.0 })
    lu.assertEquals(colors["Bans__Sun Glory"], { 1.0, 0.56, 0.0, 1.0 })
    lu.assertEquals(colors.Bans__Infusion, { 1.0, 0.29, 1.0, 1.0 })
end

function TestUiModel:testGetVisibleBanCountUsesTextFilterOnly()
    local data = {
        get = function(alias)
            lu.assertEquals(alias, "BanFilterText")
            return {
                read = function()
                    return "cast"
                end,
            }
        end,
    }

    lu.assertEquals(self.ui.GetVisibleBanCount("Apollo", data), 1)
    lu.assertEquals(self.ui.GetVisibleBanCount("Circe", data), 0)
end

function TestUiModel:testBuildBanPoolRootUsesConfiguredPoolCount()
    local root = self.ui.BuildBanPoolRoot("Apollo", {})

    lu.assertEquals(root.label, "Apollo")
    lu.assertEquals(root.primaryGodKey, "Apollo")
    lu.assertEquals(root.maxBanPools, 3)
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

function TestUiModel:testBuildBanPoolRootFallsBackToSinglePool()
    local root = self.ui.BuildBanPoolRoot("Circe", {})

    lu.assertEquals(root.label, "Circe")
    lu.assertEquals(root.maxBanPools, 1)
    lu.assertEquals(root.banPools, {
        {
            key = "Circe",
            label = "Bans",
        },
    })
end

function TestUiModel.testOtherGodsSetupTabUsesMaxPoolCapability()
    local seenTabItems = {}
    local activeRootValue = "Hermes"
    local otherGods = dofile("src/mods/ui/ui_other_gods.lua").bind({
        state = {
            banConfig = {
                GetConfiguredBanPoolCount = function()
                    return 1
                end,
                IsBanPoolCustomized = function()
                    return false
                end,
            },
        },
        model = {
            ROOT_NAV_WIDTH = 220,
            BuildBanPoolRoot = function(godKey)
                if godKey == "Hermes" then
                    return {
                        id = "Hermes",
                        label = "Hermes",
                        primaryGodKey = "Hermes",
                        maxBanPools = 5,
                        banPools = {
                            { key = "Hermes", label = "1st" },
                        },
                    }
                end
                return {
                    id = godKey,
                    label = godKey,
                    primaryGodKey = godKey,
                    maxBanPools = 1,
                    banPools = {
                        { key = godKey, label = "Bans" },
                    },
                }
            end,
            GetGodColor = function()
                return nil
            end,
        },
        components = {},
    })

    local state = {
        get = function(alias)
            lu.assertEquals(alias, "ActiveOtherGodRoot")
            return {
                read = function()
                    return activeRootValue
                end,
                write = function(_, value)
                    activeRootValue = value
                end,
            }
        end,
    }

    local draw = {
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
    }

    otherGods.draw(draw, state, {})

    lu.assertTrue(seenTabItems.Setup)
end

function TestUiModel.testOlympianRootsAreCachedByConfiguredPoolCount()
    local buildCounts = {}
    local configuredCounts = {}
    local availabilityReadCount = 0
    local activeRootValue = "Apollo"
    local olympians = dofile("src/mods/ui/ui_olympians.lua").bind({
        state = {
            banConfig = {
                GetConfiguredBanPoolCount = function(godKey)
                    return configuredCounts[godKey] or 1
                end,
                IsBanPoolCustomized = function()
                    return false
                end,
                ResolveGodKey = function(godKey)
                    return godKey
                end,
            },
        },
        model = {
            ROOT_NAV_WIDTH = 220,
            MUTED_TEXT_COLOR = { 0.6, 0.6, 0.6, 1 },
            BuildBanPoolRoot = function(godKey)
                buildCounts[godKey] = (buildCounts[godKey] or 0) + 1
                return {
                    id = godKey,
                    label = godKey,
                    primaryGodKey = godKey,
                    maxBanPools = 5,
                    hasBridalGlow = godKey == "Hera",
                    banPools = {
                        { key = godKey, label = "1st" },
                    },
                }
            end,
            GetGodColor = function()
                return nil
            end,
        },
        actions = {},
        components = {},
        godAvailability = {
            read = function()
                availabilityReadCount = availabilityReadCount + 1
                return { active = false, available = {} }
            end,
            isSnapshotActive = function(snapshot)
                return snapshot.active == true
            end,
            isSnapshotAvailable = function(snapshot, godKey)
                return snapshot.available[godKey] ~= false
            end,
        },
    })

    local state = {
        get = function(alias)
            lu.assertEquals(alias, "ActiveOlympianRoot")
            return {
                read = function()
                    return activeRootValue
                end,
                write = function(_, value)
                    activeRootValue = value
                end,
            }
        end,
    }

    local draw = {
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
    }

    olympians.draw(draw, state, {})
    lu.assertEquals(buildCounts.Apollo, 1)
    lu.assertEquals(buildCounts.Hera, 1)
    lu.assertEquals(availabilityReadCount, 1)

    olympians.draw(draw, state, {})
    lu.assertEquals(buildCounts.Apollo, 1)
    lu.assertEquals(buildCounts.Hera, 1)
    lu.assertEquals(availabilityReadCount, 2)

    configuredCounts.Apollo = 2
    olympians.draw(draw, state, {})
    lu.assertEquals(buildCounts.Apollo, 2)
    lu.assertEquals(buildCounts.Hera, 1)
    lu.assertEquals(availabilityReadCount, 3)
end
