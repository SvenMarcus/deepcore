require("deepcore/std/class")
require("deepcore/std/Queue")
require("deepcore/crossplot/serializer")

---Sends values between game scripts through shared slots.
---Owns how values are encoded; nothing outside this class sees the wire format.
---@class Mailbox
Mailbox = class()

---@param slot_store GlobalValueKeyValueStore Raw text slots shared between scripts
function Mailbox:new(slot_store)
    ---@private
    self.slot_store = slot_store

    ---@private
    ---@type table<string, Queue>
    self.outbox = {}
end

---Queues a value for delivery. The value is captured immediately, so later changes to it are not sent.
---@param key string Destination slot
---@param value any Plain value or acyclic table of plain values
---@return boolean accepted False when the value cannot be passed between scripts
function Mailbox:send(key, value)
    local encoded = serializer:serialize(value)
    if not encoded then
        return false
    end

    if not self.outbox[key] then
        self.outbox[key] = Queue()
    end

    self.outbox[key]:add(encoded)
    return true
end

---Delivers at most one queued value per destination whose slot is free.
function Mailbox:process()
    DebugMessage("In Mailbox:process()")
    for key, queue in pairs(self.outbox) do
        if queue.size > 0 and self.slot_store:is_empty(key) then
            DebugMessage("Sending Key-Value Pair with key %s", tostring(key))
            self.slot_store:write(key, queue:remove())
        end
    end
end

---Takes the value waiting in a slot and frees the slot.
---@param key string
---@return any? value Nil when the slot is empty
function Mailbox:receive(key)
    if self.slot_store:is_empty(key) then
        return nil
    end

    local text = self.slot_store:read(key)
    self.slot_store:free(key)

    return serializer:deserialize(text)
end

return Mailbox
