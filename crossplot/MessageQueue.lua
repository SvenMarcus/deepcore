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
--*   @Filename:            GlobalValueQueue.lua
--*   @License:             MIT
--*****************************************************************************

require("deepcore/std/class")
require("deepcore/std/Queue")
require("deepcore/crossplot/serializer")

---@class MessageQueue
MessageQueue = class()

---@private
function MessageQueue:new(kv_store)
    ---@private
    ---@type table<string, Queue>
    self.global_values = {}

    ---@private
    self.kv_store = kv_store
end

---@param key string Shared mailbox key that will receive the message
---@param value any Serializable Crossplot payload to prepare and queue
---@return boolean
function MessageQueue:queue_value(key, value)
    -- Convert now so queued messages contain only safe, portable data.
    local serialized = serializer:serialize(value)
    if not serialized then
        return false
    end

    return self:queue_serialized(key, serialized)
end

---Queues a message that has already been prepared for shared storage.
---@private
---@param key string Destination key
---@param serialized string Prepared message
---@return boolean queued Whether the message was queued
function MessageQueue:queue_serialized(key, serialized)
    if not self.global_values[key] then
        self.global_values[key] = Queue()
    end

    self.global_values[key]:add(serialized)
    return true
end

function MessageQueue:process()
    DebugMessage("In MessageQueue:process()")
    for key, queue in pairs(self.global_values) do
        -- Leave later messages queued until the shared slot is free.
        if queue.size > 0 and self:can_send(key) then
            local serialized = queue:remove()
            DebugMessage("Sending Key-Value Pair with key %s", tostring(key))
            self.kv_store:store_serialized(key, serialized)
        end
    end
end

---@private
function MessageQueue:can_send(key)
    return self.kv_store:is_empty(key)
end

return MessageQueue
