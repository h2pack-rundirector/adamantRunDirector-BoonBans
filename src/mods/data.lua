local internal = RunDirectorBoonBans_Internal
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

internal.godDefs = godDefs
internal.banPools = banPools
internal.banConfig = banConfig
internal.catalog = catalog
internal.storage = storageSchema.buildStorage(godDefs, baseBoonCatalog, banPools)
