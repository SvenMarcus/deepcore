describe("GlobalValueKeyValueStore", function()
    local eaw_env
    local require_utilities

    before_each(function()
        eaw_env = require("spec.eaw_env")
        eaw_env.setup_environment()

        require_utilities = require("spec.require_utilities")
        require_utilities.replace_require()
        require("deepcore/crossplot/GlobalValueKeyValueStore")
    end)

    after_each(function()
        eaw_env.teardown_environment()
        require_utilities.reset_require()
    end)

    describe("When storing simple value", function()
        it("should store value in GlobalValue", function()
            local kv_store = GlobalValueKeyValueStore()
            local global_value_spy = spy.on(GlobalValue, "Set")

            kv_store:store("key", "value")
            assert.spy(global_value_spy).was.called()
        end)

        it("should serialize value before storing it", function()
            local kv_store = GlobalValueKeyValueStore()

            kv_store:store("key", "value")

            local actual = loadstring(GlobalValue.Get("key"))()
            assert.are.equal("value", actual)
        end)

        describe("then retrieving it", function()
            it("should return stored value", function()
                local kv_store = GlobalValueKeyValueStore()
                kv_store:store("key", "value")

                assert.are.equal("value", kv_store:get("key"))
            end)
        end)
    end)

    describe("When storing table value", function()
        it("should serialize and store value in GlobalValue", function()
            local kv_store = GlobalValueKeyValueStore()

            local value = {value = 5, sub_table = {1, 2}}
            kv_store:store("key", value)

            local actual = loadstring(GlobalValue.Get("key"))()
            assert.are.same(value, actual)
        end)

        it("should preserve escaped strings and non-identifier keys", function()
            local kv_store = GlobalValueKeyValueStore()
            local value = {
                ['key with spaces'] = 'quotes " and a\nnewline',
                [true] = false
            }

            assert.is_true(kv_store:store("key", value))
            assert.are.same(value, kv_store:get("key"))
        end)

        it("should reject native values, functions, and cycles", function()
            local kv_store = GlobalValueKeyValueStore()
            local cycle = {}
            cycle.self = cycle
            local cases = {
                io.stdout,
                function() end,
                {nested = io.stdout},
                cycle
            }

            for _, value in ipairs(cases) do
                GlobalValue.Set("key", "")
                assert.is_false(kv_store:store("key", value))
                assert.are.equal("", GlobalValue.Get("key"))
            end
        end)

        describe("then retrieving it", function()
            it("should return stored value", function()
                local kv_store = GlobalValueKeyValueStore()
                
                local value = {value = 5, sub_table = {1, 2}}
                kv_store:store("key", value)

                assert.are.same(value, kv_store:get("key"))
            end)
        end)
    end)

    describe("When freeing value", function()
        it("should set value to empty string", function()
            GlobalValue.Set("key", "value")
            local kv_store = GlobalValueKeyValueStore()

            kv_store:free("key")

            assert.are.equal("", GlobalValue.Get("key"))
        end)
    end)

    describe("When taking a mailbox value", function()
        it("should clear serializable contents", function()
            local kv_store = GlobalValueKeyValueStore()
            local cases = {
                {serialized = 'return "value"', expected = "value"},
                {serialized = "return false", expected = false},
                {serialized = "return nil", expected = nil}
            }

            for _, case in ipairs(cases) do
                GlobalValue.Set("key", case.serialized)
                assert.is_false(kv_store:is_empty("key"))
                local value = kv_store:take("key")

                assert.are.same(case.expected, value)
                assert.are.equal("", GlobalValue.Get("key"))
                assert.is_true(kv_store:is_empty("key"))
            end
        end)
    end)

    describe("When getting non-existing key", function()
        it("should return nil", function()
            local kv_store = GlobalValueKeyValueStore()

            local actual = kv_store:get("NON_EXISTING")
        
            assert.is_nil(actual)
        end)
    end)
end)
