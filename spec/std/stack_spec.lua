local require_utilities = require("spec.require_utilities")

describe("Stack", function()

    before_each(function()
        require_utilities.replace_require()
        require("deepcore/std/Stack")
    end)

    after_each(function()
        require_utilities.reset_require()
    end)

    describe("added a value", function()
        it("has a size of 1", function()
            local sut = Stack()

            sut:add("stuff")

            assert.are.equal(1, sut:size())
        end)
    end)
end)
