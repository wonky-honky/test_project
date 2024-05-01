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
	var choice_callback: Callable = func(_args):;
	

func choice(question, choices: Array = [], cancellable = true):
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE;
	pause();
	var cont: GridContainer = GridContainer.new()
	cont.columns = 2;
	var q;
# RichTextLabel in a container with other things is fundamentally deeply and profoundly fucked in ways beyond a human being's understanding. Do you want 1px width ? Should 1px width even be possible ? Not according to the documentation! The fucking buttons and switches and options might have names and descriptions that claim to explain what they do, but they don't. It's a fucking random number generator for mangling the label itself and everything else that is unfortunate enough to be situated in the same container. It 100% honest to god takes less time to develop your own fucking scalable/proportional grid/flow/whatever UI with formatting and custom effects in fucking C++ or even rust than it does trying to wrangle this incomprehensible piece of actual dog shit to do anything resembling what you intended. KEEP OUT and FUCK this thing.
# it probably has something to do with the implicit vscroll because that fucks everything up in similar spectacular ways on its own
#	if question is RichTextLabel:
#		print(question.text);
#		q = question;
#		cont.add_child(q);
#	else:
	q = Label.new();
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER;
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;
	q.autowrap_mode = TextServer.AUTOWRAP_WORD;
	q.size_flags_horizontal = Control.SIZE_EXPAND_FILL;
	q.size_flags_vertical = Control.SIZE_EXPAND_FILL;
	
	if question is String:
		print("adding string: " + question)
		q.text = question;
	else:
		print("adding whatever this is as string: " + str(question))
		q.text = str(question)
	cont.add_child(q);
	cont.tree_exited.connect(func():
		mouse_filter = Control.MOUSE_FILTER_IGNORE;
		var t = get_tree();
		if t:
			t.paused = false;)
	for c: Choice in choices:
		var butan: Button = Button.new();
		butan.autowrap_mode = TextServer.AUTOWRAP_WORD;
		butan.size_flags_horizontal = Control.SIZE_EXPAND_FILL;
		butan.text = c.label;
		butan.button_up.connect(func():
			c.choice_callback.call(c.choice_callback_args);
			cont.queue_free();)
		cont.add_child(butan)
	if cancellable:
		var cancel_b: Button = Button.new();
		cancel_b.autowrap_mode = TextServer.AUTOWRAP_WORD;
		cancel_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL;
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
	testo();
#	splash("testomatic");

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
		
func testo():
	var question = "Very long text blog blog blog Very long text unbroken blog blog blog Very long text unbroken blog blog blog Very long text unbroken blog blog blog Very long text unbroken blog blog blog Very long text unbroken blog blog blog Very long text unbroken blog blog blog Very long text unbroken blog blog blog Very long text unbroken blog blog blog Very long text unbroken blog blog blog Very long text unbroken blog blog blog Very long text unbroken blog blog blog Very long text unbroken blog blog blog Very long text unbroken blog blog blog Very long text unbroken blog blog blog
	Very long text blog blog blog
	Very long text blog blog blog
	Very long text blog blog blog
	Very long text blog blog blog
	Very long text blog blog blog
	Very long text blog blog blog
	Very long text blog blog blog
	Very long text blog blog blog";
	var butan1 = Choice.new();
	var butan2 = Choice.new();
	butan1.label = "Very long text blog blog blog
	Very long text blog blog blog
	Very long text blog blog blog
	Very long text blog blog blog
	Very long text blog blog blog
	Very long text blog blog blog
	Very long text blog blog blog
	Very long text blog blog blog
	Very long text blog blog blog";
	butan2.label = "Very long text unbroken blog blog blog Very long text unbroken blog blog blog Very long text unbroken blog blog blog Very long text unbroken blog blog blog Very long text unbroken blog blog blog Very long text unbroken blog blog blog Very long text unbroken blog blog blog Very long text unbroken blog blog blog Very long text unbroken blog blog blog Very long text unbroken blog blog blog Very long text unbroken blog blog blog Very long text unbroken blog blog blog Very long text unbroken blog blog blog Very long text unbroken blog blog blog ";
	choice(question, [butan1,butan2],true);
