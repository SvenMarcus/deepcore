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
--*   @Filename:            GlobalValueEventBus.lua
--*   @License:             MIT
--*****************************************************************************

require("deepcore/std/class")
require("deepcore/std/Observable")
require("deepcore/crossplot/MessageQueue")

---@class KeyValueStoreBasedEventBus
KeyValueStoreBasedEventBus = class()

---@param name string Unique endpoint name used to address this bus's notification mailbox
---@param kv_store GlobalValueKeyValueStore Shared key-value store used to exchange Crossplot messages
---@param initial_route_source? string Startup listener group represented by this endpoint; omit to register routes immediately
function KeyValueStoreBasedEventBus:new(name, kv_store, initial_route_source)
	self.name = (name or tostring(Script))
	self.initial_route_source = initial_route_source
	self.initial_routes_submitted = initial_route_source == nil

	self.kv_store = kv_store

	---@type MessageQueue
	self.message_queue = MessageQueue(kv_store)
	self.subscribers = {}
end

---@param event_name string
---@param listener_function fun(...): any
---@param optional_self? table
function KeyValueStoreBasedEventBus:subscribe(event_name, listener_function, optional_self)
	if not self.subscribers[event_name] then
		self.subscribers[event_name] = Observable()
	end

	local subscribers = self.subscribers[event_name]
	local had_listeners = subscribers:has_listeners()
	subscribers:attach_listener(listener_function, optional_self)

	-- One signup is enough, even when several local callbacks use the event.
	if self.initial_routes_submitted and not had_listeners and subscribers:has_listeners() then
		self.message_queue:queue_value("busid:main:route", {
			name = self.name,
			event = event_name,
			active = true,
		})
	end
	DebugMessage("Registered listener for %s", event_name)
end

---Sends the complete startup listener list after setup finishes.
---@param required_initial_route_sources? string[] Listener groups that must finish before startup messages are delivered
---@return boolean queued Whether the listener list was queued
function KeyValueStoreBasedEventBus:submit_initial_routes(required_initial_route_sources)
	if self.initial_routes_submitted then
		return false
	end

	-- Send the complete startup listener list in one message.
	local events = {}
	for event_name, subscribers in pairs(self.subscribers) do
		if subscribers:has_listeners() then
			table.insert(events, event_name)
		end
	end
	table.sort(events)

	self.initial_routes_submitted = true
	local queued = self.message_queue:queue_value("busid:main:route", {
		name = self.name,
		events = events,
		initial_route_source = self.initial_route_source,
		required_initial_route_sources = required_initial_route_sources,
	})
	if queued then
		DebugMessage("Crossplot initial routes queued: source=%s endpoint=%s routes=%s",
			tostring(self.initial_route_source), tostring(self.name), tostring(table.getn(events)))
	end
	return queued
end

---@param event_name string
---@param listener_function function
---@param optional_self table
function KeyValueStoreBasedEventBus:unsubscribe(event_name, listener_function, optional_self)
	local subscribers = self.subscribers[event_name]

	if not subscribers then
		return
	end

	local had_listeners = subscribers:has_listeners()
	subscribers:detach_listener(listener_function, optional_self)

	if self.initial_routes_submitted and had_listeners and not subscribers:has_listeners() then
		-- Route states share one first-in first-out queue so their order is preserved.
		self.message_queue:queue_value("busid:main:route", {
			name = self.name,
			event = event_name,
			active = false,
		})
		DebugMessage("Sent unsubscribe message for %s to master", event_name)
	end
end

---@param event_name string
---@param ... any
function KeyValueStoreBasedEventBus:publish(event_name, ...)
	self.message_queue:queue_value("busid:main:publish", {
		event_name = event_name,
		args = arg,
	})
end

---@private
function KeyValueStoreBasedEventBus:process_notifications()
	local mailbox = "busid:" .. self.name .. ":notify"
	-- Remove the message before callbacks run so one failure cannot block later work.
	local notification = self.kv_store:take(mailbox)

	if type(notification) ~= "table"
		or type(notification.event_name) ~= "string"
		or type(notification.args) ~= "table" then
		return
	end

	local subscribers = self.subscribers[notification.event_name]
	if not subscribers then
		return
	end

	subscribers:notify(unpack(notification.args))
end

function KeyValueStoreBasedEventBus:update()
	self:process_notifications()
	self.message_queue:process()
end

---@class MainKeyValueStoreBasedEventBus
MainKeyValueStoreBasedEventBus = class()

---@param kv_store GlobalValueKeyValueStore Shared key-value store used to exchange Crossplot messages
---@param wait_for_routes? boolean Whether to hold publications until every required startup listener group has reported its routes
function MainKeyValueStoreBasedEventBus:new(kv_store, wait_for_routes)
	self.name = "busid:main"

	---@type table<string, table<string, boolean>>
	self.subscribers = {}

	---@type table<string, table>
	self.local_subscribers = {}

	self.kv_store = kv_store
	self.message_queue = MessageQueue(kv_store)
	self.installed_initial_route_sources = {}
	self.required_initial_route_sources = { ["galactic-core"] = true }
	self.routes_ready = not wait_for_routes
	if wait_for_routes and self.kv_store then
		self.kv_store:free("busid:main:ready")
	end
end

---Installs one script's complete startup listener list.
---@private
---@param initial_routes table Startup listener information
function MainKeyValueStoreBasedEventBus:process_initial_routes(initial_routes)
	if type(initial_routes) ~= "table"
		or type(initial_routes.name) ~= "string"
		or type(initial_routes.events) ~= "table"
		or type(initial_routes.initial_route_source) ~= "string" then
		return
	end

	for _, event_name in ipairs(initial_routes.events) do
		if type(event_name) ~= "string" then
			return
		end
	end
	if initial_routes.required_initial_route_sources ~= nil then
		if type(initial_routes.required_initial_route_sources) ~= "table" then
			return
		end
		for _, source in ipairs(initial_routes.required_initial_route_sources) do
			if type(source) ~= "string" then
				return
			end
		end
	end

	-- Replace this script's old listener list with its complete startup list.
	for _, subscribers in pairs(self.subscribers) do
		subscribers[initial_routes.name] = nil
	end
	for _, event_name in ipairs(initial_routes.events) do
		local subscribers = self.subscribers[event_name]
		if not subscribers then
			subscribers = {}
			self.subscribers[event_name] = subscribers
		end
		subscribers[initial_routes.name] = true
	end
	DebugMessage("Crossplot initial routes installed: source=%s endpoint=%s routes=%s",
		tostring(initial_routes.initial_route_source), tostring(initial_routes.name), tostring(table.getn(initial_routes.events)))

	self.installed_initial_route_sources[initial_routes.initial_route_source] = true
	if initial_routes.required_initial_route_sources then
		self.required_initial_route_sources = {}
		for _, source in ipairs(initial_routes.required_initial_route_sources) do
			self.required_initial_route_sources[source] = true
		end
	end

	local missing_sources = {}
	local required_sources = {}
	for source in pairs(self.required_initial_route_sources) do
		table.insert(required_sources, source)
		if not self.installed_initial_route_sources[source] then
			table.insert(missing_sources, source)
		end
	end
	if table.getn(missing_sources) > 0 then
		table.sort(missing_sources)
		DebugMessage("Crossplot routes waiting: missing sources=%s", table.concat(missing_sources, ","))
		return
	end

	table.sort(required_sources)
	self.routes_ready = true
	self.log_next_publish_after_routes = true
	-- Record that startup listeners are ready.
	self.kv_store:store("busid:main:ready", true)
	DebugMessage("Crossplot routes ready: sources=%s", table.concat(required_sources, ","))
end

---@private
function MainKeyValueStoreBasedEventBus:process_route_changes()
	local route = self.kv_store:take("busid:main:route")

	if type(route) ~= "table" then
		return
	end
	if route.events ~= nil then
		self:process_initial_routes(route)
		return
	end
	if type(route.name) ~= "string"
		or type(route.event) ~= "string"
		or type(route.active) ~= "boolean" then
		return
	end

	local subscribers = self.subscribers[route.event]
	if route.active then
		if not subscribers then
			subscribers = {}
			self.subscribers[route.event] = subscribers
		end
		subscribers[route.name] = true
	elseif subscribers then
		subscribers[route.name] = nil
	end
end

---@private
function MainKeyValueStoreBasedEventBus:process_publish_messages()
	if not self.routes_ready then
		-- Hold early messages until every startup listener is known.
		return
	end

	local publish_data = self.kv_store:take("busid:main:publish")

	if type(publish_data) ~= "table"
		or type(publish_data.event_name) ~= "string"
		or type(publish_data.args) ~= "table" then
		return
	end

	if self.log_next_publish_after_routes then
		self.log_next_publish_after_routes = false
		DebugMessage("Crossplot first publication after routes ready: event=%s", publish_data.event_name)
	end
	self:publish(publish_data.event_name, unpack(publish_data.args))
end

---@param event_name string
---@param listener_function function
---@param optional_self table
function MainKeyValueStoreBasedEventBus:subscribe(event_name, listener_function, optional_self)
	if not self.local_subscribers[event_name] then
		self.local_subscribers[event_name] = Observable()
	end

	self.local_subscribers[event_name]:attach_listener(listener_function, optional_self)

	DebugMessage("Registered local listener on master for %s", event_name)
end

---@param event_name string
---@param listener_function function
---@param optional_self table
function MainKeyValueStoreBasedEventBus:unsubscribe(event_name, listener_function, optional_self)
	self.local_subscribers[event_name]:detach_listener(listener_function, optional_self)
end

---@param event_name string
function MainKeyValueStoreBasedEventBus:publish(event_name, ...)
	self:publish_to_local_subscribers(event_name, arg)
	local subscribers = self.subscribers[event_name]

	if not subscribers then
		return
	end

	local notification = serializer:serialize({
		event_name = event_name,
		args = arg,
	})
	if not notification then
		return
	end

	for subscriber_name in pairs(subscribers) do
		self.message_queue:queue_serialized("busid:" .. subscriber_name .. ":notify", notification)
	end
end

---@private
function MainKeyValueStoreBasedEventBus:publish_to_local_subscribers(event_name, arg_table)
	local subscribers = self.local_subscribers[event_name]

	if not subscribers then
		return
	end

	DebugMessage("Publishing %s to local subscribers", tostring(event_name))
	subscribers:notify(unpack(arg_table))
end

function MainKeyValueStoreBasedEventBus:update()
	self:process_route_changes()
	self:process_publish_messages()
	self.message_queue:process()
end
