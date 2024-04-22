extends PianoParasite

# Called when the node enters the scene tree for the first time.
func _ready():
	setKeyMap({ "#INT0001_A1": "A0", "#INT0001_A2": "A1", "#INT0001_A3": "A2", "#INT0001_A4": "A3", "#INT0001_A5": "A4", "#INT0001_A6": "A5", "#INT0001_A7": "A6", "#INT0001_A8": "A7", "#INT0001_B1": "H0", "#INT0001_B2": "H1", "#INT0001_B3": "H2", "#INT0001_B4": "H3", "#INT0001_B5": "H4", "#INT0001_B6": "H5", "#INT0001_B7": "H6", "#INT0001_B8": "H7", "#INT0001_C1": "C1", "#INT0001_C2": "C2", "#INT0001_C3": "C3", "#INT0001_C4": "C4", "#INT0001_C5": "C5", "#INT0001_C6": "C6", "#INT0001_C7": "C7", "#INT0001_C8": "C8", "#INT0001_D1": "D1", "#INT0001_D2": "D2", "#INT0001_D3": "D3", "#INT0001_D4": "D4", "#INT0001_D5": "D5", "#INT0001_D6": "D6", "#INT0001_D7": "D7", "#INT0001_E1": "E1", "#INT0001_E2": "E2", "#INT0001_E3": "E3", "#INT0001_E4": "E4", "#INT0001_E5": "E5", "#INT0001_E6": "E6", "#INT0001_E7": "E7", "#INT0001_Ebony_01": "B0", "#INT0001_Ebony_02": "Cis1", "#INT0001_Ebony_03": "Es1", "#INT0001_Ebony_04": "Fis1", "#INT0001_Ebony_05": "As1", "#INT0001_Ebony_06": "B1", "#INT0001_Ebony_07": "Cis2", "#INT0001_Ebony_08": "Es2", "#INT0001_Ebony_09": "Fis2", "#INT0001_Ebony_10": "As2", "#INT0001_Ebony_11": "B2", "#INT0001_Ebony_12": "Cis3", "#INT0001_Ebony_13": "Es3", "#INT0001_Ebony_14": "Fis3", "#INT0001_Ebony_15": "As3", "#INT0001_Ebony_16": "B3", "#INT0001_Ebony_17": "Cis4", "#INT0001_Ebony_18": "Es4", "#INT0001_Ebony_19": "Fis4", "#INT0001_Ebony_20": "As4", "#INT0001_Ebony_21": "B4", "#INT0001_Ebony_22": "Cis5", "#INT0001_Ebony_23": "Es5", "#INT0001_Ebony_24": "Fis5", "#INT0001_Ebony_25": "As5", "#INT0001_Ebony_26": "B5", "#INT0001_Ebony_27": "Cis6", "#INT0001_Ebony_28": "Es6", "#INT0001_Ebony_29": "Fis6", "#INT0001_Ebony_30": "As6", "#INT0001_Ebony_31": "B6", "#INT0001_Ebony_32": "Cis7", "#INT0001_Ebony_33": "Es7", "#INT0001_Ebony_34": "Fis7", "#INT0001_Ebony_35": "As7", "#INT0001_Ebony_36": "B7", "#INT0001_F1": "F1", "#INT0001_F2": "F2", "#INT0001_F3": "F3", "#INT0001_F4": "F4", "#INT0001_F5": "F5", "#INT0001_F6": "F6", "#INT0001_F7": "F7", "#INT0001_G1": "G1", "#INT0001_G2": "G2", "#INT0001_G3": "G3", "#INT0001_G4": "G4", "#INT0001_G5": "G5", "#INT0001_G6": "G6", "#INT0001_G7": "G7" });
	for k in key_map.keys():
		var key: MeshInstance3D = find_child(k);
		var col: CollisionObject3D = key.find_child("StaticBody3D");
		if col == null:
			continue;
		var handle_key_input = func(camera, event, position, normal, shape_idx):
			if event is InputEventMouseButton and event.pressed and event.button_index == 1:
				print(k);
				key.rotate_x(PI/2);
				Tooting.play_note_anglo(key_map[k]);
		col.input_event.connect(handle_key_input);

# it would have probably been wiser to just write this mapping out manually but this is how to reproduce it:
#	var ok = getKeyMap()
#	var c = get_children()
#	var real_root = c[0];
#	var ebonies = ["B","Cis","Es","Fis","As"];
#	var final_map = {};
#	for chi in real_root.get_children():
#		var s = chi.name.split("_",false);
#		if s.size() > 2:
#			final_map[chi.name] = ebonies[(int(s[-1]) - 1) % 5] + str((int(s[-1]) - 1)/5 + 1);
#			if final_map[chi.name].begins_with("B"):
#				final_map[chi.name][1] = str(int(final_map[chi.name][1]) - 1);
#		else:
#			final_map[chi.name] = s[-1].replace("B","H");
#			if final_map[chi.name].begins_with("H") or final_map[chi.name].begins_with("A"):
#				final_map[chi.name][1] = str(int(final_map[chi.name][1]) - 1);
#	ok.merge(final_map);
#	print(ok);

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
