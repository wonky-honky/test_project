extends StaticBody3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass  # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func raycast_input(event):
	print("called input event on meter")
	print(event)
	if event.is_action("click"):
#		print(event)
		if event.is_action_pressed("click"):
			print("clicked parking meter")
			var cont: HBoxContainer = HBoxContainer.new()
			var wat: RichTextLabel = RichTextLabel.new();
			cont.z_index = 1;
			cont.size_flags_horizontal = cont.SIZE_EXPAND_FILL;
			cont.size_flags_vertical = cont.SIZE_EXPAND_FILL;
			cont.set_anchors_preset(cont.PRESET_FULL_RECT)
			wat.set_anchors_preset(wat.PRESET_FULL_RECT);
			wat.size_flags_horizontal = wat.SIZE_EXPAND_FILL;
			wat.size_flags_vertical = wat.SIZE_EXPAND_FILL;
			wat.bbcode_enabled = true;
			wat.push_font_size(50)
			wat.append_text("fuck you")
			wat.pop();
			cont.add_child(wat)
			
			var the_player: CharacterBody3D = get_node("/root/Node3D/Player");
			the_player.add_child(cont);
#			cont.show();
#			wat.show()
#			var fucking_container = the_player.find_child("CenterContainer");
#			fucking_container.add_child(wat);
			wat.push_font_size(50)
			wat.append_text("now?")
			wat.pop();
