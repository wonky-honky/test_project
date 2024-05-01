extends StaticBody3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var insurance: Node = find_child("Insurance");
	insurance.visible = false;
	var insurance_collider: CollisionShape3D = insurance.find_child("CollisionShape3D");
	insurance_collider.disabled = true;
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _input_event(camera: Camera3D, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	raycast_input(event)

func raycast_input(event):
	if event.is_action_released("click"):
		print("clicked parking meter")
		var the_player: CharacterBody3D = get_node("/root/Node3D/Player");
		var outsido: Node3D = get_node("/root/Node3D/TheBedroom/OutsideBedroomCamera")
		var chorus = get_node("/root/Chorus");
		var question = "The exit toll machine of this unit.";
		var buy_exit = chorus.Choice.new();
		buy_exit.label = "Insert money into the Exit slot.";
		buy_exit.choice_callback = func(_args):
			the_player.transform.origin = outsido.get_global_transform().origin;;
		var buy_insured = chorus.Choice.new();
		buy_insured.label = "Insert money into the Exit With Insurance slot.";
		buy_insured.choice_callback = func(_args):
			var insurance: Node = find_child("Insurance");
			insurance.visible = true;
			var insurance_collider: CollisionShape3D = insurance.find_child("CollisionShape3D");
			insurance_collider.disabled = false;
			the_player.transform.origin = outsido.get_global_transform().origin;
		chorus.choice(question, [buy_exit,buy_insured],true);
