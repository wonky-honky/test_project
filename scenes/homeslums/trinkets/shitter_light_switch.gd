extends StaticBody3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
func _input_event(camera: Camera3D, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
		if event.is_action_released("click"):
			var the_shitter = get_node("/root/Node3D/Shitter");
			var question = "A switch.";
			var light_choice = Chorus.Choice.new();
			light_choice.label = "Flip it.";
			light_choice.choice_callback = func(_args):
				var darkness = the_shitter.find_child("GroovyDarkness");
				darkness.visible = not darkness.visible;
			Chorus.choice(question,[light_choice]);
