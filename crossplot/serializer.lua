--*****************************************************************************
--*    _______ __
--*   |_     _|  |--.----.---.-.--.--.--.-----.-----.
--*     |   | |     |   _|  _  |  |  |  |     |__ --|
--*     |___| |__|__|__| |___._|________|__|__|_____|
--*    ______
--*   |   __ \.-----.--.--.-----.-----.-----.-----.
--*   |      <|  -__|  |  |  -__|     |  _  |  -__|
--*   |___|__||_____|\___/|_____|__|__|___  |_____|
--*                                   |_____|
--*
--*   @Author:              [EaWX]Pox
--*   @Date:                2020-12-23
--*   @Project:             Empire at War Expanded
--*   @Filename:            serializer.lua
--*   @License:             MIT
--*****************************************************************************

serializer = {}

function serializer:deserialize(str)
    return loadstring(str)()
end

---Serializes a Crossplot payload for shared storage.
---@param value any Serializable primitive or acyclic plain table to encode
---@return string? serialized Lua source, or nil when the value is unsupported
function serializer:serialize(value)
    -- Only plain values and tables can safely pass between game scripts.
    local serialized = self:_serializeValue(value, {})
    if serialized then
        return "return " .. serialized
    end
end

function serializer:_serializeKey(value)
    local value_type = type(value)
    if value_type == "string" then
        return "[" .. string.format("%q", value) .. "]="
    elseif value_type == "boolean" then
        return "[" .. tostring(value) .. "]="
    elseif value_type == "number" then
        local serialized = tostring(value)
        if tonumber(serialized) == value then
            return "[" .. serialized .. "]="
        end
    end
end

---@private
---@param value any Primitive or table value currently being encoded
---@param ancestors table<table, boolean> Tables on the current traversal path, used to detect cycles
---@return string? serialized Encoded value, or nil when the value is unsupported
function serializer:_serializeValue(value, ancestors)
    local value_type = type(value)
    if value_type == "nil" or value_type == "boolean" then
        return tostring(value)
    elseif value_type == "string" then
        return string.format("%q", value)
    elseif value_type == "number" then
        local serialized = tostring(value)
        if tonumber(serialized) == value then
            return serialized
        end
        return nil
    elseif value_type ~= "table" or ancestors[value] then
        return nil
    end

    ancestors[value] = true
    local entries = {}
    for key, entry in pairs(value) do
        local serialized_key = self:_serializeKey(key)
        local serialized_entry = self:_serializeValue(entry, ancestors)
        if not serialized_key or not serialized_entry then
            ancestors[value] = nil
            return nil
        end
        table.insert(entries, serialized_key .. serialized_entry)
    end
    ancestors[value] = nil

    return "{" .. table.concat(entries, ",") .. "}"
end
