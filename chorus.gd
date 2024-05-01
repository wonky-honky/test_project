extends AspectRatioContainer

var timer: Timer;

func fit_screen(c: Control):
	c.set_anchors_preset(PRESET_FULL_RECT);
	c.offset_bottom = 0;
	c.offset_left = 0;
	c.offset_right = 0;
	c.offset_top = 0;
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL;
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL;

func pause(timed = false,seconds = 3, cleanup_args = [],cleanup: Callable = func(_args):) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP;
	get_tree().paused = true;
	if timed:
		timer.one_shot = true;
		timer.start(seconds);
	timer.timeout.connect(func():
		cleanup.call(cleanup_args);
		mouse_filter = Control.MOUSE_FILTER_IGNORE;
		get_tree().paused = false;
		);

class Choice:
	var label;
	var choice_callback_args: Array;
	var choice_callback: Callable;
	

func choice(question, choices: Array = [], cancellable = true):
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE;
	pause();
	var cont: HBoxContainer = HBoxContainer.new()
	var q;
#	var dogshit_labels: Label = Label.new();
	if question is RichTextLabel:
		print(question.text);
		q = question;
		cont.add_child(q);
	else:
		q = Label.new();
		cont.add_child(q);
		if question is String:
			print("adding string: " + question)
			q.text = question;
		else:
			print("adding whatever this is as string: " + str(question))
			q.text = str(question)
	cont.size_flags_horizontal = cont.SIZE_EXPAND_FILL;
	cont.size_flags_vertical = cont.SIZE_EXPAND_FILL;
	cont.set_anchors_preset(cont.PRESET_FULL_RECT)

	cont.tree_exited.connect(func():
		mouse_filter = Control.MOUSE_FILTER_IGNORE;
		var t = get_tree();
		if t:
			t.paused = false;)
	for c: Choice in choices:
		var butan: Button = Button.new();
		butan.text = c.label;
		butan.button_up.connect(func():
			c.choice_callback.call(c.choice_callback_args);
			cont.queue_free();)
		cont.add_child(butan)
	if cancellable:
		var cancel_b: Button = Button.new();
		cancel_b.text = "Do nothing.";
		cancel_b.button_up.connect(func(): cont.queue_free())
		cont.add_child(cancel_b);
	add_child(cont);
	
func splash(text: String):
	var texto: RichTextLabel = RichTextLabel.new();
	fit_screen(texto);
	texto.bbcode_enabled = true;
	texto.push_font_size(150);
	texto.append_text(text);
	texto.pop();
	add_child(texto);
	pause(true,3,[texto],func(args): args[0].queue_free());

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	fit_screen(self);
	set_process_mode(PROCESS_MODE_WHEN_PAUSED)
	timer = Timer.new();
	add_child(timer);
	splash("testomatic");

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
		
