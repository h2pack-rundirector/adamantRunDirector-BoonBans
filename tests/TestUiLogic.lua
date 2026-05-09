local lu = require("luaunit")

require("tests/TestUtils")

TestUiShared = {}

function TestUiShared:setUp()
    self.ui, self.internal, self.state = ResetBoonBansUiHarness()
end

function TestUiShared:testBuildPackedBanDisplayValuesUsesSpecialLabels()
    local displayValues = self.ui.BuildPackedBanDisplayValues("Apollo")

    lu.assertEquals(displayValues.Bans__Strike, "Strike")
    lu.assertEquals(displayValues["Bans__Wave Pair"], "[D] Wave Pair")
    lu.assertEquals(displayValues["Bans__Sun Glory"], "[L] Sun Glory")
    lu.assertEquals(displayValues.Bans__Infusion, "[I] Infusion")
end

function TestUiShared:testBuildPackedBanValueColorsIncludesOnlySpecialBoons()
    local colors = self.ui.BuildPackedBanValueColors("Apollo")

    lu.assertNil(colors.Bans__Strike)
    lu.assertEquals(colors["Bans__Wave Pair"], { 0.82, 1.0, 0.38, 1.0 })
    lu.assertEquals(colors["Bans__Sun Glory"], { 1.0, 0.56, 0.0, 1.0 })
    lu.assertEquals(colors.Bans__Infusion, { 1.0, 0.29, 1.0, 1.0 })
end

function TestUiShared:testGetScopeSummaryUsesStagedSessionWhenProvided()
    local session = {
        read = function(key)
            if key == "Bans" then
                return 9
            end
            return nil
        end,
    }

    local banned, total = self.ui.GetScopeSummary("Apollo", session)

    lu.assertEquals(banned, 2)
    lu.assertEquals(total, 5)
end

function TestUiShared:testGetVisibleBanCountUsesTextFilterOnly()
    local session = {
        view = {
            BanFilterText = "cast",
        },
    }

    lu.assertEquals(self.ui.GetVisibleBanCount("Apollo", session), 1)
    lu.assertEquals(self.ui.GetVisibleBanCount("Circe", session), 0)
end

function TestUiShared:testGetCurrentBridalGlowTargetTextUsesEligibleBoon()
    local session = {
        view = {
            BridalGlowTargetBoon = "Hex",
        },
    }

    lu.assertEquals(self.ui.GetCurrentBridalGlowTargetText(session), "Current Target: Random")

    self.internal.godInfo.Circe.boonByKey.Hex.IsBridalGlowEligible = true
    lu.assertEquals(self.ui.GetCurrentBridalGlowTargetText(session), "Current Target: Hex")
end

function TestUiShared:testGetRootDisplayLabelDropsTierPrefixForTieredRoots()
    lu.assertEquals(
        self.ui.GetRootDisplayLabel("Apollo", self.internal.godMeta.Apollo),
        "Apollo"
    )
    lu.assertEquals(
        self.ui.GetRootDisplayLabel("Circe", self.internal.godMeta.Circe),
        "Circe"
    )
end

function TestUiShared:testGodPoolFilteringUsesIntegrationInvoke()
    local calls = {}
    lib.integrations.invoke = function(id, methodName, fallback, godKey)
        table.insert(calls, {
            id = id,
            methodName = methodName,
            fallback = fallback,
            godKey = godKey,
        })
        if methodName == "isActive" then
            return true
        end
        if methodName == "isAvailable" then
            return godKey ~= "Apollo"
        end
        return fallback
    end

    lu.assertTrue(self.ui.IsGodPoolFilteringActive())
    lu.assertFalse(self.ui.IsGodVisibleInGodPool("Apollo"))
    lu.assertTrue(self.ui.IsGodVisibleInGodPool("Zeus"))

    lu.assertEquals(calls[1], {
        id = "run-director.god-availability",
        methodName = "isActive",
        fallback = false,
        godKey = nil,
    })
    lu.assertEquals(calls[2], {
        id = "run-director.god-availability",
        methodName = "isAvailable",
        fallback = true,
        godKey = "Apollo",
    })
end

function TestUiShared:testGodPoolFilteringFallsBackInactiveWhenIntegrationMissing()
    lib.integrations.invoke = function(_, _, fallback)
        return fallback
    end

    lu.assertFalse(self.ui.IsGodPoolFilteringActive())
    lu.assertTrue(self.ui.IsGodVisibleInGodPool("Apollo"))
end
