extends Control

const GAME_SCENE := "res://scenes/main.tscn"
const VIDEO_PATH := "res://assets/branding/loading_screen.ogv"
const LOGO_PATH := "res://assets/branding/logo.jpg"

var video_player: VideoStreamPlayer
var loading_started := false

func _ready() -> void:
	_build_screen()
	if ResourceLoader.exists(VIDEO_PATH):
		var video = load(VIDEO_PATH)
		if video != null:
			video_player.stream = video
			video_player.finished.connect(_open_game)
			video_player.play()
			loading_started = true
			# Safety fallback if a device fails to emit the video's finished signal.
			_fallback_open(180.0)
			return
	_fallback_open(4.0)

func _build_screen() -> void:
	var background := ColorRect.new()
	background.color = Color("#101820")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	video_player = VideoStreamPlayer.new()
	video_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	video_player.expand = true
	video_player.autoplay = false
	video_player.show_behind_parent = true
	add_child(video_player)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.06, 0.30)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	if ResourceLoader.exists(LOGO_PATH):
		var logo := TextureRect.new()
		logo.texture = load(LOGO_PATH) as Texture2D
		logo.anchor_left = 0.04
		logo.anchor_top = 0.72
		logo.anchor_right = 0.28
		logo.anchor_bottom = 0.96
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		add_child(logo)

	var title := Label.new()
	title.text = "BUSINESS EMPIRE"
	title.anchor_left = 0.04
	title.anchor_top = 0.05
	title.anchor_right = 0.70
	title.anchor_bottom = 0.14
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#f4f3ed"))
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "MENYIAPKAN KOTA DAN ARMADA..."
	subtitle.anchor_left = 0.04
	subtitle.anchor_top = 0.88
	subtitle.anchor_right = 0.72
	subtitle.anchor_bottom = 0.95
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("#e6ad4c"))
	add_child(subtitle)

	var skip := Button.new()
	skip.text = "LEWATI"
	skip.anchor_left = 0.86
	skip.anchor_top = 0.86
	skip.anchor_right = 0.97
	skip.anchor_bottom = 0.96
	skip.pressed.connect(_open_game)
	add_child(skip)

func _fallback_open(delay_seconds: float) -> void:
	await get_tree().create_timer(delay_seconds).timeout
	_open_game()

func _open_game() -> void:
	if get_tree().current_scene != self:
		return
	get_tree().change_scene_to_file(GAME_SCENE)
