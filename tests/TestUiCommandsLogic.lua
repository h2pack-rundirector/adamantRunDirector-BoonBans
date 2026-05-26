-- luacheck: globals TestUiCommandsLogic bit32

local lu = require("luaunit")

TestUiCommandsLogic = {}

local function MakeData()
    local values = {
        PackedApolloRarity = 9,
        PackedHeraRarity = 6,
        BridalGlowTargetBoon = "",
    }
    local rows = {
        { Bans = 1 },
    }

    local state = {}

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

    function state.get(alias)
        if alias == "ApolloBanPools" then
            return tableHandle
        end
        return MakeField(alias)
    end

    return state, values, rows
end

function TestUiCommandsLogic:setUp()
    self.state = {
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
            ResolveBanFields = function(banPoolKey, state)
                local index = banPoolKey == "Apollo2" and 2 or 1
                return {
                    bans = state.get("ApolloBanPools"):get(index, "Bans"),
                }
            end,
        },
    }
    self.commands = dofile("src/mods/ui/ui_commands.lua").create(self.state)
    self.dataRefs, self.values, self.rows = MakeData()
    self.host = {
        logIf = function() end,
    }
end

function TestUiCommandsLogic:testSetConfiguredBanPoolCountAppendsRemovesAndClamps()
    lu.assertTrue(self.commands.SetConfiguredBanPoolCount("Apollo", 3, self.dataRefs))
    lu.assertEquals(#self.rows, 3)

    lu.assertFalse(self.commands.SetConfiguredBanPoolCount("Apollo", 3, self.dataRefs))
    lu.assertEquals(#self.rows, 3)

    lu.assertTrue(self.commands.SetConfiguredBanPoolCount("Apollo", 0, self.dataRefs))
    lu.assertEquals(#self.rows, 1)
end

function TestUiCommandsLogic:testSetBanMaskMasksWritesAndReportsNoop()
    lu.assertTrue(self.commands.SetBanMask("Apollo", 15, self.dataRefs))
    lu.assertEquals(self.rows[1].Bans, 7)

    lu.assertFalse(self.commands.SetBanMask("Apollo", 7, self.dataRefs))
end

function TestUiCommandsLogic:testResetAllRarityClearsUniqueRarityVars()
    lu.assertTrue(self.commands.ResetAllRarity(self.dataRefs))
    lu.assertEquals(self.values.PackedApolloRarity, 0)
    lu.assertEquals(self.values.PackedHeraRarity, 0)

    lu.assertFalse(self.commands.ResetAllRarity(self.dataRefs))
end

function TestUiCommandsLogic:testBanAllAndResetAllBansUseConfiguredMasks()
    lu.assertTrue(self.commands.BanAllGodBans("Apollo", self.dataRefs, self.host))
    lu.assertEquals(self.rows[1].Bans, 7)

    self.rows[2] = { Bans = 3 }
    lu.assertTrue(self.commands.ResetAllBans(self.dataRefs, self.host))
    lu.assertEquals(self.rows[1].Bans, 0)
    lu.assertEquals(self.rows[2].Bans, 0)
end

function TestUiCommandsLogic:testSetBridalGlowTargetWritesOnlyOnChange()
    lu.assertTrue(self.commands.SetBridalGlowTargetBoonKey("Strike", self.dataRefs))
    lu.assertEquals(self.values.BridalGlowTargetBoon, "Strike")

    lu.assertFalse(self.commands.SetBridalGlowTargetBoonKey("Strike", self.dataRefs))

    lu.assertTrue(self.commands.SetBridalGlowTargetBoonKey(nil, self.dataRefs))
    lu.assertEquals(self.values.BridalGlowTargetBoon, "")
end
