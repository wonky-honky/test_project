extends DirectionalLight3D

var when_darkness_modified = [toilet_door_when_dark]
func toilet_door_when_dark():
		var the_shitter = get_node("/root/Node3D/Shitter");
		var s_door = the_shitter.find_child("ShitterDoorInside");
		if visible:
			s_door.process_mode = Node.PROCESS_MODE_DISABLED;
		else:
			s_door.process_mode = Node.PROCESS_MODE_INHERIT;
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visibility_changed.connect(func():
		for f in when_darkness_modified:
			f.apply();
		);

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
