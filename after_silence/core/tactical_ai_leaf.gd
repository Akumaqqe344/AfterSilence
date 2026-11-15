extends ActionLeaf
var action_kind="end"
func tick(actor: Node,_blackboard: Blackboard) -> int:
	var command=actor.board.plan(actor.board.active_id(),action_kind)
	if command.is_empty(): return FAILURE
	actor.perform(command.kind,command.get("target"))
	return SUCCESS
