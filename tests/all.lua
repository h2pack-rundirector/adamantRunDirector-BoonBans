package.path = "./?.lua;./?/init.lua;" .. package.path

require("tests/TestUtils")
require("tests/TestAcquisitionLogic")
require("tests/TestBanResolverLogic")
require("tests/TestDataLogic")
require("tests/TestEntrypoint")
require("tests/TestLootLogic")
require("tests/TestNpcLogic")
require("tests/TestRunStateLogic")
require("tests/TestUiActionsLogic")
require("tests/TestUiLogic")

local lu = require("luaunit")
os.exit(lu.LuaUnit.run())
