local entity = require(script.apps.entity)
local home = require(script.apps.home)
local overview_scheduler = require(script.apps.overview_scheduler)
local registry = require(script.apps.registry)
local spawn_app = require(script.spawn_app)

return {

	apps = {
		home = home,
		entity = entity,
		scheduler = overview_scheduler,
		registry = registry,
	},

	spawn_app = spawn_app.spawn_app,
	unmount_all = spawn_app.unmount_all

}