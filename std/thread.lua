require("deepcore/std/class")

---@class DeepCoreThread
DeepCoreThread = class()

---@param func fun(...): any
---@param param any
function DeepCoreThread:new(func, param)
    ---@type fun(...): any
    self._func = func

    ---@type any
    self._param = param

    ---@type number
    self._thread_id = nil
end

function DeepCoreThread:start()
    if self:is_alive() then
        return
    end
    local thread_name = "deepcore::thread::" .. tostring(self._func)
    _G[thread_name] = self._func
    self._thread_id = Create_Thread(thread_name, self._param)
end

function DeepCoreThread:is_alive()
    return Thread.Is_Thread_Active(self._thread_id)
end

function DeepCoreThread:kill()
    if not self:is_alive() then
        return
    end
    Thread.Kill(self._thread_id)
end
