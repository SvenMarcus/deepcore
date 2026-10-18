require("deepcore/crossplot/crossplot")
require("deepcore/std/PluginLoader")
require("deepcore/std/callable")
require("deepcore/galaxy/GalacticConquest")

deepcore = {}

---@param config table Galactic DeepCore configuration, including optional required_initial_route_sources startup listener group names
function deepcore:galactic(config)
    if not config.plugin_folder then
        error("Missing mandatory setting plugin_folder")
    end

    local context = config.context or {}
    local plugin_loader = PluginLoader(context, config.plugin_folder)
    crossplot:galactic("galactic-core")
    context.galactic_conquest = GalacticConquest(config.planet_factory)
    plugin_loader:load(config.plugins)
    -- Announce the complete listener list only after every plugin is loaded.
    crossplot:submit_initial_routes(config.required_initial_route_sources or {"galactic-core"})

    return {
        planets = context.galactic_conquest.Planets,
        plugin_containers = plugin_loader:get_plugin_containers(),
        planet_dependent_plugin_containers = plugin_loader:get_planet_dependent_plugin_containers(),
        plugin_updatecycle = require("deepcore/std/plugin_updatecycle").galactic_plugin_update_cycle,
        update = function(self)
            crossplot:update()
            self:plugin_updatecycle()
        end
    }
end

function deepcore:game_object(config)
    if not config.plugin_folder then
        error("Missing mandatory setting plugin_folder")
    end

    local plugin_loader = PluginLoader(config.context, config.plugin_folder)
    crossplot:game_object()
    plugin_loader:load(config.plugins)

    return {
        plugin_containers = plugin_loader:get_plugin_containers(),
        plugin_updatecycle = require("deepcore/std/plugin_updatecycle").generic_plugin_update_cycle,
        update = function(self)
            crossplot:update()
            self:plugin_updatecycle()
        end
    }
end

function deepcore:gamescoring(config)
    if not config.plugin_folder then
        error("Missing mandatory setting plugin_folder")
    end

    local plugin_loader = PluginLoader(config.context, config.plugin_folder)
    crossplot:main()
    plugin_loader:load(config.plugins)

    return {
        plugin_containers = plugin_loader:get_plugin_containers(),
        plugin_updatecycle = require("deepcore/std/plugin_updatecycle").generic_plugin_update_cycle,
        update = function(self)
            crossplot:update()
            self:plugin_updatecycle()
        end
    }
end

return deepcore
