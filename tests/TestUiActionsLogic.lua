-- luacheck: globals TestUiActionsLogic bit32

local lu = require("luaunit")

TestUiActionsLogic = {}

local function MakeData()
    local values = {
        PackedApolloRarity = 9,
        PackedHeraRarity = 6,
        BridalGlowTargetBoon = "",
    }
    local rows = {
        { Bans = 1 },
    }

    local data = {}

    local function MakeField(alias)
        return {
            read = function()
                return values[alias]
            end,
            write = function(_, value)
                values[alias] = value
            end,
        }
    end

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

    function tableHandle.get(_, index, childAlias)
        return {
            read = function()
                return rows[index] and rows[index][childAlias] or nil
            end,
            write = function(_, value)
                rows[index][childAlias] = value
            end,
        }
    end

    function data.get(alias)
        if alias == "ApolloBanPools" then
            return tableHandle
        end
        return MakeField(alias)
    end

    return data, values, rows
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
            ResolveBanFields = function(banPoolKey, data)
                local index = banPoolKey == "Apollo2" and 2 or 1
                return {
                    bans = data.get("ApolloBanPools"):get(index, "Bans"),
                }
            end,
        },
    }
    self.actions = dofile("src/mods/ui/ui_actions.lua").create(self.data)
    self.dataRefs, self.values, self.rows = MakeData()
    self.services = {
        logIf = function() end,
    }
end

function TestUiActionsLogic:testSetConfiguredBanPoolCountAppendsRemovesAndClamps()
    lu.assertTrue(self.actions.SetConfiguredBanPoolCount("Apollo", 3, self.dataRefs))
    lu.assertEquals(#self.rows, 3)

    lu.assertFalse(self.actions.SetConfiguredBanPoolCount("Apollo", 3, self.dataRefs))
    lu.assertEquals(#self.rows, 3)

    lu.assertTrue(self.actions.SetConfiguredBanPoolCount("Apollo", 0, self.dataRefs))
    lu.assertEquals(#self.rows, 1)
end

function TestUiActionsLogic:testSetBanMaskMasksWritesAndReportsNoop()
    lu.assertTrue(self.actions.SetBanMask("Apollo", 15, self.dataRefs))
    lu.assertEquals(self.rows[1].Bans, 7)

    lu.assertFalse(self.actions.SetBanMask("Apollo", 7, self.dataRefs))
end

function TestUiActionsLogic:testResetAllRarityClearsUniqueRarityVars()
    lu.assertTrue(self.actions.ResetAllRarity(self.dataRefs))
    lu.assertEquals(self.values.PackedApolloRarity, 0)
    lu.assertEquals(self.values.PackedHeraRarity, 0)

    lu.assertFalse(self.actions.ResetAllRarity(self.dataRefs))
end

function TestUiActionsLogic:testBanAllAndResetAllBansUseConfiguredMasks()
    lu.assertTrue(self.actions.BanAllGodBans("Apollo", self.dataRefs, self.services))
    lu.assertEquals(self.rows[1].Bans, 7)

    self.rows[2] = { Bans = 3 }
    lu.assertTrue(self.actions.ResetAllBans(self.dataRefs, self.services))
    lu.assertEquals(self.rows[1].Bans, 0)
    lu.assertEquals(self.rows[2].Bans, 0)
end

function TestUiActionsLogic:testSetBridalGlowTargetWritesOnlyOnChange()
    lu.assertTrue(self.actions.SetBridalGlowTargetBoonKey("Strike", self.dataRefs))
    lu.assertEquals(self.values.BridalGlowTargetBoon, "Strike")

    lu.assertFalse(self.actions.SetBridalGlowTargetBoonKey("Strike", self.dataRefs))

    lu.assertTrue(self.actions.SetBridalGlowTargetBoonKey(nil, self.dataRefs))
    lu.assertEquals(self.values.BridalGlowTargetBoon, "")
end
