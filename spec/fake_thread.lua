local function setup_thread_globals()
    local thread_mt = {}

    local alive_threads = {}

    thread_mt.__call = function(t, name, param)
        table.insert(alive_threads, {
            param = param
        })
        return #alive_threads
    end

    thread_mt.__index = {}

    function thread_mt.__index.Kill(thread_id)
        table.remove(alive_threads, thread_id)
    end

    function thread_mt.__index.Kill_All()
        alive_threads = {}
    end

    function thread_mt.__index.Is_Thread_Active(id)
        return alive_threads[id] ~= nil
    end

    _G.Create_Thread = setmetatable({}, thread_mt)
    _G.Thread = setmetatable({
        Create = thread_mt.__call
    }, thread_mt)
end

return setup_thread_globals
