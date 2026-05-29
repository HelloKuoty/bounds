extends Node
## Global signal hub. Decouples systems.
##
## (Builder note: this IS the "domain event" backbone — the architecture mirrors
## the very ideas the game embodies. But that pun stays between us; nothing here
## leaks to the player.)
##
## Signals are declared only as the code that emits them lands — no empty
## placeholders for unbuilt mechanics. See TASKS.md for the planned additions.

# Board / territory signals live on BoardState itself (it's a self-contained
# model). A controller connects to a board and relays what the rest of the app
# needs. EventBus carries only run-wide and UI concerns.

# --- Run / meta scope ---
signal run_started()
signal node_entered(node_id: String, type: String)
signal run_ended(outcome: String)  # "victory" | "defeat"

# --- UI / system ---
signal toast(message: String, level: String)  # "info" | "warn" | "error"


func _ready() -> void:
	# Sanity print so we know the autoload is alive in headless runs.
	print("[EventBus] ready")
