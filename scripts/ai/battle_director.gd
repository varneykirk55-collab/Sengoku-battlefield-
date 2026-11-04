class_name BattleDirector
extends Node
## Runs both AI armies:
##   * a spatial grid of soldiers for cheap "who is near me" queries,
##   * staggered AI thinking (each AI decides ~ai_think_hz times per second, spread over frames),
##   * squads of AI soldiers assigned to objectives (attack points they don't hold, defend
##     threatened points they do), reassigned every few seconds,
##   * attack tokens so only a few AI fight the player in melee at once,
##   * animation / shadow level-of-detail by distance to the camera.

const GRID_CELL := 12.0

var battle: Node
var config: BattleConfig
var soldiers: Array[Soldier] = []
var ais: Array[AIController] = []
var squads: Array[Squad] = []
var objectives: Array[CapturePoint] = []

## Profiling counters (read by tests and the performance report).
var stats := {"thinks": 0, "los_checks": 0, "reassignments": 0}

var _grid: Dictionary = {}  # Vector2i -> Array[Soldier]
var _think_cursor := 0
var _think_budget := 0.0
var _reassign_left := 0.0
var _grid_age := 0
var _player_attackers: Array[AIController] = []


func setup(b: Node, cfg: BattleConfig, points: Array[CapturePoint]) -> void:
	battle = b
	config = cfg
	objectives = points


func register(s: Soldier) -> void:
	if not soldiers.has(s):
		soldiers.append(s)
	if s.controller is AIController and not ais.has(s.controller):
		ais.append(s.controller as AIController)
		(s.controller as AIController).director = self


## Groups each faction's AI soldiers into squads.
func build_squads() -> void:
	squads.clear()
	for f in 2:
		var members: Array[Soldier] = []
		for a in ais:
			if a.soldier.faction == f:
				members.append(a.soldier)
		var sq: Squad = null
		for m in members:
			if sq == null or sq.members.size() >= config.squad_size:
				sq = Squad.new()
				sq.id = squads.size()
				sq.faction = f
				squads.append(sq)
			sq.members.append(m)
			(m.controller as AIController).squad = sq
	reassign_squads()


func _physics_process(delta: float) -> void:
	_grid_age += 1
	if _grid_age >= 3:
		_rebuild_grid()
	_reassign_left -= delta
	if _reassign_left <= 0.0:
		_reassign_left = config.squad_reassign_interval
		reassign_squads()
	# Staggered thinking: spread ai_think_hz decisions per AI across physics frames.
	if ais.is_empty():
		return
	_think_budget += ais.size() * config.ai_think_hz * delta
	var n := int(_think_budget)
	_think_budget -= n
	for i in mini(n, ais.size()):
		_think_cursor = (_think_cursor + 1) % ais.size()
		var ai := ais[_think_cursor]
		if is_instance_valid(ai) and ai.soldier.alive:
			ai.think()
			stats.thinks += 1
		_update_lod(ai.soldier)


# ----------------------------------------------------------------------------- squads & objectives
## Sends squads where they are needed: points the faction doesn't own (attack), and owned points
## with enemies nearby (defend). Each extra squad on the same point is worth less, so the army
## spreads over all three objectives.
func reassign_squads() -> void:
	if objectives.is_empty():
		return
	stats.reassignments += 1
	for f in 2:
		var faction_squads := squads.filter(func(q: Squad) -> bool: return q.faction == f)
		var load := {}  # objective -> squads already sent
		# Rank squads by how close they are to any objective so nearby squads keep sensible orders.
		for sq: Squad in faction_squads:
			var best: CapturePoint = null
			var best_score := -INF
			var center := _squad_center(sq)
			for cp in objectives:
				var owned := cp.owner_faction == f
				var enemies := _count_near(cp.global_position, cp.radius + 18.0, 1 - f)
				var value := 1.0 if not owned else (0.35 + 0.25 * mini(enemies, 4))
				if cp.owner_faction == 1 - f:
					value += 0.25  # taking an enemy point also stops their ticket bleed
				var dist := center.distance_to(cp.global_position)
				var score := value / (1.0 + float(load.get(cp, 0)) * 0.9) - dist / 400.0
				if cp == sq.objective:
					score += 0.15  # stickiness: don't flip orders constantly
				if score > best_score:
					best_score = score
					best = cp
			sq.objective = best
			sq.order = &"defend" if best.owner_faction == f else &"attack"
			load[best] = int(load.get(best, 0)) + 1


func _squad_center(sq: Squad) -> Vector3:
	var c := Vector3.ZERO
	var n := 0
	for m in sq.members:
		if m.alive:
			c += m.global_position
			n += 1
	if n == 0:
		var pts := get_tree().get_nodes_in_group("spawn_%d" % sq.faction)
		return (pts[0] as Node3D).global_position if not pts.is_empty() else Vector3.ZERO
	return c / n


# ----------------------------------------------------------------------------- spatial queries
func _rebuild_grid() -> void:
	_grid_age = 0
	_grid.clear()
	for s in soldiers:
		if is_instance_valid(s) and s.alive:
			var k := _cell(s.global_position)
			if not _grid.has(k):
				_grid[k] = []
			_grid[k].append(s)


func _cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / GRID_CELL), floori(p.z / GRID_CELL))


## Living soldiers within radius of a point. faction = -1 for any.
func soldiers_near(p: Vector3, radius: float, faction: int = -1) -> Array[Soldier]:
	var out: Array[Soldier] = []
	var r := ceili(radius / GRID_CELL)
	var c := _cell(p)
	var r2 := radius * radius
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			for s: Soldier in _grid.get(c + Vector2i(dx, dz), []):
				if s.alive and (faction < 0 or s.faction == faction) and s.global_position.distance_squared_to(p) <= r2:
					out.append(s)
	return out


func _count_near(p: Vector3, radius: float, faction: int) -> int:
	return soldiers_near(p, radius, faction).size()


## The best enemy for `s` to fight: near, visible, preferring ones threatening its objective.
func find_target(s: Soldier, radius: float, objective_pos: Vector3) -> Soldier:
	var candidates := soldiers_near(s.global_position, radius, 1 - s.faction)
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(a: Soldier, b: Soldier) -> bool:
		return _target_score(s, a, objective_pos) < _target_score(s, b, objective_pos))
	# Only the best couple of candidates get a (relatively expensive) line-of-sight ray.
	for i in mini(candidates.size(), 3):
		if has_line_of_sight(s.head_position(), candidates[i].chest_position()):
			return candidates[i]
	return null


func _target_score(s: Soldier, t: Soldier, objective_pos: Vector3) -> float:
	var d := s.global_position.distance_to(t.global_position)
	var near_obj := t.global_position.distance_to(objective_pos) < 20.0
	return d - (6.0 if near_obj else 0.0) + (4.0 if t.is_player and not can_attack_player_now() else 0.0)


func has_line_of_sight(from: Vector3, to: Vector3) -> bool:
	stats.los_checks += 1
	var q := PhysicsRayQueryParameters3D.create(from, to, Soldier.LAYER_WORLD)
	return battle.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# ----------------------------------------------------------------------------- player attack tokens
func can_attack_player_now() -> bool:
	_player_attackers = _player_attackers.filter(func(a: AIController) -> bool:
		return is_instance_valid(a) and a.soldier.alive and a.target != null and a.target.is_player)
	return _player_attackers.size() < config.max_player_attackers


## An AI asks to fight the player in melee. Returns true if it may.
func request_player_attack(ai: AIController) -> bool:
	if _player_attackers.has(ai):
		return true
	if can_attack_player_now():
		_player_attackers.append(ai)
		return true
	return false


func release_player_attack(ai: AIController) -> void:
	_player_attackers.erase(ai)


func player_attacker_count() -> int:
	can_attack_player_now()
	return _player_attackers.size()


# ----------------------------------------------------------------------------- level of detail
func _update_lod(s: Soldier) -> void:
	var d := AudioManager.listener_position().distance_to(s.global_position)
	var interval := 0.0 if d < 25.0 else (1.0 / 30.0 if d < 60.0 else (1.0 / 15.0 if d < 120.0 else 1.0 / 8.0))
	s.visual.update_interval = interval
	# Physics LOD: out of sight-range and not fighting -> character controller at half rate.
	var fighting := s.controller is AIController and (s.controller as AIController).target != null and \
		(s.controller as AIController).target.global_position.distance_to(s.global_position) < 15.0
	s.half_rate_physics = d > 70.0 and not fighting
	var shadows := d < 70.0
	if s.visual.get_meta("shadows", true) != shadows:
		s.visual.set_meta("shadows", shadows)
		s.visual.set_cast_shadows(shadows)
