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
const JUMP_VELOCITY = 50.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var mouse_sensitivity = 0.01
# https://github.com/godotengine/godot/issues/29727 amazing

func _ready():
	var p = self;
	p.set_physics_process(false);
	p.set_process_input(false);
	p.set_process_unhandled_input(false);
	# grab this from a child node I guess so that I only need one player.gd for all scenes
	var start_cam: Camera3D = get_node("/root/Node3D/TheBedroom/WakeupCamera");
	var player_cam: Camera3D = p.find_child("Camera3D");
	start_cam.make_current();
	var t: Timer = Timer.new();
	add_child(t);
	t.one_shot = true;
	t.timeout.connect(func():
		Fade.fade_out(1);
		Fade.fade_in(5).finished.connect(func():
			player_cam.make_current();
			p.set_physics_process(true);
			p.set_process_input(true);
			p.set_process_unhandled_input(true);
			t.queue_free();
			);
		)
	t.start(0.017);


func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
# https://github.com/godotengine/godot/issues/29727 amazing
	elif event.is_action_pressed("click"):
#		print("still eating the fucking mouse click")
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
## https://github.com/godotengine/godot/issues/29727 fucking amazing
#		else:
#			var thecamera = get_viewport().get_camera_3d();
#			var space = get_world_3d().direct_space_state
 #			var query = PhysicsRayQueryParameters3D.create(thecamera.global_position,
  #          thecamera.global_position - thecamera.global_transform.basis.z * 100)
#			var collision = space.intersect_ray(query)
#			if collision and collision.collider.has_method("raycast_input"):
#				collision.collider.raycast_input(event)
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var thecamera = get_viewport().get_camera_3d();
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		thecamera.rotate_x(-event.relative.y * mouse_sensitivity)
		thecamera.rotation.x = clampf(thecamera.rotation.x, -deg_to_rad(70), deg_to_rad(70))
	elif event.is_action_released("suicide"):
		var gs = get_node("/root/GlobalState");
		gs.score += 10;
		Chorus.game_over("You take a moment to reflect on yourself, on the state of the world and on your position and role in it. Something smells like it's burning. You think you have just gained one thousand points. An euphoric feeling envelops you. Your vision fades.");

func _physics_process(delta: float) -> void:

	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta
		print_debug("falling at " + str(velocity.y));
		if velocity.y < - 100.0 :
			Fade.fade_out(1,Color.RED);
			Fade.fade_in(1,Color.RED);
			Chorus.game_over("You have fallen to your death.");
		
	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("strafe_left", "strafe_right", "fwd", "bck")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
