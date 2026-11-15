extends Control

const GAME_SCENE := "res://scenes/main.tscn"

var settings_panel: PanelContainer
var music_slider: HSlider
var sound_slider: HSlider
var status_label: Label

func _ready() -> void:
	_build_menu()

func _build_menu() -> void:
	# Full-screen background and layered graphic accents.
	var background := ColorRect.new()
	background.color = Color("#101b25")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var glow := ColorRect.new()
	glow.color = Color(0.10, 0.31, 0.30, 0.28)
	glow.anchor_left = 0.52
	glow.anchor_top = 0.0
	glow.anchor_right = 1.0
	glow.anchor_bottom = 1.0
	glow.offset_left = 0
	glow.offset_top = 0
	glow.offset_right = 0
	glow.offset_bottom = 0
	add_child(glow)

	var accent := ColorRect.new()
	accent.color = Color("#e6ad4c")
	accent.anchor_left = 0.0
	accent.anchor_top = 0.0
	accent.anchor_right = 0.012
	accent.anchor_bottom = 1.0
	accent.offset_right = 0
	add_child(accent)

	var layout := HBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 64
	layout.offset_top = 42
	layout.offset_right = -64
	layout.offset_bottom = -42
	layout.add_theme_constant_override("separation", 40)
	add_child(layout)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 14)
	layout.add_child(left)

	var eyebrow := _label("ADI INTERACTIVE  /  BUSINESS SIMULATION", 15, Color("#e6ad4c"))
	left.add_child(eyebrow)

	var title := _label("BUSINESS\nEMPIRE", 64, Color("#f4f3ed"))
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	left.add_child(title)

	var subtitle := _label("BANGUN PERUSAHAAN.\nKENDALIKAN ARMADA. KUASAI KOTA.", 18, Color("#b8c5c8"))
	subtitle.add_theme_constant_override("line_spacing", 7)
	left.add_child(subtitle)

	var divider := ColorRect.new()
	divider.color = Color("#52646b")
	divider.custom_minimum_size = Vector2(300, 2)
	left.add_child(divider)

	var version := _label("EARLY ACCESS  •  ANDROID PROTOTYPE", 13, Color("#82949a"))
	left.add_child(version)

	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(360, 0)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.09, 0.12, 0.94)
	panel_style.border_color = Color("#354a50")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 28
	panel_style.content_margin_right = 28
	panel_style.content_margin_top = 30
	panel_style.content_margin_bottom = 30
	right.add_theme_stylebox_override("panel", panel_style)
	layout.add_child(right)

	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	right.add_child(actions)

	var menu_heading := _label("MENU UTAMA", 22, Color("#f4f3ed"))
	actions.add_child(menu_heading)
	var menu_hint := _label("Pilih langkah berikutnya", 14, Color("#9aabb0"))
	actions.add_child(menu_hint)

	var play := _button("▶   MULAI BERMAIN", true)
	play.pressed.connect(_start_game)
	actions.add_child(play)

	var settings := _button("⚙   PENGATURAN", false)
	settings.pressed.connect(_toggle_settings)
	actions.add_child(settings)

	var exit := _button("KELUAR", false)
	exit.pressed.connect(_exit_game)
	actions.add_child(exit)

	status_label = _label("PROGRES TERSIMPAN OTOMATIS DI PERANGKAT", 11, Color("#82949a"))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	actions.add_child(status_label)

	_build_settings()

func _label(value: String, size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	return result

func _button(caption: String, primary: bool) -> Button:
	var result := Button.new()
	result.text = caption
	result.custom_minimum_size = Vector2(290, 58)
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.add_theme_font_size_override("font_size", 17)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#dca84d") if primary else Color("#1b3039")
	normal.border_color = Color("#f1c875") if primary else Color("#40545c")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(7)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#efbd63") if primary else Color("#29434d")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#bd8735") if primary else Color("#13242c")
	result.add_theme_stylebox_override("normal", normal)
	result.add_theme_stylebox_override("hover", hover)
	result.add_theme_stylebox_override("pressed", pressed)
	result.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	result.add_theme_color_override("font_color", Color("#14212a") if primary else Color("#e8ece9"))
	result.add_theme_color_override("font_hover_color", Color("#14212a") if primary else Color.WHITE)
	return result

func _build_settings() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.visible = false
	settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	settings_panel.position = Vector2(-210, -150)
	settings_panel.size = Vector2(420, 300)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#14242d")
	style.border_color = Color("#e6ad4c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	settings_panel.add_theme_stylebox_override("panel", style)
	add_child(settings_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	settings_panel.add_child(content)
	content.add_child(_label("PENGATURAN AUDIO", 22, Color("#f4f3ed")))
	content.add_child(_label("Volume musik", 14, Color("#b8c5c8")))
	music_slider = HSlider.new()
	music_slider.min_value = 0
	music_slider.max_value = 100
	music_slider.value = 70
	content.add_child(music_slider)
	content.add_child(_label("Volume efek suara", 14, Color("#b8c5c8")))
	sound_slider = HSlider.new()
	sound_slider.min_value = 0
	sound_slider.max_value = 100
	sound_slider.value = 80
	content.add_child(sound_slider)
	var close := _button("SIMPAN & TUTUP", true)
	close.pressed.connect(_toggle_settings)
	content.add_child(close)

func _toggle_settings() -> void:
	settings_panel.visible = not settings_panel.visible

func _start_game() -> void:
	status_label.text = "MEMUAT GAMEPLAY..."
	var packed := load(GAME_SCENE) as PackedScene
	if packed == null:
		status_label.text = "GAGAL MEMUAT GAME. FILE SCENE TIDAK DITEMUKAN."
		push_error("Main gameplay scene not found: " + GAME_SCENE)
		return
	var error := get_tree().change_scene_to_packed(packed)
	if error != OK:
		status_label.text = "GAGAL MEMBUKA GAME: " + str(error)
		push_error("Unable to change to gameplay scene. Error: " + str(error))

func _exit_game() -> void:
	get_tree().quit()
