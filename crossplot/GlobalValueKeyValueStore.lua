require("deepcore/std/class")

---Raw text slots backed by GlobalValue. Knows nothing about what the text contains.
---@class GlobalValueKeyValueStore
GlobalValueKeyValueStore = class()

---@param key string
---@return string?
function GlobalValueKeyValueStore:read(key)
    return GlobalValue.Get(key)
end

---@param key string
---@param text string
function GlobalValueKeyValueStore:write(key, text)
    GlobalValue.Set(key, text)
end

---@param key string
---@return boolean
function GlobalValueKeyValueStore:is_empty(key)
    local text = GlobalValue.Get(key)
    return text == nil or text == ""
end

---@param key string
function GlobalValueKeyValueStore:free(key)
    GlobalValue.Set(key, "")
end

return GlobalValueKeyValueStore
