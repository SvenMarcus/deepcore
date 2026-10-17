describe("crossplot MainKeyValueStoreBasedEventBus", function()
    local eaw_env = require("spec.eaw_env")
    local require_utilities = require("spec.require_utilities")

    before_each(function()
        eaw_env.setup_environment()
        require_utilities.replace_require()
        require("deepcore/crossplot/KeyValueStoreBasedEventBus")
        require("deepcore/crossplot/GlobalValueKeyValueStore")
    end)

    after_each(function()
        eaw_env.teardown_environment()
        require_utilities.reset_require()
    end)

    local main
    local eventbus
    local subscriber_func

    describe("Given subscribed function", function()
        before_each(function()
            main = MainKeyValueStoreBasedEventBus(GlobalValueKeyValueStore())
            eventbus = KeyValueStoreBasedEventBus("eventbus", GlobalValueKeyValueStore())

            subscriber_func = spy.new(function() end)
            eventbus:subscribe("MY_EVENT", subscriber_func)

            eventbus:update()
            main:update()
        end)

        describe("when publishing", function()
            it("should call callback function", function()
                main:publish("MY_EVENT", "args")

                main:update()
                eventbus:update()

                assert.spy(subscriber_func).was.called_with("args")
            end)
        end)

        describe("when unsubscribing", function()
            describe("then publishing", function()
                it("should not call callback function", function()
                    eventbus:unsubscribe("MY_EVENT", subscriber_func)

                    eventbus:update()
                    main:update()

                    main:publish("MY_EVENT", "args")

                    main:update()
                    eventbus:update()

                    assert.spy(subscriber_func).was.not_called()
                end)
            end)
        end)

        describe("when replacing the listener before updating", function()
            it("should preserve the route change order", function()
                local replacement = spy.new(function() end)
                eventbus:unsubscribe("MY_EVENT", subscriber_func)
                eventbus:subscribe("MY_EVENT", replacement)

                eventbus:update()
                main:update()
                eventbus:update()
                main:update()

                main:publish("MY_EVENT", "args")
                main:update()
                eventbus:update()

                assert.spy(subscriber_func).was.not_called()
                assert.spy(replacement).was.called_with("args")
            end)
        end)
    end)

    describe("Given subscribed function with context", function()
        local context

        before_each(function()
            main = MainKeyValueStoreBasedEventBus(GlobalValueKeyValueStore())
            eventbus = KeyValueStoreBasedEventBus("eventbus", GlobalValueKeyValueStore())

            context = {}
            subscriber_func = spy.new(function() end)
            eventbus:subscribe("MY_EVENT", subscriber_func, context)

            eventbus:update()
            main:update()
        end)

        describe("when publishing", function()
            it("should call callback function with context", function()
                main:publish("MY_EVENT", "args")

                main:update()
                eventbus:update()

                assert.spy(subscriber_func).was.called_with(context, "args")
            end)
        end)

        describe("when unsubscribing", function()
            describe("then publishing", function()
                it("should not call callback function", function()
                    eventbus:unsubscribe("MY_EVENT", subscriber_func, context)

                    eventbus:update()
                    main:update()

                    main:publish("MY_EVENT", "args")

                    main:update()
                    eventbus:update()

                    assert.spy(subscriber_func).was.not_called()
                end)
            end)
        end)
    end)

    describe("Given two functions subscribed from one event bus", function()
        local second_subscriber_func

        before_each(function()
            main = MainKeyValueStoreBasedEventBus(GlobalValueKeyValueStore())
            eventbus = KeyValueStoreBasedEventBus("eventbus", GlobalValueKeyValueStore())

            subscriber_func = spy.new(function() end)
            second_subscriber_func = spy.new(function() end)
            eventbus:subscribe("MY_EVENT", subscriber_func)
            eventbus:subscribe("MY_EVENT", second_subscriber_func)

            for _ = 1, 2 do
                eventbus:update()
                main:update()
            end
        end)

        it("should call each function once per publication", function()
            main:publish("MY_EVENT", "args")

            for _ = 1, 2 do
                main:update()
                eventbus:update()
            end

            assert.spy(subscriber_func).was.called(1)
            assert.spy(second_subscriber_func).was.called(1)
        end)
    end)

    describe("Given duplicate remote route activations", function()
        before_each(function()
            main = MainKeyValueStoreBasedEventBus(GlobalValueKeyValueStore())

            for _ = 1, 2 do
                main.kv_store:store("busid:main:route", {
                    name = "eventbus",
                    event = "MY_EVENT",
                    active = true
                })
                main:update()
            end
        end)

        it("should keep one route and notification per endpoint", function()
            assert.is_true(main.subscribers.MY_EVENT.eventbus)
            assert.is_nil(main.kv_store:get("busid:main:route"))

            main:publish("MY_EVENT", "args")
            main:update()

            assert.are.same({
                event_name = "MY_EVENT",
                args = {"args", n = 1}
            }, main.kv_store:get("busid:eventbus:notify"))

            main.kv_store:free("busid:eventbus:notify")
            main:update()
            assert.is_nil(main.kv_store:get("busid:eventbus:notify"))

            main.kv_store:store("busid:main:route", {
                name = "eventbus",
                event = "MY_EVENT",
                active = false
            })
            main:update()
            assert.are.same({}, main.subscribers.MY_EVENT)
        end)

        it("should retain other endpoints when one route is removed", function()
            main.kv_store:store("busid:main:route", {
                name = "other_eventbus",
                event = "MY_EVENT",
                active = true
            })
            main:update()

            main.kv_store:store("busid:main:route", {
                name = "eventbus",
                event = "MY_EVENT",
                active = false
            })
            main:update()

            main:publish("MY_EVENT", "args")
            main:update()

            assert.is_nil(main.kv_store:get("busid:eventbus:notify"))
            assert.are.same({
                event_name = "MY_EVENT",
                args = {"args", n = 1}
            }, main.kv_store:get("busid:other_eventbus:notify"))
        end)
    end)

    describe("Given initial routes", function()
        before_each(function()
            main = MainKeyValueStoreBasedEventBus(GlobalValueKeyValueStore(), true)
        end)

        local function install_routes(name, events, initial_route_source, required_initial_route_sources)
            main.kv_store:store("busid:main:route", {
                name = name,
                events = events,
                initial_route_source = initial_route_source,
                required_initial_route_sources = required_initial_route_sources
            })
            main:update()
        end

        it("should install a complete endpoint route set atomically", function()
            local debug_message = spy.on(_G, "DebugMessage")
            install_routes("eventbus", {"FIRST_EVENT", "SECOND_EVENT"}, "galactic-core", {"galactic-core"})

            assert.is_true(main.subscribers.FIRST_EVENT.eventbus)
            assert.is_true(main.subscribers.SECOND_EVENT.eventbus)
            assert.is_true(main.kv_store:get("busid:main:ready"))
            assert.is_nil(main.kv_store:get("busid:main:route"))
            assert.spy(debug_message).was.called_with(
                "Crossplot initial routes installed: source=%s endpoint=%s routes=%s",
                "galactic-core", "eventbus", "2")
            assert.spy(debug_message).was.called_with(
                "Crossplot routes ready: sources=%s", "galactic-core")
        end)

        it("should retain inbound publications until every required initial route source is installed", function()
            local debug_message = spy.on(_G, "DebugMessage")
            local listener = spy.new(function() end)
            main:subscribe("MY_EVENT", listener)
            main.kv_store:store("busid:main:publish", {
                event_name = "MY_EVENT",
                args = {"value"}
            })

            install_routes("controller", {}, "custom-controller")
            assert.spy(listener).was.not_called()
            assert.is_not_nil(main.kv_store:get("busid:main:publish"))
            assert.spy(debug_message).was.called_with(
                "Crossplot routes waiting: missing sources=%s", "galactic-core")

            install_routes("plugins", {}, "galactic-core", {"galactic-core", "custom-controller"})
            assert.spy(listener).was.called_with("value")
            assert.is_nil(main.kv_store:get("busid:main:publish"))
            assert.spy(debug_message).was.called_with(
                "Crossplot routes ready: sources=%s", "custom-controller,galactic-core")
            assert.spy(debug_message).was.called_with(
                "Crossplot first publication after routes ready: event=%s", "MY_EVENT")
        end)

        it("should clear malformed route sets", function()
            local malformed_messages = {
                "not a message",
                {},
                {name = 42, events = {}, initial_route_source = "galactic-core"},
                {name = "eventbus", events = "MY_EVENT", initial_route_source = "galactic-core"},
                {name = "eventbus", events = {42}, initial_route_source = "galactic-core"},
                {name = "eventbus", events = {}, initial_route_source = 42}
            }

            for _, message in ipairs(malformed_messages) do
                main.kv_store:store("busid:main:route", message)
                assert.has_no.errors(function()
                    main:update()
                end)
                assert.is_nil(main.kv_store:get("busid:main:route"))
            end
        end)
    end)

    describe("Given an inbound publish message", function()
        before_each(function()
            main = MainKeyValueStoreBasedEventBus(GlobalValueKeyValueStore())
        end)

        it("should free the message before invoking local listeners", function()
            local mailbox = "busid:main:publish"
            local received = {}
            main:subscribe("MY_EVENT", function(value)
                assert.is_nil(main.kv_store:get(mailbox))
                table.insert(received, value)
                if value == "first" then
                    main.kv_store:store(mailbox, {
                        event_name = "MY_EVENT",
                        args = {"second"}
                    })
                end
            end)
            main.kv_store:store(mailbox, {
                event_name = "MY_EVENT",
                args = {"first"}
            })

            main:update()

            assert.are.same({"first"}, received)
            assert.are.same({
                event_name = "MY_EVENT",
                args = {"second"}
            }, main.kv_store:get(mailbox))

            main:update()

            assert.are.same({"first", "second"}, received)
            assert.is_nil(main.kv_store:get(mailbox))
        end)

        it("should clear malformed messages without invoking listeners", function()
            local listener = spy.new(function() end)
            main:subscribe("MY_EVENT", listener)
            local malformed_messages = {
                "not a message",
                {},
                {event_name = 42, args = {}},
                {event_name = "MY_EVENT"},
                {event_name = "MY_EVENT", args = "not an argument list"}
            }

            for _, message in ipairs(malformed_messages) do
                main.kv_store:store("busid:main:publish", message)
                assert.has_no.errors(function()
                    main:update()
                end)
                assert.is_nil(main.kv_store:get("busid:main:publish"))
            end

            assert.spy(listener).was.not_called()
        end)

        it("should clear publish messages for unknown events", function()
            main.kv_store:store("busid:main:publish", {
                event_name = "UNKNOWN_EVENT",
                args = {}
            })

            main:update()

            assert.is_nil(main.kv_store:get("busid:main:publish"))
        end)

        it("should clear malformed route messages", function()
            local malformed_messages = {
                "not a message",
                {},
                {name = 42, event = "MY_EVENT", active = true},
                {name = "eventbus", event = 42, active = true},
                {name = "eventbus", event = "MY_EVENT", active = "yes"}
            }

            for _, message in ipairs(malformed_messages) do
                main.kv_store:store("busid:main:route", message)
                assert.has_no.errors(function()
                    main:update()
                end)
                assert.is_nil(main.kv_store:get("busid:main:route"))
            end
        end)

        it("should clear falsey contents from every mailbox", function()
            eventbus = KeyValueStoreBasedEventBus("eventbus", GlobalValueKeyValueStore())
            local cases = {
                {
                    key = "busid:eventbus:notify",
                    serialized = "return false",
                    update = function() eventbus:update() end
                },
                {
                    key = "busid:main:publish",
                    serialized = "return nil",
                    update = function() main:update() end
                },
                {
                    key = "busid:main:route",
                    serialized = "return false",
                    update = function() main:update() end
                }
            }

            for _, case in ipairs(cases) do
                GlobalValue.Set(case.key, case.serialized)
                assert.has_no.errors(case.update)
                assert.are.equal("", GlobalValue.Get(case.key))
            end
        end)
    end)

    describe("Given subscribed function on main", function()
        before_each(function()
            main = MainKeyValueStoreBasedEventBus(GlobalValueKeyValueStore())

            subscriber_func = spy.new(function() end)
            main:subscribe("MY_EVENT", subscriber_func)
        end)

        describe("when publishing", function()
            it("should call callback function", function()
                main:publish("MY_EVENT", "args")

                assert.spy(subscriber_func).was.called_with("args")
            end)
        end)

        describe("when unsubscribing", function()
            describe("then publishing", function()
                it("should not call callback function", function()
                    main:unsubscribe("MY_EVENT", subscriber_func)

                    main:publish("MY_EVENT")

                    assert.spy(subscriber_func).was.not_called()
                end)
            end)
        end)
    end)

    describe("Given subscribed function with context on main", function()
        local context

        before_each(function()
            main = MainKeyValueStoreBasedEventBus()

            context = {}
            subscriber_func = spy.new(function() end)
            main:subscribe("MY_EVENT", subscriber_func, context)
        end)

        describe("when publishing", function()
            it("should call callback function", function()
                main:publish("MY_EVENT", "args")

                assert.spy(subscriber_func).was.called_with(context, "args")
            end)
        end)

        describe("when unsubscribing", function()
            describe("then publishing", function()
                it("should not call callback function", function()
                    main:unsubscribe("MY_EVENT", subscriber_func, context)

                    main:publish("MY_EVENT")

                    assert.spy(subscriber_func).was.not_called()
                end)
            end)
        end)
    end)
end)
