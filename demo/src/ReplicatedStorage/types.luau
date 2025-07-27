local jecs = require(game:GetService("ReplicatedStorage").ecs)

export type World = typeof(jecs.world())
export type Entity = jecs.Entity
export type Id<T> = jecs.Id<T>
export type Snapshot = {
	[string]: {
		set: { jecs.Entity }?,
		values: { any }?,
		removed: { jecs.Entity }?
	}
}

return {}
