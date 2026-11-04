class_name Squad
extends RefCounted
## A handful of AI soldiers that share an objective order (attack or defend a capture point).

var id := 0
var faction := 0
var members: Array[Soldier] = []
var objective: CapturePoint
## &"attack" (take the point) or &"defend" (hold the point)
var order: StringName = &"attack"


func living() -> int:
	var n := 0
	for m in members:
		if m.alive:
			n += 1
	return n


## A spot for member `index` around the objective, so a squad spreads out instead of stacking.
func slot_for(member: Soldier) -> Vector3:
	if objective == null:
		return member.global_position
	var i := members.find(member)
	var ring := 3.0 + 2.5 * float(i % 3) + float(id % 3)
	var a := float(id) * 1.7 + float(i) * TAU / maxf(members.size(), 1)
	return objective.global_position + Vector3(cos(a), 0.0, sin(a)) * minf(ring, objective.radius - 2.0)
