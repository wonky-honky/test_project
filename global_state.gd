extends Node

var score = 0;
var high_score = 0;
var money = 300;
var deaths = 0;
var scores = {"Insured": 10};

func total_score() -> int:
	return scores.values().reduce(func(acc,s): if s > 0:
		return acc + s
		else:
			return acc);

		
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
