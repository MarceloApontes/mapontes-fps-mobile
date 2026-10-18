extends Node3D

# MAPONTES FPS - Godot 4 - Etapa 1: prototipo independente e leve.
# A migracao completa da logica Babylon.js sera feita em etapas futuras.

const SPEED := 5.0
const RUN_SPEED := 8.0
const SENSITIVITY := 0.0025
const GRAVITY := 19.0
const RELOAD_SECONDS := 2.6483333
const RELOAD_EMPTY_SECONDS := 3.4983335
const MAX_AMMO := 30
const FIRE_INTERVAL := 0.095
const BURST_INTERVAL := 0.105

var player: CharacterBody3D
var camera: Camera3D
var pitch := 0.0
var ammo := MAX_AMMO
var reserve := 180
var reloading := false
var collected := 0
var targets: Array[StaticBody3D] = []
var briefcases: Array[Area3D] = []
var move_flags := {"forward": false, "back": false, "left": false, "right": false, "run": false}
var mobile_jump_requested := false
var mobile_crouching := false
var mobile_crouch_offset := 0.0
var mobile_camera_base_y := 0.0
var mobile := false
var mobile_joystick_axis := Vector2.ZERO
var ammo_label: Label
var objective_label: Label
var status_label: Label
var info_label: Label
var status_time := 0.0
var mouse_captured := false
var enemy: StaticBody3D
var enemy_alive := true
var enemy_health: int = 100
# PATCH 025.1: patrulha simples entre dois pontos.
const PATROL_SPEED := 1.35
const PATROL_WAIT := 1.2
var patrol_points: Array[Vector3] = []
var patrol_destination: int = 1
var patrol_wait_time: float = 0.0
var patrol_steer_direction := Vector3.ZERO
var patrol_avoid_side: float = 1.0
var patrol_blocked_time: float = 0.0
var patrol_stuck_time: float = 0.0
var patrol_last_position := Vector3.ZERO
const PATROL_SENSOR_DISTANCE := 1.15
const PATROL_TURN_SPEED := 3.0
# PATCH 025.2: percepcao visual (sem perseguicao ou disparos).
const DETECT_DISTANCE := 13.0
const DETECT_HALF_ANGLE := 60.0
const DETECT_CONFIRM_SECONDS := 0.35
const DETECT_LOST_SECONDS := 2.5
const ALERT_TURN_SPEED := 3.2
var enemy_ai_state: String = "PATRULHA"
var enemy_seen_time: float = 0.0
var enemy_lost_time: float = 0.0
var enemy_last_seen: Vector3 = Vector3.ZERO
var enemy_ai_sprite: TextureRect
const ENEMY_HUD_DISTANCE := 15.0
const HUD_NEAR_TEXTURE = preload("res://assets/hud/enemy_near.png")
const HUD_ALERT_TEXTURE = preload("res://assets/hud/enemy_alert.png")
var enemy_hud_time: float = 0.0
const ENEMY_HUD_FADE_SECONDS := 1.5
var enemy_hud_alpha: float = 0.0

var enemy_model_holder: Node3D
var enemy_anim_player: AnimationPlayer
var patrol_walk_anim: String = ""
var patrol_idle_anim: String = ""
var weapon_animation: AnimationPlayer
var weapon_reload_animation: String = ""
var weapon_anims: Dictionary = {}
var weapon_action_time: float = 0.0
var weapon_state: String = ""
var weapon_pivot: Node3D
# PATCH 025.3.1: AK-12 como unica arma ativa neste teste.
var equipped_weapon: int = 2
var weapon_model: Node3D
# Malhas de vidro da luneta AK-12; ocultas somente ao mirar.
var ak12_scope_lenses: Array[MeshInstance3D] = []
var ak12_scope_reticle: TextureRect
# PATCH 025.3.8: camera optica independente 4x em janela circular.
var ak12_scope_viewport: SubViewport
var ak12_scope_camera: Camera3D
var ak12_scope_display: TextureRect
var ak12_scope_zoom_label: Label
var ak12_scope_zoom_value: Label
var ak12_scope_smooth_diameter: float = 0.0
var ak12_scope_lens_visible: bool = false
# PATCH 025.3.21: alinhamento continuo (0..1) para revelar a lente progressivamente.
var ak12_scope_alignment_alpha: float = 0.0
# PATCH 025.3.19: opacidade progressiva ao entrar e sair do ADS.
var ak12_scope_fade_alpha: float = 0.0
const AK12_SCOPE_FOV: float = 18.0
# Zoom optico ajustavel: 1x a 6x; inicia sempre em 1x ao mirar.
const AK12_SCOPE_ZOOM_MIN: int = 1
const AK12_SCOPE_ZOOM_MAX: int = 6
var ak12_scope_zoom: int = 1
# O FOV optico depende tambem do diametro da lente na tela.
# Igualar apenas os FOVs cria efeito de afastamento porque o circulo e menor.
var ak12_scope_base_tan: float = tan(deg_to_rad(AIM_FOV) * 0.5)
const AK12_SCOPE_DIAMETER: float = 310.0
# Limites de seguranca para o tamanho projetado da lente na tela.
const AK12_SCOPE_MIN_DIAMETER: float = 90.0
const AK12_SCOPE_MAX_DIAMETER: float = 430.0
const AK12_SCOPE_RETICLE = preload("res://assets/hud/ak12_scope_reticle.png")
var ak74_ammo: int = MAX_AMMO
var ak74_reserve: int = 180
var ak12_ammo: int = MAX_AMMO
var ak12_reserve: int = 180
var ak12_ads_offset: Vector3 = Vector3(-0.155, -0.33, -0.185)
var ak12_ads_rotation: Vector3 = Vector3(-3.5, -1.3, 0.0)
var reload_progress: float = 0.0
var active_reload_duration: float = RELOAD_SECONDS
var pause_panel: PanelContainer
var enemy_hitboxes: Dictionary = {}
var hitbox_debug_visible: bool = false
var hitbox_debug_meshes: Array[MeshInstance3D] = []
var weapon_kick: float = 0.0
# PATCH 025.3.47: recuo visual da camera independente da posicao da AK-12.
var camera_recoil_pitch: float = 0.0
var camera_recoil_yaw: float = 0.0
var walk_phase: float = 0.0
var shot_flash: float = 0.0
# A = automatico; S = rajada de 3; U = unico
var fire_modes: Array[String] = ["A", "S", "U"]
var fire_mode_index: int = 2
var trigger_held: bool = false
var burst_remaining: int = 0
var trigger_latched: bool = false
var fire_cooldown: float = 0.0
var fire_mode_label: Label
var aiming: bool = false
var aim_blend: float = 0.0
var crosshair_label: Label
const HIP_FOV := 75.0
const AIM_FOV := 58.0
# Ajuste fino ADS. O GLB nao tem animacao propria de mira.
# Estes valores sao calibraveis durante o jogo.
var ads_offset := Vector3(-0.05, 0.08, -0.095)
var ads_rotation_offset := Vector3(-1.5, -1.3, 0.0)
var ads_debug_enabled := false
# PATCH 025.3.36: F7 + V alterna calibracao entre arma e fumaca.
var ak12_smoke_debug := false
# PATCH 025.3.40: F7 e C agora calibram exclusivamente o clarao.
var ak12_flash_offset := Vector3(-0.125, 0.2, 1.40) # PATCH 025.3.41: +0.05 em Z sobre ajuste 1.35
var ak12_smoke_offset := Vector3(-0.125, 0.2, 1.33)
# PATCH 025.3.39: direcao independente, ajustavel no modo F7.
var ak12_smoke_direction_sign := 1.0
# PATCH 025.3.38: camera orbital temporaria, exclusiva da inspecao da fumaca.
var smoke_inspection_camera: Camera3D
var smoke_inspection_enabled := false
var smoke_inspection_yaw := 1.15
var smoke_inspection_pitch := 0.20
var smoke_inspection_distance := 1.6
var ak12_calibration_ads: bool = false
# PATCH 025.3.3: calibracao exclusiva da AK-12 fora da mira (HIP).
# Valores iniciais preservam a posicao original.
var ak12_hip_offset: Vector3 = Vector3(-0.235, -0.02, 0.155)
var ak12_hip_rotation: Vector3 = Vector3(2.5, 1.0, 0.0)
# Alvo de calibracao - marcas persistem ate reiniciar a partida.
var calibration_target: StaticBody3D
var calibration_hits: int = 0
var calibration_label: Label

func _ready() -> void:
	mobile = OS.get_name() == "Android"
	_build_world()
	_build_player()
	_build_hud()
	_build_pause_menu()
	_build_weapon()
	if not mobile:
		_capture_mouse()
	_message("RECUPERE AS 3 MALETAS. B ALTERNA A / S / U.", 5.0)

var _room_marks: Array[Node3D] = []

func _make_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, collidable := true) -> Node3D:
	var body: Node3D = StaticBody3D.new() if collidable else Node3D.new()
	parent.add_child(body)
	body.position = pos
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	body.add_child(mesh)
	if collidable:
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		body.add_child(collider)
	return body

# Aplica textura original em um objeto sem modificar colisao nem fisica.
func _apply_texture(body: Node3D, texture_path: String, uv_scale: Vector3) -> void:
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		return
	for child in body.get_children():
		if child is MeshInstance3D:
			var mesh_instance: MeshInstance3D = child as MeshInstance3D
			var material := StandardMaterial3D.new()
			material.albedo_texture = texture
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			material.uv1_scale = uv_scale
			mesh_instance.material_override = material
			break

func _build_world() -> void:
	var world := WorldEnvironment.new()
	add_child(world)
	var env := Environment.new()
	# Panorama tropical escolhido para o Campo Rondonia (imagem 2:1).
	var panorama_texture: Texture2D = load("res://assets/texturas/paisagem-tropical-panoramica.jpg") as Texture2D
	if panorama_texture != null:
		var sky_material := PanoramaSkyMaterial.new()
		sky_material.panorama = panorama_texture
		var sky := Sky.new()
		sky.sky_material = sky_material
		env.sky = sky
		env.background_mode = Environment.BG_SKY
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.56, 0.76, 0.89)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.82, 0.77)
	env.ambient_light_energy = 0.85
	world.environment = env
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = false
	# PATCH 006: terreno maior para que as bordas fiquem longe do jogador.
	# Mantemos uma unica malha com uma unica colisao: baixo custo para notebook/Android.
	var ground := _make_box(self, Vector3(0, -0.5, 0), Vector3(260, 1, 260), Color.WHITE)
	_apply_texture(ground, "res://assets/texturas/terra-floresta-mapa3.webp", Vector3(58, 58, 1))
	# Harmoniza o solo com os verdes e ocres do novo horizonte tropical.
	for child in ground.get_children():
		if child is MeshInstance3D:
			var surface: MeshInstance3D = child as MeshInstance3D
			var ground_mat: StandardMaterial3D = surface.material_override as StandardMaterial3D
			if ground_mat != null:
				ground_mat.albedo_color = Color(0.88, 0.9, 0.81)
				ground_mat.roughness = 1.0
			break
	for i in range(9):
		var x := -24.0 + i * 6.0
		var building := _make_box(self, Vector3(x, 1.5, -24), Vector3(4, 3, 3), Color.WHITE)
		_apply_texture(building, "res://assets/texturas/muro-cidade-abandonada-v1.jpg", Vector3(2, 1, 1))
	# PATCH 008: contêineres com as texturas originais do Babylon.js.
	# Mantemos corpos de colisao simples e poucos objetos para notebooks e Android.
	for i in range(4):
		var container_pos := Vector3(-16.0 + float(i) * 9.0, 1.35, -9.0)
		_create_textured_container(container_pos, Vector3(6.0, 2.7, 2.5))

	_create_weapon_test_room()
	_add_vegetation()
	# Caixotes de madeira do jogo original, com colisao simples.
	for crate_pos in [Vector3(-12, 0.85, -16), Vector3(-10.25, 0.85, -16),
		Vector3(6, 0.85, -16), Vector3(7.75, 0.85, -16),
		Vector3(6, 2.55, -16), Vector3(18, 0.85, -15)]:
		_create_wooden_crate(crate_pos)
	_create_test_enemy(Vector3(0, 0, -19))
	_create_calibration_target()
	for pos in [Vector3(-8, 0.4, -14), Vector3(3, 0.4, -20), Vector3(12, 0.4, -12)]:
		_create_case(pos)
	for pos in [Vector3(-4, 1, -18), Vector3(10, 1, -19), Vector3(17, 1, -10)]:
		var target := _make_box(self, pos, Vector3(0.8, 2, 0.7), Color(0.64, 0.18, 0.14)) as StaticBody3D
		targets.append(target)

# PATCH 025.3.29: sala de testes escura, com porta aberta e colisao.
# Local: lado direito da area inicial, sem bloquear objetivos existentes.
func _create_weapon_test_room() -> void:
	var room := Node3D.new()
	room.name = "Sala_Teste_Armas_Efeitos"
	add_child(room)
	room.position = Vector3(16.0, 0.0, 12.0)
	var black := Color(0.055, 0.061, 0.071)
	var dark_floor := Color(0.115, 0.125, 0.14)
	var frame := Color(0.31, 0.34, 0.37)
	# Sala 10 x 10 m; piso em y=0 e teto em y=4.2.
	var test_floor := _make_box(room, Vector3(0, -0.08, 0), Vector3(10.0, 0.16, 10.0), dark_floor)
	test_floor.add_to_group("sala_teste_impactos")
	_make_box(room, Vector3(0, 4.2, 0), Vector3(10.0, 0.2, 10.0), black)
	var test_wall_left := _make_box(room, Vector3(-5.0, 2.1, 0), Vector3(0.2, 4.2, 10.0), black)
	test_wall_left.add_to_group("sala_teste_impactos")
	var test_wall_right := _make_box(room, Vector3(5.0, 2.1, 0), Vector3(0.2, 4.2, 10.0), black)
	test_wall_right.add_to_group("sala_teste_impactos")
	var test_wall_back := _make_box(room, Vector3(0, 2.1, -5.0), Vector3(10.0, 4.2, 0.2), black)
	test_wall_back.add_to_group("sala_teste_impactos")
	# Frente (+Z): vao central de 2.2 m, sem colisao invisivel.
	var front_left := _make_box(room, Vector3(-3.05, 2.1, 5.0), Vector3(3.9, 4.2, 0.2), black)
	front_left.add_to_group("sala_teste_impactos")
	var front_right := _make_box(room, Vector3(3.05, 2.1, 5.0), Vector3(3.9, 4.2, 0.2), black)
	front_right.add_to_group("sala_teste_impactos")
	var front_top := _make_box(room, Vector3(0, 3.65, 5.0), Vector3(2.2, 1.1, 0.2), black)
	front_top.add_to_group("sala_teste_impactos")
	# Batente visivel; passagem livre de 2.2 m largura x 3.1 m altura.
	_make_box(room, Vector3(-1.14, 1.55, 5.14), Vector3(0.08, 3.1, 0.14), frame)
	_make_box(room, Vector3(1.14, 1.55, 5.14), Vector3(0.08, 3.1, 0.14), frame)
	_make_box(room, Vector3(0, 3.13, 5.14), Vector3(2.36, 0.08, 0.14), frame)
	# Luz branca para avaliar clarão, fumaca e capsulas contra as paredes escuras.
	var lamp := OmniLight3D.new()
	lamp.name = "Luz_Interna_Testes"
	room.add_child(lamp)
	lamp.position = Vector3(0, 3.75, 0)
	lamp.light_color = Color(0.93, 0.96, 1.0)
	lamp.light_energy = 1.25
	lamp.omni_range = 10.0
	lamp.shadow_enabled = false
	_make_box(room, Vector3(0, 4.04, 0), Vector3(1.7, 0.06, 0.65), Color(0.8, 0.84, 0.9), false)
	# Letreiro acima da porta, legivel de fora da sala.
	var sign := Label3D.new()
	sign.name = "Letreiro_Sala_Teste"
	room.add_child(sign)
	sign.text = "SALA DE TESTE\nARMAS E EFEITOS"
	sign.font_size = 64
	sign.pixel_size = 0.0035
	sign.modulate = Color(0.93, 0.95, 1.0)
	sign.outline_size = 8
	sign.position = Vector3(0, 3.72, 5.17)
	sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	# PATCH 025.3.30: textura do estande aplicada na parede do fundo.
	# A parede original e sua colisao permanecem intactas.
	var back_wall_art := MeshInstance3D.new()
	back_wall_art.name = "Textura_Fundo_Sala_Testes"
	room.add_child(back_wall_art)
	var wall_quad := QuadMesh.new()
	wall_quad.size = Vector2(9.72, 4.06)
	back_wall_art.mesh = wall_quad
	# A parede de fundo fica em z=-5; a face interna aponta para +Z.
	back_wall_art.position = Vector3(0.0, 2.1, -4.885)
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_texture = load("res://assets/texturas/fundo_sala_testes.png") as Texture2D
	wall_mat.albedo_color = Color.WHITE
	wall_mat.roughness = 0.88
	wall_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	back_wall_art.material_override = wall_mat
	# PATCH 025.3.31: laterais e piso com texturas proprias.
	# Planos ligeiramente a frente das paredes para evitar z-fighting.
	_room_texture_quad(room, "Parede_Lateral_Esquerda", "res://assets/texturas/parede_lateral_esquerda.png", Vector3(-4.885, 2.1, 0), Vector3(0, 90, 0), Vector2(9.72, 4.06))
	_room_texture_quad(room, "Parede_Lateral_Direita", "res://assets/texturas/parede_lateral_direita.png", Vector3(4.885, 2.1, 0), Vector3(0, -90, 0), Vector2(9.72, 4.06))
	_room_texture_quad(room, "Piso_Texturizado", "res://assets/texturas/chao_sala_testes.png", Vector3(0, 0.012, 0), Vector3(-90, 0, 0), Vector2(9.72, 9.72))

func _room_texture_quad(parent: Node3D, label: String, path: String, pos: Vector3, rot: Vector3, dimensions: Vector2) -> void:
	var visual := MeshInstance3D.new()
	visual.name = label
	parent.add_child(visual)
	var quad := QuadMesh.new()
	quad.size = dimensions
	visual.mesh = quad
	visual.position = pos
	visual.rotation_degrees = rot
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(path) as Texture2D
	mat.roughness = 0.88
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.material_override = mat

# Furos novos, posicionados pela colisao real do raycast, com limite de memoria.
# PATCH 025.3.32: marcas de impacto com sprites PNG transparentes.
# Usa o ponto e a normal do raycast original, sem mudar a logica dos disparos.
func _room_bullet_mark(point: Vector3, normal: Vector3, surface_kind: String = "", shot_distance: float = 0.0) -> void:
	var n: Vector3 = normal.normalized()
	if n.length_squared() < 0.01:
		return
	var kind: String = surface_kind if surface_kind != "" else ("piso" if n.y > 0.65 else "metal")
	# Três famílias de sprites por distância, duas variações aleatórias em cada.
	# Perto: 01-02 | médio: 03-04 | longe: 05-06.
	var variation: int = randi_range(1, 2)
	if shot_distance >= 35.0:
		variation = randi_range(5, 6)
	elif shot_distance >= 12.0:
		variation = randi_range(3, 4)
	var tex_path: String = "res://assets/impactos/%s_%02d.png" % [kind, variation]
	var tex: Texture2D = load(tex_path) as Texture2D
	if tex == null:
		return
	var mark := MeshInstance3D.new()
	mark.name = "Impacto_%s_%02d" % [kind, variation]
	var quad := QuadMesh.new()
	var size_m: float = randf_range(0.095, 0.135) if kind == "metal" else randf_range(0.08, 0.11)
	# Variação discreta para não criar crateras exageradas à distância.
	if shot_distance >= 35.0:
		size_m *= randf_range(0.82, 0.95)
	elif shot_distance >= 12.0:
		size_m *= randf_range(0.92, 1.03)
	else:
		size_m *= randf_range(1.0, 1.10)
	quad.size = Vector2(size_m, size_m)
	mark.mesh = quad
	add_child(mark)
	mark.global_position = point + n * 0.018
	var up_axis: Vector3 = Vector3.UP if absf(n.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	mark.global_transform.basis = Basis.looking_at(-n, up_axis)
	mark.rotate_object_local(Vector3.FORWARD, randf_range(0.0, TAU))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = tex
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mat.render_priority = 2
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.no_depth_test = false
	mark.material_override = mat
	_room_marks.append(mark)
	if _room_marks.size() > 120:
		var oldest: Node3D = _room_marks.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

# PATCH 008: seis faces com texturas diferentes e colisao unica.
# Alvo fixo em frente a area inicial; face voltada ao jogador (+Z).
func _create_calibration_target() -> void:
	calibration_target = StaticBody3D.new()
	calibration_target.name = "Alvo_Calibracao_ADS"
	add_child(calibration_target)
	calibration_target.position = Vector3(4.0, 1.28, 1.0)
	var visual := MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = Vector2(1.65, 2.2)
	visual.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_texture = load("res://assets/texturas/alvo_calibracao.png") as Texture2D
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.material_override = material
	calibration_target.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.65, 2.2, 0.06)
	collision.shape = shape
	calibration_target.add_child(collision)
	# Poste discreto atras do alvo.
	_make_box(self, Vector3(4.0, 0.67, 0.83), Vector3(0.08, 1.34, 0.08), Color(0.28, 0.27, 0.24))

func _mark_calibration_hit(world_point: Vector3) -> void:
	if not is_instance_valid(calibration_target):
		return
	var local_point: Vector3 = calibration_target.to_local(world_point)
	# Limita o decalque a face frontal e impede atravessar a superficie.
	local_point.z = 0.043
	var mark := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 0.027
	disk.bottom_radius = 0.027
	disk.height = 0.002
	mark.mesh = disk
	mark.name = "Marca_ADS_%d" % (calibration_hits + 1)
	mark.rotation_degrees.x = 90.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.96, 0.25, 0.08)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mark.material_override = mat
	calibration_target.add_child(mark)
	mark.position = local_point
	calibration_hits += 1
	if calibration_label != null:
		calibration_label.text = "ALVO ADS: %d ACERTOS | T: LIMPAR" % calibration_hits
	print("[ALVO ADS] Acerto #", calibration_hits, " posicao local: ", local_point)

func _clear_calibration_marks() -> void:
	if not is_instance_valid(calibration_target):
		return
	for child in calibration_target.get_children():
		if child is MeshInstance3D and child.name.begins_with("Marca_ADS_"):
			child.queue_free()
	calibration_hits = 0
	if calibration_label != null:
		calibration_label.text = "ALVO ADS: 0 ACERTOS | T: LIMPAR"

func _create_textured_container(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Conteiner_Texturizado_PATCH008"
	add_child(body)
	body.position = pos
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var front: Texture2D = load("res://assets/texturas/conteiner-frente.png") as Texture2D
	var side: Texture2D = load("res://assets/texturas/conteiner-lateral.png") as Texture2D
	var doors: Texture2D = load("res://assets/texturas/conteiner-portas.png") as Texture2D
	var roof: Texture2D = load("res://assets/texturas/conteiner-teto.png") as Texture2D
	# O eixo X (6 m) representa o comprimento do conteiner.
	# Laterais: faces longas em Z; frente/portas: extremidades curtas em X.
	_container_face(body, Vector3(size.x * 0.5 + 0.003, 0, 0), Vector3(0, 0, -90), Vector2(size.z, size.y), front, 90.0)
	_container_face(body, Vector3(-size.x * 0.5 - 0.003, 0, 0), Vector3(0, 0, 90), Vector2(size.z, size.y), doors, -90.0)
	_container_face(body, Vector3(0, 0, size.z * 0.5 + 0.003), Vector3(90, 0, 0), Vector2(size.x, size.y), side, 180.0)
	_container_face(body, Vector3(0, 0, -size.z * 0.5 - 0.003), Vector3(-90, 0, 0), Vector2(size.x, size.y), side, 180.0)
	_container_face(body, Vector3(0, size.y * 0.5 + 0.003, 0), Vector3.ZERO, Vector2(size.x, size.z), roof)
	_container_face(body, Vector3(0, -size.y * 0.5 - 0.003, 0), Vector3(180, 0, 0), Vector2(size.x, size.z), roof)

func _container_face(parent: Node3D, pos: Vector3, rot: Vector3, dimensions: Vector2, texture: Texture2D, uv_rotation_degrees: float = 0.0) -> void:
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = dimensions
	mesh.mesh = plane
	mesh.position = pos
	mesh.rotation_degrees = rot
	# Gira a imagem no proprio plano sem deslocar a face nem sua colisao.
	mesh.rotate_object_local(Vector3.UP, deg_to_rad(uv_rotation_degrees))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.82, 0.8)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.95
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if texture != null:
		mat.albedo_texture = texture
	mesh.material_override = mat
	parent.add_child(mesh)

# PATCH 007: vegetacao de baixo custo, sem colisao e com materiais compartilhados.
func _add_vegetation() -> void:
	var foliage_material := StandardMaterial3D.new()
	foliage_material.albedo_color = Color(0.24, 0.38, 0.16)
	foliage_material.roughness = 1.0
	var dry_material := StandardMaterial3D.new()
	dry_material.albedo_color = Color(0.44, 0.47, 0.22)
	dry_material.roughness = 1.0
	var trunk_material := StandardMaterial3D.new()
	trunk_material.albedo_color = Color(0.38, 0.29, 0.18)
	var grass_mesh := CylinderMesh.new()
	grass_mesh.top_radius = 0.03
	grass_mesh.bottom_radius = 0.27
	grass_mesh.height = 0.65
	grass_mesh.radial_segments = 3
	var bush_mesh := SphereMesh.new()
	bush_mesh.radius = 0.75
	bush_mesh.height = 1.15
	bush_mesh.radial_segments = 6
	bush_mesh.rings = 3
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.13
	trunk_mesh.bottom_radius = 0.2
	trunk_mesh.height = 2.3
	trunk_mesh.radial_segments = 5
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.5
	crown_mesh.height = 2.4
	crown_mesh.radial_segments = 7
	crown_mesh.rings = 4
	var group := Node3D.new()
	group.name = "Vegetacao_Leve_PATCH007"
	add_child(group)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7007
	# A faixa central permanece livre para o jogador e para as maletas.
	for i in range(105):
		var x: float = rng.randf_range(-105.0, 105.0)
		var z: float = rng.randf_range(-105.0, 105.0)
		if absf(x) < 23.0 and z > -35.0 and z < 24.0:
			continue
		var clump := MeshInstance3D.new()
		clump.mesh = grass_mesh
		clump.material_override = dry_material if i % 3 == 0 else foliage_material
		clump.position = Vector3(x, 0.3, z)
		clump.scale = Vector3(1.0 + rng.randf(), 0.6 + rng.randf(), 1.0 + rng.randf())
		group.add_child(clump)
	for i in range(38):
		var x: float = rng.randf_range(-105.0, 105.0)
		var z: float = rng.randf_range(-105.0, 105.0)
		if absf(x) < 23.0 and z > -35.0 and z < 24.0:
			continue
		var bush := MeshInstance3D.new()
		bush.mesh = bush_mesh
		bush.material_override = foliage_material
		bush.position = Vector3(x, 0.48, z)
		group.add_child(bush)
	# Arvores distantes, simplificadas, para suavizar o encontro com o panorama.
	for i in range(18):
		var angle: float = TAU * float(i) / 18.0
		var radius: float = 67.0 + rng.randf_range(-9.0, 9.0)
		var x: float = cos(angle) * radius
		var z: float = sin(angle) * radius
		var trunk := MeshInstance3D.new()
		trunk.mesh = trunk_mesh
		trunk.material_override = trunk_material
		trunk.position = Vector3(x, 1.15, z)
		group.add_child(trunk)
		var crown := MeshInstance3D.new()
		crown.mesh = crown_mesh
		crown.material_override = foliage_material
		crown.position = Vector3(x, 3.0, z)
		group.add_child(crown)

# PATCH 011 - Caixote texturizado original, tamanho 1.7 m.
func _create_wooden_crate(pos: Vector3) -> void:
	var crate := _make_box(self, pos, Vector3(1.7, 1.7, 1.7), Color.WHITE)
	crate.name = "Caixote_Madeira"
	_apply_texture(crate, "res://assets/texturas/caixote-madeira.png", Vector3.ONE)

# Arma de referencia FPS de geometria simples, presa a camera.
# Modelo AK-74M original sera importado em uma etapa posterior.
# PATCH 012 - importa a arma e o soldado GLB originais.
# Ajustes de orientacao ficam concentrados nestas constantes.
const WEAPON_ROTATION := Vector3(0.0, 180.0, 0.0)
const SOLDIER_ROTATION := Vector3(0.0, 0.0, 0.0)

func _import_model(path: String, parent: Node3D, desired_size: float) -> Node3D:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_warning("Modelo GLB nao carregado: " + path)
		return null
	var model: Node3D = packed.instantiate() as Node3D
	if model == null:
		return null
	parent.add_child(model)
	# Centraliza e escala a partir da geometria importada.
	var bounds := _model_bounds(model)
	if bounds.size.length() > 0.001:
		var factor: float = desired_size / maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		model.scale = Vector3.ONE * factor
		model.position = -bounds.get_center() * factor
	return model

func _model_bounds(root: Node3D) -> AABB:
	var found := false
	var result := AABB()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		var local_box: AABB = mesh_node.get_aabb()
		var relative: Transform3D = root.global_transform.affine_inverse() * mesh_node.global_transform
		var transformed: AABB = relative * local_box
		if not found:
			result = transformed
			found = true
		else:
			result = result.merge(transformed)
	return result

func _build_weapon() -> void:
	weapon_pivot = Node3D.new()
	weapon_pivot.name = "Arma_Equipada"
	camera.add_child(weapon_pivot)
	weapon_pivot.position = Vector3(0.26, -0.34, -0.49)
	weapon_pivot.rotation_degrees = WEAPON_ROTATION
	_load_equipped_weapon()

func _load_equipped_weapon() -> void:
	# Elimina somente a representacao anterior, sem tocar no mundo ou no jogador.
	if is_instance_valid(weapon_model):
		weapon_pivot.remove_child(weapon_model)
		weapon_model.queue_free()
	ak12_scope_lenses.clear()
	weapon_model = null
	weapon_animation = null
	weapon_reload_animation = ""
	weapon_anims.clear()
	weapon_state = ""
	weapon_action_time = 0.0
	var model_path: String = "res://assets/modelos/ak-12animated.glb"
	weapon_model = _import_model(model_path, weapon_pivot, 1.65)
	if weapon_model == null:
		push_warning("PATCH 025.3: nao foi possivel importar " + model_path)
		return
	# A GLB possui a malha lense_0. Escondemos apenas o vidro opaco no ADS.
	for candidate in weapon_model.find_children("*", "MeshInstance3D", true, false):
		var lens_mesh: MeshInstance3D = candidate as MeshInstance3D
		if lens_mesh != null and lens_mesh.name.to_lower().begins_with("lense"):
			ak12_scope_lenses.append(lens_mesh)
	# Renderiza arma na camera principal, mas nao na camera da luneta.
	for part in weapon_model.find_children("*", "VisualInstance3D", true, false):
		var visual: VisualInstance3D = part as VisualInstance3D
		if visual != null:
			visual.layers = 2
	for node in weapon_model.find_children("*", "AnimationPlayer", true, false):
		weapon_animation = node as AnimationPlayer
		break
	if weapon_animation == null:
		push_warning("PATCH 025.3: modelo sem AnimationPlayer: " + model_path)
		return
	for anim_name in weapon_animation.get_animation_list():
		var low: String = String(anim_name).to_lower()
		if equipped_weapon == 1:
			for state in ["idle", "draw", "walk", "run", "shot", "reload", "reload_full", "reload_var2"]:
				if low.ends_with("ak_" + state):
					weapon_anims[state] = String(anim_name)
		else:
			if low.ends_with("equip"):
				weapon_anims["draw"] = String(anim_name)
			elif low.ends_with("idle"):
				weapon_anims["idle"] = String(anim_name)
			elif low.ends_with("shoot"):
				weapon_anims["shot"] = String(anim_name)
			elif low.ends_with("reload"):
				weapon_anims["reload"] = String(anim_name)
	if weapon_anims.has("draw"):
		_weapon_action("draw")
	elif weapon_anims.has("idle"):
		_weapon_play("idle", true)

func _switch_weapon(next_weapon: int) -> void:
	if next_weapon == equipped_weapon or reloading or get_tree().paused:
		return
	if next_weapon != 1 and next_weapon != 2:
		return
	if equipped_weapon == 1:
		ak74_ammo = ammo
		ak74_reserve = reserve
	else:
		ak12_ammo = ammo
		ak12_reserve = reserve
	equipped_weapon = next_weapon
	ammo = ak74_ammo if equipped_weapon == 1 else ak12_ammo
	reserve = ak74_reserve if equipped_weapon == 1 else ak12_reserve
	_set_trigger(false)
	burst_remaining = 0
	fire_cooldown = 0.0
	aiming = false
	aim_blend = 0.0
	weapon_kick = 0.0
	_load_equipped_weapon()
	_update_hud()
	_message("EQUIPADA: " + ("AK-74M" if equipped_weapon == 1 else "AK-12"), 1.5)

func _weapon_play(state: String, restart: bool = false) -> void:
	if weapon_animation == null or not weapon_anims.has(state):
		return
	if not restart and weapon_state == state and weapon_animation.is_playing():
		return
	weapon_state = state
	weapon_animation.play(str(weapon_anims[state]), 0.02 if restart else 0.12)

func _weapon_action(state: String) -> void:
	if not weapon_anims.has(state) or weapon_animation == null:
		return
	var anim: Animation = weapon_animation.get_animation(str(weapon_anims[state]))
	weapon_action_time = anim.length if anim != null else 0.2
	_weapon_play(state, true)

func _create_test_enemy(pos: Vector3) -> void:
	enemy = StaticBody3D.new()
	enemy.name = "Inimigo_Soldado_Original"
	add_child(enemy)
	# O modelo e as hitboxes usam exatamente o mesmo referencial.
	enemy.position = Vector3(pos.x, 0.0, pos.z)
	var model_holder := Node3D.new()
	model_holder.name = "Soldado_Visual_E_Hitboxes"
	enemy.add_child(model_holder)
	model_holder.rotation_degrees = SOLDIER_ROTATION
	enemy_model_holder = model_holder
	# Circuito com trechos diagonais para testar corpo, pernas e curvas.
	patrol_points = [
		enemy.position,
		enemy.position + Vector3(3.0, 0.0, 5.5),
		enemy.position + Vector3(-2.5, 0.0, 8.0),
		enemy.position + Vector3(-3.5, 0.0, 3.0)
	]
	patrol_last_position = enemy.position
	patrol_destination = 1
	patrol_wait_time = PATROL_WAIT
	print("[PATCH 025.1.1] Patrulha criada: ", patrol_points)
	# Procura animacoes de locomocao no modelo original, se existirem.
	# Se nao existirem, o soldado ainda patrulha sem animacao.
	var model: Node3D = _import_model("res://assets/modelos/low_poly_soldier_free.glb", model_holder, 1.8)
	if model == null:
		_make_box(enemy, Vector3(0, 0.9, 0), Vector3(0.65, 1.8, 0.35), Color(0.24, 0.33, 0.21), false)
		return
	for anim_node in model.find_children("*", "AnimationPlayer", true, false):
		var candidate := anim_node as AnimationPlayer
		for anim_name in candidate.get_animation_list():
			var lower := String(anim_name).to_lower()
			if patrol_walk_anim == "" and ("walk" in lower or "walking" in lower):
				enemy_anim_player = candidate
				patrol_walk_anim = String(anim_name)
			if patrol_idle_anim == "" and ("idle" in lower or "standing" in lower):
				patrol_idle_anim = String(anim_name)
	print("[PATCH 025.1.1] Animacoes: walk=", patrol_walk_anim, " idle=", patrol_idle_anim)
	# Apoia a base da geometria no terreno. A posicao do modelo tambem
	# afeta o esqueleto, portanto as hitboxes seguem os mesmos ossos.
	# Alinhamento definitivo feito abaixo, apos os anexos dos ossos.
	# Evita calcular a base duas vezes em coordenadas diferentes.
	# Procura os esqueletos do GLB (pode haver mais de uma skin).
	var skeleton: Skeleton3D = null
	for node in model.find_children("*", "Skeleton3D", true, false):
		var candidate: Skeleton3D = node as Skeleton3D
		if skeleton == null or candidate.get_bone_count() > skeleton.get_bone_count():
			skeleton = candidate
	if skeleton == null:
		push_warning("Soldado sem Skeleton3D: hitboxes por osso indisponiveis.")
		return
	# Medidas desejadas em metros; converter conforme escala global do anexo.
	var specs: Array[Dictionary] = [
		{"bone": "head", "zone": "CABECA", "size": Vector3(0.23, 0.26, 0.23), "offset": Vector3(0, 0.07, 0)},
		{"bone": "chest", "zone": "TRONCO", "size": Vector3(0.48, 0.38, 0.28), "offset": Vector3(0, 0, 0)},
		{"bone": "spine", "zone": "TRONCO", "size": Vector3(0.42, 0.25, 0.28), "offset": Vector3(0, 0, 0)},
		{"bone": "up_arm_l", "zone": "BRACO", "size": Vector3(0.19, 0.30, 0.19), "offset": Vector3(0, -0.10, 0)},
		{"bone": "low_arm_l", "zone": "BRACO", "size": Vector3(0.16, 0.28, 0.16), "offset": Vector3(0, -0.10, 0)},
		{"bone": "up_arm_r", "zone": "BRACO", "size": Vector3(0.19, 0.30, 0.19), "offset": Vector3(0, -0.10, 0)},
		{"bone": "low_arm_r", "zone": "BRACO", "size": Vector3(0.16, 0.28, 0.16), "offset": Vector3(0, -0.10, 0)},
		{"bone": "thigh_l", "zone": "PERNAS", "size": Vector3(0.23, 0.44, 0.24), "offset": Vector3(0, 0.19, 0)},
		{"bone": "leg_l", "zone": "PERNAS", "size": Vector3(0.19, 0.38, 0.20), "offset": Vector3(0, 0.19, 0)},
		{"bone": "thigh_r", "zone": "PERNAS", "size": Vector3(0.23, 0.44, 0.24), "offset": Vector3(0, 0.19, 0)},
		{"bone": "leg_r", "zone": "PERNAS", "size": Vector3(0.19, 0.38, 0.20), "offset": Vector3(0, 0.19, 0)},
		{"bone": "foot_l", "zone": "PERNAS", "size": Vector3(0.23, 0.29, 0.17), "offset": Vector3(0, 0.085, 0)},
		{"bone": "foot_r", "zone": "PERNAS", "size": Vector3(0.23, 0.29, 0.17), "offset": Vector3(0, 0.085, 0)}
	]
	var count: int = 0
	var skeletons: Array[Skeleton3D] = []
	for node in model.find_children("*", "Skeleton3D", true, false):
		skeletons.append(node as Skeleton3D)
	for spec in specs:
		# Usa o esqueleto que realmente contem o osso solicitado.
		var target_skeleton: Skeleton3D = null
		var bone_id: int = -1
		for candidate in skeletons:
			var found_id: int = _find_soldier_bone(candidate, str(spec["bone"]))
			if found_id >= 0:
				target_skeleton = candidate
				bone_id = found_id
				break
		if bone_id < 0:
			push_warning("Osso nao encontrado: " + str(spec["bone"]))
			continue
		var attachment := BoneAttachment3D.new()
		attachment.name = "Anexo_" + str(spec["bone"])
		target_skeleton.add_child(attachment)
		attachment.bone_name = target_skeleton.get_bone_name(bone_id)
		attachment.force_update_transform()
		# BoneAttachment3D acompanha a pose animada sem depender de atualizacoes manuais.
		# Os ossos deste GLB apontam suas articulacoes ao longo do eixo Y local.
		# Usar deslocamentos locais corretos evita caixas fora das coxas e canelas.
		var local_size: Vector3 = _enemy_world_size_to_bone(attachment, spec["size"] as Vector3)
		var local_offset: Vector3 = _enemy_world_size_to_bone(attachment, spec["offset"] as Vector3)
		_add_enemy_hitbox(attachment, str(spec["zone"]), local_offset, local_size)
		count += 1
	# PATCH 024.2: usar a posicao dos ossos dos pes na pose atual,
	# em vez da AABB da malha, que pode incluir espacos vazios.
	# Movemos somente o holder: malha, esqueleto e hitboxes juntos.
	var foot_y: float = INF
	var feet_found: int = 0
	for node in model.find_children("*", "BoneAttachment3D", true, false):
		var attachment: BoneAttachment3D = node as BoneAttachment3D
		if attachment.name == "Anexo_foot_l" or attachment.name == "Anexo_foot_r":
			attachment.force_update_transform()
			foot_y = minf(foot_y, attachment.global_position.y)
			feet_found += 1
	if feet_found > 0:
		# Centro aproximado do osso do pe a 8 cm do solo.
		# Valor facilmente ajustavel depois de conferir o print.
		var target_foot_bone_y: float = 0.08
		var adjustment: float = target_foot_bone_y - foot_y
		model_holder.position.y += adjustment
		print("[PATCH 024.2] pes encontrados=", feet_found,
			" | altura osso antes=", snappedf(foot_y, 0.001),
			" | deslocamento aplicado=", snappedf(adjustment, 0.001),
			" | altura osso prevista=", snappedf(foot_y + adjustment, 0.001))
	else:
		push_warning("[PATCH 024.2] Ossos dos pes nao encontrados; altura nao alterada.")
	print("MAPONTES FPS PATCH 024.2: hitboxes por osso: ", count, " / 13")

func _enemy_world_size_to_bone(attachment: BoneAttachment3D, world_vector: Vector3) -> Vector3:
	# Mantem tamanho em metros depois da escala global do modelo importado.
	var scale_world: Vector3 = attachment.global_transform.basis.get_scale().abs()
	return Vector3(
		world_vector.x / maxf(scale_world.x, 0.0001),
		world_vector.y / maxf(scale_world.y, 0.0001),
		world_vector.z / maxf(scale_world.z, 0.0001))

func _find_soldier_bone(skeleton: Skeleton3D, key: String) -> int:
	for i in range(skeleton.get_bone_count()):
		var name: String = skeleton.get_bone_name(i).to_lower()
		if name.begins_with(key + "_") or name == key:
			return i
	return -1

func _add_enemy_hitbox(parent: Node3D, zone: String, offset: Vector3, dimensions: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Hitbox_" + zone
	parent.add_child(body)
	body.position = offset
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	shape_node.shape = shape
	body.add_child(shape_node)
	enemy_hitboxes[body] = zone
	# Malha visual apenas para depuracao, sem colisao adicional.
	var debug_mesh := MeshInstance3D.new()
	debug_mesh.name = "Visual_Hitbox_" + zone
	var cube := BoxMesh.new()
	cube.size = dimensions
	debug_mesh.mesh = cube
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.albedo_color = Color(1.0, 0.2, 0.2, 0.28) if zone == "CABECA" else (Color(0.2, 0.9, 0.3, 0.25) if zone == "TRONCO" else (Color(0.2, 0.5, 1.0, 0.25) if zone == "BRACO" else Color(1.0, 0.8, 0.2, 0.25)))
	debug_mesh.material_override = mat
	body.add_child(debug_mesh)
	debug_mesh.visible = hitbox_debug_visible
	hitbox_debug_meshes.append(debug_mesh)

func _toggle_hitboxes() -> void:
	hitbox_debug_visible = not hitbox_debug_visible
	for mesh in hitbox_debug_meshes:
		if is_instance_valid(mesh):
			mesh.visible = hitbox_debug_visible
	_message("HITBOXES: " + ("VISIVEIS" if hitbox_debug_visible else "OCULTAS"), 1.5)

func _create_case(pos: Vector3) -> void:
	var area := Area3D.new()
	add_child(area)
	area.position = pos
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.65, 0.42, 0.28)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.7, 0.13)
	mesh.material_override = mat
	area.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.25
	collision.shape = shape
	area.add_child(collision)
	area.body_entered.connect(_on_case_entered.bind(area))
	briefcases.append(area)

func _build_player() -> void:
	player = CharacterBody3D.new()
	add_child(player)
	player.position = Vector3(0, 2, 10)
	var capsule := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.height = 1.8
	shape.radius = 0.35
	capsule.shape = shape
	player.add_child(capsule)
	camera = Camera3D.new()
	player.add_child(camera)
	camera.position = Vector3(0, 0.65, 0)
	camera.current = true
	camera.fov = HIP_FOV
	camera.cull_mask = 3
	# Camera independente: nao move a arma nem altera o ponto de disparo.
	smoke_inspection_camera = Camera3D.new()
	smoke_inspection_camera.name = "CameraInspecaoFumaca"
	add_child(smoke_inspection_camera)
	smoke_inspection_camera.current = false
	smoke_inspection_camera.cull_mask = 3
	smoke_inspection_camera.fov = 65.0

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	ammo_label = _label(ui, Vector2.ZERO, "", 21)
	_place_bottom_right(ammo_label, -92.0)
	fire_mode_label = _label(ui, Vector2.ZERO, "", 18)
	_place_bottom_right(fire_mode_label, -58.0)
	objective_label = _label(ui, Vector2(16, 43), "", 21)
	info_label = _label(ui, Vector2(16, 76), "WASD: mover | Shift: correr | Mouse: atirar | Botao direito: mirar | R: recarregar | Esc: soltar mouse", 15)
	status_label = _label(ui, Vector2(16, 113), "", 19)
	calibration_label = _label(ui, Vector2(16, 145), "ALVO ADS: 0 ACERTOS | T: LIMPAR", 17)
	# Renderizacao optica independente: apenas o mundo, sem o modelo da arma.
	ak12_scope_viewport = SubViewport.new()
	ak12_scope_viewport.name = "AK12_Optica_4x"
	ak12_scope_viewport.size = Vector2i(512, 512)
	ak12_scope_viewport.transparent_bg = false
	ak12_scope_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	ak12_scope_viewport.world_3d = get_world_3d()
	add_child(ak12_scope_viewport)
	ak12_scope_camera = Camera3D.new()
	_update_ak12_scope_fov()
	ak12_scope_camera.cull_mask = 1
	ak12_scope_viewport.add_child(ak12_scope_camera)
	ak12_scope_camera.current = true
	ak12_scope_display = TextureRect.new()
	ak12_scope_display.name = "AK12_Visao_Circular"
	ak12_scope_display.texture = ak12_scope_viewport.get_texture()
	ak12_scope_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ak12_scope_display.stretch_mode = TextureRect.STRETCH_SCALE
	ak12_scope_display.set_anchors_preset(Control.PRESET_TOP_LEFT)
	ak12_scope_display.offset_left = -AK12_SCOPE_DIAMETER * 0.5
	ak12_scope_display.offset_top = -AK12_SCOPE_DIAMETER * 0.5
	ak12_scope_display.offset_right = AK12_SCOPE_DIAMETER * 0.5
	ak12_scope_display.offset_bottom = AK12_SCOPE_DIAMETER * 0.5
	ak12_scope_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var optical_shader := Shader.new()
	optical_shader.code = """shader_type canvas_item;
void fragment() {
	vec2 p = UV * 2.0 - vec2(1.0);
	float r = length(p);
	vec4 img = texture(TEXTURE, UV);
	float edge = 1.0 - smoothstep(0.94, 0.995, r);
	float vignette = 1.0 - 0.15 * smoothstep(0.70, 0.98, r);
	// Reflexo de vidro sutil apenas no anel periferico da optica.
	float rim = smoothstep(0.78, 0.90, r) * (1.0 - smoothstep(0.95, 0.99, r));
	float highlight = pow(max(0.0, 1.0 - length((UV - vec2(0.27, 0.26)) * vec2(1.1, 1.4))), 9.0);
	vec3 glass = vec3(0.18, 0.27, 0.32) * rim * highlight * 0.13;
	COLOR = vec4(img.rgb * vignette + glass, img.a * edge);
}"""
	var optical_material := ShaderMaterial.new()
	optical_material.shader = optical_shader
	ak12_scope_display.material = optical_material
	ak12_scope_display.visible = false
	ui.add_child(ak12_scope_display)
	# Reticulo PNG fornecido pelo criador, centralizado na imagem optica.
	ak12_scope_reticle = TextureRect.new()
	ak12_scope_reticle.name = "AK12_Reticulo_Optico"
	ak12_scope_reticle.texture = AK12_SCOPE_RETICLE
	ak12_scope_reticle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ak12_scope_reticle.stretch_mode = TextureRect.STRETCH_SCALE
	ak12_scope_reticle.set_anchors_preset(Control.PRESET_TOP_LEFT)
	ak12_scope_reticle.offset_left = -AK12_SCOPE_DIAMETER * 0.5
	ak12_scope_reticle.offset_top = -AK12_SCOPE_DIAMETER * 0.5
	ak12_scope_reticle.offset_right = AK12_SCOPE_DIAMETER * 0.5
	ak12_scope_reticle.offset_bottom = AK12_SCOPE_DIAMETER * 0.5
	ak12_scope_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ak12_scope_reticle.visible = false
	ui.add_child(ak12_scope_reticle)
	# PATCH 025.3.23: indicador em duas tipografias, acima da municao.
	# O valor do zoom tem 48px (3x o tamanho de OPTICA, 16px).
	ak12_scope_zoom_label = Label.new()
	ak12_scope_zoom_label.name = "AK12_Zoom_Titulo"
	ak12_scope_zoom_label.text = "OPTICA"
	ak12_scope_zoom_label.add_theme_font_size_override("font_size", 16)
	ak12_scope_zoom_label.add_theme_color_override("font_color", Color(0.80, 0.94, 0.96, 0.88))
	ak12_scope_zoom_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	ak12_scope_zoom_label.add_theme_constant_override("shadow_offset_x", 1)
	ak12_scope_zoom_label.add_theme_constant_override("shadow_offset_y", 1)
	ak12_scope_zoom_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ak12_scope_zoom_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ak12_scope_zoom_label.anchor_left = 1.0
	ak12_scope_zoom_label.anchor_right = 1.0
	ak12_scope_zoom_label.anchor_top = 1.0
	ak12_scope_zoom_label.anchor_bottom = 1.0
	ak12_scope_zoom_label.offset_left = -214.0
	ak12_scope_zoom_label.offset_right = -122.0
	ak12_scope_zoom_label.offset_top = -154.0
	ak12_scope_zoom_label.offset_bottom = -126.0
	ak12_scope_zoom_label.visible = false
	ui.add_child(ak12_scope_zoom_label)
	ak12_scope_zoom_value = Label.new()
	ak12_scope_zoom_value.name = "AK12_Zoom_Valor"
	ak12_scope_zoom_value.text = "1X"
	ak12_scope_zoom_value.add_theme_font_size_override("font_size", 48)
	ak12_scope_zoom_value.add_theme_color_override("font_color", Color(0.86, 0.97, 1.0, 0.97))
	ak12_scope_zoom_value.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	ak12_scope_zoom_value.add_theme_constant_override("shadow_offset_x", 2)
	ak12_scope_zoom_value.add_theme_constant_override("shadow_offset_y", 2)
	ak12_scope_zoom_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ak12_scope_zoom_value.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ak12_scope_zoom_value.anchor_left = 1.0
	ak12_scope_zoom_value.anchor_right = 1.0
	ak12_scope_zoom_value.anchor_top = 1.0
	ak12_scope_zoom_value.anchor_bottom = 1.0
	ak12_scope_zoom_value.offset_left = -124.0
	ak12_scope_zoom_value.offset_right = -22.0
	ak12_scope_zoom_value.offset_top = -177.0
	ak12_scope_zoom_value.offset_bottom = -112.0
	ak12_scope_zoom_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ak12_scope_zoom_value.visible = false
	ui.add_child(ak12_scope_zoom_value)
	# Sprites sem texto, 35% menores; aparecem somente ate 15 m.
	enemy_ai_sprite = TextureRect.new()
	enemy_ai_sprite.position = Vector2(18, 175)
	enemy_ai_sprite.size = Vector2(81, 81)
	enemy_ai_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_ai_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enemy_ai_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_ai_sprite.texture = HUD_NEAR_TEXTURE
	ui.add_child(enemy_ai_sprite)
	enemy_ai_sprite.visible = false
	enemy_ai_sprite.modulate.a = 0.0
	var center := Label.new()
	center.text = "+"
	crosshair_label = center
	center.add_theme_font_size_override("font_size", 26)
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.position = Vector2(-7, -16)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(center)
	_update_hud()
	if mobile:
		info_label.text = "MOBILE HUD 2.4 | MOVIMENTO + TIRO + MIRAR + MODO + CORRER + RECARGA + AGACHAR + PULAR"
		var touch_hud := Control.new()
		touch_hud.name = "MobileHUD2"
		touch_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		touch_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		touch_hud.set_script(preload("res://scripts/mobile_hud.gd"))
		ui.add_child(touch_hud)
		touch_hud.setup(self)

func _label(parent: Control, pos: Vector2, value: String, size: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

# Alinha os indicadores a direita e os ancora ao rodape em qualquer resolucao.
func _place_bottom_right(label: Label, bottom_offset: float) -> void:
	label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	label.anchor_left = 1.0
	label.anchor_right = 1.0
	label.anchor_top = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = -290.0
	label.offset_right = -22.0
	label.offset_top = bottom_offset
	label.offset_bottom = bottom_offset + 32.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _touch_button(parent: Control, label: String, offset: Vector2, size: Vector2, action: String) -> void:
	var button := Button.new()
	button.text = label
	button.size = size
	if action in ["fire", "reload"]:
		button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	else:
		button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	button.position = offset
	button.modulate.a = 0.74
	button.keep_pressed_outside = true
	parent.add_child(button)
	if action == "fire":
		button.button_down.connect(func(): _set_trigger(true))
		button.button_up.connect(func(): _set_trigger(false))
	elif action == "reload":
		button.button_down.connect(_reload)
	elif action == "aim":
		button.button_down.connect(func():
			if equipped_weapon == 2 and not aiming:
				_reset_ak12_scope_zoom()
			aiming = true
		)
		button.button_up.connect(func(): aiming = false)
	else:
		button.button_down.connect(func(): move_flags[action] = true)
		button.button_up.connect(func(): move_flags[action] = false)

func _process(delta: float) -> void:
	# Recuo imediato no disparo e retorno progressivo ao ponto de mira.
	# A mira optica acompanha a camera principal.
	camera_recoil_pitch = move_toward(camera_recoil_pitch, 0.0, delta * 0.085)
	camera_recoil_yaw = move_toward(camera_recoil_yaw, 0.0, delta * 0.075)
	if is_instance_valid(camera):
		camera.rotation.x = clampf(pitch + camera_recoil_pitch, -1.35, 1.35)
		camera.rotation.y = camera_recoil_yaw
	if smoke_inspection_enabled:
		_update_smoke_inspection_camera()
	# Movimento suave da arma: respiracao, caminhada, corrida e recuo.
	if is_instance_valid(weapon_pivot):
		aim_blend = move_toward(aim_blend, 1.0 if aiming and not reloading else 0.0, delta * 7.5)
		camera.fov = lerpf(HIP_FOV, AIM_FOV, aim_blend)
		if crosshair_label != null:
			crosshair_label.modulate.a = 1.0 - aim_blend
		# A lente do GLB nao e transparente. Durante ADS removemos somente essa
		# malha da renderizacao, preservando a carcaca e o posicionamento aprovado.
		# PATCH 025.3.24: ativa a renderizacao assim que o ADS comeca.
		# Na saida, aiming=false desliga tudo imediatamente (sem mira fantasma).
		var scope_open: bool = equipped_weapon == 2 and aiming and not reloading
		if ak12_scope_camera != null and is_instance_valid(camera):
			ak12_scope_camera.global_transform = camera.global_transform
		var horizontal_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
		var moving: bool = horizontal_speed > 0.2 and player.is_on_floor()
		if weapon_animation != null and weapon_action_time <= 0.0 and not reloading:
			weapon_animation.speed_scale = 1.35 if horizontal_speed <= SPEED + 0.5 else 1.55
		if weapon_action_time > 0.0:
			weapon_action_time = maxf(0.0, weapon_action_time - delta)
		if not reloading and weapon_action_time <= 0.0:
			var target_state: String = "run" if moving and horizontal_speed > SPEED + 0.5 else ("walk" if moving else "idle")
			_weapon_play("idle" if equipped_weapon == 2 else target_state)
		if moving:
			walk_phase += delta * (16.0 if horizontal_speed > SPEED + 0.5 else 11.0)
		var bob: float = sin(walk_phase) * (0.032 if horizontal_speed <= SPEED + 0.5 else 0.046) if moving else sin(Time.get_ticks_msec() * 0.0017) * 0.003
		var sway: float = sin(walk_phase * 0.5) * (0.018 if moving else 0.0)
		weapon_kick = move_toward(weapon_kick, 0.0, delta * 1.7)
		var reload_drop: float = sin(reload_progress * PI) if reloading and weapon_reload_animation == "" else 0.0
		var hip_pos := Vector3(0.26 + sway + reload_drop * 0.12, -0.34 + bob + weapon_kick * 0.22 - reload_drop * 0.25, -0.49 + weapon_kick * 0.70) + ak12_hip_offset
		# Aproximacao ADS: desloca a arma para o centro da camera e reduz balanco.
		# Os offsets podem ser calibrados conforme a geometria da mira do GLB.
		var active_ads_offset: Vector3 = ads_offset if equipped_weapon == 1 else ak12_ads_offset
		var active_ads_rotation: Vector3 = ads_rotation_offset if equipped_weapon == 1 else ak12_ads_rotation
		var ads_pos := active_ads_offset + Vector3(0.0, bob * 0.08 + weapon_kick * 0.12, weapon_kick * 0.4)
		weapon_pivot.position = weapon_pivot.position.lerp(
			hip_pos.lerp(ads_pos, aim_blend), minf(1.0, delta * 12.0))
		var hip_rot := WEAPON_ROTATION + ak12_hip_rotation + Vector3(-weapon_kick * 55.0 + reload_drop * 36.0, 0, (sin(walk_phase) * 2.6 if moving else 0.0) + reload_drop * 22.0)
		var ads_rot := WEAPON_ROTATION + active_ads_rotation + Vector3(-weapon_kick * 28.0, 0, 0)
		weapon_pivot.rotation_degrees = weapon_pivot.rotation_degrees.lerp(
			hip_rot.lerp(ads_rot, aim_blend), minf(1.0, delta * 9.0))
		# Atualiza a sobreposicao DEPOIS de mover o modelo da arma.
		# Assim a optica acompanha a abertura real do GLB, inclusive no ADS.
		_update_ak12_scope_projection(scope_open)
		# Malha e imagem optica alternam juntas, sem quadro intermediario preto.
		var lens_replaced: bool = scope_open and ak12_scope_lens_visible
		for lens_mesh in ak12_scope_lenses:
			if is_instance_valid(lens_mesh):
				lens_mesh.visible = not lens_replaced
		# PATCH 025.3.23: sem fade-in artificial. A imagem segue a lente 3D
		# e so existe quando o encaixe fisico e valido neste mesmo quadro.
		# Mantem o corte imediato na saida (sem mira fantasma).
		var optical_valid: bool = scope_open and ak12_scope_lens_visible and aiming and not reloading
		ak12_scope_fade_alpha = 1.0 if optical_valid else 0.0
		for optical_overlay in [ak12_scope_display, ak12_scope_reticle]:
			if is_instance_valid(optical_overlay):
				optical_overlay.modulate.a = ak12_scope_fade_alpha
				optical_overlay.visible = optical_valid
		if is_instance_valid(ak12_scope_zoom_label):
			ak12_scope_zoom_label.visible = optical_valid
		if is_instance_valid(ak12_scope_zoom_value):
			ak12_scope_zoom_value.text = "%dX" % ak12_scope_zoom
			ak12_scope_zoom_value.visible = optical_valid
		if reloading:
			reload_progress = minf(1.0, reload_progress + delta / active_reload_duration)
	if status_time > 0:
		status_time -= delta
		if status_time <= 0:
			status_label.text = ""

# Projeta a malha da lente 3D para coordenadas 2D da viewport.
# Nao modifica a calibracao da AK-12; move apenas a imagem optica e o reticulo.
func _update_ak12_scope_projection(scope_open: bool) -> void:
	# Invalida o estado ANTES de qualquer retorno antecipado.
	# O desenho final dos tres overlays e feito em _process().
	ak12_scope_lens_visible = false
	ak12_scope_alignment_alpha = 0.0
	if not scope_open or not aiming or reloading or not is_instance_valid(camera):
		return
	if ak12_scope_lenses.is_empty():
		return
	var lens: MeshInstance3D = null
	for item in ak12_scope_lenses:
		if is_instance_valid(item) and item.mesh != null:
			lens = item
			break
	if lens == null:
		return
	var bounds: AABB = lens.get_aabb()
	var local_center: Vector3 = bounds.get_center()
	var world_center: Vector3 = lens.to_global(local_center)
	if camera.is_position_behind(world_center):
		return
	var center_2d: Vector2 = camera.unproject_position(world_center)
	# Projeta os cantos da caixa da lente para estimar seu diametro aparente.
	var low: Vector2 = Vector2(INF, INF)
	var high: Vector2 = Vector2(-INF, -INF)
	for i in range(8):
		var corner: Vector3 = bounds.position + Vector3(
			bounds.size.x if (i & 1) != 0 else 0.0,
			bounds.size.y if (i & 2) != 0 else 0.0,
			bounds.size.z if (i & 4) != 0 else 0.0)
		var world_corner: Vector3 = lens.to_global(corner)
		if camera.is_position_behind(world_corner):
			continue
		var projected: Vector2 = camera.unproject_position(world_corner)
		low = low.min(projected)
		high = high.max(projected)
	var diameter: float = AK12_SCOPE_DIAMETER
	if low.x != INF:
		# A geometria 'lense' inclui a superficie transparente; pequena folga
		# evita que a imagem ampliada ultrapasse a borda metalica.
		diameter = clampf(minf(high.x - low.x, high.y - low.y) * 0.85,
			AK12_SCOPE_MIN_DIAMETER, AK12_SCOPE_MAX_DIAMETER)
	# A imagem segue a lente fisica durante a entrada e so converge ao centro
	# quando o ADS esta concluido. A saida continua instantanea.
	var viewport_size: Vector2 = camera.get_viewport().get_visible_rect().size
	var viewport_center: Vector2 = viewport_size * 0.5
	# PATCH 025.3.25: o recorte acompanha a lente fisica sem interpolacao
	# adicional do centro, evitando salto ao terminar a entrada.
	# So desenha quando a abertura fisica esta dentro da tela.
	var half_diameter: float = diameter * 0.5
	if center_2d.x < -half_diameter or center_2d.x > viewport_size.x + half_diameter:
		return
	if center_2d.y < -half_diameter or center_2d.y > viewport_size.y + half_diameter:
		return
	ak12_scope_lens_visible = true
	ak12_scope_alignment_alpha = 1.0
	var optical_center: Vector2 = center_2d
	# PATCH 025.3.26: ajuste fino do recorte interno, reduzindo o anel escuro
	# perceptivel na subida sem ultrapassar a moldura fisica.
	# Uma margem extra impede que a imagem atravesse o aro metalico.
	var target_diameter: float = diameter * 0.94
	# PATCH 025.3.25: sem atraso temporal no diametro. Durante a subida,
	# suavizar a abertura separadamente da arma causa o circulo "surgindo".
	# Centro e tamanho seguem a mesma projecao 3D no mesmo quadro.
	ak12_scope_smooth_diameter = target_diameter
	var safe_diameter: float = target_diameter
	for overlay in [ak12_scope_display, ak12_scope_reticle]:
		if overlay == null:
			continue
		overlay.set_anchors_preset(Control.PRESET_TOP_LEFT)
		overlay.position = optical_center - Vector2.ONE * safe_diameter * 0.5
		overlay.size = Vector2.ONE * safe_diameter
	# O indicador agora permanece no HUD, acima da municao, e nao na lente.
	_update_ak12_scope_fov()

# Evita objetos por sensores de frente e laterais. Navegacao local simples;
# nao substitui um NavigationAgent3D em labirintos ou corredores fechados.
func _patrol_path_clear(direction: Vector3, distance: float) -> bool:
	var world := get_world_3d().direct_space_state
	for height: float in [0.45, 1.05]:
		var origin: Vector3 = enemy.global_position + Vector3.UP * height
		for side: float in [-0.22, 0.22]:
			var sideways: Vector3 = Vector3(-direction.z, 0.0, direction.x)
			var start: Vector3 = origin + sideways * side
			var query := PhysicsRayQueryParameters3D.create(start, start + direction * distance)
			query.exclude = [enemy.get_rid()]
			query.collide_with_areas = false
			if not world.intersect_ray(query).is_empty():
				return false
	return true

func _enemy_can_see_player() -> bool:
	if not is_instance_valid(enemy) or not is_instance_valid(player):
		return false
	var eye: Vector3 = enemy.global_position + Vector3.UP * 1.55
	var target: Vector3 = player.global_position + Vector3.UP * 0.85
	var toward: Vector3 = target - eye
	if toward.length() > DETECT_DISTANCE:
		return false
	var flat: Vector3 = Vector3(toward.x, 0.0, toward.z)
	if flat.length_squared() < 0.0001:
		return true
	# Frente baseada na direcao real da patrulha, independente do eixo do GLB.
	var facing: Vector3 = patrol_steer_direction
	if enemy_ai_state != "PATRULHA":
		facing = Vector3(enemy_last_seen.x - enemy.global_position.x, 0.0,
			enemy_last_seen.z - enemy.global_position.z)
	if facing.length_squared() > 0.001:
		var cosine: float = facing.normalized().dot(flat.normalized())
		if cosine < cos(deg_to_rad(DETECT_HALF_ANGLE)):
			return false
	# Raios atingem paredes/caixotes; nao atravessa obstaculos.
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, target)
	ray.exclude = [enemy.get_rid()]
	ray.collide_with_areas = false
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.get("collider") == player

func _update_enemy_awareness(delta: float) -> void:
	var hud_near: bool = false
	var hud_distance: float = ENEMY_HUD_DISTANCE + 1.0
	if enemy_alive and is_instance_valid(player) and is_instance_valid(enemy):
		hud_distance = player.global_position.distance_to(enemy.global_position)
		hud_near = hud_distance <= ENEMY_HUD_DISTANCE
	var target_alpha: float = 1.0 if hud_near else 0.0
	enemy_hud_alpha = move_toward(enemy_hud_alpha, target_alpha, delta / ENEMY_HUD_FADE_SECONDS)
	if is_instance_valid(enemy_ai_sprite):
		enemy_ai_sprite.visible = enemy_hud_alpha > 0.001
		enemy_ai_sprite.modulate.a = enemy_hud_alpha
		if hud_near:
			enemy_hud_time += delta
			var proximity: float = clampf(1.0 - hud_distance / ENEMY_HUD_DISTANCE, 0.0, 1.0)
			var amplitude: float = 0.5 + proximity * 5.0
			var frequency: float = 9.0 + proximity * 23.0
			enemy_ai_sprite.position = Vector2(18.0, 175.0) + Vector2(
				sin(enemy_hud_time * frequency) * amplitude,
				cos(enemy_hud_time * frequency * 1.37) * amplitude * 0.65)
		else:
			enemy_ai_sprite.position = Vector2(18.0, 175.0)
	if not enemy_alive or not is_instance_valid(player) or not is_instance_valid(enemy):
		return
	var visible: bool = _enemy_can_see_player()
	if visible:
		enemy_seen_time += delta
		enemy_lost_time = 0.0
		if enemy_seen_time >= DETECT_CONFIRM_SECONDS:
			enemy_last_seen = player.global_position
			if enemy_ai_state != "ALERTA":
				enemy_ai_state = "ALERTA"
				print("[PATCH 025.2] Soldado detectou o jogador")
	else:
		enemy_seen_time = 0.0
		if enemy_ai_state == "ALERTA":
			enemy_lost_time += delta
			if enemy_lost_time >= DETECT_LOST_SECONDS:
				enemy_ai_state = "PATRULHA"
				patrol_wait_time = PATROL_WAIT
				patrol_steer_direction = Vector3.ZERO
				print("[PATCH 025.2] Soldado perdeu o jogador e retomou patrulha")
	if is_instance_valid(enemy_ai_sprite):
		if enemy_ai_state == "ALERTA":
			enemy_ai_sprite.texture = HUD_ALERT_TEXTURE
		else:
			enemy_ai_sprite.texture = HUD_NEAR_TEXTURE

func _update_enemy_alert_rotation(delta: float) -> void:
	if not is_instance_valid(enemy_model_holder):
		return
	var to_player: Vector3 = enemy_last_seen - enemy.global_position
	to_player.y = 0.0
	if to_player.length_squared() < 0.001:
		return
	var target_angle: float = atan2(-to_player.x, -to_player.z) + PI
	enemy_model_holder.rotation.y = lerp_angle(enemy_model_holder.rotation.y,
		target_angle, minf(1.0, delta * ALERT_TURN_SPEED))

func _update_enemy_patrol(delta: float) -> void:
	if not enemy_alive or not is_instance_valid(enemy) or patrol_points.size() < 2:
		return
	if patrol_wait_time > 0.0:
		patrol_wait_time = maxf(0.0, patrol_wait_time - delta)
		_set_patrol_animation(false)
		return

	var movement := patrol_points[patrol_destination] - enemy.position
	movement.y = 0.0
	if movement.length() < 0.30:
		patrol_destination = (patrol_destination + 1) % patrol_points.size()
		patrol_wait_time = PATROL_WAIT
		patrol_steer_direction = Vector3.ZERO
		patrol_blocked_time = 0.0
		_set_patrol_animation(false)
		return

	var desired := movement.normalized()
	var selected := desired
	var obstacle_ahead := not _patrol_path_clear(desired, PATROL_SENSOR_DISTANCE)
	if obstacle_ahead:
		patrol_blocked_time += delta
		# Prioriza um desvio moderado; se bloqueado, testa angulos maiores.
		var found := false
		for degrees: float in [25.0, 45.0, 70.0, 95.0, 135.0, 180.0]:
			for sign_side: float in [patrol_avoid_side, -patrol_avoid_side]:
				var candidate: Vector3 = desired.rotated(Vector3.UP, deg_to_rad(degrees * sign_side))
				if _patrol_path_clear(candidate, PATROL_SENSOR_DISTANCE):
					selected = candidate
					patrol_avoid_side = sign_side
					found = true
					break
			if found:
				break
		if not found:
			_set_patrol_animation(false)
			# Sem saida visivel: inverte lado de busca, sem atravessar o objeto.
			if patrol_blocked_time > 1.2:
				patrol_avoid_side *= -1.0
				patrol_blocked_time = 0.0
			return
	else:
		patrol_blocked_time = 0.0

	# Suaviza a mudanca de direcao sem permitir atravesar obstaculos.
	if patrol_steer_direction.length_squared() < 0.01:
		patrol_steer_direction = selected
	var steer_weight := minf(1.0, delta * PATROL_TURN_SPEED)
	var smoothed := patrol_steer_direction.lerp(selected, steer_weight).normalized()
	if not _patrol_path_clear(smoothed, 0.48):
		smoothed = selected
	if not _patrol_path_clear(smoothed, 0.48):
		_set_patrol_animation(false)
		return
	patrol_steer_direction = smoothed
	var speed_factor := 0.72 if obstacle_ahead else 1.0
	enemy.position += smoothed * minf(PATROL_SPEED * speed_factor * delta, movement.length())
	if is_instance_valid(enemy_model_holder):
		# Mantem a compensacao de 180 graus aprovada no PATCH 025.1.2.
		var target_angle := atan2(-smoothed.x, -smoothed.z) + PI
		enemy_model_holder.rotation.y = lerp_angle(enemy_model_holder.rotation.y, target_angle, minf(1.0, delta * 4.0))
	_set_patrol_animation(true)

func _set_patrol_animation(walking: bool) -> void:
	if not is_instance_valid(enemy_anim_player):
		return
	var target := patrol_walk_anim if walking else patrol_idle_anim
	if target == "":
		return
	if enemy_anim_player.current_animation != target:
		enemy_anim_player.play(target, 0.2)

func _physics_process(delta: float) -> void:
	_update_enemy_awareness(delta)
	if enemy_ai_state == "PATRULHA":
		_update_enemy_patrol(delta)
	else:
		_update_enemy_alert_rotation(delta)
		_set_patrol_animation(false)
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	if not get_tree().paused and not reloading:
		if burst_remaining > 0 and fire_cooldown <= 0.0:
			if _fire():
				burst_remaining -= 1
				fire_cooldown = BURST_INTERVAL
			else:
				burst_remaining = 0
		elif fire_modes[fire_mode_index] == "A" and trigger_held and fire_cooldown <= 0.0:
			if _fire():
				fire_cooldown = FIRE_INTERVAL
	var axis := Vector2.ZERO
	axis.x = float(Input.is_key_pressed(KEY_D) or move_flags["right"]) - float(Input.is_key_pressed(KEY_A) or move_flags["left"])
	axis.y = float(Input.is_key_pressed(KEY_S) or move_flags["back"]) - float(Input.is_key_pressed(KEY_W) or move_flags["forward"])
	axis = (axis + mobile_joystick_axis).limit_length(1.0)
	var direction := (player.global_transform.basis * Vector3(axis.x, 0, axis.y)).normalized()
	var running: bool = (Input.is_key_pressed(KEY_SHIFT) or bool(move_flags["run"])) and not mobile_crouching
	var speed: float = (SPEED * 0.48) if mobile_crouching else (RUN_SPEED if running else SPEED)
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta
	else:
		if mobile_jump_requested:
			player.velocity.y = 6.0
		else:
			player.velocity.y = 0.0
	mobile_jump_requested = false
	# Agachar: diminui velocidade e altura da camera, sem modificar colisores.
	if is_instance_valid(camera):
		if mobile_camera_base_y == 0.0:
			mobile_camera_base_y = camera.position.y
		mobile_crouch_offset = move_toward(mobile_crouch_offset, -0.48 if mobile_crouching else 0.0, delta * 2.2)
		camera.position.y = mobile_camera_base_y + mobile_crouch_offset
	player.move_and_slide()

# O campo de visao da optica precisa cobrir somente a area visivel na lente.
# 1x = mesma escala angular por pixel da camera principal; zoom maior amplia.
func _update_ak12_scope_fov() -> void:
	if not is_instance_valid(ak12_scope_camera) or not is_instance_valid(camera):
		return
	var screen_height: float = maxf(1.0, camera.get_viewport().get_visible_rect().size.y)
	var lens_diameter: float = AK12_SCOPE_DIAMETER
	if is_instance_valid(ak12_scope_display) and ak12_scope_display.size.y > 1.0:
		lens_diameter = ak12_scope_display.size.y
	# A camera optica usa viewport quadrado; FOV e vertical no Godot.
	var visible_fraction: float = clampf(lens_diameter / screen_height, 0.01, 1.0)
	var reference_tan: float = tan(deg_to_rad(camera.fov) * 0.5)
	var optical_tan: float = reference_tan * visible_fraction / float(ak12_scope_zoom)
	ak12_scope_camera.fov = rad_to_deg(2.0 * atan(optical_tan))

# Cada nova entrada em ADS comeca com a visao optica natural em 1x.
func _reset_ak12_scope_zoom() -> void:
	ak12_scope_zoom = AK12_SCOPE_ZOOM_MIN
	if is_instance_valid(ak12_scope_camera):
		_update_ak12_scope_fov()
	print("[AK-12 OPTICA] Zoom inicial: 1x")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_captured:
		if smoke_inspection_enabled:
			smoke_inspection_yaw -= event.relative.x * 0.008
			smoke_inspection_pitch = clampf(smoke_inspection_pitch + event.relative.y * 0.008, -1.15, 1.15)
			_update_smoke_inspection_camera()
		else:
			_look(event.relative)
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		# Ajusta a ampliacao apenas enquanto mira com a AK-12.
		if not get_tree().paused and mouse_captured and equipped_weapon == 2 and aiming:
			var direction: int = 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1
			var next_zoom: int = clampi(ak12_scope_zoom + direction, AK12_SCOPE_ZOOM_MIN, AK12_SCOPE_ZOOM_MAX)
			if next_zoom != ak12_scope_zoom:
				ak12_scope_zoom = next_zoom
				if is_instance_valid(ak12_scope_camera):
					_update_ak12_scope_fov()
				_message("LUNETA AK-12: %dx" % ak12_scope_zoom, 1.0)
				print("[AK-12 OPTICA] Zoom: ", ak12_scope_zoom, "x")
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if not get_tree().paused and mouse_captured:
			if event.pressed and not aiming and equipped_weapon == 2:
				_reset_ak12_scope_zoom()
			aiming = event.pressed
		elif not event.pressed:
			aiming = false
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not get_tree().paused:
		if event.pressed and not mouse_captured:
			_capture_mouse()
		elif mouse_captured:
			_set_trigger(event.pressed)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T and not get_tree().paused:
			_clear_calibration_marks()
		elif event.keycode == KEY_F7 and not get_tree().paused:
			ads_debug_enabled = not ads_debug_enabled
			if not ads_debug_enabled:
				_set_smoke_inspection(false)
			print("[F7 CLARAO] ", "ATIVADO" if ads_debug_enabled else "DESATIVADO", " | offset=", ak12_flash_offset)
			_message("CLARAO: AJUSTE " + ("ATIVO" if ads_debug_enabled else "DESATIVADO"), 2.0)
			return
		elif ads_debug_enabled and not get_tree().paused and event.keycode == KEY_C:
			_set_smoke_inspection(not smoke_inspection_enabled)
			return
		elif smoke_inspection_enabled and not get_tree().paused and event.keycode in [KEY_Q, KEY_E]:
			smoke_inspection_yaw += 0.15 if event.keycode == KEY_Q else -0.15
			_update_smoke_inspection_camera()
			return
		elif ads_debug_enabled and not get_tree().paused and event.keycode in [KEY_I, KEY_K, KEY_J, KEY_L, KEY_O, KEY_P]:
			match event.keycode:
				KEY_I: ak12_flash_offset.y += 0.025
				KEY_K: ak12_flash_offset.y -= 0.025
				KEY_J: ak12_flash_offset.x -= 0.025
				KEY_L: ak12_flash_offset.x += 0.025
				KEY_O: ak12_flash_offset.z -= 0.05
				KEY_P: ak12_flash_offset.z += 0.05
			print("[F7 CLARAO] offset=", ak12_flash_offset)
			_message("CLARAO x=%.3f y=%.3f z=%.3f" % [ak12_flash_offset.x, ak12_flash_offset.y, ak12_flash_offset.z], 1.3)
			return
		# PATCH 025.3.52: o PC usa o mesmo pedido de pulo do Mobile HUD.
		# Espaco: pula somente se estiver no chao (validado na fisica).
		elif event.keycode == KEY_SPACE and not get_tree().paused and not OS.has_feature("mobile"):
			mobile_jump_requested = true
		# PATCH 025.3.50: CTRL alterna agachamento no PC.
		# C permanece reservado para inspecao F7 da AK-12.
		elif event.keycode in [KEY_CTRL] and not get_tree().paused and not OS.has_feature("mobile"):
			mobile_crouching = not mobile_crouching
			_message("AGACHADO" if mobile_crouching else "EM PE", 0.8)
		elif event.keycode == KEY_B and not get_tree().paused:
			fire_mode_index = (fire_mode_index + 1) % fire_modes.size()
			burst_remaining = 0
			_update_hud()
			_message("MODO DE TIRO: " + _fire_mode_name(), 1.5)
		elif event.keycode == KEY_H and not get_tree().paused:
			_toggle_hitboxes()
		elif event.keycode == KEY_R and not get_tree().paused:
			_reload()
		elif event.keycode == KEY_ESCAPE:
			_toggle_pause_menu()

func _build_pause_menu() -> void:
	if mobile:
		var mobile_menu := Control.new()
		mobile_menu.name = "MobilePauseMenu"
		mobile_menu.set_script(preload("res://scripts/mobile_pause.gd"))
		var layer := CanvasLayer.new()
		layer.name = "MobilePauseLayer"
		layer.layer = 20
		layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(layer)
		layer.add_child(mobile_menu)
		mobile_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mobile_menu.setup(self)
		return
	var overlay := CanvasLayer.new()
	overlay.name = "MenuPausa"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)
	pause_panel = PanelContainer.new()
	pause_panel.visible = false
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.position = Vector2(-140, -115)
	pause_panel.custom_minimum_size = Vector2(280, 230)
	overlay.add_child(pause_panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	pause_panel.add_child(layout)
	var heading := Label.new()
	heading.text = "MAPONTES FPS - PAUSADO"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(heading)
	var resume_button := Button.new()
	resume_button.text = "CONTINUAR"
	resume_button.pressed.connect(_toggle_pause_menu)
	layout.add_child(resume_button)
	var restart_button := Button.new()
	restart_button.text = "REINICIAR PARTIDA"
	restart_button.pressed.connect(_restart_game)
	layout.add_child(restart_button)
	var exit_button := Button.new()
	exit_button.text = "SAIR / FECHAR"
	exit_button.pressed.connect(_exit_game)
	layout.add_child(exit_button)
	var help := Label.new()
	help.text = "ESC: menu | H: mostrar/ocultar hitboxes"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(help)

func _toggle_pause_menu() -> void:
	if mobile:
		var mobile_menu = get_node_or_null("MobilePauseLayer/MobilePauseMenu")
		if mobile_menu != null:
			mobile_menu.toggle()
		return
	aiming = false
	_set_trigger(false)
	burst_remaining = 0
	if pause_panel == null:
		return
	var pausing: bool = not pause_panel.visible
	pause_panel.visible = pausing
	get_tree().paused = pausing
	if pausing:
		mouse_captured = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_capture_mouse()

func _exit_game() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().quit()

func _restart_game() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene()

func _capture_mouse() -> void:
	if mobile:
		return
	mouse_captured = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# PATCH 025.3.38: modo orbital apenas para observar a ponta do cano.
func _set_smoke_inspection(enabled: bool) -> void:
	smoke_inspection_enabled = enabled and ads_debug_enabled and is_instance_valid(smoke_inspection_camera)
	if smoke_inspection_enabled:
		_update_smoke_inspection_camera()
		smoke_inspection_camera.make_current()
		_message("INSPECAO CLARAO: MOUSE GIRA | C VOLTA | F7 SAI", 3.0)
	else:
		if is_instance_valid(camera):
			camera.make_current()
		_message("CAMERA NORMAL", 1.5)
	print("[F7 CLARAO] Camera inspecao: ", "ATIVADA" if smoke_inspection_enabled else "DESATIVADA")

func _update_smoke_inspection_camera() -> void:
	if not is_instance_valid(smoke_inspection_camera) or not is_instance_valid(weapon_pivot):
		return
	var center: Vector3 = weapon_pivot.to_global(AK12_MUZZLE_LOCAL + ak12_flash_offset)
	var direction := Vector3(cos(smoke_inspection_pitch) * sin(smoke_inspection_yaw), sin(smoke_inspection_pitch), cos(smoke_inspection_pitch) * cos(smoke_inspection_yaw))
	smoke_inspection_camera.global_position = center + direction * smoke_inspection_distance
	smoke_inspection_camera.look_at(center, Vector3.UP)

func _look(relative: Vector2) -> void:
	player.rotate_y(-relative.x * SENSITIVITY)
	pitch = clamp(pitch - relative.y * SENSITIVITY, -1.35, 1.35)
	camera.rotation.x = clampf(pitch + camera_recoil_pitch, -1.35, 1.35)

func _fire_mode_name() -> String:
	match fire_modes[fire_mode_index]:
		"A": return "A - AUTOMATICO"
		"S": return "S - RAJADA 3"
		_: return "U - UNICO"

func _set_trigger(pressed: bool) -> void:
	if pressed and not trigger_latched and not get_tree().paused:
		trigger_held = true
		match fire_modes[fire_mode_index]:
			"A":
				if fire_cooldown <= 0.0 and _fire():
					fire_cooldown = FIRE_INTERVAL
			"S":
				burst_remaining = 3
			"U":
				if fire_cooldown <= 0.0 and _fire():
					fire_cooldown = FIRE_INTERVAL
	elif not pressed:
		trigger_held = false
	trigger_latched = pressed

func _fire() -> bool:
	if get_tree().paused or reloading:
		return false
	if ammo <= 0:
		_message("SEM MUNICAO: RECARREGUE!", 1.5)
		return false
	ammo -= 1
	_weapon_action("shot")
	weapon_kick = minf(weapon_kick + 0.24, 0.32)
	# Cada disparo levanta ligeiramente a visao e desloca-a para um lado.
	# Em ADS, o recuo e mais contido para permitir acompanhar o alvo.
	var recoil_scale: float = 0.60 if aiming else 1.0
	camera_recoil_pitch = clampf(camera_recoil_pitch + 0.010 * recoil_scale, 0.0, 0.045)
	camera_recoil_yaw = clampf(camera_recoil_yaw + randf_range(-0.004, 0.004) * recoil_scale, -0.018, 0.018)
	camera.rotation.x = clampf(pitch + camera_recoil_pitch, -1.35, 1.35)
	camera.rotation.y = camera_recoil_yaw
	_update_hud()
	_muzzle_flash()
	_spawn_muzzle_smoke()
	_eject_ak12_casing()
	var center := get_viewport().get_visible_rect().size / 2.0
	var from := camera.project_ray_origin(center)
	var to := from + camera.project_ray_normal(center) * 120.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var hit_zone: String = ""
	if not hit.is_empty() and enemy_hitboxes.has(hit.collider):
		hit_zone = str(enemy_hitboxes[hit.collider])
	if not hit.is_empty():
		if hit.collider == calibration_target:
			_mark_calibration_hit(hit.position)
		else:
			_spawn_impact(hit.position, hit.normal, hit_zone != "")
			# PATCH 025.3.42: marcas persistentes em todas as estruturas estaticas.
			# Inimigos, alvos destrutiveis e o alvo ADS continuam com logica propria.
			if hit_zone == "" and hit.collider is StaticBody3D and not hit.collider in targets:
				var surface_name: String = str(hit.collider.name).to_lower()
				var surface_kind: String = "concreto"
				if "container" in surface_name or "metal" in surface_name or "chapa" in surface_name or "portao" in surface_name:
					surface_kind = "metal"
				elif hit.normal.y > 0.65:
					surface_kind = "piso"
				_room_bullet_mark(hit.position, hit.normal, surface_kind, from.distance_to(hit.position))
	if hit_zone != "" and enemy_alive:
		var zone: String = hit_zone
		var damage: int = 100 if zone == "CABECA" else (35 if zone == "TRONCO" else (20 if zone == "BRACO" else 15))
		enemy_health = maxi(0, enemy_health - damage)
		if enemy_health == 0:
			enemy_alive = false
			enemy.queue_free()
			_message("INIMIGO ELIMINADO - " + zone + "!", 2.0)
		else:
			_message(zone + " -" + str(damage) + " HP | VIDA: " + str(enemy_health), 1.5)
	elif not hit.is_empty() and hit.collider in targets:
		var target: StaticBody3D = hit.collider
		targets.erase(target)
		target.queue_free()
		_message("ALVO ATINGIDO!", 1.4)
	return true

# Efeitos leves sem assets adicionais: brilho do disparo e fragmentos de impacto.
# PATCH 025.3.27: efeitos leves gerados por geometria, sem texturas externas.
# Os efeitos pertencem ao pivot da arma e nao entram na camera optica (layer 2).
# Ajuste visual do ponto de saida do cano (coordenadas locais do pivot).
# Godot: a direcao frontal da camera e -Z, nao +Z.
const AK12_MUZZLE_LOCAL: Vector3 = Vector3(-0.02, 0.07, -0.82)

func _muzzle_flash() -> void:
	if not is_instance_valid(weapon_pivot) or equipped_weapon != 2:
		return
	var root := Node3D.new()
	root.name = "AK12_Clarão_Disparo"
	weapon_pivot.add_child(root)
	root.position = AK12_MUZZLE_LOCAL + ak12_flash_offset
	for i in range(6):
		var flame := MeshInstance3D.new()
		flame.layers = 2
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = 0.012 if i > 0 else 0.026
		mesh.height = randf_range(0.13, 0.22)
		flame.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 0.86, 0.43, 0.92) if i == 0 else Color(1.0, 0.43, 0.07, 0.78)
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 3.2
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		flame.material_override = mat
		root.add_child(flame)
		flame.rotation_degrees = Vector3(-90.0, 0.0, float(i) * 60.0 + randf_range(-10.0, 10.0))
		flame.position = Vector3(0.0, 0.0, 0.07)
	get_tree().create_timer(0.052).timeout.connect(func():
		if is_instance_valid(root):
			root.queue_free()
	)

func _spawn_muzzle_smoke() -> void:
	if not is_instance_valid(weapon_pivot) or equipped_weapon != 2:
		return
	# Fumaca segue o cano no instante do tiro, depois se dissipa suavemente.
	# PATCH 025.3.35: avancar somente a origem da fumaca, sem mover arma, clarão ou disparos.
	# Offset local acompanha a rotacao da arma (inclusive ao mirar).
	var smoke_local: Vector3 = AK12_MUZZLE_LOCAL + ak12_smoke_offset
	var origin: Vector3 = weapon_pivot.to_global(smoke_local)
	var forward: Vector3 = weapon_pivot.global_transform.basis.z.normalized()
	for i in range(3):
		var puff := MeshInstance3D.new()
		puff.name = "AK12_Fumaca"
		puff.layers = 3
		var sphere := SphereMesh.new()
		sphere.radius = 0.018 + float(i) * 0.008
		sphere.height = sphere.radius * 2.0
		sphere.radial_segments = 8
		sphere.rings = 4
		puff.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.78, 0.81, 0.83, 0.30 - float(i) * 0.055)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		puff.material_override = mat
		add_child(puff)
		puff.global_position = origin + forward * (float(i) * 0.045)
		var drift: Vector3 = forward * randf_range(0.09, 0.20) + Vector3(randf_range(-0.05, 0.05), randf_range(0.09, 0.19), 0.0)
		var duration: float = 0.48 + float(i) * 0.12
		var tween := create_tween().set_parallel(true)
		tween.tween_property(puff, "global_position", puff.global_position + drift, duration)
		tween.tween_property(puff, "scale", Vector3.ONE * 3.6, duration)
		tween.tween_property(mat, "albedo_color:a", 0.0, duration)
		tween.chain().tween_callback(puff.queue_free)

func _eject_ak12_casing() -> void:
	if not is_instance_valid(weapon_pivot) or equipped_weapon != 2:
		return
	# Casquilho visual leve: sem RigidBody, para nao alterar a fisica dos tiros.
	var casing := MeshInstance3D.new()
	casing.name = "AK12_Capsula"
	casing.layers = 2
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.007
	mesh.bottom_radius = 0.007
	mesh.height = 0.033
	casing.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.metallic = 0.8
	mat.roughness = 0.3
	mat.albedo_color = Color(0.78, 0.60, 0.25)
	casing.material_override = mat
	add_child(casing)
	var origin: Vector3 = weapon_pivot.to_global(Vector3(0.09, 0.09, 0.15))
	casing.global_position = origin
	var side: Vector3 = weapon_pivot.global_transform.basis.x.normalized()
	var back: Vector3 = -weapon_pivot.global_transform.basis.z.normalized()
	var flight: Vector3 = side * randf_range(0.22, 0.38) + back * 0.08 + Vector3.UP * randf_range(0.14, 0.25)
	var peak: Vector3 = origin + flight * 0.55
	var finish: Vector3 = origin + flight + Vector3.DOWN * 0.28
	var tween := create_tween().set_parallel(true)
	var position_track := create_tween()
	position_track.tween_property(casing, "global_position", peak, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	position_track.tween_property(casing, "global_position", finish, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(casing, "rotation_degrees", Vector3(randf_range(400.0, 720.0), randf_range(240.0, 480.0), randf_range(360.0, 650.0)), 0.48)
	position_track.tween_callback(casing.queue_free)

func _spawn_impact(point: Vector3, normal: Vector3, on_enemy: bool) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.65, 0.16, 0.12) if on_enemy else Color(0.68, 0.59, 0.42)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var n: Vector3 = normal.normalized()
	if n.length_squared() < 0.01:
		n = Vector3.UP
	for i in range(9):
		var particle := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		var sz: float = randf_range(0.025, 0.075)
		mesh.size = Vector3.ONE * sz
		particle.mesh = mesh
		particle.material_override = material
		add_child(particle)
		particle.global_position = point + n * 0.06
		var direction: Vector3 = (n * randf_range(0.2, 0.9) + Vector3(randf_range(-1.0, 1.0), randf_range(-0.1, 0.8), randf_range(-1.0, 1.0))).normalized()
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", particle.global_position + direction * randf_range(0.3, 1.1), 0.38)
		tween.tween_property(particle, "scale", Vector3.ZERO, 0.38)
		tween.chain().tween_callback(particle.queue_free)

func _reload() -> void:
	if reloading or ammo == MAX_AMMO or reserve <= 0:
		return
	reloading = true
	burst_remaining = 0
	_set_trigger(false)
	reload_progress = 0.0
	active_reload_duration = RELOAD_EMPTY_SECONDS if ammo == 0 else RELOAD_SECONDS
	if weapon_animation != null:
		var selected: String = ""
		for anim_name in weapon_animation.get_animation_list():
			var low: String = String(anim_name).to_lower()
			if equipped_weapon == 2 and low.ends_with("reload"):
				selected = String(anim_name)
				break
			if ammo == 0 and "ak_reload_full" in low:
				selected = String(anim_name)
				break
			if ammo > 0 and "ak_reload" in low and "full" not in low and "var2" not in low:
				selected = String(anim_name)
				break
		if selected != "":
			weapon_reload_animation = selected
			var animation: Animation = weapon_animation.get_animation(selected)
			if animation != null:
				active_reload_duration = animation.length
				weapon_animation.speed_scale = 1.0
				weapon_animation.play(selected)
				weapon_state = "reload"
				weapon_action_time = 0.0
	_message("RECARREGANDO...", active_reload_duration)
	await get_tree().create_timer(active_reload_duration).timeout
	if not is_inside_tree():
		return
	var needed: int = mini(MAX_AMMO - ammo, reserve)
	ammo += needed
	reserve -= needed
	reloading = false
	reload_progress = 0.0
	weapon_state = ""
	if weapon_animation != null and weapon_reload_animation != "":
		weapon_animation.speed_scale = 1.0
	_update_hud()

func _on_case_entered(body: Node3D, case_node: Area3D) -> void:
	if body != player or not is_instance_valid(case_node):
		return
	briefcases.erase(case_node)
	case_node.queue_free()
	collected += 1
	_update_hud()
	if collected == 3:
		_message("OBJETIVO CONCLUIDO! ETAPA 1 DO PROTOTIPO FINALIZADA.", 20.0)
	else:
		_message("MALETA RECUPERADA!", 2.0)

func _update_hud() -> void:
	if ammo_label:
		ammo_label.text = "%s | MUNICAO: %d / %d" % [("AK-74M" if equipped_weapon == 1 else "AK-12"), ammo, reserve]
	if fire_mode_label:
		fire_mode_label.text = "TIRO [B]: " + _fire_mode_name()
	if objective_label:
		objective_label.text = "MALETAS: %d / 3" % collected

func _message(message: String, seconds: float) -> void:
	if status_label:
		status_label.text = message
	status_time = seconds
