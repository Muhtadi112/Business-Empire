extends Control

const SAVE_PATH := "user://business_empire_2d.cfg"
const START_CASH := 50000000
const BUSINESS_TYPES := [
	{"name":"KIOS SEMBAKO","cost":10000000,"income":18000,"color":Color("#e9b85b"),"desc":"Usaha kecil dengan pemasukan stabil."},
	{"name":"MINIMARKET","cost":35000000,"income":62000,"color":Color("#64b6a4"),"desc":"Toko modern dengan pelanggan lebih ramai."},
	{"name":"GUDANG LOGISTIK","cost":80000000,"income":145000,"color":Color("#7197c7"),"desc":"Pusat penyimpanan dan distribusi barang."},
	{"name":"PABRIK","cost":200000000,"income":390000,"color":Color("#bb8acb"),"desc":"Produksi skala besar dengan biaya tinggi."}
]

var cash: int = START_CASH
var total_income: int = 0
var owned: Array[Dictionary] = [{"type":0,"level":1}]
var cash_label: Label
var income_label: Label
var level_label: Label
var business_list: VBoxContainer
var status_label: Label
var elapsed := 0.0

class CityMap extends Control:
	var plots: Array[Dictionary] = []
	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color("#b8c99a"))
		# Jalan utama dan jalan lingkungan, gaya peta 2D top-down.
		draw_rect(Rect2(Vector2(w * 0.43, 0), Vector2(w * 0.18, h)), Color("#555d62"))
		draw_rect(Rect2(Vector2(0, h * 0.43), Vector2(w, h * 0.16)), Color("#555d62"))
		for y in range(8, int(h), 34):
			draw_line(Vector2(w * 0.52, y), Vector2(w * 0.52, y + 15), Color("#f4e7b4"), 2.0)
		for x in range(8, int(w), 34):
			draw_line(Vector2(x, h * 0.51), Vector2(x + 15, h * 0.51), Color("#f4e7b4"), 2.0)
		var positions := [
			Rect2(w*0.06,h*0.08,w*0.25,h*0.25), Rect2(w*0.68,h*0.08,w*0.25,h*0.25),
			Rect2(w*0.06,h*0.66,w*0.25,h*0.25), Rect2(w*0.68,h*0.66,w*0.25,h*0.25)
		]
		var palette := [Color("#e9b85b"),Color("#64b6a4"),Color("#7197c7"),Color("#bb8acb")]
		for i in range(positions.size()):
			var r: Rect2 = positions[i]
			draw_rect(r, Color("#91a77a"))
			draw_rect(Rect2(r.position + Vector2(7, 7), r.size - Vector2(14, 14)), palette[i % palette.size()])
			draw_rect(Rect2(r.position + Vector2(13, 13), r.size - Vector2(26, 26)), Color("#e8e0c9"))
			draw_rect(Rect2(r.position + Vector2(r.size.x*0.40, r.position.y*0.0 + r.size.y*0.43), Vector2(r.size.x*0.20, r.size.y*0.18)), Color("#65747a"))
		draw_circle(Vector2(w*0.36,h*0.18), 13, Color("#477d4f"))
		draw_circle(Vector2(w*0.63,h*0.78), 17, Color("#477d4f"))
		draw_circle(Vector2(w*0.34,h*0.78), 11, Color("#477d4f"))
		draw_string(ThemeDB.fallback_font, Vector2(w*0.445,h*0.38), "JALAN RAYA", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color.WHITE)

func _ready() -> void:
	_load_game()
	_build_ui()
	_refresh()
	_save_game()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= 1.0:
		elapsed = 0.0
		cash += total_income
		_refresh_header()
		_save_game()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#101a20")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := _label("BUSINESS EMPIRE", 27, Color("#f4f1e8"))
	_place(title, 26, 24, 430, 42)
	var subtitle := _label("BANGUN USAHA • KEMBANGKAN KOTA", 13, Color("#9eb0ad"))
	_place(subtitle, 28, 66, 460, 24)

	var level_panel := _panel(Color("#263941"))
	_place(level_panel, 535, 25, 155, 62)
	level_label = _label("LEVEL 01", 17, Color("#f1c66f"))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_panel.add_child(level_label)

	var wallet := _panel(Color("#1c2b31"))
	_place(wallet, 24, 112, 672, 105)
	var wallet_title := _label("SALDO PERUSAHAAN", 13, Color("#a9bbb6"))
	_place(wallet_title, 43, 126, 300, 22)
	cash_label = _label("Rp 50.000.000", 29, Color("#f4f1e8"))
	_place(cash_label, 42, 151, 430, 45)
	income_label = _label("+ Rp 0 / detik", 15, Color("#72d5a2"))
	_place(income_label, 430, 158, 240, 28)

	var map_title := _label("KAWASAN USAHA", 18, Color("#f4f1e8"))
	_place(map_title, 27, 237, 350, 28)
	var map_hint := _label("Peta kota • pilih lokasi untuk ekspansi", 12, Color("#9eb0ad"))
	_place(map_hint, 28, 267, 500, 22)
	var map := CityMap.new()
	_place(map, 24, 300, 672, 350)

	var business_title := _label("PORTOFOLIO BISNIS", 19, Color("#f4f1e8"))
	_place(business_title, 27, 672, 400, 30)
	status_label = _label("Pilih usaha untuk mulai berkembang.", 12, Color("#9eb0ad"))
	_place(status_label, 28, 704, 650, 22)

	var scroll := ScrollContainer.new()
	_place(scroll, 24, 735, 672, 445)
	add_child(scroll)
	business_list = VBoxContainer.new()
	business_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	business_list.add_theme_constant_override("separation", 10)
	scroll.add_child(business_list)

	var footer := _label("PROGRES TERSIMPAN OTOMATIS", 11, Color("#71858a"))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(footer, 24, 1200, 672, 24)

func _refresh() -> void:
	total_income = 0
	for item in owned:
		var data: Dictionary = BUSINESS_TYPES[int(item.type)]
		total_income += int(data.income) * int(item.level)
	_refresh_header()
	for child in business_list.get_children():
		child.queue_free()
	for i in range(BUSINESS_TYPES.size()):
		var data: Dictionary = BUSINESS_TYPES[i]
		var owned_item := _find_owned(i)
		var card := _panel(Color("#1c2b31"))
		card.custom_minimum_size = Vector2(640, 104)
		business_list.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		var swatch := ColorRect.new()
		swatch.color = data.color
		swatch.custom_minimum_size = Vector2(9, 70)
		row.add_child(swatch)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var name := _label(str(data.name), 16, Color("#f4f1e8"))
		info.add_child(name)
		var details := _label(str(data.desc), 11, Color("#9eb0ad"))
		info.add_child(details)
		var state := _label("", 12, Color("#72d5a2"))
		if owned_item.is_empty():
			state.text = "Belum dimiliki • " + _money(int(data.cost))
		else:
			state.text = "Level " + str(owned_item.level) + " • " + _money(int(data.income) * int(owned_item.level)) + "/detik"
		info.add_child(state)
		var action := Button.new()
		action.custom_minimum_size = Vector2(128, 54)
		action.add_theme_font_size_override("font_size", 13)
		if owned_item.is_empty():
			action.text = "BANGUN\n" + _short_money(int(data.cost))
			action.pressed.connect(_buy_business.bind(i))
		else:
			var upgrade_cost := _upgrade_cost(i, int(owned_item.level))
			action.text = "UPGRADE\n" + _short_money(upgrade_cost)
			action.pressed.connect(_upgrade_business.bind(i))
		row.add_child(action)

func _buy_business(index: int) -> void:
	var data: Dictionary = BUSINESS_TYPES[index]
	var cost := int(data.cost)
	if cash < cost:
		status_label.text = "Saldo belum cukup untuk membangun " + str(data.name) + "."
		return
	cash -= cost
	owned.append({"type":index,"level":1})
	status_label.text = str(data.name) + " berhasil dibangun!"
	_refresh()

func _upgrade_business(index: int) -> void:
	var item := _find_owned(index)
	if item.is_empty():
		return
	var cost := _upgrade_cost(index, int(item.level))
	if cash < cost:
		status_label.text = "Saldo belum cukup untuk upgrade."
		return
	cash -= cost
	for entry in owned:
		if int(entry.type) == index:
			entry.level = int(entry.level) + 1
			break
	status_label.text = str(BUSINESS_TYPES[index].name) + " berhasil ditingkatkan."
	_refresh()

func _upgrade_cost(index: int, level: int) -> int:
	return int(BUSINESS_TYPES[index].cost) * (level + 1)

func _find_owned(index: int) -> Dictionary:
	for item in owned:
		if int(item.type) == index:
			return item
	return {}

func _refresh_header() -> void:
	if cash_label:
		cash_label.text = _money(cash)
	if income_label:
		income_label.text = "+ " + _money(total_income) + " / detik"
	if level_label:
		var level := 1 + int(owned.size() / 2)
		level_label.text = "LEVEL " + str(level).pad_zeros(2)

func _money(value: int) -> String:
	var digits := str(maxi(0, value))
	var out := ""
	for i in range(digits.length()):
		out += digits[i]
		if (digits.length() - i - 1) % 3 == 0 and i < digits.length() - 1:
			out += "."
	return "Rp " + out

func _short_money(value: int) -> String:
	if value >= 1000000000:
		return "%.1f M" % (float(value) / 1000000000.0)
	if value >= 1000000:
		return "%.0f jt" % (float(value) / 1000000.0)
	return "%.0f rb" % (float(value) / 1000.0)

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _panel(color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _place(control: Control, x: float, y: float, w: float, h: float) -> void:
	control.position = Vector2(x, y)
	control.size = Vector2(w, h)
	add_child(control)

func _save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "cash", cash)
	cfg.set_value("game", "owned", owned)
	cfg.save(SAVE_PATH)

func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	cash = int(cfg.get_value("game", "cash", START_CASH))
	var saved: Variant = cfg.get_value("game", "owned", [{"type":0,"level":1}])
	if saved is Array:
		owned.clear()
		for item in saved:
			if item is Dictionary and int(item.get("type", -1)) >= 0 and int(item.get("type", -1)) < BUSINESS_TYPES.size():
				owned.append({"type":int(item.type),"level":maxi(1,int(item.get("level",1)))})
		if owned.is_empty():
			owned.append({"type":0,"level":1})
