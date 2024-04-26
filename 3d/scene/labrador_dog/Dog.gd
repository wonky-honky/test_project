extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
func raycast_input(event):
	if event.is_action_pressed("click"):
		var ani: AnimationPlayer = get_node("/root/Node3D/Dog/AnimationPlayer");
		ani.play("Animation");
