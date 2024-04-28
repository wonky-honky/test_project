extends AspectRatioContainer

var timer: Timer;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_process_mode(PROCESS_MODE_WHEN_PAUSED)
#	z_index = 1;
#	stretch_mode = AspectRatioContainer.STRETCH_COVER;
	set_anchors_preset(PRESET_FULL_RECT);
	offset_bottom = 0;
	offset_left = 0;
	offset_right = 0;
	offset_top = 0;
	size_flags_horizontal = Control.SIZE_EXPAND_FILL;
	size_flags_vertical = Control.SIZE_EXPAND_FILL;
	mouse_filter = Control.MOUSE_FILTER_STOP;
	timer = Timer.new();
	get_tree().paused = true;
	
#	gui_input.connect(eat_input);
#	set_process_input(true);
#	set_process_unhandled_input(true);
	add_child(timer);
#	var testo: PanelContainer = PanelContainer.new();
#	var testo: AspectRatioContainer = AspectRatioContainer.new();
#	add_child(testo);
#	testo.set_anchors_preset(Control.PRESET_BOTTOM_WIDE);
#	testo.mouse_filter = Control.MOUSE_FILTER_STOP;
	var texto: RichTextLabel = RichTextLabel.new();
#	texto.fit_content = true;
#	texto.set_anchors_preset(PRESET_FULL_RECT);
#	texto.offset_bottom = 0;
#	texto.offset_left = 0;
#	texto.offset_right = 0;
#	texto.offset_top = 0;
#	texto.set_anchor(SIDE_BOTTOM,0.4)
#	texto.set_anchor(SIDE_RIGHT,0.4)
#	texto.set_anchor(SIDE_LEFT,0.4)
	
#	texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL;
#	texto.size_flags_vertical = Control.SIZE_EXPAND_FILL;
	texto.bbcode_enabled = true;
	texto.push_font_size(150);
	texto.append_text("TEXTO");
	texto.pop();

	add_child(texto);
#	testo.add_child(texto);
	timer.one_shot = true;
	timer.start(10);
	timer.timeout.connect(func():
#		testo.queue_free();
		texto.queue_free();
		mouse_filter = Control.MOUSE_FILTER_IGNORE;
		get_tree().paused = false;
#		gui_input.disconnect(eat_input);
#		set_process_input(false);
#		testo.mouse_filter = Control.MOUSE_FILTER_IGNORE;
		);

# hmm this doesnt work
#func eat_input(event: InputEvent) -> void:
#	accept_event()
#func _input(event: InputEvent) -> void:
#	eat_input(event)
#func _unhandled_input(event: InputEvent) -> void:
#	eat_input(event)
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
		
