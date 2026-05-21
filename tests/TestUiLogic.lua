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
