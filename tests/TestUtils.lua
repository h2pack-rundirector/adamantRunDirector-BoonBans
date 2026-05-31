-- luacheck: globals bit32 store import

public = {}
_PLUGIN = { guid = "test-boon-bans" }

local MAX_UINT32 = 4294967295

local function deepCopy(orig)
    if type(orig) ~= "table" then
        return orig
    end
    local copy = {}
    for key, value in pairs(orig) do
        copy[key] = deepCopy(value)
    end
    return copy
end

local function makeBitBinaryOp(predicate)
    return function(a, b)
        local result = 0
        local bitValue = 1
        a = a or 0
        b = b or 0

        while a > 0 or b > 0 do
            local abit = a % 2
            local bbit = b % 2
            if predicate(abit, bbit) then
                result = result + bitValue
            end
            a = math.floor(a / 2)
            b = math.floor(b / 2)
            bitValue = bitValue * 2
        end

        return result
    end
end

bit32 = {
    band = makeBitBinaryOp(function(a, b)
        return a == 1 and b == 1
    end),
    bor = makeBitBinaryOp(function(a, b)
        return a == 1 or b == 1
    end),
    bnot = function(a)
        return MAX_UINT32 - (a or 0)
    end,
    lshift = function(a, n)
        return ((a or 0) * (2 ^ (n or 0))) % (2 ^ 32)
    end,
    rshift = function(a, n)
        return math.floor((a or 0) / (2 ^ (n or 0)))
    end,
}

rom = {
    mods = {},
    game = {
        DeepCopyTable = deepCopy,
    },
    ImGuiCol = {
        Button = 1,
        ButtonHovered = 2,
        ButtonActive = 3,
        Text = 4,
        Header = 5,
        HeaderHovered = 6,
        HeaderActive = 7,
    },
    gui = {
        add_to_menu_bar = function() end,
        add_imgui = function() end,
    },
}

lib = {
    isEnabled = function()
        return false
    end,
    store = {
        write = function(targetStore, key, value)
            if targetStore and type(targetStore.write) == "function" then
                targetStore.write(key, value)
            end
        end,
    },
}

local storeValues = {}
store = {}

function store.get(key)
    return {
        read = function()
            return storeValues[key]
        end,
        write = function(_, value)
            storeValues[key] = value
        end,
    }
end

