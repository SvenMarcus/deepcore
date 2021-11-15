PluginTargets = {}

function PluginTargets.always()
    return function()
        return true
    end
end

function PluginTargets.never()
    return function()
        return false
    end
end

function PluginTargets.interval(seconds)
    return setmetatable(
        {seconds = seconds, next_update = -1, week = 0},
        {
            __call = function(t)
                local current_time = GetCurrentTime()
                if t.next_update == -1 or current_time >= t.next_update then
                    t.week = t.week + 1
                    t.next_update = t.week * 40
                    return true
                end

                return false
            end
        }
    )
end

function PluginTargets.story_flag(flag_name, player)
    return setmetatable(
        {flag_name = flag_name, player = player or Find_Player("local")},
        {
            __call = function(t)
                return Check_Story_Flag(t.player, t.flag_name, nil, true)
            end
        }
    )
end
