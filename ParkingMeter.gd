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
#	print("actually caught collision in engine without manual raycast")
	raycast_input(event)

func raycast_input(event):
#	print("called input event on meter")
	print(event)
	if event.is_action("click"):
#		print(event)
		if event.is_action_pressed("click"):
			print("clicked parking meter")
			var cont: HBoxContainer = HBoxContainer.new()
			var wat: RichTextLabel = RichTextLabel.new();
			var butan: Button = Button.new();
			var butan2: Button = Button.new();
			var the_player: CharacterBody3D = get_node("/root/Node3D/Player");			
			butan.text = "Buy exit";
			butan.size.x = 800;
			butan.size.y = 600;
			butan.button_up.connect(func():
				var thebedroom: Node3D = get_node("/root/Node3D/TheBedroom");
				var outsido: Node3D = get_node("/root/Node3D/TheBedroom/OutsideBedroomCamera");
				the_player.transform.origin = outsido.get_global_transform().origin;;
				cont.queue_free();
				);
			butan2.text = "Buy exit with insurance";
			butan2.size.x = 800;
			butan2.size.y = 600;
			butan2.button_up.connect(func():
				var thebedroom: Node3D = get_node("/root/Node3D/TheBedroom");
				var outsido: Node3D = get_node("/root/Node3D/TheBedroom/OutsideBedroomCamera");
				var insurance: Node = find_child("Insurance");
				insurance.visible = true;
				var insurance_collider: CollisionShape3D = insurance.find_child("CollisionShape3D");
				insurance_collider.disabled = false;
				the_player.transform.origin = outsido.get_global_transform().origin;
				
				cont.queue_free();
				);
			cont.z_index = 1;
			cont.size_flags_horizontal = cont.SIZE_EXPAND_FILL;
			cont.size_flags_vertical = cont.SIZE_EXPAND_FILL;
			cont.set_anchors_preset(cont.PRESET_FULL_RECT)
			wat.set_anchors_preset(wat.PRESET_FULL_RECT);
			wat.size_flags_horizontal = wat.SIZE_EXPAND_FILL;
			wat.size_flags_vertical = wat.SIZE_EXPAND_FILL;
			wat.bbcode_enabled = true;
			wat.push_font_size(50)
			wat.append_text("Pay to exit your hovel?")
			wat.pop();
			cont.add_child(wat)
			cont.add_child(butan)
			cont.add_child(butan2)

			the_player.add_child(cont);
#			cont.show();
#			wat.show()
#			var fucking_container = the_player.find_child("CenterContainer");
#			fucking_container.add_child(wat);
			wat.push_font_size(50)
			wat.pop();
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE;
