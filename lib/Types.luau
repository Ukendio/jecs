--!native
--!optimize 2
--!strict

export type i53 = number
export type i24 = number

export type Ty = {i53}
export type ArchetypeId = number

export type Column = {any}

export type Archetype = {
	id: number,
	edges: {
		[i24]: {
			add: Archetype,
			remove: Archetype,
		},
	},
	types: Ty,
	type: string | number,
	entities: {number},
	columns: {Column},
	records: {},
}

export type Record = {
	archetype: Archetype,
	row: number,
}

export type EntityIndex = {[i24]: Record}
export type ComponentIndex = {[i24]: ArchetypeMap}

export type ArchetypeRecord = number
export type ArchetypeMap = {sparse: {[ArchetypeId]: ArchetypeRecord}, size: number}
export type Archetypes = {[ArchetypeId]: Archetype}

export type ArchetypeDiff = {
	added: Ty,
	removed: Ty,
}

export type Hook = {
	ids: Ty,
	archetype: Archetype,
	otherArchetype: Archetype,
	offset: number,
}

export type EventDescription = Hook & {
	event: number,
}

export type World = {
	archetypeIndex: {[number | string]: Archetype},
	archetypes: {[number]: Archetype},
	componentIndex: {[i24]: ArchetypeMap},
	entityIndex: {[i53]: Record},
	hooks: {[number]: {Hook}},
	nextComponentId: number,
	nextEntityId: number,
	ROOT_ARCHETYPE: Archetype,

	get: (self: World) -> (),
}

export type WorldStatic = {
	new: () -> World,
}

return false
