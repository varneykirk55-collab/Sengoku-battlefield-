class_name Combat
extends RefCounted
## Shared combat rules: finding soldiers, resolving katana strikes and matchlock shots.
## Player and AI go through exactly the same code.

## Chance that two katanas meeting mid-swing clash (no damage, both recoil).
static var clash_chance := 0.3
const HEAD_HEIGHT := 1.45


static func are_enemies(a: Node, b: Node) -> bool:
	return a is Soldier and b is Soldier and (a as Soldier).faction != (b as Soldier).faction


## Living soldiers whose bodies overlap a sphere.
static func soldiers_near(from: Node3D, center: Vector3, radius: float) -> Array[Soldier]:
	var out: Array[Soldier] = []
	var shape := SphereShape3D.new()
	shape.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, center)
	q.collision_mask = Soldier.LAYER_SOLDIERS
	q.collide_with_areas = false
	for hit in from.get_world_3d().direct_space_state.intersect_shape(q, 64):
		var s := hit.collider as Soldier
		if s and s.alive and not out.has(s):
			out.append(s)
	return out


## Resolves one katana contact. Returns &"hit", &"clash" or &"ignored".
static func melee_strike(attacker: Soldier, defender: Soldier, attack: AttackData, direction: Vector3) -> StringName:
	if not defender.alive or not are_enemies(attacker, defender):
		return &"ignored"
	var contact := attacker.chest_position().lerp(defender.chest_position(), 0.6)
	var dk := defender.weapons.current() as KatanaWeapon if defender.weapons else null
	if dk and dk.is_dangerous() and randf() < clash_chance \
			and defender.body_forward().dot(-direction) > 0.5:
		# Blades meet: both swings are knocked aside.
		var ak := attacker.weapons.current() as KatanaWeapon
		if ak:
			ak.knocked_aside()
		dk.knocked_aside()
		attacker.push(-direction * 2.5)
		defender.push(direction * 2.5)
		AudioManager.play(&"blade_clash", contact)
		FX.sparks(contact, -direction)
		Events.combat_noise.emit(contact, 0.6)
		if attacker.is_player or defender.is_player:
			FX.hitstop(0.06)
		return &"clash"
	var dealt := defender.take_damage(attack.damage, attacker, &"katana")
	if defender.alive:
		defender.push(direction * attack.knockback)
	AudioManager.play(&"katana_hit", contact)
	FX.blood(contact, direction)
	Events.combat_noise.emit(contact, 0.5)
	if attacker.is_player and dealt > 0.0:
		FX.hitstop(attack.hitstop * (1.6 if not defender.alive else 1.0))
	return &"hit"


## Fires one matchlock ball along a ray. Returns
## {hit: bool, position, normal, soldier, headshot, damage, distance}.
static func hitscan(shooter: Soldier, origin: Vector3, direction: Vector3, data: FirearmData) -> Dictionary:
	var to := origin + direction * data.max_range
	var q := PhysicsRayQueryParameters3D.create(origin, to, Soldier.LAYER_WORLD | Soldier.LAYER_SOLDIERS, [shooter.get_rid()])
	var r := shooter.get_world_3d().direct_space_state.intersect_ray(q)
	var result := {"hit": false, "position": to, "normal": -direction, "soldier": null, "headshot": false, "damage": 0.0, "distance": data.max_range}
	if r.is_empty():
		return result
	result.hit = true
	result.position = r.position
	result.normal = r.normal
	result.distance = origin.distance_to(r.position)
	var s := r.collider as Soldier
	if s:
		result.soldier = s
		if are_enemies(shooter, s):
			var dmg := data.damage_at(result.distance)
			if r.position.y > s.global_position.y + HEAD_HEIGHT:
				dmg *= data.headshot_multiplier
				result.headshot = true
			result.damage = s.take_damage(dmg, shooter, &"matchlock")
			if s.alive:
				s.push(direction * 1.5)
		AudioManager.play(&"bullet_hit_flesh", r.position)
		FX.blood(r.position, direction)
	else:
		var wood := r.collider is Node and (r.collider as Node).is_in_group("wood")
		AudioManager.play(&"bullet_hit_wood" if wood else &"bullet_hit_ground", r.position)
		FX.dust(r.position, r.normal)
	return result


## Closest point on a shot's path to a listener, for the near-miss whiz.
static func closest_point_on_segment(a: Vector3, b: Vector3, p: Vector3) -> Vector3:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return a + ab * t
