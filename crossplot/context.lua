require("deepcore/crossplot/KeyValueStoreBasedEventBus")
require("deepcore/std/Queue")
require("deepcore/std/class")

---@class CrossplotContext
CrossplotContext = class()

---@param ready_condition fun(): boolean
---@param event_bus KeyValueStoreBasedEventBus
function CrossplotContext:new(ready_condition, event_bus)
	self._ready_condition = ready_condition
	self._is_ready = false

	self._event_bus = event_bus

	---@type Queue
	self._queue = Queue()
end

---@param event_name string
---@param listener_function fun(...): any
---@param optional_self? table
function CrossplotContext:subscribe(event_name, listener_function, optional_self)
	self._event_bus:subscribe(event_name, listener_function, optional_self)
end

---@param event_name string
---@param ... any
function CrossplotContext:publish(event_name, ...)
	self._queue:add({ event_name = event_name, args = arg })
end

---@private
---Check if the context is ready
---@return boolean
function CrossplotContext:is_ready()
	if self._is_ready then
		return true
	end
	self._is_ready = self._ready_condition()
	return self._is_ready
end

function CrossplotContext:update()
	if not self:is_ready() then
		return
	end
	for _, event in self._queue:iter() do
		self._event_bus:publish(event.event_name, unpack(event.args))
	end
end

NULL_CONTEXT = {}
function NULL_CONTEXT:subscribe(event_name, listener_function, optional_self) end
function NULL_CONTEXT:publish(event_name, ...) end
function NULL_CONTEXT:update() end
