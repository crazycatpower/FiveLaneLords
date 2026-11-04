extends "res://battle.gd"
# Experimental policy only. Production Battle/AI are unchanged.
var economy_goals: Array = [6,6]
var max_per_lane: Array = [99,99]

func snapshot(team: int) -> Dictionary:
	var state := super.snapshot(team)
	var home: String = B.home_card(lords[team].lord)
	var total_count := count_buildings(team,home)
	state.candidates = state.candidates.filter(func(c: Dictionary) -> bool:
		if c.kind != home: return true
		var existing := building_at(c.cell)
		if not existing.is_empty() and existing.team == team and existing.kind == home:
			return true # repair/refresh is always allowed
		if total_count >= economy_goals[team]:
			return false
		var lane: int = c.cell.y
		var in_lane := 0
		for b: Dictionary in buildings:
			if b.hp > 0 and b.team == team and b.kind == home and b.cell.y == lane:
				in_lane += 1
		if in_lane >= max_per_lane[team]:
			return false
		return true)
	return state
