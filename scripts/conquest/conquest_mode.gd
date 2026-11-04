class_name ConquestMode
extends Node
## Conquest rules (all numbers in BattleConfig):
##   * Soldiers inside a point move its progress toward their side; more soldiers capture faster
##     (up to a cap). Any enemy presence contests it (no progress).
##   * An enemy-held point must first be neutralised (progress back to 0, at double speed),
##     then captured.
##   * Every death costs that side one ticket. The side holding fewer points bleeds tickets.
##   * A side at zero tickets loses.
## Audio cues follow the player's side: captured / lost / contested / capture ticks / low tickets.

signal match_over(winner: int)

const UPDATE_STEP := 0.1

var battle: Node
var config: BattleConfig
var points: Array[CapturePoint] = []
var tickets: Array[float] = [0.0, 0.0]
var player_faction := 0
var over := false
var winner := -1
var warned := [false, false]

var _accum := 0.0


func setup(b: Node, cfg: BattleConfig, objectives: Array[CapturePoint], player_side: int) -> void:
	battle = b
	config = cfg
	points = objectives
	player_faction = player_side
	tickets = [float(cfg.starting_tickets), float(cfg.starting_tickets)]
	Events.soldier_killed.connect(_on_soldier_killed)
	for cp in points:
		cp.owner_changed.connect(_on_owner_changed)


func ticket_count(faction: int) -> int:
	return maxi(0, ceili(tickets[faction]))


func owned_by(faction: int) -> int:
	var n := 0
	for cp in points:
		if cp.owner_faction == faction:
			n += 1
	return n


func _physics_process(delta: float) -> void:
	if over:
		return
	_accum += delta
	while _accum >= UPDATE_STEP:
		_accum -= UPDATE_STEP
		_step(UPDATE_STEP)


func _step(dt: float) -> void:
	for cp in points:
		_update_point(cp, dt)
	# Ticket bleed: the side holding fewer points loses tickets over time.
	var diff := owned_by(0) - owned_by(1)
	if diff != 0:
		var loser := 1 if diff > 0 else 0
		_spend(loser, absf(diff) * config.bleed_per_point * dt)


func _update_point(cp: CapturePoint, dt: float) -> void:
	var counts := cp.soldiers_inside()
	var was_contested := cp.contested
	cp.contested = counts[0] > 0 and counts[1] > 0
	var player_inside := _player_inside(cp)
	if cp.contested:
		if player_inside and not was_contested:
			AudioManager.play(&"objective_contested")
		return
	var f := 0 if counts[0] > 0 else (1 if counts[1] > 0 else -1)
	var before := cp.progress
	if f >= 0:
		var n: int = counts[f]
		var mult := minf(1.0 + config.capture_bonus_per_soldier * (n - 1), config.capture_max_multiplier)
		var dir := 1.0 if f == 0 else -1.0
		if dir * cp.progress < 0.0:
			mult *= 2.0  # tearing down the enemy's hold is quicker than raising your own
		cp.progress = clampf(cp.progress + dir * mult * dt / config.capture_time, -1.0, 1.0)
		# An enemy-held point is neutralised when its progress reaches zero...
		if cp.owner_faction == 1 - f and before * cp.progress <= 0.0:
			cp.set_owner_faction(CapturePoint.NEUTRAL)
		# ...and captured when it reaches full on this side.
		if dir * cp.progress >= 1.0 and cp.owner_faction != f:
			cp.set_owner_faction(f)
		if player_inside and f == player_faction and absf(cp.progress - before) > 0.0 and cp.owner_faction != f:
			AudioManager.play(&"capture_tick")
	else:
		# Empty point: drifts back to its owner's full colour, or to neutral if nobody owns it.
		var rest := 0.0 if cp.owner_faction == CapturePoint.NEUTRAL else (1.0 if cp.owner_faction == 0 else -1.0)
		cp.progress = move_toward(cp.progress, rest, dt / (config.capture_time * 2.0))
	if cp.progress != before:
		Events.objective_changed.emit(cp)


func _player_inside(cp: CapturePoint) -> bool:
	var p: Soldier = battle.player if battle else null
	return p != null and p.alive and p.global_position.distance_to(cp.global_position) < cp.radius


func _on_owner_changed(cp: CapturePoint, new_owner: int, old_owner: int) -> void:
	Events.objective_changed.emit(cp)
	if new_owner >= 0:
		Events.objective_captured.emit(cp, new_owner)
		if new_owner == player_faction:
			AudioManager.play(&"objective_captured")
	if old_owner == player_faction and new_owner != player_faction:
		AudioManager.play(&"objective_lost")


func _on_soldier_killed(victim: Node, _killer: Node) -> void:
	if victim is Soldier and not over:
		_spend((victim as Soldier).faction, 1.0)


func _spend(faction: int, amount: float) -> void:
	if over:
		return
	var before := ticket_count(faction)
	tickets[faction] = maxf(0.0, tickets[faction] - amount)
	var after := ticket_count(faction)
	if after != before:
		Events.tickets_changed.emit(faction, after)
	if faction == player_faction and not warned[faction] and after <= config.ticket_warning_at:
		warned[faction] = true
		AudioManager.play(&"ticket_warning")
	if after <= 0:
		_end(1 - faction)


func _end(win: int) -> void:
	over = true
	winner = win
	Events.match_ended.emit(win)
	match_over.emit(win)


## Respawn transform near a point the faction holds that has no enemies on it, or null.
func forward_spawn(faction: int) -> Variant:
	var options: Array[CapturePoint] = []
	for cp in points:
		if cp.owner_faction == faction and not cp.contested and cp.soldiers_inside()[1 - faction] == 0:
			options.append(cp)
	if options.is_empty():
		return null
	var cp: CapturePoint = options[randi() % options.size()]
	var a := randf() * TAU
	var pos := cp.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(4.0, cp.radius - 2.0)
	return pos
