extends StaticBody3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _input_event(camera: Camera3D, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event.is_action_released("click"):
		var the_player: CharacterBody3D = get_node("/root/Node3D/Player");
		var the_shitter = get_node("/root/Node3D/Shitter");
		var question = "An unlocked hatch.";

		var descend_choice = Chorus.Choice.new();
		descend_choice.label = "Descend.";
		descend_choice.choice_callback = func(_args):
			the_shitter.find_child("GroovyDarkness").visible = true;

			the_player.transform.origin = the_shitter.find_child("Camera3D").get_global_transform().origin;
		Chorus.choice(question,[descend_choice]);
		
