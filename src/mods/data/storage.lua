local storageSchema = {}

local function appendPaddingStorage(storage)
    storage[#storage + 1] = {
        type = "bool",
        alias = "EnablePadding",
        default = false,
    }
    storage[#storage + 1] = {
        type = "int",
        alias = "Padding_PrioritizeCoreForFirstN",
        default = 1,
        min = 0,
        max = 15,
    }
    storage[#storage + 1] = {
        type = "bool",
        alias = "Padding_AvoidFutureAllowed",
        default = true,
    }
    storage[#storage + 1] = {
        type = "bool",
        alias = "Padding_AllowDuos",
        default = false,
    }
end

function storageSchema.buildStorage(features)
    local storage = {
        { type = "int",    alias = "ImproveFirstNBoonRarity",
            default = 0, min = 0, max = 15 },
        { type = "string", alias = "BridalGlowTargetBoon",
            default = "", maxLen = 128 },
    }

    if features and features.privatePadding == true then
        appendPaddingStorage(storage)
    end

    return storage
end

return storageSchema
