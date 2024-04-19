extends Toot

var elapsed = 0;
# Called when the node enters the scene tree for the first time.
func _ready():
	#super.toot();
	super.load_song();
	

		
		

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	elapsed += delta;
	var i = int(elapsed);
	#var rng = RandomNumberGenerator.new();
	#var i = rng.randi_range(1,3);
	if i % 2 == 0:
		super.play_note(Toot.ShittyNote.E);
	elif i % 3 == 0:
		super.play_note(Toot.ShittyNote.G);
	else:
		super.play_note(Toot.ShittyNote.C)
