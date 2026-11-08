describe("Mailbox", function()
    local require_utilities
    local eaw_env

    local slots
    local mailbox

    before_each(function()
        eaw_env = require("spec.eaw_env")
        eaw_env.setup_environment()

        require_utilities = require("spec.require_utilities")
        require_utilities.replace_require()

        require("deepcore/crossplot/Mailbox")
        slots = require("spec.crossplot.fake_slot_store")()
        mailbox = Mailbox(slots)
    end)

    after_each(function()
        eaw_env.teardown_environment()
        require_utilities.reset_require()
    end)

    local function deliver(key, value)
        local sender = Mailbox(slots)
        assert.is_true(sender:send(key, value))
        sender:process()
    end

    describe("When sending a value", function()
        it("should not occupy the slot before processing", function()
            assert.is_true(mailbox:send("key", "value"))

            assert.is_true(slots:is_empty("key"))
        end)

        it("should make the value receivable after processing", function()
            mailbox:send("key", "value")
            mailbox:process()

            assert.are.equal("value", mailbox:receive("key"))
        end)

        it("should round-trip tables with escaped strings and non-identifier keys", function()
            local value = {
                value = 5,
                sub_table = {1, 2},
                ["key with spaces"] = 'quotes " and a\nnewline',
                [true] = false
            }

            deliver("key", value)

            assert.are.same(value, mailbox:receive("key"))
        end)

        it("should reject unsupported values", function()
            local cycle = {}
            cycle.self = cycle
            local cases = {io.stdout, function() end, {nested = io.stdout}, cycle}

            for _, value in ipairs(cases) do
                assert.is_false(mailbox:send("key", value))
            end

            mailbox:process()
            assert.is_true(slots:is_empty("key"))
        end)

        it("should keep the value as it was when sent", function()
            local value = {count = 1}
            mailbox:send("key", value)
            value.count = 2

            mailbox:process()

            assert.are.same({count = 1}, mailbox:receive("key"))
        end)
    end)

    describe("When the slot is occupied", function()
        it("should not overwrite it", function()
            deliver("key", "first")

            mailbox:send("key", "second")
            mailbox:process()

            assert.are.equal("first", mailbox:receive("key"))
        end)
    end)

    describe("When sending several values to one key", function()
        it("should deliver one per process call in order", function()
            mailbox:send("key", "first")
            mailbox:send("key", "second")

            mailbox:process()
            assert.are.equal("first", mailbox:receive("key"))
            assert.is_nil(mailbox:receive("key"))

            mailbox:process()
            assert.are.equal("second", mailbox:receive("key"))
        end)

        it("should not deliver a message twice", function()
            mailbox:send("key", "value")

            mailbox:process()
            mailbox:receive("key")
            mailbox:process()

            assert.is_nil(mailbox:receive("key"))
        end)
    end)

    describe("When receiving", function()
        it("should return nil for an empty slot", function()
            assert.is_nil(mailbox:receive("NON_EXISTING"))
        end)

        it("should free the slot", function()
            deliver("key", "value")

            mailbox:receive("key")

            assert.is_true(slots:is_empty("key"))
        end)

        it("should return falsy values", function()
            deliver("key", false)

            assert.is_false(mailbox:receive("key"))
        end)
    end)
end)
