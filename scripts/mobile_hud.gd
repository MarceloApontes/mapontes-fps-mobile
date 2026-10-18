extends Control
# MAPONTES FPS - PATCH 025.3.49 MOBILE HUD 2.4
# Controles independentes por indice de toque; exclusivo Android.

var game: Node3D
var joystick_sensitivity := 1.0
var camera_sensitivity := 1.0
var custom_positions: Dictionary = {}
var custom_sizes: Dictionary = {}
var pause_center := Vector2.ZERO
const SETTINGS_PATH := "user://mapontes_mobile_hud.cfg"
const ACTIONS = ["tiro", "mirar", "modo", "correr", "recarregar", "agachar", "pular", "pausa", "zoom"]
var joystick_finger := -1
var fire_finger := -1
var run_finger := -1
var auto_run_forward := false
var reload_finger := -1
var crouch_finger := -1
var jump_finger := -1
var reload_center := Vector2.ZERO
var crouch_center := Vector2.ZERO
var jump_center := Vector2.ZERO
var button_sprites := {}
var run_center := Vector2.ZERO
var camera_finger := -1
var zoom_finger := -1
var mode_notice_time := 0.0
var mode_notice_text := ""
var joystick_axis := Vector2.ZERO
var joystick_center := Vector2.ZERO
var fire_center := Vector2.ZERO
var aim_center := Vector2.ZERO
var mode_center := Vector2.ZERO
var zoom_top := Vector2.ZERO
var zoom_bottom := Vector2.ZERO
var zoom_center := Vector2.ZERO
var zoom_height := 0.0
var scale_factor := 1.0
var joystick_radius := 104.0
var button_radius := 65.0
var zoom_radius := 28.0
var default_button_radius := 65.0

func setup(owner_game: Node3D) -> void:
	game = owner_game
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)
	resized.connect(_layout_controls)
	load_settings()
	_layout_controls()
	_load_button_sprites()

func _layout_controls() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	scale_factor = clampf(minf(size.x / 1920.0, size.y / 1080.0), 0.55, 1.55)
	joystick_radius = 104.0 * scale_factor
	button_radius = 65.0 * scale_factor
	default_button_radius = button_radius
	zoom_radius = 32.0 * scale_factor
	mode_center = Vector2(size.x - 142.0 * scale_factor, size.y - 170.0 * scale_factor)
	fire_center = Vector2(size.x - 325.0 * scale_factor, size.y - 258.0 * scale_factor)
	aim_center = Vector2(size.x - 130.0 * scale_factor, size.y - 350.0 * scale_factor)
	run_center = Vector2(size.x - 330.0 * scale_factor, size.y - 465.0 * scale_factor)
	reload_center = Vector2(size.x - 515.0 * scale_factor, size.y - 240.0 * scale_factor)
	crouch_center = Vector2(size.x - 515.0 * scale_factor, size.y - 410.0 * scale_factor)
	jump_center = Vector2(size.x - 515.0 * scale_factor, size.y - 580.0 * scale_factor)
	pause_center = Vector2(size.x - 95.0 * scale_factor, 75.0 * scale_factor)
	for action in ACTIONS:
		if custom_positions.has(action):
			set_action_center(action, Vector2(float(custom_positions[action][0]) * size.x, float(custom_positions[action][1]) * size.y))
	zoom_center = Vector2(size.x - 68.0 * scale_factor, size.y * 0.425)
	zoom_height = size.y * 0.41
	if custom_positions.has("zoom"):
		zoom_center = Vector2(float(custom_positions["zoom"][0]) * size.x, float(custom_positions["zoom"][1]) * size.y)
	_update_zoom_bounds()
	queue_redraw()

func _update_zoom_bounds() -> void:
	var half := zoom_height * get_action_scale("zoom") * 0.5
	zoom_top = zoom_center - Vector2(0.0, half)
	zoom_bottom = zoom_center + Vector2(0.0, half)

func get_action_scale(action: String) -> float:
	return clampf(float(custom_sizes.get(action, 1.0)), 0.55, 2.0)

func get_action_radius(action: String) -> float:
	return default_button_radius * get_action_scale(action)

func set_action_scale(action: String, value: float) -> void:
	custom_sizes[action] = clampf(value, 0.55, 2.0)
	if action == "zoom":
		_update_zoom_bounds()
	queue_redraw()

func _zoom_visible() -> bool:
	return game != null and game.equipped_weapon == 2 and game.aiming and not game.reloading

func _input(event: InputEvent) -> void:
	if game == null or game.get_tree().paused:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_start_touch(event.index, event.position)
		else:
			_end_touch(event.index)
	elif event is InputEventScreenDrag:
		if event.index == joystick_finger:
			_update_joystick(event.position)
			get_viewport().set_input_as_handled()
		elif event.index == zoom_finger:
			_update_zoom(event.position)
			get_viewport().set_input_as_handled()
		elif event.index == camera_finger:
			game._look(event.relative * 0.75 * camera_sensitivity)
			get_viewport().set_input_as_handled()

func _start_touch(finger: int, pos: Vector2) -> void:
	if auto_run_forward and not bool(game.move_flags["run"]):
		auto_run_forward = false
		game.move_flags["forward"] = false
	# Botoes tem prioridade sobre camera/joystick.
	if pos.distance_to(pause_center) <= get_action_radius("pausa") * 0.8:
		game._toggle_pause_menu()
	elif pos.distance_to(fire_center) <= get_action_radius("tiro") * 1.3:
		if fire_finger == -1:
			fire_finger = finger
			game._set_trigger(true)
	elif pos.distance_to(reload_center) <= get_action_radius("recarregar") * 1.3:
		if reload_finger == -1:
			reload_finger = finger
			game._reload()
	elif pos.distance_to(crouch_center) <= get_action_radius("agachar") * 1.3:
		if crouch_finger == -1:
			crouch_finger = finger
			game.mobile_crouching = not game.mobile_crouching
	elif pos.distance_to(jump_center) <= get_action_radius("pular") * 1.3:
		if jump_finger == -1:
			jump_finger = finger
			game.mobile_jump_requested = true
	elif pos.distance_to(run_center) <= get_action_radius("correr") * 1.3:
		if run_finger == -1:
			run_finger = finger
			auto_run_forward = not auto_run_forward
			game.move_flags["run"] = auto_run_forward
			game.move_flags["forward"] = auto_run_forward
	elif pos.distance_to(aim_center) <= get_action_radius("mirar") * 1.3:
		if game.aiming:
			game.aiming = false
		else:
			if game.equipped_weapon == 2:
				game._reset_ak12_scope_zoom()
			game.aiming = true
	elif pos.distance_to(mode_center) <= get_action_radius("modo") * 1.3:
		game.fire_mode_index = (game.fire_mode_index + 1) % game.fire_modes.size()
		game.burst_remaining = 0
		game._update_hud()
		mode_notice_text = "MODO DE TIRO: " + game._fire_mode_name()
		mode_notice_time = 1.3
	elif _zoom_visible() and absf(pos.x - zoom_top.x) <= zoom_radius * 2.2 * get_action_scale("zoom") and pos.y >= zoom_top.y - zoom_radius * get_action_scale("zoom") and pos.y <= zoom_bottom.y + zoom_radius * get_action_scale("zoom"):
		if zoom_finger == -1:
			zoom_finger = finger
			_update_zoom(pos)
	elif pos.x < size.x * 0.5 and joystick_finger == -1:
		joystick_finger = finger
		joystick_center = pos
		joystick_axis = Vector2.ZERO
		game.mobile_joystick_axis = Vector2.ZERO
	elif pos.x >= size.x * 0.5 and camera_finger == -1:
		camera_finger = finger
	else:
		return
	queue_redraw()
	get_viewport().set_input_as_handled()

func _end_touch(finger: int) -> void:
	var handled := false
	if finger == joystick_finger:
		joystick_finger = -1
		joystick_axis = Vector2.ZERO
		game.mobile_joystick_axis = Vector2.ZERO
		handled = true
	elif finger == fire_finger:
		fire_finger = -1
		game._set_trigger(false)
		handled = true
	elif finger == reload_finger:
		reload_finger = -1
		handled = true
	elif finger == crouch_finger:
		crouch_finger = -1
		handled = true
	elif finger == jump_finger:
		jump_finger = -1
		handled = true
	elif finger == run_finger:
		run_finger = -1
		handled = true
	elif finger == zoom_finger:
		zoom_finger = -1
		handled = true
	elif finger == camera_finger:
		camera_finger = -1
		handled = true
	if handled:
		queue_redraw()
		get_viewport().set_input_as_handled()

func _update_joystick(pos: Vector2) -> void:
	joystick_axis = ((pos - joystick_center) / joystick_radius * joystick_sensitivity).limit_length(1.0)
	if auto_run_forward and joystick_axis.y < -0.40:
		auto_run_forward = false
		game.move_flags["run"] = false
		game.move_flags["forward"] = false
	game.mobile_joystick_axis = joystick_axis
	queue_redraw()

func _update_zoom(pos: Vector2) -> void:
	if not _zoom_visible():
		return
	var t := clampf((zoom_bottom.y - pos.y) / maxf(1.0, zoom_bottom.y - zoom_top.y), 0.0, 1.0)
	var next_zoom := clampi(roundi(1.0 + t * 5.0), 1, 6)
	if next_zoom != game.ak12_scope_zoom:
		game.ak12_scope_zoom = next_zoom
		game._update_ak12_scope_fov()
	queue_redraw()

func _process(_delta: float) -> void:
	if mode_notice_time > 0.0:
		mode_notice_time = maxf(0.0, mode_notice_time - _delta)
	if game != null and not _zoom_visible() and zoom_finger != -1:
		zoom_finger = -1
	queue_redraw()

func _draw() -> void:
	if size.x < 1.0 or game == null:
		return
	var rim := Color(0.49, 0.85, 0.88, 0.7)
	if joystick_finger != -1:
		draw_circle(joystick_center, joystick_radius, Color(0.035, 0.075, 0.09, 0.40))
		draw_arc(joystick_center, joystick_radius, 0, TAU, 72, rim, 3.0 * scale_factor, true)
		var knob := joystick_center + joystick_axis * joystick_radius * 0.64
		draw_circle(knob, joystick_radius * 0.4, Color(0.18, 0.51, 0.55, 0.8))
		draw_arc(knob, joystick_radius * 0.4, 0, TAU, 48, Color(0.75, 0.98, 0.96, 0.9), 2.0 * scale_factor, true)
	_draw_action(pause_center, "PAUSA", false, Color(0.74, 0.91, 0.95, 0.92))
	_draw_action(fire_center, "TIRO", fire_finger != -1, Color(0.96, 0.45, 0.28, 0.92))
	_draw_action(run_center, "CORRER", auto_run_forward, Color(0.46, 0.91, 0.58, 0.94))
	_draw_action(reload_center, "RECARREGAR", reload_finger != -1, Color(0.72, 0.88, 0.98, 0.94))
	_draw_action(crouch_center, "AGACHAR", game.mobile_crouching, Color(0.75, 0.87, 0.96, 0.94))
	_draw_action(jump_center, "PULAR", jump_finger != -1, Color(0.82, 0.92, 0.98, 0.94))
	_draw_action(aim_center, "MIRAR", game.aiming, Color(0.43, 0.84, 0.93, 0.94))
	_draw_action(mode_center, "MODO " + game.fire_modes[game.fire_mode_index], false, Color(0.8, 0.81, 0.55, 0.9))
	if _zoom_visible():
		_draw_zoom()
	if mode_notice_time > 0.0:
		_draw_mode_notice()

func _draw_zoom() -> void:
	var zoom_scale := get_action_scale("zoom")
	var t := float(game.ak12_scope_zoom - 1) / 5.0
	var knob := zoom_bottom.lerp(zoom_top, t)
	draw_line(zoom_top, zoom_bottom, Color(0.06, 0.12, 0.15, 0.72), 17.0 * scale_factor * zoom_scale, true)
	draw_line(zoom_top, zoom_bottom, Color(0.50, 0.87, 0.91, 0.85), 4.0 * scale_factor * zoom_scale, true)
	for i in range(6):
		var tick := zoom_bottom.lerp(zoom_top, float(i) / 5.0)
		draw_line(tick - Vector2(9.0, 0.0) * scale_factor * zoom_scale, tick + Vector2(9.0, 0.0) * scale_factor * zoom_scale, Color(0.83, 0.97, 0.97, 0.85), 2.0 * scale_factor)
	draw_circle(knob, zoom_radius * zoom_scale, Color(0.12, 0.38, 0.44, 0.95))
	draw_arc(knob, zoom_radius * zoom_scale, 0, TAU, 48, Color(0.83, 0.98, 0.99), 2.0 * scale_factor, true)
	var label := "%dX" % game.ak12_scope_zoom
	var font := ThemeDB.fallback_font
	var font_size := maxi(12, roundi(23.0 * scale_factor))
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, knob - Vector2(text_size.x * 0.5, -text_size.y * 0.30), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

func _draw_action(center: Vector2, label: String, pressed: bool, accent: Color) -> void:
	var key := label.split(" ")[0].to_lower()
	var action_scale := get_action_scale(key)
	var button_radius_local := get_action_radius(key)
	if label == "PAUSA":
		draw_circle(center, button_radius_local * 0.66, Color(0.04, 0.10, 0.13, 0.75))
		draw_arc(center, button_radius_local * 0.66, 0, TAU, 48, Color(0.7, 0.93, 0.95), 3.0 * scale_factor * action_scale)
		for side in [-1.0, 1.0]:
			draw_rect(Rect2(center + Vector2(side * 11.0 * scale_factor - 4.0 * scale_factor * action_scale, -16.0 * scale_factor), Vector2(8.0, 32.0) * scale_factor), Color.WHITE)
		return
	if button_sprites.has(key):
		var side := button_radius_local * 2.0
		var dst := Rect2(center - Vector2.ONE * button_radius_local, Vector2.ONE * side)
		draw_texture_rect(button_sprites[key], dst, false, Color(1.0, 1.0, 1.0, 0.96 if pressed else 0.76))
		if pressed:
			draw_circle(center, button_radius_local * 0.73, Color(accent.r, accent.g, accent.b, 0.18))
		if key == "modo":
			var font := ThemeDB.fallback_font
			draw_string(font, center + Vector2(button_radius_local * 0.46, -button_radius_local * 0.47), game.fire_modes[game.fire_mode_index], HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(15, roundi(24.0 * scale_factor * action_scale)), Color.WHITE)
		return
	draw_circle(center, button_radius_local, Color(0.035, 0.065, 0.075, 0.64 if pressed else 0.44))
	draw_arc(center, button_radius_local, 0, TAU, 64, accent, 4.0 * scale_factor * action_scale, true)
	if pressed:
		draw_circle(center, button_radius_local * 0.84, Color(accent.r, accent.g, accent.b, 0.20))
	var font := ThemeDB.fallback_font
	var font_size := maxi(12, roundi((19.0 if label.length() > 5 else 25.0) * scale_factor))
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, center - Vector2(text_size.x * 0.5, -text_size.y * 0.30), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.92, 0.98, 1.0))

func _draw_mode_notice() -> void:
	var opacity := clampf(mode_notice_time / 0.35, 0.0, 1.0)
	var font := ThemeDB.fallback_font
	var font_size := maxi(17, roundi(33.0 * scale_factor))
	var text_width := font.get_string_size(mode_notice_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var center := Vector2(size.x * 0.5, size.y * 0.46)
	var rect := Rect2(center - Vector2(text_width * 0.5 + 24.0 * scale_factor, 30.0 * scale_factor),
		Vector2(text_width + 48.0 * scale_factor, 60.0 * scale_factor))
	draw_rect(rect, Color(0.025, 0.075, 0.085, 0.74 * opacity), true)
	draw_rect(rect, Color(0.51, 0.89, 0.87, 0.82 * opacity), false, 2.0 * scale_factor)
	draw_string(font, Vector2(center.x - text_width * 0.5, center.y + 10.0 * scale_factor),
		mode_notice_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.96, 1.0, 1.0, opacity))

func _load_button_sprites() -> void:
	for action in ["tiro", "mirar", "modo", "correr", "recarregar", "agachar", "pular"]:
		var path := "res://assets/mobile_hud/btn_%s.png" % action
		if ResourceLoader.exists(path):
			button_sprites[action] = load(path)

# Preferencias persistentes do Android (mantidas entre sessoes).
func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	joystick_sensitivity = clampf(float(cfg.get_value("sensitivity", "joystick", 1.0)), 0.4, 2.0)
	camera_sensitivity = clampf(float(cfg.get_value("sensitivity", "camera", 1.0)), 0.4, 2.0)
	var stored = cfg.get_value("hud", "positions", {})
	if stored is Dictionary:
		custom_positions = stored.duplicate(true)
	var sizes = cfg.get_value("hud", "sizes", {})
	if sizes is Dictionary:
		custom_sizes = sizes.duplicate(true)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("sensitivity", "joystick", joystick_sensitivity)
	cfg.set_value("sensitivity", "camera", camera_sensitivity)
	cfg.set_value("hud", "positions", custom_positions)
	cfg.set_value("hud", "sizes", custom_sizes)
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Nao foi possivel salvar configuracoes do HUD: %s" % err)

func get_action_center(action: String) -> Vector2:
	match action:
		"tiro": return fire_center
		"mirar": return aim_center
		"modo": return mode_center
		"correr": return run_center
		"recarregar": return reload_center
		"agachar": return crouch_center
		"pular": return jump_center
		"pausa": return pause_center
		"zoom": return zoom_center
	return Vector2.ZERO

func set_action_center(action: String, center: Vector2) -> void:
	var margin := get_action_radius(action)
	var p := Vector2(clampf(center.x, margin, maxf(margin, size.x - margin)), clampf(center.y, margin, maxf(margin, size.y - margin)))
	match action:
		"tiro": fire_center = p
		"mirar": aim_center = p
		"modo": mode_center = p
		"correr": run_center = p
		"recarregar": reload_center = p
		"agachar": crouch_center = p
		"pular": jump_center = p
		"pausa": pause_center = p
		"zoom":
			zoom_center = p
			_update_zoom_bounds()
	queue_redraw()

func save_current_layout() -> void:
	for action in ACTIONS:
		var center := get_action_center(action)
		custom_positions[action] = [center.x / maxf(size.x, 1.0), center.y / maxf(size.y, 1.0)]
	save_settings()

func restore_default_layout() -> void:
	custom_positions.clear()
	custom_sizes.clear()
	_layout_controls()
