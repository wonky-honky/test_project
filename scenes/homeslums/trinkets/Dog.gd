extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _input_event(camera: Camera3D, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
#	print("actually caught collision in engine without manual raycast")
	raycast_input(event)

func raycast_input(event):
	if event.is_action_pressed("click"):
		var ani: AnimationMixer = get_node("/root/Node3D/Dog/AnimationPlayer");
		var petting_hand: Node3D = get_node("/root/Node3D/HandPetting");
		petting_hand.visible = true;
		
		ani.play("Animation");
		ani.animation_finished.connect(func(_ignore): petting_hand.visible = false);
