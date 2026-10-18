require("deepcore/std/class")
require("deepcore/crossplot/serializer")

---@class GlobalValueKeyValueStore
GlobalValueKeyValueStore = class()

---@param key string
---@param value any
---@return boolean
function GlobalValueKeyValueStore:store(key, value)
    local serialized = serializer:serialize(value)
    if not serialized then
        return false
    end

    return self:store_serialized(key, serialized)
end

---Stores a value that has already been prepared for shared storage.
---@private
---@param key string Storage key
---@param serialized string Prepared value
---@return boolean stored Whether the value was stored
function GlobalValueKeyValueStore:store_serialized(key, serialized)
    GlobalValue.Set(key, serialized)
    return true
end

---@param key string
function GlobalValueKeyValueStore:get(key)
    local value = GlobalValue.Get(key)
    if not value then
        return nil
    end

    return serializer:deserialize(value)
end

---Reads and clears a value from shared storage.
---@param key string Storage key
---@return any? value Stored value, or nil when empty
function GlobalValueKeyValueStore:take(key)
    local serialized = GlobalValue.Get(key)
    if serialized == nil or serialized == "" then
        return nil
    end

    -- Clear the shared slot before anyone starts handling its message.
    self:free(key)
    return serializer:deserialize(serialized)
end

---Checks whether shared storage has a value waiting at a key.
---@param key string Storage key
---@return boolean empty Whether the key is empty
function GlobalValueKeyValueStore:is_empty(key)
    local value = GlobalValue.Get(key)
    return value == nil or value == ""
end

---@param key string
function GlobalValueKeyValueStore:free(key)
    GlobalValue.Set(key, "")
end

return GlobalValueKeyValueStore
