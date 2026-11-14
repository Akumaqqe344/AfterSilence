# Third-party source integration — 0.11.0

## Beehave

https://github.com/bitbrain/beehave

Pinned revision: fe589153fa780a3f88989578ceb5f539afffb7c2 (godot-4.x).
MIT license retained in `addons/beehave/LICENSE`.

Used at runtime: `SelectorComposite`, `ActionLeaf`, `Blackboard` dispatch the
boss's windup, attack and exposed phases. Game adapter:
`after_silence/core/boss_phase_leaf.gd`. Both archive bosses use it.

Local upstream change: `debug/debugger_messages.gd` checks
`EngineDebugger.is_active()` before sending debugger messages, preventing errors
in standalone headless tests launched with the editor binary.

## NPC TalkKit

https://github.com/vanquyt-games/npc-talkkit

Pinned revision: ea7f04f158dbcb40bcfd30f32c62fd263a34e487.
MIT license retained in `addons/npc_talkkit/LICENSE`.

Used at runtime: Nadia's “About tomorrow” conversation. Its blocking event opens
an After Silence choice panel. The game owns relationship changes and save flags.
Wood texture, pixel font and portrait are game assets. Voice blips are off.
Upstream source is unmodified. Adapter: `world/talkkit_pilot.gd`.

## Architectural references, no copied source

NPC Routine Scheduler, Godot State Charts, CodingQuests dialogue/quest,
inventory and save examples, windeko quest system, Popochiu, Town Demo,
Ali0600 RPG Template and Fantail Camera informed the design tasks. New
JSON schedules, objectives, inventory/storage and checkpoints are native
After Silence implementations.

LimboAI was an alternative to Beehave and is not installed. Dialogic and Yarn
Spinner runtimes are not installed. The existing cutscene director and dialogue
layer remain responsible for the campaign; no complete framework migration has
been performed. No third-party demo artwork was copied.
