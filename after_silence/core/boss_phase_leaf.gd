extends ActionLeaf
var phase_name="windup"
func tick(actor: Node, blackboard: Blackboard) -> int:
	if actor.phase!=phase_name: return FAILURE
	actor.tick_phase(float(blackboard.get_value("dt",0.0)))
	return SUCCESS
