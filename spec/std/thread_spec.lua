describe("Given a thread", function()
    local eaw_env = require("spec.eaw_env")
    local require_utilities = require("spec.require_utilities")
    local setup_fake_thread = require("spec.fake_thread")
    ---@type DeepCoreThread
    local sut

    before_each(function()
        require_utilities.replace_require()
        setup_fake_thread()

        require("deepcore/std/thread")
    end)

    after_each(function()
        require_utilities.reset_require()
    end)

    local function spy_on_create_thread(opt_thread_id)
        local _create_thread = Create_Thread
        local thread_spy = spy.new(function(...)
            _create_thread(...)
            return opt_thread_id or 1
        end)

        _G.Create_Thread = thread_spy

        return thread_spy
    end

    local function spy_on_thread_kill()
        local _thread_kill = _G.Thread.Kill
        local kill_spy = spy.new(function(id)
            _thread_kill(id)
        end)

        _G.Thread.Kill = kill_spy

        return kill_spy
    end

    it("is not alive", function()
        sut = DeepCoreThread()

        assert.is_false(sut:is_alive())
    end)

    describe("when killing without starting", function()
        it("doesn't call Thread.Kill", function()
            local kill_spy = spy_on_thread_kill()
            sut = DeepCoreThread(function()
            end)

            sut:kill()

            assert.spy(kill_spy).was.not_called()
        end)
    end)

    describe("when starting", function()
        it("creates a thread", function()
            local thread_spy = spy_on_create_thread()
            sut = DeepCoreThread(function()
            end)

            sut:start()

            assert.spy(thread_spy).was.called()
        end)

        it("creates a thread that calls the given function with parameter", function()
            _G.Create_Thread = function(func_name, param)
                _G[func_name](param)
            end

            local expected_param = "expected"
            local func_spy = spy.new(function()
            end)
            sut = DeepCoreThread(func_spy, expected_param)

            sut:start()

            assert.spy(func_spy).was.called_with(expected_param)
        end)

        it("is alive", function()
            sut = DeepCoreThread(function()
            end)

            sut:start()

            assert.is_true(sut:is_alive())
        end)
    end)

    describe("when starting, then killing it", function()
        local function make_started_thread()
            sut = DeepCoreThread(function()
            end)
            sut:start()

            return sut
        end

        it("is not alive", function()
            local kill_spy = spy_on_thread_kill()
            spy_on_create_thread()

            local sut = make_started_thread()

            sut:kill()

            assert.is_false(sut:is_alive())
        end)
    end)

    describe("when starting twice", function()
        it("only starts once", function()
            local thread_spy = spy_on_create_thread()
            sut = DeepCoreThread(function()
            end)

            sut:start()
            sut:start()

            assert.spy(thread_spy).was.called(1)
        end)
    end)

    describe("and a second thread", function()
        ---@type DeepCoreThread
        local second

        local function thread_name(func)
            return "deepcore::thread::" .. tostring(func)
        end

        describe("when starting both", function()
            it("starts both with unique thread names", function()
                local first_func = function()
                end
                local second_func = function()
                end

                local thread_spy = spy_on_create_thread()

                sut = DeepCoreThread(first_func)
                sut:start()

                second = DeepCoreThread(second_func)
                second:start()

                assert.spy(thread_spy).was.called_with(thread_name(first_func), nil)
                assert.spy(thread_spy).was.called_with(thread_name(second_func), nil)
            end)
        end)
    end)
end)
