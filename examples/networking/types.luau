local jecs = require("@jecs")

export type snapshot = {
	[string]: {
		set: { jecs.Entity }?,
		values: { any }?,
		removed: { jecs.Entity }?,
		pair: true,
		relation: jecs.Entity,
		target: jecs.Entity
	} | {
		set: { jecs.Entity }?,
		values: { any }?,
		removed: { jecs.Entity }?,
		pair: false,
	}
}

return {}
