describe("DeepCoreCrossplotTransitionPolicy", function()
    local require_utilities = require("spec.require_utilities")

    before_each(function()
        require_utilities.replace_require()
        _G.crossplot = {
            subscribe = function() end
        }
        require("deepcore/statemachine/transition-policies/DeepCoreCrossplotTransitionPolicy")
    end)

    after_each(function()
        require_utilities.reset_require()
        _G.crossplot = nil
        _G.DeepCoreCrossplotTransitionPolicy = nil
    end)

    it("should consume repeated story transitions one at a time", function()
        local transition_count = 0
        local policy = DeepCoreCrossplotTransitionPolicy("NEXT_ERA", function()
            transition_count = transition_count + 1
        end)

        policy:state_transition_trigger("NEXT_ERA")
        policy:state_transition_trigger("NEXT_ERA")

        assert.is_true(policy:should_transition({}))
        policy:on_transition({})
        assert.is_true(policy:should_transition({}))
        policy:on_transition({})
        assert.is_false(policy:should_transition({}))
        assert.are.equal(2, transition_count)
    end)
end)
