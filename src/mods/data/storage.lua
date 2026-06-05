local storageSchema = {}

function storageSchema.buildStorage()
    return {
        { type = "bool",   alias = "EnablePadding",
            default = false },
        { type = "int",    alias = "Padding_PrioritizeCoreForFirstN",
            default = 1, min = 0, max = 15 },
        { type = "bool",   alias = "Padding_AvoidFutureAllowed",
            default = true },
        { type = "bool",   alias = "Padding_AllowDuos",
            default = false },
        { type = "int",    alias = "ImproveFirstNBoonRarity",
            default = 0, min = 0, max = 15 },
        { type = "string", alias = "BridalGlowTargetBoon",
            default = "", maxLen = 128 },
    }
end

return storageSchema
