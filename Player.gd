extends CharacterBody3D


#		pass
#func _input(event):
#	if event is InputEventMouseMotion:
#		rotate_y(deg_to_rad(-event.relative.x*mouse_sens))
#		var changev=-event.relative.y*mouse_sens
#		if camera_anglev+changev>-50 and camera_anglev+changev<50:
#			camera_anglev+=changev
#			rotate_x(deg_to_rad(changev))

const SPEED = 50.0
const JUMP_VELOCITY = 45.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var mouse_sensitivity = 0.01
# https://github.com/godotengine/godot/issues/29727 amazing
func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
# https://github.com/godotengine/godot/issues/29727 amazing
	if event.is_action_pressed("click"):
#		print("still eating the fucking mouse click")
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
# https://github.com/godotengine/godot/issues/29727 fucking amazing
		else:
			var thecamera = get_viewport().get_camera_3d();
			var space = get_world_3d().direct_space_state
			var query = PhysicsRayQueryParameters3D.create(thecamera.global_position,
            thecamera.global_position - thecamera.global_transform.basis.z * 100)
			var collision = space.intersect_ray(query)
			if collision and collision.collider.has_method("raycast_input"):
				collision.collider.raycast_input(event)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var thecamera = get_viewport().get_camera_3d();
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		thecamera.rotate_x(-event.relative.y * mouse_sensitivity)
		thecamera.rotation.x = clampf(thecamera.rotation.x, -deg_to_rad(70), deg_to_rad(70))


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
