class_name CombatLayers
extends RefCounted
## Physics layer numbers for the combat sandbox (contract section 1; named in project.godot).
## Layer numbers are 1-based like the editor; use bit() to get the mask value.

const WORLD: int = 1
const PLAYER_BODY: int = 10
const ENEMY_BODY: int = 11
const PLAYER_HURTBOX: int = 12
const ENEMY_HURTBOX: int = 13
const PLAYER_HITBOX: int = 14
const ENEMY_HITBOX: int = 15
const INTERACT: int = 16

const TEAM_PLAYER: StringName = &"player"
const TEAM_ENEMY: StringName = &"enemy"


## Mask bit for a 1-based layer number.
static func bit(layer: int) -> int:
	return 1 << (layer - 1)


static func body_layer(team: StringName) -> int:
	return PLAYER_BODY if team == TEAM_PLAYER else ENEMY_BODY


## What a body collides with: the world, and the other team's body (enemies also push each other).
## `through_enemies` is Red dashing: she slips through enemy bodies.
static func body_mask(team: StringName, through_enemies: bool = false) -> int:
	if team == TEAM_PLAYER:
		var mask: int = bit(WORLD)
		if not through_enemies:
			mask |= bit(ENEMY_BODY)
		return mask
	return bit(WORLD) | bit(PLAYER_BODY) | bit(ENEMY_BODY)


static func hurtbox_layer(team: StringName) -> int:
	return PLAYER_HURTBOX if team == TEAM_PLAYER else ENEMY_HURTBOX


## A hurtbox is only ever looked at; it scans nothing.
static func hurtbox_mask() -> int:
	return 0


static func hitbox_layer(team: StringName) -> int:
	return PLAYER_HITBOX if team == TEAM_PLAYER else ENEMY_HITBOX


## What a team's hitbox queries: the other team's hurtboxes.
static func hitbox_mask(team: StringName) -> int:
	return bit(ENEMY_HURTBOX) if team == TEAM_PLAYER else bit(PLAYER_HURTBOX)


static func opposing(team: StringName) -> StringName:
	return TEAM_ENEMY if team == TEAM_PLAYER else TEAM_PLAYER
