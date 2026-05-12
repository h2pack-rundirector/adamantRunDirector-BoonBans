-- luacheck: globals TestUiActionsLogic bit32

local lu = require("luaunit")

TestUiActionsLogic = {}

local function MakeSession()
    local values = {
        PackedApolloRarity = 9,
        PackedHeraRarity = 6,
        BridalGlowTargetBoon = "",
    }
    local rows = {
        { Bans = 1 },
    }

    local session = {}

    function session.read(alias)
        return values[alias]
    end

    function session.write(alias, value)
        values[alias] = value
    end

    function session.table(alias)
        lu.assertEquals(alias, "ApolloBanPools")
        local tableHandle = {}

        function tableHandle.count()
            return #rows
        end

        function tableHandle.append()
            rows[#rows + 1] = { Bans = 0 }
        end

        function tableHandle.remove(_, index)
            table.remove(rows, index)
        end

        function tableHandle.rowHandle(_, index)
            return {
                read = function(childAlias)
                    return rows[index] and rows[index][childAlias] or nil
                end,
                write = function(childAlias, value)
                    rows[index][childAlias] = value
                end,
            }
        end

        return tableHandle
    end

    return session, values, rows
end

function TestUiActionsLogic:setUp()
    self.data = {
        godDefs = {
            Apollo = {
                rarityVar = "PackedApolloRarity",
            },
            Apollo2 = {
                duplicateOf = "Apollo",
            },
            Hera = {
                rarityVar = "PackedHeraRarity",
            },
        },
        banPools = {
            getBanMask = function()
                return 7
            end,
        },
        banConfig = {
            GetBanPoolTableConfig = function(godKey)
                if godKey == "Apollo" then
                    return { alias = "ApolloBanPools" }
                end
                return nil
            end,
            GetMaxConfigurableBanPools = function()
                return 3
            end,
            ResolveBanBinding = function(banPoolKey, session)
                local index = banPoolKey == "Apollo2" and 2 or 1
                return session.table("ApolloBanPools"):rowHandle(index), "Bans"
            end,
        },
    }
    self.actions = dofile("src/mods/ui/ui_actions.lua").create(self.data)
    self.session, self.values, self.rows = MakeSession()
    self.host = {
        logIf = function() end,
    }
end

function TestUiActionsLogic:testSetConfiguredBanPoolCountAppendsRemovesAndClamps()
    lu.assertTrue(self.actions.SetConfiguredBanPoolCount("Apollo", 3, self.session))
    lu.assertEquals(#self.rows, 3)

    lu.assertFalse(self.actions.SetConfiguredBanPoolCount("Apollo", 3, self.session))
    lu.assertEquals(#self.rows, 3)

    lu.assertTrue(self.actions.SetConfiguredBanPoolCount("Apollo", 0, self.session))
    lu.assertEquals(#self.rows, 1)
end

function TestUiActionsLogic:testSetBanMaskMasksWritesAndReportsNoop()
    lu.assertTrue(self.actions.SetBanMask("Apollo", 15, self.session))
    lu.assertEquals(self.rows[1].Bans, 7)

    lu.assertFalse(self.actions.SetBanMask("Apollo", 7, self.session))
end

function TestUiActionsLogic:testResetAllRarityClearsUniqueRarityVars()
    lu.assertTrue(self.actions.ResetAllRarity(self.session))
    lu.assertEquals(self.values.PackedApolloRarity, 0)
    lu.assertEquals(self.values.PackedHeraRarity, 0)

    lu.assertFalse(self.actions.ResetAllRarity(self.session))
end

function TestUiActionsLogic:testBanAllAndResetAllBansUseConfiguredMasks()
    lu.assertTrue(self.actions.BanAllGodBans("Apollo", self.session, self.host))
    lu.assertEquals(self.rows[1].Bans, 7)

    self.rows[2] = { Bans = 3 }
    lu.assertTrue(self.actions.ResetAllBans(self.session, self.host))
    lu.assertEquals(self.rows[1].Bans, 0)
    lu.assertEquals(self.rows[2].Bans, 0)
end

function TestUiActionsLogic:testSetBridalGlowTargetWritesOnlyOnChange()
    lu.assertTrue(self.actions.SetBridalGlowTargetBoonKey("Strike", self.session))
    lu.assertEquals(self.values.BridalGlowTargetBoon, "Strike")

    lu.assertFalse(self.actions.SetBridalGlowTargetBoonKey("Strike", self.session))

    lu.assertTrue(self.actions.SetBridalGlowTargetBoonKey(nil, self.session))
    lu.assertEquals(self.values.BridalGlowTargetBoon, "")
end
