extends Toot

var elapsed = 0;
# Called when the node enters the scene tree for the first time.
func _ready():
	#super.toot();
	super.load_song();
	

		
		

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
#	elapsed += delta;
#	var i = int(elapsed);
#	var since_last_sec = int(elapsed * 1000) % 1000;
#	if (0 <= since_last_sec) and (since_last_sec <= 16):
#		if i % 2 == 0:	
#			super.play_note(Toot.ShittyNote.E);
#		elif i % 3 == 0:
#			super.play_note(Toot.ShittyNote.G);
#		else:
#			super.play_note(Toot.ShittyNote.C)
#	else:
#		super.depress_note(Toot.C);
#		super.depress_note(Toot.G);
#		super.depress_note(Toot.E);
