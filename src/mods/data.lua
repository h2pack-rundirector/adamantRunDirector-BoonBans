_G.bit32 = _G.bit32 or require("bit32")

local definitions = import("mods/data/definitions.lua")
local features = import("mods/features.lua")
local catalogModule = import("mods/data/catalog/catalog.lua")
local storageSchema = import("mods/data/storage.lua")
local controlDeclarations = import("mods/data/controls.lua")
local controlTemplates = import("mods/controls/templates.lua")
local sourceResolverModule = import("mods/data/source_resolver.lua")

local godDefs = definitions.build()
local baseBoonCatalog = catalogModule.buildBase(godDefs)
local catalog = catalogModule.build(godDefs, baseBoonCatalog)
local sourceResolver = sourceResolverModule.create(godDefs, catalog)

return {
    features = features,
    sourceResolver = sourceResolver,
    storage = storageSchema.buildStorage(features),
    controlTemplates = controlTemplates,
    controls = controlDeclarations.build(godDefs, catalog),
}
