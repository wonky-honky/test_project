extends Node3D

var start_transform;
#var extreme_transform;
var timer: Timer;
const PETTING_TIME = 2;
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	start_transform = transform;
#	extreme_transform = start_transform.translated(Vector3(0,200,0))
	timer = Timer.new();
	timer.one_shot = false;
	add_child(timer);
	var petting_callback = func(): if is_visible_in_tree():
		print("hand has become visible")
		timer.start(PETTING_TIME);
	else:
		timer.stop();
	visibility_changed.connect(petting_callback)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if !timer.is_stopped():
#		print("time left " + str(timer.time_left))
		transform.origin.y = lerpf(start_transform.origin.y,start_transform.origin.y + 1.0,(timer.time_left/PETTING_TIME))
#		print("new hand y " + str(transform.origin.y))
	pass
