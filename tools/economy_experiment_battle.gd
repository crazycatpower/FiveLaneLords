extends "res://battle.gd"
# Experimental policy only. Production Battle/AI are unchanged.
var economy_goals: Array = [6,6]
func snapshot(team: int) -> Dictionary:
	var state := super.snapshot(team)
	var home: String = B.home_card(lords[team].lord)
	if count_buildings(team,home) >= economy_goals[team]:
		state.candidates = state.candidates.filter(func(c: Dictionary) -> bool:
			if c.kind != home: return true
			var existing := building_at(c.cell)
			return not existing.is_empty() and existing.team == team and existing.kind == home)
	return state
