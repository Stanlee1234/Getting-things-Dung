extends Node2D

@onready var voice_player: AudioStreamPlayer2D = $VoicePlayer
@onready var subtitle_label: Label = $UI/SubtitleLabel
@onready var skip_label: Label = $UI/SkipLabel
@onready var beetle = $Beetle
@onready var control_bubble = get_node_or_null("LevelControls")
@onready var music_player: AudioStreamPlayer = get_node_or_null("MusicPlayer")

var jump_controls: Node2D = null
var ball_controls: Node2D = null

# Preload voice audio files
const INTRO_VOICE = preload("res://Assets/voicelines/introvoiceline1.mp3")
const INTRO_VOICE_2 = preload("res://Assets/voicelines/introvoiceline2.mp3")
const INTRO_VOICE_3 = preload("res://Assets/voicelines/introvoiceline3.mp3")
const INTRO_VOICE_4 = preload("res://Assets/voicelines/introvoiceline4.mp3")
const END_VOICE_1 = preload("res://Assets/voicelines/endvoiceline1.mp3")
const END_SCREEN_SCENE = "res://Scenes/end_screen.tscn"

# Preloads for dynamic fallback instantiation
const CONTROL_BUBBLE_SCRIPT = preload("res://Scripts/control_bubble.gd")
const SPEAR_LAUNCHER_SCENE = preload("res://Scenes/spear_launcher.tscn")
const CEO_DESK_SCENE = preload("res://Scenes/ceo_desk.tscn")

const DROP_VOICES = [
	{
		"stream": preload("res://Assets/voicelines/dropvoiceline1.mp3"),
		"captions": [
			{"time": 0.0, "text": "Almost had it that time."},
			{"time": 2.2, "text": "And by almost, I mean you weren't even close..."},
			{"time": 5.2, "text": "...and now your ball's in the basement."}
		]
	},
	{
		"stream": preload("res://Assets/voicelines/dropvoiceline2.mp3"),
		"captions": [
			{"time": 0.0, "text": "There she goes."},
			{"time": 1.4, "text": "All that huffing and puffing gone in three seconds."}
		]
	},
	{
		"stream": preload("res://Assets/voicelines/dropvoiceline3.mp3"),
		"captions": [
			{"time": 0.0, "text": "Look at the bright side, son."},
			{"time": 2.4, "text": "Walking all the way back down is way faster than pushing it up."}
		]
	},
	{
		"stream": preload("res://Assets/voicelines/dropvoiceline4.mp3"),
		"captions": [
			{"time": 0.0, "text": "Don't look at me like that."},
			{"time": 1.7, "text": "I'm just the guy on the intercom."},
			{"time": 3.8, "text": "You're the one who kicked it."}
		]
	}
]

# Timed captions: text changes at playback timestamps (in seconds)
var current_captions: Array = []
var is_intro_playing: bool = false
var ledge_voiceline_played: bool = false
var ball_voiceline_played: bool = false
var worm_voiceline_played: bool = false
var ceo_ending_triggered: bool = false
var is_ending: bool = false

var pending_voice_stream: AudioStream = null
var pending_voice_captions: Array = []

var available_drop_indices: Array[int] = []
var last_drop_time: float = -999.0
const DROP_COOLDOWN: float = 7.0

func _ready() -> void:
	# 0. Start looping background music on repeat
	if is_instance_valid(music_player):
		music_player.process_mode = Node.PROCESS_MODE_ALWAYS
		if not music_player.finished.is_connected(_on_music_finished):
			music_player.finished.connect(_on_music_finished)
		if not music_player.playing:
			music_player.play()

	# 1. Pause game world and physics during intro
	process_mode = Node.PROCESS_MODE_ALWAYS
	voice_player.process_mode = Node.PROCESS_MODE_ALWAYS
	voice_player.attenuation = 0.0
	voice_player.max_distance = 100000.0
	$UI.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	# 2. Lock the player and ensure camera snaps to player at start
	if is_instance_valid(beetle):
		beetle.input_enabled = false
	var pcam_group = get_node_or_null("PcamGroup")
	if is_instance_valid(pcam_group):
		pcam_group.priority = 5
	var pcam_player = get_node_or_null("PcamPlayer")
	if is_instance_valid(pcam_player):
		pcam_player.priority = 10
	
	# 3. Connect voice player finished signal
	voice_player.finished.connect(_on_voice_player_finished)
	
	# 4. Setup interactive elements dynamically if not already in scene
	_setup_level_elements()
	
	# 5. Connect any existing trigger zones
	_connect_zones()

	# 6. Define captions for introvoiceline1
	var intro_captions = [
		{"time": 0.0, "text": "Well, howdy there, new hire. Welcome to the bottom floor."},
		{"time": 4.7, "text": "Now don't let your size fool ya, "},
		{"time": 6.7, "text": "just 'cause you're three millimeters tall don't mean you get out of unpaid overtime."},
		{"time": 12.0, "text": "Go on, stretch them little legs out with Left and Right."}
	]
	
	# 7. Start the intro voice
	is_intro_playing = true
	play_voice(INTRO_VOICE, intro_captions)

func _setup_level_elements() -> void:
	# A. JumpControls at the first ledge if not present
	jump_controls = get_node_or_null("JumpControls")
	if not is_instance_valid(jump_controls):
		jump_controls = Node2D.new()
		jump_controls.name = "JumpControls"
		jump_controls.set_script(CONTROL_BUBBLE_SCRIPT)
		jump_controls.position = Vector2(-518.0, 259.0)
		jump_controls.set("lines", ["Hold W : Jump"])
		add_child(jump_controls)
		
	# B. BallControls near the ball if not present
	ball_controls = get_node_or_null("BallControls")
	if not is_instance_valid(ball_controls):
		ball_controls = Node2D.new()
		ball_controls.name = "BallControls"
		ball_controls.set_script(CONTROL_BUBBLE_SCRIPT)
		ball_controls.position = Vector2(-84.0, 260.0)
		ball_controls.set("lines", ["Hold W : Boost", "Shift : Find Ball"])
		add_child(ball_controls)

	# C. CEO Desk at summit penthouse (X=1100, Y=-736) if not present
	var existing_ceo = get_node_or_null("CeoDesk")
	if not is_instance_valid(existing_ceo):
		existing_ceo = get_tree().root.find_child("CeoDesk", true, false)
	if not is_instance_valid(existing_ceo):
		var desk_inst = CEO_DESK_SCENE.instantiate()
		desk_inst.name = "CeoDesk"
		desk_inst.position = Vector2(1100.0, -736.0)
		add_child(desk_inst)
		
	# D. Worms (SpearLaunchers) placed along the vertical path if none exist
	var worms = get_tree().get_nodes_in_group("worms")
	if worms.is_empty():
		_spawn_worm(Vector2(-448.0, -32.0), Vector2(75.0, -650.0), 2.8, 0.5)
		_spawn_worm(Vector2(160.0, -576.0), Vector2(-130.0, -680.0), 2.4, 1.2)
		_spawn_worm(Vector2(680.0, -736.0), Vector2(60.0, -700.0), 3.0, 0.8)

func _spawn_worm(pos: Vector2, launch_vel: Vector2, loop_interval: float, delay: float) -> void:
	var w = SPEAR_LAUNCHER_SCENE.instantiate()
	w.position = pos
	w.set("launch_velocity", launch_vel)
	w.set("interval", loop_interval)
	w.set("initial_delay", delay)
	add_child(w)

func _connect_zones() -> void:
	# Connect CeoDesk / CeoArea zones for ending
	for cz in get_tree().get_nodes_in_group("ceo_zone"):
		if cz is Area2D:
			cz.collision_mask = cz.collision_mask | 3
			if not cz.body_entered.is_connected(_on_ceo_desk_body_entered):
				cz.body_entered.connect(_on_ceo_desk_body_entered)
		elif cz.has_node("Area2D"):
			var a = cz.get_node("Area2D")
			a.collision_mask = a.collision_mask | 3
			if not a.body_entered.is_connected(_on_ceo_desk_body_entered):
				a.body_entered.connect(_on_ceo_desk_body_entered)

	var ceo_root = get_node_or_null("CeoDesk")
	if not is_instance_valid(ceo_root):
		ceo_root = get_node_or_null("CeoArea")
	if is_instance_valid(ceo_root):
		for child in ceo_root.get_children():
			if child is Area2D:
				child.collision_mask = child.collision_mask | 3
				if not child.body_entered.is_connected(_on_ceo_desk_body_entered):
					child.body_entered.connect(_on_ceo_desk_body_entered)
		if ceo_root is Area2D:
			ceo_root.collision_mask = ceo_root.collision_mask | 3
			if not ceo_root.body_entered.is_connected(_on_ceo_desk_body_entered):
				ceo_root.body_entered.connect(_on_ceo_desk_body_entered)
				
	# Connect NarrationArea zones (JumpArea, BallArea, CoworkerArea)
	var narration_node = get_node_or_null("NarrationArea")
	if is_instance_valid(narration_node):
		var jump_area = narration_node.get_node_or_null("JumpArea")
		if is_instance_valid(jump_area) and not jump_area.body_entered.is_connected(_on_jump_area_body_entered):
			jump_area.collision_mask = jump_area.collision_mask | 3
			jump_area.body_entered.connect(_on_jump_area_body_entered)
		var ball_area = narration_node.get_node_or_null("BallArea")
		if is_instance_valid(ball_area) and not ball_area.body_entered.is_connected(_on_ball_area_body_entered):
			ball_area.collision_mask = ball_area.collision_mask | 3
			ball_area.body_entered.connect(_on_ball_area_body_entered)
		var cw_area = narration_node.get_node_or_null("CoworkerArea")
		if is_instance_valid(cw_area) and not cw_area.body_entered.is_connected(_on_coworker_area_body_entered):
			cw_area.collision_mask = cw_area.collision_mask | 3
			cw_area.body_entered.connect(_on_coworker_area_body_entered)

	# Connect CoworkerArea zones if present
	var cw_root = get_node_or_null("CoworkerArea")
	if is_instance_valid(cw_root):
		for child in cw_root.get_children():
			if child is Area2D:
				child.collision_mask = child.collision_mask | 2
				if not child.body_entered.is_connected(_on_coworker_area_body_entered):
					child.body_entered.connect(_on_coworker_area_body_entered)
		if cw_root is Area2D:
			cw_root.collision_mask = cw_root.collision_mask | 2
			if not cw_root.body_entered.is_connected(_on_coworker_area_body_entered):
				cw_root.body_entered.connect(_on_coworker_area_body_entered)

func _process(_delta: float) -> void:
	if is_instance_valid(voice_player) and is_instance_valid(beetle):
		voice_player.global_position = beetle.global_position

	if is_instance_valid(voice_player) and voice_player.playing:
		_update_subtitles()
	
	if not is_intro_playing:
		_check_ledge_trigger()
		_check_ball_trigger()
		_check_worm_trigger()
		_check_ceo_trigger()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE)):
		if is_narrating():
			skip_current_narration()

func is_narrating() -> bool:
	return is_intro_playing or (is_instance_valid(voice_player) and voice_player.playing)

func skip_current_narration() -> void:
	if is_intro_playing:
		_on_intro_finished()
	elif is_ending:
		if is_instance_valid(voice_player):
			voice_player.stop()
		subtitle_label.text = ""
		current_captions = []
		if is_instance_valid(skip_label):
			skip_label.visible = false
		_on_ceo_fade_to_credits()
	else:
		if is_instance_valid(voice_player):
			voice_player.stop()
		if is_instance_valid(subtitle_label):
			subtitle_label.text = ""
		current_captions = []
		if is_instance_valid(skip_label):
			skip_label.visible = false
		if pending_voice_stream != null:
			var stream = pending_voice_stream
			var captions = pending_voice_captions
			pending_voice_stream = null
			pending_voice_captions = []
			play_voice(stream, captions)

# ==========================================
# TRIGGER CHECKS
# ==========================================
func _check_ledge_trigger() -> void:
	if ledge_voiceline_played or not is_instance_valid(beetle):
		return
	var jump_area = get_node_or_null("NarrationArea/JumpArea")
	if is_instance_valid(jump_area):
		for body in jump_area.get_overlapping_bodies():
			if body == beetle or body.name == "Beetle":
				_trigger_ledge_voiceline()
				return
		var col = jump_area.get_node_or_null("CollisionShape2D")
		if is_instance_valid(col) and col.shape is RectangleShape2D:
			var half_size: Vector2 = col.shape.size * 0.5
			var center: Vector2 = col.global_position
			if abs(beetle.global_position.x - center.x) <= (half_size.x + 10.0) and abs(beetle.global_position.y - center.y) <= (half_size.y + 40.0):
				_trigger_ledge_voiceline()
				return

func _trigger_ledge_voiceline() -> void:
	if ledge_voiceline_played:
		return
	ledge_voiceline_played = true
	if is_instance_valid(jump_controls) and jump_controls.has_method("pop_up"):
		jump_controls.pop_up()
	var intro2_captions = [
		{"time": 0.0, "text": "Now the corporate ladder wasn't built for a fellow your height."},
		{"time": 4.0, "text": "Tappin' jump ain't gonna cut it here."},
		{"time": 6.5, "text": "You got to plant your feet, hold down Up to hunker real low..."},
		{"time": 11.4, "text": "...and let 'er rip when you're ready to fly!"}
	]
	if is_instance_valid(voice_player) and voice_player.playing:
		pending_voice_stream = INTRO_VOICE_2
		pending_voice_captions = intro2_captions
	else:
		play_voice(INTRO_VOICE_2, intro2_captions)

func _check_ball_trigger() -> void:
	if ball_voiceline_played or not is_instance_valid(beetle):
		return
	var ball = get_node_or_null("DungBall")
	var ball_area = get_node_or_null("NarrationArea/BallArea")
	if is_instance_valid(ball_area):
		for body in ball_area.get_overlapping_bodies():
			if body == beetle or body.name == "Beetle" or (is_instance_valid(ball) and body == ball):
				_trigger_ball_voiceline()
				return
		var col = ball_area.get_node_or_null("CollisionShape2D")
		if is_instance_valid(col) and col.shape is RectangleShape2D:
			var half_size: Vector2 = col.shape.size * 0.5
			var center: Vector2 = col.global_position
			var beetle_in: bool = abs(beetle.global_position.x - center.x) <= (half_size.x + 10.0) and abs(beetle.global_position.y - center.y) <= (half_size.y + 40.0)
			var ball_in: bool = is_instance_valid(ball) and abs(ball.global_position.x - center.x) <= (half_size.x + 10.0) and abs(ball.global_position.y - center.y) <= (half_size.y + 40.0)
			if beetle_in or ball_in:
				_trigger_ball_voiceline()
				return
	if is_instance_valid(ball) and beetle.global_position.distance_to(ball.global_position) < 70.0:
		_trigger_ball_voiceline()

func _trigger_ball_voiceline() -> void:
	if ball_voiceline_played:
		return
	ball_voiceline_played = true
	if is_instance_valid(ball_controls) and ball_controls.has_method("pop_up"):
		ball_controls.pop_up()
	var intro3_captions = [
		{"time": 0.0, "text": "Look at the size of that workload now."},
		{"time": 3.0, "text": "Polite pushing will get it rolling on flat ground sure, but management wants vertical results."},
		{"time": 9.8, "text": "Cozy right up against the side of that sphere till you're doing a proper dung beetle handstand..."},
		{"time": 15.6, "text": "...then hold Up, coil them hind legs until you're shaking, and launch it up the ledges!"},
		{"time": 22.2, "text": "Just don't forget to hold Shift when you inevitably lose sight of it."}
	]
	if is_instance_valid(voice_player) and voice_player.playing:
		pending_voice_stream = INTRO_VOICE_3
		pending_voice_captions = intro3_captions
	else:
		play_voice(INTRO_VOICE_3, intro3_captions)

func _check_worm_trigger() -> void:
	if worm_voiceline_played or not is_instance_valid(beetle):
		return
	var worms = get_tree().get_nodes_in_group("worms")
	for worm in worms:
		if is_instance_valid(worm) and beetle.global_position.distance_to(worm.global_position) < 220.0:
			_trigger_worm_voiceline()
			return

func _trigger_worm_voiceline() -> void:
	if worm_voiceline_played:
		return
	worm_voiceline_played = true
	var intro4_captions = [
		{"time": 0.0, "text": "Heads up, intern! Or rather, heads down."},
		{"time": 2.8, "text": "Those floor worms don't take kindly to folks rolling heavy paperwork over their roofs."},
		{"time": 7.6, "text": "Time your push right after they snap back down..."},
		{"time": 10.8, "text": "...or kiss your progress goodbye."}
	]
	if is_instance_valid(voice_player) and voice_player.playing:
		pending_voice_stream = INTRO_VOICE_4
		pending_voice_captions = intro4_captions
	else:
		play_voice(INTRO_VOICE_4, intro4_captions)

func _check_ceo_trigger() -> void:
	if ceo_ending_triggered:
		return
	var ball = get_node_or_null("DungBall")
	
	# Check summit penthouse area: X >= 950 and Y <= -680
	var beetle_at_summit: bool = is_instance_valid(beetle) and beetle.global_position.x >= 950.0 and beetle.global_position.y <= -680.0
	var ball_at_summit: bool = is_instance_valid(ball) and ball.global_position.x >= 950.0 and ball.global_position.y <= -680.0
	if beetle_at_summit or ball_at_summit:
		_trigger_ceo_end_event()
		return

	var ceo_area = get_tree().root.find_child("CeoDesk", true, false)
	if not is_instance_valid(ceo_area):
		ceo_area = get_tree().root.find_child("CeoArea", true, false)
		
	if is_instance_valid(ceo_area):
		var area_node: Area2D = ceo_area if ceo_area is Area2D else ceo_area.get_node_or_null("Area2D")
		if is_instance_valid(area_node):
			var col = area_node.get_node_or_null("CollisionShape2D")
			if is_instance_valid(col) and col.shape is RectangleShape2D:
				var half_size: Vector2 = col.shape.size * 0.5
				var center: Vector2 = col.global_position
				var ball_in: bool = is_instance_valid(ball) and abs(ball.global_position.x - center.x) <= half_size.x and abs(ball.global_position.y - center.y) <= half_size.y
				var beetle_in: bool = is_instance_valid(beetle) and abs(beetle.global_position.x - center.x) <= half_size.x and abs(beetle.global_position.y - center.y) <= half_size.y
				if ball_in or beetle_in:
					_trigger_ceo_end_event()

func _on_ceo_desk_body_entered(body: Node2D) -> void:
	var ball = get_node_or_null("DungBall")
	if body == beetle or body == ball or (is_instance_valid(ball) and body == ball):
		_trigger_ceo_end_event()

func _trigger_ceo_end_event() -> void:
	if ceo_ending_triggered:
		return
	ceo_ending_triggered = true
	is_ending = true
	
	if is_instance_valid(beetle):
		beetle.input_enabled = false
		beetle.velocity = Vector2.ZERO
	
	var end_captions = [
		{"time": 0.0, "text": "Congratulations, intern! You climbed the corporate ladder and got the job done."},
		{"time": 5.0, "text": "Now step right up to the CEO's desk for your big promotion."},
		{"time": 9.8, "text": "Oh wait... looking at the calendar here..."},
		{"time": 12.8, "text": "...the CEO isn't even in the building today!"},
		{"time": 16.0, "text": "In fact, we moved headquarters across town last week."},
		{"time": 19.8, "text": "You just climbed an abandoned building, son."},
		{"time": 22.5, "text": "Have a good weekend!"}
	]
	play_voice(END_VOICE_1, end_captions)
	
	# Transition to end screen after voiceline (23.5s)
	get_tree().create_timer(23.5).timeout.connect(_on_ceo_fade_to_credits)

var credits_shown: bool = false
func _on_ceo_fade_to_credits() -> void:
	if credits_shown:
		return
	credits_shown = true
	get_tree().change_scene_to_file.call_deferred(END_SCREEN_SCENE)

func _on_jump_area_body_entered(body: Node2D) -> void:
	if body == beetle or body.name == "Beetle":
		_trigger_ledge_voiceline()

func _on_ball_area_body_entered(body: Node2D) -> void:
	var ball = get_node_or_null("DungBall")
	if body == beetle or body.name == "Beetle" or (is_instance_valid(ball) and body == ball) or body.name == "DungBall":
		_trigger_ball_voiceline()

func _on_music_finished() -> void:
	if is_instance_valid(music_player):
		music_player.play()

func _on_coworker_area_body_entered(body: Node2D) -> void:
	var ball = get_node_or_null("DungBall")
	if body == ball or body.name == "DungBall":
		if is_instance_valid(ball) and ball.has_method("trigger_coworker_event"):
			ball.trigger_coworker_event()

# ==========================================
# REUSABLE ONE-PLAYER VOICE SYSTEM
# ==========================================
func play_voice(stream: AudioStream, captions: Array = []) -> void:
	if is_instance_valid(beetle):
		voice_player.global_position = beetle.global_position
	voice_player.stop()
	voice_player.stream = stream
	current_captions = captions
	subtitle_label.text = ""
	if is_instance_valid(skip_label):
		skip_label.visible = true
	voice_player.play()

func play_drop_voiceline() -> void:
	if is_intro_playing:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_drop_time < DROP_COOLDOWN:
		return
	
	last_drop_time = current_time
	
	if available_drop_indices.is_empty():
		for i in range(DROP_VOICES.size()):
			available_drop_indices.append(i)
		available_drop_indices.shuffle()
	
	var chosen_idx = available_drop_indices.pop_back()
	var drop_data = DROP_VOICES[chosen_idx]
	play_voice(drop_data["stream"], drop_data["captions"])

func _update_subtitles() -> void:
	if current_captions.is_empty():
		return
	var pos = voice_player.get_playback_position()
	for i in range(current_captions.size() - 1, -1, -1):
		if pos >= current_captions[i]["time"]:
			subtitle_label.text = current_captions[i]["text"]
			break

func _on_voice_player_finished() -> void:
	subtitle_label.text = ""
	current_captions = []
	if is_instance_valid(skip_label):
		skip_label.visible = false
	if is_intro_playing:
		_on_intro_finished()
	elif pending_voice_stream != null:
		var stream = pending_voice_stream
		var captions = pending_voice_captions
		pending_voice_stream = null
		pending_voice_captions = []
		play_voice(stream, captions)

# ==========================================
# GAME START
# ==========================================
func _on_intro_finished() -> void:
	if not is_intro_playing:
		return
	is_intro_playing = false
	voice_player.stop()
	subtitle_label.text = ""
	current_captions = []
	if is_instance_valid(skip_label):
		skip_label.visible = false
	
	# Unpause the game immediately so the ball falls down
	get_tree().paused = false
	
	# Unlock gameplay immediately
	if is_instance_valid(beetle):
		beetle.input_enabled = true
	
	# Pop up the wobbly controls bubble!
	if is_instance_valid(control_bubble) and control_bubble.has_method("pop_up"):
		control_bubble.pop_up()
