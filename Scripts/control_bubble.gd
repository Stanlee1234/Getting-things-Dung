extends Node2D

const PALETTE: Array[Color] = [
	Color("#91a4db"), # blue
	Color("#97db91"), # green
	Color("#db9591"), # coral / pink
	Color("#dbaf91"), # orange
	Color("#dbd991"), # yellow
	Color("#b991db")  # purple
]

@export var lines: Array[String] = [
	"A/D : Walk"
]
@export var font: Font = preload("res://Assets/augiepixel.ttf")
@export var font_size: int = 14
@export var line_spacing: float = 18.0
@export var fly_distance: float = 180.0

var letters: Array[Dictionary] = []
var time: float = 0.0
var is_active: bool = false
var is_settled: bool = false
var is_dismissing: bool = false

func _ready() -> void:
	visible = false
	_build_letters()

func _build_letters() -> void:
	for child in get_children():
		child.queue_free()
	letters.clear()

	var color_idx: int = 0
	for row in range(lines.size()):
		var line_text: String = lines[row]
		var line_width: float = font.get_string_size(line_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var cur_x: float = -line_width / 2.0
		var cur_y: float = row * line_spacing

		for col in range(line_text.length()):
			var ch: String = line_text[col]
			var ch_w: float = font.get_char_size(ch.unicode_at(0), font_size).x
			if ch != " ":
				var lbl = Label.new()
				lbl.text = ch
				lbl.add_theme_font_override("font", font)
				lbl.add_theme_font_size_override("font_size", font_size)
				lbl.add_theme_color_override("font_color", PALETTE[color_idx % PALETTE.size()])
				lbl.add_theme_constant_override("outline_size", 4)
				lbl.add_theme_color_override("font_outline_color", Color("#22201e"))
				lbl.pivot_offset = Vector2(ch_w / 2.0, font_size / 2.0)
				lbl.position = Vector2(cur_x, cur_y + fly_distance)
				lbl.scale = Vector2(0.6, 1.4)
				lbl.modulate.a = 0.0
				add_child(lbl)
				letters.append({
					"label": lbl,
					"rest_pos": Vector2(cur_x, cur_y)
				})
				color_idx += 1
			cur_x += ch_w

func pop_up() -> void:
	if letters.is_empty():
		_build_letters()
	
	visible = true
	is_active = true
	is_settled = false
	is_dismissing = false
	time = 0.0

	var tween = create_tween().set_parallel(true)
	for i in range(letters.size()):
		var data = letters[i]
		var lbl: Label = data["label"]
		var rest: Vector2 = data["rest_pos"]
		var delay: float = i * 0.035

		lbl.position = rest + Vector2(0.0, fly_distance)
		lbl.scale = Vector2(0.6, 1.4)
		lbl.modulate.a = 0.0

		# Spring fly-in from the bottom
		tween.tween_property(lbl, "position:y", rest.y, 0.45)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)\
			.set_delay(delay)
		tween.tween_property(lbl, "scale", Vector2.ONE, 0.45)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)\
			.set_delay(delay)
		tween.tween_property(lbl, "modulate:a", 1.0, 0.15)\
			.set_delay(delay)

	tween.finished.connect(func(): is_settled = true)

func _process(delta: float) -> void:
	if not visible or not is_settled or is_dismissing:
		return

	time += delta
	for i in range(letters.size()):
		var data = letters[i]
		var lbl: Label = data["label"]
		var rest: Vector2 = data["rest_pos"]

		# Playful Jame Gam floating wave & tilt
		var wave: float = sin(time * 3.5 + i * 0.4) * 2.0
		lbl.position.y = rest.y + wave
		lbl.rotation = sin(time * 2.5 + i * 0.3) * 0.04
		var squash: float = sin(time * 3.0 + i * 0.5) * 0.04
		lbl.scale = Vector2(1.0 + squash, 1.0 - squash)

func dismiss() -> void:
	if is_dismissing:
		return
	is_dismissing = true

	var tween = create_tween().set_parallel(true)
	for i in range(letters.size()):
		var data = letters[i]
		var lbl: Label = data["label"]
		var rest: Vector2 = data["rest_pos"]
		var delay: float = (letters.size() - 1 - i) * 0.015

		tween.tween_property(lbl, "position:y", rest.y + fly_distance, 0.35)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_IN)\
			.set_delay(delay)
		tween.tween_property(lbl, "scale", Vector2(0.6, 1.4), 0.35)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_IN)\
			.set_delay(delay)
		tween.tween_property(lbl, "modulate:a", 0.0, 0.2)\
			.set_delay(delay + 0.1)

	tween.finished.connect(queue_free)
