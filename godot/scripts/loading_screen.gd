extends Control

const GAME_SCENE := "res://scenes/main.tscn"
const VIDEO_PATH := "res://assets/branding/loading_screen.ogv"
const POSTER_PATH := "res://assets/branding/loading_poster.jpg"
const LOGO_PATH := "res://assets/branding/logo.jpg"
const DURATION_PATH := "res://assets/branding/loading_duration.txt"

var video_player: VideoStreamPlayer
var transition_started := false

func _ready() -> void:
	_build_screen()
	var fallback_seconds := 6.0
	if FileAccess.file_exists(DURATION_PATH):
		var duration_text := FileAccess.get_file_as_string(DURATION_PATH).strip_edges()
		if duration_text.is_valid_float():
			fallback_seconds = maxf(4.0, float(duration_text) + 2.0)

	if ResourceLoader.exists(VIDEO_PATH):
		var video_stream := load(VIDEO_PATH) as VideoStream
		if video_stream != null:
			video_player.stream = video_stream
			video_player.visible = true
			video_player.finished.connect(_open_game)
			video_player.play()
			_hide_video_if_not_started()
			_fallback_open(fallback_seconds)
			return

	video_player.visible = false
	_fallback_open(6.0)

func _build_screen() -> void:
	var background := ColorRect.new()
	background.color = Color("#101820")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	if ResourceLoader.exists(POSTER_PATH):
		var poster := TextureRect.new()
		poster.texture = load(POSTER_PATH) as Texture2D
		poster.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		poster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		poster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		add_child(poster)

	video_player = VideoStreamPlayer.new()
	video_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	video_player.expand = true
	video_player.autoplay = false
	video_player.visible = false
	video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(video_player)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.06, 0.48)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	if ResourceLoader.exists(LOGO_PATH):
		var logo := TextureRect.new()
		logo.texture = load(LOGO_PATH) as Texture2D
		logo.anchor_left = 0.04
		logo.anchor_top = 0.70
		logo.anchor_right = 0.28
		logo.anchor_bottom = 0.95
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(logo)

	var title := Label.new()
	title.text = "BUSINESS EMPIRE"
	title.anchor_left = 0.04
	title.anchor_top = 0.06
	title.anchor_right = 0.78
	title.anchor_bottom = 0.15
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("#ffffff"))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "MENYIAPKAN KOTA DAN ARMADA..."
	subtitle.anchor_left = 0.04
	subtitle.anchor_top = 0.88
	subtitle.anchor_right = 0.74
	subtitle.anchor_bottom = 0.96
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color("#f0c16b"))
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(subtitle)

	var skip := Button.new()
	skip.text = "LEWATI"
	skip.anchor_left = 0.85
	skip.anchor_top = 0.86
	skip.anchor_right = 0.97
	skip.anchor_bottom = 0.96
	skip.pressed.connect(_open_game)
	add_child(skip)

func _hide_video_if_not_started() -> void:
	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree() or transition_started:
		return
	if not video_player.is_playing():
		video_player.visible = false

func _fallback_open(delay_seconds: float) -> void:
	await get_tree().create_timer(delay_seconds).timeout
	_open_game()

func _open_game() -> void:
	if transition_started:
		return
	transition_started = true
	var error := get_tree().change_scene_to_file(GAME_SCENE)
	if error != OK:
		transition_started = false
		push_error("Gagal membuka gameplay: " + str(error))
