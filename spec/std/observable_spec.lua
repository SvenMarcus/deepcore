describe("Observable", function()
    local observable
    local require_utilities = require("spec.require_utilities")

    before_each(function()
        require_utilities.replace_require()
        require("deepcore/std/Observable")
        observable = Observable()
    end)

    after_each(function()
        require_utilities.reset_require()
        _G.Observable = nil
    end)

    it("should finish notifying the original listeners when one detaches", function()
        local calls = {}
        local first
        first = function()
            table.insert(calls, "first")
            observable:detach_listener(first)
        end
        local second = function()
            table.insert(calls, "second")
        end

        observable:attach_listener(first)
        observable:attach_listener(second)
        observable:notify()

        assert.are.same({"first", "second"}, calls)

        calls = {}
        observable:notify()
        assert.are.same({"second"}, calls)
    end)

    it("should finish notifying a listener detached by another listener", function()
        local calls = {}
        local second = function()
            table.insert(calls, "second")
        end
        local first = function()
            table.insert(calls, "first")
            observable:detach_listener(second)
        end

        observable:attach_listener(first)
        observable:attach_listener(second)
        observable:notify()

        assert.are.same({"first", "second"}, calls)

        calls = {}
        observable:notify()
        assert.are.same({"first"}, calls)
    end)

    it("should defer listeners attached while notifying", function()
        local calls = {}
        local attached = false
        local third = function()
            table.insert(calls, "third")
        end
        local first = function()
            table.insert(calls, "first")
            if not attached then
                observable:attach_listener(third)
                attached = true
            end
        end
        local second = function()
            table.insert(calls, "second")
        end

        observable:attach_listener(first)
        observable:attach_listener(second)
        observable:notify()

        assert.are.same({"first", "second"}, calls)

        calls = {}
        observable:notify()
        assert.are.same({"first", "second", "third"}, calls)
    end)
end)
