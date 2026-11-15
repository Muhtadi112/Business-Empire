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
	var load_factor := 1.0 - (cargo_weight / 8.0) * 0.28 if cargo_loaded else 1.0
	var desired_accel := throttle * TRUCK_ACCELERATION * load_factor
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
	_add_roadside_details()
	_add_warehouse()
	_add_box(self, Vector3(0, 0.15, -35), Vector3(0.5, 0.25, 250), Color(0.94, 0.76, 0.2))
	_add_box(self, Vector3(-5.85, 0.08, -35), Vector3(0.12, 0.08, 250), Color(0.95, 0.95, 0.86))
	_add_box(self, Vector3(5.85, 0.08, -35), Vector3(0.12, 0.08, 250), Color(0.95, 0.95, 0.86))

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
	# Pakai model Kenney sesuai zona; geometri prosedural hanya fallback.
	var pack := "commercial" if pos.z > -15.0 else ("suburban" if pos.z > -75.0 else "industrial")
	var prefix := "building-type-" if pack == "suburban" else "building-"
	var variant := String.chr(97 + int(abs(pos.x * 2.0 + pos.z)) % 6)
	if _add_kenney_model(pack, prefix + variant, Vector3(pos.x, 0.0, pos.z), Vector3(0.82, 0.82, 0.82)):
		return
	_add_box(self, pos, size, color)
	_add_box(self, Vector3(pos.x, pos.y + size.y * 0.5 + 0.12, pos.z), Vector3(size.x + 0.45, 0.24, size.z + 0.45), Color(0.24, 0.28, 0.3))
	var floors := maxi(1, int(size.y / 2.5))
	for floor_index in range(floors):
		for window_index in range(3):
			var wz := pos.z - size.z * 0.34 + window_index * size.z * 0.32
			_add_box(self, Vector3(pos.x + size.x * 0.501, 1.15 + floor_index * 2.35, wz), Vector3(0.07, 0.92, 1.15), Color(0.12, 0.28, 0.36))
			_add_box(self, Vector3(pos.x + size.x * 0.53, 1.15 + floor_index * 2.35, wz), Vector3(0.035, 0.08, 1.22), Color(0.72, 0.76, 0.72))
	_add_box(self, Vector3(pos.x + size.x * 0.505, 0.95, pos.z), Vector3(0.08, 1.8, 1.25), Color(0.22, 0.17, 0.12))
	_add_box(self, Vector3(pos.x + size.x * 0.54, 2.15, pos.z), Vector3(0.18, 0.18, size.z * 0.9), Color(0.85, 0.68, 0.28))

func _add_kenney_model(pack: String, model_name: String, pos: Vector3, model_scale: Vector3, yaw: float = 0.0) -> bool:
	var path := "res://assets/kenney_runtime/%s/%s.glb" % [pack, model_name]
	if not ResourceLoader.exists(path):
		return false
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("Model Kenney gagal dimuat: " + path)
		return false
	var instance := packed.instantiate() as Node3D
	if instance == null:
		return false
	instance.position = pos
	instance.scale = model_scale
	instance.rotation.y = yaw
	add_child(instance)
	return true

func _add_roadside_details() -> void:
	# Tile jalan Kenney disusun sepanjang koridor utama.
	for tile_index in range(25):
		var road_z := 85.0 - float(tile_index) * 10.0
		_add_kenney_model("roads", "road-straight", Vector3(0, 0.035, road_z), Vector3(1.0, 1.0, 1.0))
	for side in [-1, 1]:
		_add_box(self, Vector3(side * 8.8, 0.12, -35), Vector3(2.2, 0.22, 250), Color(0.58, 0.57, 0.51))
		for i in range(8):
			var z := 8.0 - float(i) * 24.0
			var x := float(side) * (13.5 + float(i % 2) * 2.0)
			_add_tree(Vector3(x, 0.0, z), 1.0 + float(i % 3) * 0.15)
			if i % 2 == 0:
				_add_streetlight(Vector3(float(side) * 7.8, 0.0, z - 7.0))
	_add_box(self, Vector3(0, 0.08, -14), Vector3(11.8, 0.12, 0.5), Color(0.92, 0.88, 0.72))
	_add_box(self, Vector3(0, 0.08, -56), Vector3(11.8, 0.12, 0.5), Color(0.92, 0.88, 0.72))
	_add_box(self, Vector3(-14.0, 2.5, -43), Vector3(0.25, 5.0, 0.25), Color(0.25, 0.27, 0.28))
	_add_box(self, Vector3(-14.0, 4.9, -43), Vector3(7.0, 1.5, 0.25), Color(0.78, 0.16, 0.12))
	_add_box(self, Vector3(-14.0, 4.9, -42.82), Vector3(5.8, 0.85, 0.04), Color(0.95, 0.88, 0.7))

func _add_tree(pos: Vector3, scale_value: float) -> void:
	var model := "tree-large" if scale_value > 1.1 else "tree-small"
	if _add_kenney_model("suburban", model, pos, Vector3.ONE * scale_value * 0.8):
		return
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18 * scale_value
	trunk_mesh.bottom_radius = 0.28 * scale_value
	trunk_mesh.height = 2.4 * scale_value
	trunk.mesh = trunk_mesh
	trunk.position = pos + Vector3(0, 1.2 * scale_value, 0)
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.34, 0.22, 0.13)
	trunk.material_override = bark
	add_child(trunk)
	var crown := MeshInstance3D.new()
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.35 * scale_value
	crown_mesh.height = 2.5 * scale_value
	crown.mesh = crown_mesh
	crown.position = pos + Vector3(0, 3.0 * scale_value, 0)
	var leaves := StandardMaterial3D.new()
	leaves.albedo_color = Color(0.16, 0.38, 0.2)
	crown.material_override = leaves
	add_child(crown)

func _add_streetlight(pos: Vector3) -> void:
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.055
	pole_mesh.bottom_radius = 0.09
	pole_mesh.height = 6.0
	pole.mesh = pole_mesh
	pole.position = pos + Vector3(0, 3.0, 0)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.22, 0.25, 0.27)
	pole.material_override = metal
	add_child(pole)
	_add_box(self, pos + Vector3(0.65, 5.85, 0), Vector3(1.35, 0.12, 0.22), Color(0.25, 0.28, 0.3))
	_add_box(self, pos + Vector3(1.15, 5.72, 0), Vector3(0.42, 0.08, 0.3), Color(0.95, 0.88, 0.62))

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
	var red := _make_material(Color(0.72, 0.12, 0.09), 0.32, 0.05)
	var dark_red := _make_material(Color(0.34, 0.055, 0.045), 0.48)
	var glass := _make_material(Color(0.09, 0.24, 0.31), 0.18, 0.35)
	var rubber := _make_material(Color(0.045, 0.05, 0.055), 0.92)
	var metal := _make_material(Color(0.48, 0.52, 0.54), 0.35, 0.55)
	var white := _make_material(Color(0.88, 0.87, 0.79), 0.55)
	# Chassis and cargo box: longer rigid truck silhouette.
	_add_truck_box(Vector3(0, 0.55, 0.85), Vector3(2.35, 0.45, 7.4), dark_red)
	_add_truck_box(Vector3(0, 1.85, 1.65), Vector3(2.45, 2.45, 5.15), white)
	_add_truck_box(Vector3(0, 3.12, 1.65), Vector3(2.5, 0.12, 5.22), metal)
	for side in [-1, 1]:
		_add_truck_box(Vector3(side * 1.24, 1.85, 1.65), Vector3(0.06, 2.45, 5.15), red)
		for z in [-0.65, 0.75, 2.15, 3.55]:
			_add_truck_box(Vector3(side * 1.28, 1.85, z), Vector3(0.04, 0.07, 0.07), metal)
	# Driver cabin, sloped-looking windscreen, bumper and grille.
	_add_truck_box(Vector3(0, 1.25, -2.35), Vector3(2.35, 1.25, 2.35), red)
	_add_truck_box(Vector3(0, 2.15, -2.28), Vector3(2.2, 0.8, 1.72), red)
	_add_truck_box(Vector3(0, 2.13, -3.16), Vector3(1.92, 0.68, 0.055), glass)
	_add_truck_box(Vector3(0, 1.52, -3.57), Vector3(1.65, 0.22, 0.12), dark_red)
	_add_truck_box(Vector3(0, 0.76, -3.58), Vector3(2.42, 0.32, 0.22), metal)
	_add_truck_box(Vector3(0, 1.08, -3.51), Vector3(0.95, 0.28, 0.08), dark_red)
	for side in [-1, 1]:
		_add_truck_box(Vector3(side * 0.88, 1.28, -3.55), Vector3(0.42, 0.28, 0.08), white)
		_add_truck_box(Vector3(side * 1.28, 2.05, -2.18), Vector3(0.48, 0.12, 0.12), dark_red)
		_add_truck_box(Vector3(side * 1.48, 2.05, -2.15), Vector3(0.08, 0.62, 0.08), metal)
		_add_truck_box(Vector3(side * 1.48, 2.36, -2.15), Vector3(0.3, 0.22, 0.12), glass)
		_add_truck_box(Vector3(side * 1.22, 1.1, 3.2), Vector3(0.08, 0.3, 4.7), Color(0.9,0.2,0.12))
	# Wheels with visible hubs on both axles.
	for x in [-1.25, 1.25]:
		for z in [-2.35, 2.0, 3.15]:
			var wheel := MeshInstance3D.new()
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.52
			wheel_mesh.bottom_radius = 0.52
			wheel_mesh.height = 0.34
			wheel.mesh = wheel_mesh
			wheel.rotation.z = PI / 2.0
			wheel.position = Vector3(x, 0.12, z)
			wheel.material_override = rubber
			truck.add_child(wheel)
			var hub := MeshInstance3D.new()
			var hub_mesh := CylinderMesh.new()
			hub_mesh.top_radius = 0.23
			hub_mesh.bottom_radius = 0.23
			hub_mesh.height = 0.36
			hub.mesh = hub_mesh
			hub.rotation.z = PI / 2.0
			hub.position = Vector3(x * 1.01, 0.12, z)
			hub.material_override = metal
			truck.add_child(hub)
	# Rear lamps and reflective strips.
	for side in [-1, 1]:
		_add_truck_box(Vector3(side * 0.92, 1.0, 4.27), Vector3(0.24, 0.48, 0.08), Color(0.8,0.06,0.04))
		_add_truck_box(Vector3(side * 0.92, 1.0, 4.32), Vector3(0.12, 0.2, 0.04), Color(1.0,0.72,0.12))
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.7, 2.5, 8.0)
	collision.shape = shape
	collision.position = Vector3(0, 0.85, 0.45)
	truck.add_child(collision)

func _make_material(color: Color, roughness_value: float = 0.7, metallic_value: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness_value
	material.metallic = metallic_value
	return material

func _add_truck_box(pos: Vector3, size: Vector3, material_or_color) -> void:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = pos
	if material_or_color is Material:
		part.material_override = material_or_color
	else:
		part.material_override = _make_material(material_or_color)
	truck.add_child(part)

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
	status_label = _make_label("TRUK SIAP • PILIH MUATAN DAN AMBIL KONTRAK", Vector2(36, 58), 14, Color.WHITE, root)
	cargo_label = _make_label("MUATAN: PAKET ELEKTRONIK • 2 TON", Vector2(36, 108), 14, Color(0.95, 0.82, 0.4), root)
	vehicle_label = _make_label("BBM 100%   •   KONDISI 100%", Vector2(36, 88), 14, Color.WHITE, root)
	speed_label = _make_label("0 KM/J", Vector2(1090, 30), 24, Color.WHITE, root)

	cargo_button = Button.new()
	cargo_button.text = "GANTI JENIS MUATAN"
	cargo_button.position = Vector2(18, 230)
	cargo_button.size = Vector2(260, 48)
	cargo_button.add_theme_font_size_override("font_size", 15)
	cargo_button.pressed.connect(_on_cargo_pressed)
	root.add_child(cargo_button)

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

func _on_cargo_pressed() -> void:
	if contract_active:
		status_label.text = "MUATAN SEDANG DIKIRIM • SELESAIKAN KONTRAK DULU"
		return
	cargo_index = (cargo_index + 1) % CARGO_NAMES.size()
	cargo_weight = CARGO_WEIGHTS[cargo_index]
	cargo_reward = CARGO_REWARDS[cargo_index]
	cargo_label.text = "MUATAN: " + CARGO_NAMES[cargo_index] + " • " + str(int(cargo_weight)) + " TON"
	contract_button.text = "AMBIL KONTRAK • Rp" + _format_money(cargo_reward + completed_deliveries * 1500000)
	status_label.text = "MUATAN DIPILIH • " + CARGO_NAMES[cargo_index]
	_save_game()

func _on_contract_pressed() -> void:
	if truck_condition <= 0.0:
		status_label.text = "TRUK RUSAK TOTAL • KEMBALI KE DEPOT UNTUK SERVIS"
		return
	if fuel <= 0.0:
		status_label.text = "BBM HABIS • KEMBALI KE DEPOT UNTUK ISI BBM"
		return
	if not contract_active:
		contract_active = true
		cargo_loaded = true
		cargo_button.disabled = true
		contract_button.text = "TUJUAN: GUDANG • ANTARKAN BARANG"
		status_label.text = "KONTRAK AKTIF • ANTARKAN " + CARGO_NAMES[cargo_index] + " KE GUDANG"
		warehouse_marker.visible = true
	else:
		status_label.text = "KONTRAK SEDANG BERJALAN • IKUTI PENANDA HIJAU"

func _complete_contract() -> void:
	contract_active = false
	cargo_loaded = false
	cargo_button.disabled = false
	contract_done = true
	completed_deliveries += 1
	var reward := cargo_reward + maxi(0, completed_deliveries - 1) * 1500000
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
	data.set_value("company", "deliveries", completed_deliveries)
	data.set_value("company", "cargo_index", cargo_index)
	data.set_value("vehicle", "fuel", fuel)
	data.set_value("vehicle", "condition", truck_condition)
	var error := data.save("user://business_empire_save.cfg")
	if error != OK:
		push_warning("Gagal menyimpan progres: " + str(error))

func _load_game() -> void:
	var data := ConfigFile.new()
	if data.load("user://business_empire_save.cfg") == OK:
		cash = int(data.get_value("company", "cash", STARTING_CASH))
		completed_deliveries = int(data.get_value("company", "deliveries", 0))
		cargo_index = clampi(int(data.get_value("company", "cargo_index", 0)), 0, CARGO_NAMES.size() - 1)
		cargo_weight = CARGO_WEIGHTS[cargo_index]
		cargo_reward = CARGO_REWARDS[cargo_index]
		fuel = clampf(float(data.get_value("vehicle", "fuel", 100.0)), 0.0, 100.0)
		truck_condition = clampf(float(data.get_value("vehicle", "condition", 100.0)), 0.0, 100.0)

func _update_hud() -> void:
	if cargo_label:
		cargo_label.text = "MUATAN: " + CARGO_NAMES[cargo_index] + " • " + str(int(cargo_weight)) + " TON"
	if contract_button and not contract_active:
		contract_button.text = "AMBIL KONTRAK • Rp" + _format_money(cargo_reward + completed_deliveries * 1500000)
	if cargo_button:
		cargo_button.disabled = contract_active
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
