describe("Eventbus", function()
    local require_utilities
    local eaw_env

    local busid
    local eventbus

    local fake_kvstore

    before_each(function()
        local make_fake_kvstore = require("spec.crossplot.fake_kvstore")

        require_utilities = require("spec.require_utilities")
        require_utilities.replace_require()
        
        eaw_env = require("spec.eaw_env")
        eaw_env.setup_environment()
        
        busid = "busid:".._G.Script
        
        require("deepcore/crossplot/KeyValueStoreBasedEventBus")
        fake_kvstore = make_fake_kvstore()
        eventbus = KeyValueStoreBasedEventBus(_G.Script, fake_kvstore)
    end)

    after_each(function()
        require_utilities.reset_require()
        eaw_env.teardown_environment()
        fake_kvstore:clear()
    end)

    describe("When subscribing to an event", function()
        it("should set the GlobalValue for the master event bus", function()
            local function func() end
            eventbus:subscribe("MY_EVENT", func)
            
            eventbus:update()

            local subscriber = fake_kvstore:get("busid:main:route")
            assert.are.equal(subscriber.name, Script)
            assert.are.equal(subscriber.event, "MY_EVENT")
            assert.is_true(subscriber.active)
        end)

        it("should only register the endpoint for the first listener", function()
            eventbus:subscribe("MY_EVENT", function() end)
            eventbus:update()
            fake_kvstore:free("busid:main:route")

            eventbus:subscribe("MY_EVENT", function() end)
            eventbus:update()

            assert.is_nil(fake_kvstore:get("busid:main:route"))
        end)
    end)

    describe("Given a named initial route source", function()
        before_each(function()
            eventbus = KeyValueStoreBasedEventBus(_G.Script, fake_kvstore, "galactic-core")
        end)

        it("should submit all routes atomically", function()
            local debug_message = spy.on(_G, "DebugMessage")
            eventbus:subscribe("SECOND_EVENT", function() end)
            eventbus:subscribe("FIRST_EVENT", function() end)

            eventbus:update()
            assert.is_nil(fake_kvstore:get("busid:main:route"))

            eventbus:submit_initial_routes({"galactic-core"})
            eventbus:update()

            assert.are.same({
                name = Script,
                events = {"FIRST_EVENT", "SECOND_EVENT"},
                initial_route_source = "galactic-core",
                required_initial_route_sources = {"galactic-core"}
            }, fake_kvstore:get("busid:main:route"))
            assert.spy(debug_message).was.called_with(
                "Crossplot initial routes queued: source=%s endpoint=%s routes=%s",
                "galactic-core", Script, "2")
        end)

        it("should send later subscription changes normally", function()
            eventbus:submit_initial_routes()
            eventbus:update()
            fake_kvstore:free("busid:main:route")

            eventbus:subscribe("LATE_EVENT", function() end)
            eventbus:update()

            assert.are.same({
                name = Script,
                event = "LATE_EVENT",
                active = true
            }, fake_kvstore:get("busid:main:route"))
        end)
    end)

    describe("Given subscribed to an event", function()
        describe("when publishing event", function()
            it("should call the callback function", function()
                local func = spy.new(function() end)
                eventbus:subscribe("MY_EVENT", func)
                fake_kvstore:store(busid..":notify", { event_name = 'MY_EVENT', args = {4, 2} })

                eventbus:update()

                assert.spy(func).was.called_with(4, 2)
            end)

            it("should reset the GlobalValue", function()
                local func = function() end
                eventbus:subscribe("MY_EVENT", func)
                fake_kvstore:store(busid..":notify", { event_name = 'MY_EVENT', args = {4, 2} })

                eventbus:update()

                assert.is_nil(fake_kvstore:get(busid..":notify"))
            end)

            it("should free the notification before invoking its listener", function()
                local mailbox = busid..":notify"
                local received = {}
                eventbus:subscribe("MY_EVENT", function(value)
                    assert.is_nil(fake_kvstore:get(mailbox))
                    table.insert(received, value)
                    if value == "first" then
                        fake_kvstore:store(mailbox, {
                            event_name = "MY_EVENT",
                            args = {"second"}
                        })
                    end
                end)
                fake_kvstore:store(mailbox, {
                    event_name = "MY_EVENT",
                    args = {"first"}
                })

                eventbus:update()

                assert.are.same({"first"}, received)
                assert.are.same({
                    event_name = "MY_EVENT",
                    args = {"second"}
                }, fake_kvstore:get(mailbox))

                eventbus:update()

                assert.are.same({"first", "second"}, received)
                assert.is_nil(fake_kvstore:get(mailbox))
            end)

            it("should clear notifications for unknown events", function()
                fake_kvstore:store(busid..":notify", {
                    event_name = "UNKNOWN_EVENT",
                    args = {}
                })

                eventbus:update()

                assert.is_nil(fake_kvstore:get(busid..":notify"))
            end)

            it("should clear malformed notifications without invoking listeners", function()
                local listener = spy.new(function() end)
                eventbus:subscribe("MY_EVENT", listener)
                local malformed_messages = {
                    "not a message",
                    {},
                    {event_name = 42, args = {}},
                    {event_name = "MY_EVENT"},
                    {event_name = "MY_EVENT", args = "not an argument list"}
                }

                for _, message in ipairs(malformed_messages) do
                    fake_kvstore:store(busid..":notify", message)
                    assert.has_no.errors(function()
                        eventbus:update()
                    end)
                    assert.is_nil(fake_kvstore:get(busid..":notify"))
                end

                assert.spy(listener).was.not_called()
            end)
        end)

        describe("when unsubscribing", function()
            it("should set the GlobalValue for the master event bus", function()
                local function func() end
                eventbus:subscribe("MY_EVENT", func)
                eventbus:update()
                fake_kvstore:free("busid:main:route")

                eventbus:unsubscribe("MY_EVENT", func)
                eventbus:update()

                local unsubscriber = fake_kvstore:get("busid:main:route")
                assert.are.equal(unsubscriber.name, _G.Script)
                assert.are.equal(unsubscriber.event, "MY_EVENT")
                assert.is_false(unsubscriber.active)
            end)

            it("should unregister the endpoint only after the last listener", function()
                local function first() end
                local function second() end
                eventbus:subscribe("MY_EVENT", first)
                eventbus:subscribe("MY_EVENT", second)
                eventbus:update()
                fake_kvstore:free("busid:main:route")

                eventbus:unsubscribe("MY_EVENT", first)
                eventbus:update()
                assert.is_nil(fake_kvstore:get("busid:main:route"))

                eventbus:unsubscribe("MY_EVENT", second)
                eventbus:update()

                local unsubscriber = fake_kvstore:get("busid:main:route")
                assert.are.equal(unsubscriber.name, _G.Script)
                assert.are.equal(unsubscriber.event, "MY_EVENT")
                assert.is_false(unsubscriber.active)
            end)
        end)
    end)
end)
