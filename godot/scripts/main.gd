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
var target_position := Vector3(0, 0, -185.0)
var joystick_vector := Vector2.ZERO
var touch_origin := Vector2.ZERO
var joystick_touch := -1
var pause_panel: PanelContainer
var pause_button: Button

func _ready() -> void:
	_load_game()
	_build_world()
	_build_truck()
	_build_camera()
	_build_hud()
	_update_hud()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < 420.0 and event.position.y > 420.0 and joystick_touch == -1:
				joystick_touch = event.index
				touch_origin = event.position
				joystick_vector = Vector2.ZERO
		elif event.index == joystick_touch:
			joystick_touch = -1
			joystick_vector = Vector2.ZERO
	elif event is InputEventScreenDrag and event.index == joystick_touch:
		var drag: Vector2 = (event.position - touch_origin) / 82.0
		joystick_vector = Vector2(clampf(drag.x, -1.0, 1.0), clampf(drag.y, -1.0, 1.0))

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
	# MAP: kota kecil Indonesia dengan koridor utama, pusat komersial,
	# kawasan permukiman, industri, dan terminal logistik.
	var world_env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.16, 0.32, 0.49)
	sky_material.sky_horizon_color = Color(0.72, 0.79, 0.82)
	environment.sky.sky_material = sky_material
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.78, 0.81, 0.82)
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_env.environment = environment
	add_child(world_env)

	# Tanah utama dan bidang rumput di luar kota.
	_add_box(self, Vector3(0, -0.65, -75), Vector3(260, 1.2, 430), Color(0.27, 0.39, 0.25))
	var ground_body := StaticBody3D.new()
	ground_body.position = Vector3(0, -0.65, -75)
	var ground_collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(260, 1.2, 430)
	ground_collision.shape = ground_shape
	ground_body.add_child(ground_collision)
	add_child(ground_body)

	# Jalan arteri utama dua arah.
	_add_box(self, Vector3(0, -0.015, -75), Vector3(13.5, 0.12, 410), Color(0.105, 0.115, 0.12))
	_add_box(self, Vector3(-7.1, 0.0, -75), Vector3(1.0, 0.14, 410), Color(0.48, 0.46, 0.39))
	_add_box(self, Vector3(7.1, 0.0, -75), Vector3(1.0, 0.14, 410), Color(0.48, 0.46, 0.39))
	for z in range(125, -276, -10):
		_add_box(self, Vector3(0, 0.065, float(z)), Vector3(0.16, 0.025, 4.5), Color(0.94, 0.82, 0.48))
	for side in [-1, 1]:
		_add_box(self, Vector3(float(side) * 6.55, 0.075, -75), Vector3(0.12, 0.035, 410), Color(0.9, 0.9, 0.82))

	# Jalan penghubung ke blok kota pada tiga distrik.
	for z in [-28.0, -78.0, -128.0, -178.0, -228.0]:
		_add_box(self, Vector3(0, 0.015, z), Vector3(100, 0.12, 8.0), Color(0.13, 0.14, 0.145))
		for x in range(-45, 46, 8):
			_add_box(self, Vector3(float(x), 0.09, z), Vector3(3.5, 0.025, 0.16), Color(0.88, 0.84, 0.72))

	# Trotoar, jalur hijau, lampu jalan dan pohon peneduh.
	for side in [-1, 1]:
		_add_box(self, Vector3(float(side) * 8.6, 0.10, -75), Vector3(2.0, 0.22, 410), Color(0.55, 0.54, 0.48))
		_add_box(self, Vector3(float(side) * 11.0, 0.015, -75), Vector3(2.8, 0.12, 410), Color(0.31, 0.43, 0.27))
		for i in range(17):
			var zpos := 115.0 - float(i) * 23.0
			_add_tree(Vector3(float(side) * (10.6 + float(i % 2) * 1.2), 0.0, zpos), 0.95 + float(i % 3) * 0.12)
			if i % 2 == 0:
				_add_streetlight(Vector3(float(side) * 8.0, 0.0, zpos - 8.0))

	# Pusat komersial: ruko dan bangunan usaha.
	for i in range(6):
		var zc := 8.0 - float(i) * 12.0
		for side in [-1, 1]:
			var x := float(side) * (22.0 + float(i % 2) * 5.0)
			_add_building(Vector3(x, 0.0, zc), Vector3(11, 9, 10), Color(0.68, 0.67, 0.59))
	# Detail fasad pusat komersial dari kit Kenney.
	for i in range(4):
		_add_kenney_model("commercial", "detail-awning-wide" if i % 2 == 0 else "detail-awning", Vector3(-25.0 + float(i) * 12.0, 0.0, -5.0 - float(i % 2) * 12.0), Vector3(0.8, 0.8, 0.8))
	# Area parkir dan marka depan pertokoan.
	_add_box(self, Vector3(25, 0.025, -23), Vector3(30, 0.12, 18), Color(0.19, 0.20, 0.20))
	for i in range(7):
		_add_box(self, Vector3(12.5 + float(i) * 4.1, 0.10, -23), Vector3(0.12, 0.025, 12), Color(0.88, 0.88, 0.82))

	# Permukiman: rumah lebih renggang, pepohonan, pagar dan halaman.
	for i in range(6):
		var zs := -55.0 - float(i) * 12.0
		for side in [-1, 1]:
			var x := float(side) * (25.0 + float(i % 2) * 10.0)
			_add_building(Vector3(x, 0.0, zs), Vector3(10, 6, 9), Color(0.72, 0.64, 0.51))
			_add_tree(Vector3(x + float(side) * 8.0, 0.0, zs - 3.0), 0.9)
			_add_kenney_model("suburban", "fence-low", Vector3(x + float(side) * 5.5, 0.0, zs + 5.0), Vector3(0.65, 0.65, 0.65))

	# Zona industri: gudang, workshop dan halaman truk.
	for i in range(5):
		var zi := -145.0 - float(i) * 16.0
		for side in [-1, 1]:
			var x := float(side) * (27.0 + float(i % 2) * 7.0)
			_add_building(Vector3(x, 0.0, zi), Vector3(17, 8, 15), Color(0.49, 0.55, 0.57))
	_add_box(self, Vector3(0, 0.04, -190), Vector3(74, 0.14, 34), Color(0.22, 0.23, 0.22))
	for i in range(9):
		_add_box(self, Vector3(-31.0 + float(i) * 7.5, 0.13, -190), Vector3(0.13, 0.025, 24), Color(0.91, 0.82, 0.48))

	# Model jalan modular Kenney sebagai detail visual pada persimpangan.
	for z in [-28.0, -78.0, -128.0, -178.0]:
		_add_kenney_model("roads", "road-straight", Vector3(0, 0.09, z), Vector3(0.45, 0.45, 0.45))

	_add_roadside_details()
	_add_district_signs()
	_add_warehouse()

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
	# Semua varian di bawah sudah diverifikasi dari inventaris ZIP Kenney.
	var pack := "commercial" if pos.z > -15.0 else ("suburban" if pos.z > -75.0 else "industrial")
	var prefix := "building-type-" if pack == "suburban" else "building-"
	var variant := String.chr(97 + int(abs(pos.x * 2.0 + pos.z)) % 6)
	if not _add_kenney_model(pack, prefix + variant, Vector3(pos.x, 0.0, pos.z), Vector3(0.82, 0.82, 0.82)):
		_add_procedural_building(pos, size, color, int(abs(pos.x + pos.z)) % 3)

func _add_procedural_building(pos: Vector3, size: Vector3, wall_color: Color, style_index: int) -> void:
	# Fallback visual permanen agar blok kota tetap terisi saat model eksternal gagal dimuat.
	var center := pos + Vector3(0.0, size.y * 0.5, 0.0)
	_add_box(self, center, size, wall_color)
	_add_box(self, center + Vector3(0.0, size.y * 0.5 + 0.12, 0.0), Vector3(size.x + 0.45, 0.24, size.z + 0.45), Color(0.19, 0.23, 0.25))
	var road_side := -1.0 if pos.x > 0.0 else 1.0
	var facade_x := pos.x + road_side * (size.x * 0.5 + 0.045)
	var glass_material := Color("#8fb8c3") if style_index != 1 else Color("#d4c38b")
	var floors := maxi(1, int(size.y / 2.5))
	for floor_index in range(floors):
		var window_y := 1.1 + float(floor_index) * 2.2
		if window_y > size.y - 0.45:
			continue
		for window_index in range(2):
			var window_z := pos.z - size.z * 0.25 + float(window_index) * size.z * 0.5
			_add_box(self, Vector3(facade_x, window_y, window_z), Vector3(0.09, 1.1, maxf(0.8, size.z * 0.22)), glass_material)
	_add_box(self, Vector3(facade_x, 0.9, pos.z + size.z * 0.28), Vector3(0.1, 1.8, 1.1), Color("#34434a"))

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
	# Papan petunjuk distrik di sisi jalan.
	_add_box(self, Vector3(-16.0, 2.6, -42), Vector3(0.22, 5.2, 0.22), Color(0.24, 0.26, 0.27))
	_add_box(self, Vector3(-16.0, 4.7, -42), Vector3(8.0, 1.6, 0.28), Color(0.12, 0.31, 0.27))
	_add_box(self, Vector3(-16.0, 4.72, -41.82), Vector3(7.1, 0.9, 0.035), Color(0.9, 0.87, 0.72))
	# Pembatas jalan dan drainase di pinggir arteri.
	for side in [-1, 1]:
		_add_box(self, Vector3(float(side) * 12.7, 0.12, -75), Vector3(0.22, 0.24, 410), Color(0.39, 0.4, 0.37))
	# Marka zebra cross pada persimpangan.
	for z in [-28.0, -78.0, -128.0, -178.0]:
		for i in range(7):
			_add_box(self, Vector3(-4.5 + float(i) * 1.5, 0.105, z - 5.0), Vector3(0.85, 0.025, 1.2), Color(0.88, 0.88, 0.82))

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

func _add_district_signs() -> void:
	_add_district_sign("KAWASAN NIAGA", Vector3(-22.0, 0.0, -15.0), Color("#dca84d"))
	_add_district_sign("PERMUKIMAN", Vector3(22.0, 0.0, -88.0), Color("#5d9d75"))
	_add_district_sign("KAWASAN INDUSTRI", Vector3(-22.0, 0.0, -145.0), Color("#668da5"))
	# Traffic signal poles to make major intersections easier to read.
	for z in [-78.0, -128.0]:
		for side in [-1, 1]:
			var x := float(side) * 7.8
			_add_box(self, Vector3(x, 2.0, z - 5.0), Vector3(0.16, 4.0, 0.16), Color("#30383a"))
			_add_box(self, Vector3(x, 3.5, z - 5.0), Vector3(0.65, 1.65, 0.55), Color("#202729"))
			_add_box(self, Vector3(x, 4.0, z - 4.7), Vector3(0.28, 0.28, 0.12), Color("#a83e35"))
			_add_box(self, Vector3(x, 3.5, z - 4.7), Vector3(0.28, 0.28, 0.12), Color("#d5a944"))
			_add_box(self, Vector3(x, 3.0, z - 4.7), Vector3(0.28, 0.28, 0.12), Color("#39945d"))

func _add_district_sign(caption: String, pos: Vector3, accent_color: Color) -> void:
	_add_box(self, pos + Vector3(0, 2.1, 0), Vector3(0.18, 4.2, 0.18), Color("#353d3c"))
	_add_box(self, pos + Vector3(0, 4.0, 0), Vector3(8.8, 1.35, 0.28), Color("#182a2d"))
	_add_box(self, pos + Vector3(0, 4.0, -0.17), Vector3(8.1, 0.92, 0.035), accent_color)
	var sign_label := Label3D.new()
	sign_label.text = caption
	sign_label.font_size = 44
	sign_label.pixel_size = 0.012
	sign_label.modulate = Color("#172329")
	sign_label.position = pos + Vector3(0, 3.78, -0.22)
	add_child(sign_label)

func _add_warehouse() -> void:
	# Terminal distribusi: model industri Kenney, kontainer, tangki dan area parkir.
	_add_box(self, Vector3(0, 0.10, -185), Vector3(76, 0.2, 42), Color(0.24, 0.25, 0.24))
	_add_kenney_model("industrial", "building-t", Vector3(0, 0, -205), Vector3(1.35, 1.35, 1.35))
	_add_kenney_model("industrial", "detail-tank-large", Vector3(-22, 0, -207), Vector3(1.2, 1.2, 1.2))
	_add_kenney_model("industrial", "detail-tank", Vector3(22, 0, -207), Vector3(1.4, 1.4, 1.4))
	_add_kenney_model("industrial", "chimney-large", Vector3(-16, 0, -222), Vector3(1.1, 1.1, 1.1))
	for i in range(3):
		var container_name: String = ["shipping-container-a", "shipping-container-b", "shipping-container-c"][i]
		_add_kenney_model("industrial", container_name, Vector3(-25.0 + float(i) * 12.0, 0.0, -177.0), Vector3(1.2, 1.2, 1.2))
	# Pagar perimeter terminal.
	for x in range(-38, 39, 4):
		for z in [-225, -165]:
			_add_box(self, Vector3(float(x), 1.0, float(z)), Vector3(0.12, 2.0, 0.12), Color(0.3, 0.33, 0.33))
	for z in range(-225, -164, 4):
		for x in [-38.0, 38.0]:
			_add_box(self, Vector3(x, 1.0, float(z)), Vector3(0.12, 2.0, 0.12), Color(0.3, 0.33, 0.33))
	_add_box(self, Vector3(0, 1.9, -165), Vector3(11, 3.8, 0.25), Color(0.14, 0.28, 0.24))
	# Marker area bongkar muat.
	warehouse_marker = _add_box(self, target_position, Vector3(12, 0.16, 12), Color(0.2, 0.8, 0.45))
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
	root.process_mode = Node.PROCESS_MODE_ALWAYS
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
	pause_button = Button.new()
	pause_button.text = "Ⅱ  PAUSE"
	pause_button.position = Vector2(1080, 82)
	pause_button.size = Vector2(150, 48)
	pause_button.add_theme_font_size_override("font_size", 16)
	pause_button.pressed.connect(_toggle_pause)
	root.add_child(pause_button)
	_build_pause_panel(root)

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

	var steer_hint := _make_label("JOYSTICK KEMUDI", Vector2(45, 680), 12, Color(0.9, 0.94, 0.96), root)
	steer_hint.size = Vector2(240, 24)
	var steer_zone := Panel.new()
	steer_zone.position = Vector2(35, 510)
	steer_zone.size = Vector2(300, 150)
	var steer_style := StyleBoxFlat.new()
	steer_style.bg_color = Color(0.12, 0.18, 0.2, 0.28)
	steer_style.border_color = Color(0.8, 0.85, 0.85, 0.35)
	steer_style.set_border_width_all(2)
	steer_style.set_corner_radius_all(72)
	steer_zone.add_theme_stylebox_override("panel", steer_style)
	steer_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(steer_zone)
	_make_control_button("▲ GAS", Vector2(1080, 565), Vector2(150, 100), func(): throttle = 1.0, func(): throttle = 0.0, root)
	_make_control_button("▼ REM", Vector2(900, 565), Vector2(150, 100), func(): throttle = -0.65, func(): throttle = 0.0, root)
	var hint := _make_label("KENDALIKAN TRUK • ANTARKAN MUATAN KE GUDANG", Vector2(420, 655), 13, Color(0.9, 0.94, 0.96), root)
	hint.size = Vector2(450, 28)


func _build_pause_panel(parent: Control) -> void:
	pause_panel = PanelContainer.new()
	pause_panel.visible = false
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.position = Vector2(-190, -145)
	pause_panel.size = Vector2(380, 290)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.07, 0.1, 0.97)
	panel_style.border_color = Color(0.82, 0.62, 0.27)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_top = 22
	panel_style.content_margin_bottom = 22
	pause_panel.add_theme_stylebox_override("panel", panel_style)
	parent.add_child(pause_panel)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	pause_panel.add_child(actions)
	var heading := Label.new()
	heading.text = "GAME DIJEDA"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 25)
	heading.add_theme_color_override("font_color", Color(0.95, 0.82, 0.5))
	actions.add_child(heading)
	var resume := Button.new()
	resume.text = "LANJUTKAN"
	resume.custom_minimum_size = Vector2(300, 52)
	resume.pressed.connect(_toggle_pause)
	actions.add_child(resume)
	var menu := Button.new()
	menu.text = "KEMBALI KE MENU UTAMA"
	menu.custom_minimum_size = Vector2(300, 52)
	menu.pressed.connect(_return_to_menu)
	actions.add_child(menu)

func _toggle_pause() -> void:
	var should_pause := not get_tree().paused
	get_tree().paused = should_pause
	pause_panel.visible = should_pause
	pause_button.text = "▶  LANJUT" if should_pause else "Ⅱ  PAUSE"

func _return_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

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
