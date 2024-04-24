extends StaticBody3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func raycast_input(event):
	print("called input event on meter")
	print(event)
	if event.is_action("click"):
#		print(event)
		if event.is_action_pressed("click"):
			print("clicked parking meter");
