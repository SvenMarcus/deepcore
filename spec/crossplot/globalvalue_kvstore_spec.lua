describe("GlobalValueKeyValueStore", function()
    local eaw_env
    local require_utilities
    local store

    before_each(function()
        eaw_env = require("spec.eaw_env")
        eaw_env.setup_environment()

        require_utilities = require("spec.require_utilities")
        require_utilities.replace_require()
        require("deepcore/crossplot/GlobalValueKeyValueStore")
        store = GlobalValueKeyValueStore()
    end)

    after_each(function()
        eaw_env.teardown_environment()
        require_utilities.reset_require()
    end)

    it("should write and read raw text through GlobalValue", function()
        store:write("key", "text")

        assert.are.equal("text", GlobalValue.Get("key"))
        assert.are.equal("text", store:read("key"))
        assert.is_false(store:is_empty("key"))
    end)

    it("should be empty for unset keys", function()
        assert.is_true(store:is_empty("NON_EXISTING"))
        assert.is_nil(store:read("NON_EXISTING"))
    end)

    it("should set value to empty string when freeing", function()
        store:write("key", "text")

        store:free("key")

        assert.are.equal("", GlobalValue.Get("key"))
        assert.is_true(store:is_empty("key"))
    end)
end)
