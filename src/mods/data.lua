_G.bit32 = _G.bit32 or require("bit32")

local definitions = import("mods/data/definitions.lua")
local catalogModule = import("mods/data/catalog/catalog.lua")
local banPoolsModule = import("mods/data/ban_pools.lua")
local banConfigModule = import("mods/data/ban_config.lua")
local storageSchema = import("mods/data/storage_schema.lua")

local godDefs = definitions.build()
local baseBoonCatalog = catalogModule.buildBase(godDefs)
local banPools = banPoolsModule.create(godDefs, baseBoonCatalog)
local banConfig = banConfigModule.create(godDefs, banPools)
local catalog = catalogModule.build(godDefs, baseBoonCatalog)

return {
    godDefs = godDefs,
    baseBoonCatalog = baseBoonCatalog,
    banPools = banPools,
    banConfig = banConfig,
    catalog = catalog,
    storage = storageSchema.buildStorage(godDefs, baseBoonCatalog, banPools),
}
