local busted = require("busted")
local describe = busted.describe
local it = busted.it
local before_each = busted.before_each
local after_each = busted.after_each

describe("CrossplotContext", function()
	local eaw_env
	local require_utilities

	before_each(function()
		eaw_env = require("spec.eaw_env")
		eaw_env.setup_environment()

		require_utilities = require("spec.require_utilities")
		require_utilities.replace_require()

		require("deepcore/crossplot/crossplot")
		crossplot:galactic()
	end)

	after_each(function()
		eaw_env.teardown_environment()
		require_utilities.reset_require()

		crossplot = nil
	end)

	---@param main_bus MainKeyValueStoreBasedEventBus
	---@param ... KeyValueStoreBasedEventBus
	local function update_buses(main_bus, ...)
		for _, bus in ipairs({ ... }) do
			bus:update()
		end
		main_bus:update()
		for _, bus in ipairs({ ... }) do
			bus:update()
		end
		main_bus:update()
	end

	it("a context with ready condition publishes an event", function()
		local main_bus = MainKeyValueStoreBasedEventBus(GlobalValueKeyValueStore())
		local receiving_message_bus = KeyValueStoreBasedEventBus("receiver", GlobalValueKeyValueStore())
		local context = crossplot:acquire_context(function()
			return true
		end)

		local message_received = false
		receiving_message_bus:subscribe("test_event", function()
			message_received = true
		end)
		update_buses(main_bus, receiving_message_bus)

		context:publish("test_event")
		update_buses(main_bus, crossplot, receiving_message_bus)

		assert.is_true(message_received)
	end)

	it("a context with not ready condition does not publish events", function()
		local main_bus = MainKeyValueStoreBasedEventBus(GlobalValueKeyValueStore())
		local receiving_message_bus = KeyValueStoreBasedEventBus("receiver", GlobalValueKeyValueStore())
		local context = crossplot:acquire_context(function()
			return false
		end)

		local message_received = false
		receiving_message_bus:subscribe("test_event", function()
			message_received = true
		end)
		update_buses(main_bus, receiving_message_bus)

		context:publish("test_event")
		update_buses(main_bus, crossplot, receiving_message_bus)

		assert.is_false(message_received)
	end)

	it("can subscribe to events from a context", function()
		local main_bus = MainKeyValueStoreBasedEventBus(GlobalValueKeyValueStore())
		local sending_bus = KeyValueStoreBasedEventBus("sender", GlobalValueKeyValueStore())
		local context = crossplot:acquire_context(function()
			return true
		end)

		local message_received = false
		context:subscribe("test_event", function()
			message_received = true
		end)

		update_buses(main_bus, sending_bus)

		context:publish("test_event")
		update_buses(main_bus, crossplot, sending_bus)

		assert.is_true(message_received)
	end)
end)
