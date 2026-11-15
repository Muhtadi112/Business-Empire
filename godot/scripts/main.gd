extends Node3D

const STARTING_CASH := 50000000
const CONTRACT_REWARD := 12500000
const TRUCK_ACCELERATION := 10.0
const MAX_SPEED := 25.0
const TURN_RATE := 1.35
const CARGO_NAMES := ["PAKET ELEKTRONIK", "BAHAN BANGUNAN", "HASIL PERTANIAN"]
const CARGO_WEIGHTS := [2.0, 8.0, 5.0]
const CARGO_REWARDS := [12500000, 18500000, 15000000]

var cash: int = STARTING_CASH
var contract_active := false
var contract_done := false
var completed_deliveries := 0
var cargo_index := 0
var cargo_weight := 2.0
var cargo_reward := 12500000
var cargo_loaded := false
var fuel := 100.0
var truck_condition := 100.0
var impact_cooldown := 0.0
var autosave_timer := 0.0
var speed := 0.0
var throttle := 0.0
var steering := 0.0
var truck: CharacterBody3D
var camera: Camera3D
var camera_first_person := false
var cash_label: Label
var status_label: Label
var speed_label: Label
var vehicle_label: Label
var service_button: Button
var contract_button: Button
var camera_button: Button
var cargo_button: Button
var cargo_label: Label
var warehouse_marker: MeshInstance3D
var target_position := Vector3(0, 0, -95.0)
var joystick_vector := Vector2.ZERO
var touch_origin := Vector2.ZERO
var joystick_touch := -1

func _ready() -> void:
	_load_game()
	_build_world()
	_build_truck()
	_build_camera()
	_build_hud()
	_update_hud()

func _physics_process(delta: float) -> void:
	if truck == null:
		return
	var steer_input := steering
	if joystick_vector.length() > 0.12:
		throttle = -joystick_vector.y
		steer_input = joystick_vector.x
	impact_cooldown = maxf(0.0, impact_cooldown - delta)
	if fuel <= 0.0 or truck_condition <= 0.0:
		throttle = 0.0
	var desired_accel := throttle * TRUCK_ACCELERATION
	speed = move_toward(speed, desired_accel * MAX_SPEED / TRUCK_ACCELERATION, TRUCK_ACCELERATION * delta)
	if abs(throttle) < 0.05:
		speed = move_toward(speed, 0.0, 2.8 * delta)
	if abs(speed) > 0.25:
		truck.rotate_y(-steer_input * TURN_RATE * delta * sign(speed))
	truck.velocity = -truck.global_basis.z * speed
	truck.velocity.y = -9.8
	truck.move_and_slide()
	fuel = maxf(0.0, fuel - abs(speed) * delta * 0.004)
	if abs(speed) > 12.0 and impact_cooldown <= 0.0:
		for collision_index in range(truck.get_slide_collision_count()):
			var impact := truck.get_slide_collision(collision_index)
			if abs(impact.get_normal().y) < 0.6:
				truck_condition = maxf(0.0, truck_condition - minf(12.0, abs(speed) * 0.35))
				impact_cooldown = 1.2
				status_label.text = "BENTURAN! KONDISI TRUK " + str(roundi(truck_condition)) + "%"
				break
	if truck_condition <= 0.0:
		speed = move_toward(speed, 0.0, 12.0 * delta)
	if vehicle_label:
		vehicle_label.text = "BBM " + str(roundi(fuel)) + "%   •   KONDISI " + str(roundi(truck_condition)) + "%"
	if camera:
		if camera_first_person:
			var cab_position := truck.global_position + truck.global_basis * Vector3(0, 2.15, -0.65)
			camera.global_position = camera.global_position.lerp(cab_position, min(1.0, delta * 7.0))
			camera.look_at(cab_position + (-truck.global_basis.z * 30.0) + Vector3(0, -0.15, 0), Vector3.UP)
		else:
			var camera_target := truck.global_position + truck.global_basis * Vector3(0, 5.2, 10.5)
			camera.global_position = camera.global_position.lerp(camera_target, min(1.0, delta * 4.0))
			camera.look_at(truck.global_position + Vector3(0, 1.5, 0), Vector3.UP)
	if contract_active and truck.global_position.distance_to(target_position) < 13.0:
		_complete_contract()
	_update_speed_label()
	autosave_timer += delta
	if autosave_timer >= 10.0:
		_save_game()
		autosave_timer = 0.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _build_world() -> void:
	var world_env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.17, 0.35, 0.55)
	sky_material.sky_horizon_color = Color(0.65, 0.78, 0.86)
	environment.sky.sky_material = sky_material
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.78, 0.86)
	environment.ambient_light_energy = 0.8
	world_env.environment = environment
	add_child(world_env)

	_add_box(self, Vector3(0, -0.6, -35), Vector3(220, 1, 260), Color(0.25, 0.42, 0.25))
	var ground_body := StaticBody3D.new()
	ground_body.position = Vector3(0, -0.6, -35)
	var ground_collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(220, 1, 260)
	ground_collision.shape = ground_shape
	ground_body.add_child(ground_collision)
	add_child(ground_body)
	_add_box(self, Vector3(0, -0.05, -35), Vector3(12, 0.12, 250), Color(0.12, 0.13, 0.14))
	for z in range(15, -151, -12):
		_add_box(self, Vector3(0, 0.025, z), Vector3(0.18, 0.025, 5.0), Color(0.92, 0.86, 0.55))
	for side in [-1, 1]:
		_add_box(self, Vector3(side * 7.5, 0.0, -35), Vector3(2.0, 0.12, 250), Color(0.48, 0.48, 0.43))
		for i in range(9):
			var zpos := 10.0 - float(i) * 22.0
			var x := float(side) * (19.0 + float(i % 3) * 7.0)
			var size := Vector3(12.0 + float(i % 2) * 4.0, 7.0 + float(i % 3) * 2.0, 12.0)
			_add_building(Vector3(x, size.y / 2.0 - 0.1, zpos), size, [Color(0.72,0.68,0.57), Color(0.57,0.68,0.72), Color(0.69,0.61,0.52)][i % 3])
	_add_warehouse()
	_add_box(self, Vector3(0, 0.15, -35), Vector3(0.5, 0.25, 250), Color(0.94, 0.76, 0.2))

func _add_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance

func _add_building(pos: Vector3, size: Vector3, color: Color) -> void:
	_add_box(self, pos, size, color)
	for floor_index in range(maxi(1, int(size.y / 2.5))):
		for window_index in range(2):
			_add_box(self, Vector3(pos.x, 1.2 + floor_index * 2.5, pos.z + (window_index - 0.5) * 3.2 - size.z * 0.28), Vector3(0.08, 0.85, 1.4), Color(0.19, 0.35, 0.43))

func _add_warehouse() -> void:
	_add_box(self, Vector3(0, 3.0, -103), Vector3(24, 6, 20), Color(0.55, 0.59, 0.62))
	_add_box(self, Vector3(0, 0.4, -92.8), Vector3(8, 0.8, 0.3), Color(0.17, 0.2, 0.22))
	_add_box(self, Vector3(-6, 1.8, -92.5), Vector3(3.5, 3.6, 0.25), Color(0.22, 0.34, 0.42))
	warehouse_marker = _add_box(self, target_position, Vector3(10, 0.15, 10), Color(0.2, 0.8, 0.45))
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color(0.1, 0.9, 0.4, 0.35)
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	warehouse_marker.material_override = marker_material
	warehouse_marker.visible = false

func _build_truck() -> void:
	truck = CharacterBody3D.new()
	truck.position = Vector3(0, 0.8, 12)
	add_child(truck)
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(0.78, 0.16, 0.12)
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(2.5, 1.2, 4.8)
	body.mesh = body_mesh
	body.position = Vector3(0, 0.45, 0)
	body.material_override = body_material
	truck.add_child(body)
	var cabin := MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(2.25, 1.45, 1.7)
	cabin.mesh = cabin_mesh
	cabin.position = Vector3(0, 1.65, -1.25)
	cabin.material_override = body_material
	truck.add_child(cabin)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.18, 0.34, 0.42)
	glass.metallic = 0.2
	var windshield := MeshInstance3D.new()
	var glass_mesh := BoxMesh.new()
	glass_mesh.size = Vector3(2.0, 0.85, 0.06)
	windshield.mesh = glass_mesh
	windshield.position = Vector3(0, 1.75, -2.12)
	windshield.material_override = glass
	truck.add_child(windshield)
	for x in [-1.25, 1.25]:
		for z in [-1.5, 1.5]:
			var wheel := MeshInstance3D.new()
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.48
			wheel_mesh.bottom_radius = 0.48
			wheel_mesh.height = 0.32
			wheel.mesh = wheel_mesh
			wheel.rotation.z = PI / 2.0
			wheel.position = Vector3(x, 0.1, z)
			var rubber := StandardMaterial3D.new()
			rubber.albedo_color = Color(0.07, 0.07, 0.075)
			wheel.material_override = rubber
			truck.add_child(wheel)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.5, 2.4, 4.8)
	collision.shape = shape
	collision.position.y = 0.8
	truck.add_child(collision)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(0, 6, 23)
	camera.current = true
	camera.fov = 72
	add_child(camera)
	camera.look_at(truck.global_position, Vector3.UP)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	var top_panel := ColorRect.new()
	top_panel.color = Color(0.035, 0.07, 0.1, 0.88)
	top_panel.position = Vector2(18, 16)
	top_panel.size = Vector2(430, 88)
	root.add_child(top_panel)
	cash_label = _make_label("KAS PERUSAHAAN", Vector2(36, 24), 18, Color(0.35, 0.95, 0.68), root)
	status_label = _make_label("TRUK SIAP • PILIH MUATAN DAN AMBIL KONTRAK", Vector2(36, 58), 14, Color.WHITE, root)\n\tcargo_label = _make_label("MUATAN: PAKET ELEKTRONIK • 2 TON", Vector2(36, 108), 14, Color(0.95, 0.82, 0.4), root)
	vehicle_label = _make_label("BBM 100%   •   KONDISI 100%", Vector2(36, 88), 14, Color.WHITE, root)
	speed_label = _make_label("0 KM/J", Vector2(1090, 30), 24, Color.WHITE, root)

	contract_button = Button.new()
	contract_button.text = "AMBIL KONTRAK • Rp12,5 JT"
	contract_button.position = Vector2(850, 85)
	contract_button.size = Vector2(390, 58)
	contract_button.add_theme_font_size_override("font_size", 19)
	contract_button.pressed.connect(_on_contract_pressed)
	root.add_child(contract_button)

	camera_button = Button.new()
	camera_button.text = "KAMERA: ORANG KETIGA"
	camera_button.position = Vector2(18, 118)
	camera_button.size = Vector2(260, 48)
	camera_button.add_theme_font_size_override("font_size", 15)
	camera_button.pressed.connect(_toggle_camera)
	root.add_child(camera_button)

	service_button = Button.new()
	service_button.text = "SERVIS & ISI BBM"
	service_button.position = Vector2(18, 174)
	service_button.size = Vector2(260, 48)
	service_button.add_theme_font_size_override("font_size", 15)
	service_button.pressed.connect(_service_truck)
	root.add_child(service_button)

	_make_control_button("◀", Vector2(35, 570), Vector2(90, 90), func(): steering = -1.0, func(): steering = 0.0, root)
	_make_control_button("▶", Vector2(235, 570), Vector2(90, 90), func(): steering = 1.0, func(): steering = 0.0, root)
	_make_control_button("▲ GAS", Vector2(1080, 565), Vector2(150, 100), func(): throttle = 1.0, func(): throttle = 0.0, root)
	_make_control_button("▼ REM", Vector2(900, 565), Vector2(150, 100), func(): throttle = -0.65, func(): throttle = 0.0, root)
	var hint := _make_label("KENDALIKAN TRUK • ANTARKAN MUATAN KE GUDANG", Vector2(420, 655), 13, Color(0.9, 0.94, 0.96), root)
	hint.size = Vector2(450, 28)

func _make_label(text_value: String, pos: Vector2, font_size: int, color: Color, parent: Control) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _make_control_button(caption: String, pos: Vector2, button_size: Vector2, on_down: Callable, on_up: Callable, parent: Control) -> void:
	var button := Button.new()
	button.text = caption
	button.position = pos
	button.size = button_size
	button.add_theme_font_size_override("font_size", 23)
	button.button_down.connect(on_down)
	button.button_up.connect(on_up)
	parent.add_child(button)

func _toggle_camera() -> void:
	camera_first_person = not camera_first_person
	camera_button.text = "KAMERA: KABIN" if camera_first_person else "KAMERA: ORANG KETIGA"
	if status_label:
		status_label.text = "KAMERA KABIN • PANDANGAN PENGEMUDI" if camera_first_person else "KAMERA EKSTERNAL • ORANG KETIGA"

func _on_contract_pressed() -> void:
	if truck_condition <= 0.0:
		status_label.text = "TRUK RUSAK TOTAL • KEMBALI KE DEPOT UNTUK SERVIS"
		return
	if fuel <= 0.0:
		status_label.text = "BBM HABIS • KEMBALI KE DEPOT UNTUK ISI BBM"
		return
	if not contract_active:
		contract_active = true
		contract_button.text = "TUJUAN: GUDANG • ANTARKAN BARANG"
		status_label.text = "MUATAN DIAMBIL • MENUJU GUDANG"
		warehouse_marker.visible = true
	else:
		status_label.text = "KONTRAK SEDANG BERJALAN • IKUTI PENANDA HIJAU"

func _complete_contract() -> void:
	contract_active = false
	contract_done = true
	completed_deliveries += 1
	var reward := CONTRACT_REWARD + maxi(0, completed_deliveries - 1) * 1500000
	cash += reward
	warehouse_marker.visible = false
	status_label.text = "PENGIRIMAN #" + str(completed_deliveries) + " BERHASIL • +Rp" + _format_money(reward)
	contract_button.text = "AMBIL KONTRAK • Rp" + _format_money(cargo_reward + completed_deliveries * 1500000)
	contract_done = false
	_save_game()
	_update_hud()

func _service_truck() -> void:
	if truck.global_position.distance_to(Vector3(0, 0.8, 12)) > 18.0:
		status_label.text = "DEPOT TERLALU JAUH • KEMBALI KE AREA AWAL"
		return
	var service_cost := int((100.0 - fuel) * 3500.0 + (100.0 - truck_condition) * 85000.0)
	if service_cost > cash:
		status_label.text = "KAS TIDAK CUKUP • BIAYA SERVIS Rp" + _format_money(service_cost)
		return
	cash -= service_cost
	fuel = 100.0
	truck_condition = 100.0
	status_label.text = "TRUK SELESAI DISERVIS • BIAYA Rp" + _format_money(service_cost)
	_save_game()
	_update_hud()

func _save_game() -> void:
	var data := ConfigFile.new()
	data.set_value("company", "cash", cash)
	data.set_value("company", "deliveries", completed_deliveries)\n\tdata.set_value("company", "cargo_index", cargo_index)
	data.set_value("vehicle", "fuel", fuel)
	data.set_value("vehicle", "condition", truck_condition)
	var error := data.save("user://business_empire_save.cfg")
	if error != OK:
		push_warning("Gagal menyimpan progres: " + str(error))

func _load_game() -> void:
	var data := ConfigFile.new()
	if data.load("user://business_empire_save.cfg") == OK:
		cash = int(data.get_value("company", "cash", STARTING_CASH))
		completed_deliveries = int(data.get_value("company", "deliveries", 0))\n\t\tcargo_index = clampi(int(data.get_value("company", "cargo_index", 0)), 0, CARGO_NAMES.size() - 1)\n\t\tcargo_weight = CARGO_WEIGHTS[cargo_index]\n\t\tcargo_reward = CARGO_REWARDS[cargo_index]
		fuel = clampf(float(data.get_value("vehicle", "fuel", 100.0)), 0.0, 100.0)
		truck_condition = clampf(float(data.get_value("vehicle", "condition", 100.0)), 0.0, 100.0)

func _update_hud() -> void:
	if cash_label:
		cash_label.text = "KAS PERUSAHAAN  •  Rp" + _format_money(cash) + "   |   PENGIRIMAN " + str(completed_deliveries)
	if vehicle_label:
		vehicle_label.text = "BBM " + str(roundi(fuel)) + "%   •   KONDISI " + str(roundi(truck_condition)) + "%"

func _update_speed_label() -> void:
	if speed_label:
		speed_label.text = str(roundi(abs(speed) * 3.6)) + " KM/J"

func _format_money(value: int) -> String:
	var raw := str(value)
	var result := ""
	var count := 0
	for index in range(raw.length() - 1, -1, -1):
		result = raw[index] + result
		count += 1
		if count % 3 == 0 and index > 0:
			result = "." + result
	return result
