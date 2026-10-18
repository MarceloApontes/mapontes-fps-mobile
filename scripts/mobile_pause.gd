extends Control
# PATCH 025.3.53 - Pausa, audio, sensibilidade e editor HUD mobile.
# Este controle continua processando com a arvore pausada.
var game
var hud
var panel: PanelContainer
var content: VBoxContainer
var edit_overlay: Control
var drag_action := ""
var drag_finger := -1
var drag_origin := Vector2.ZERO
var original_positions: Dictionary = {}
var audio_slider: HSlider
var joy_slider: HSlider
var cam_slider: HSlider
var edit_status: Label
var backdrop: ColorRect
var sensitivity_value: Label
var editor_title: Label
var original_sizes: Dictionary = {}
var edit_touches: Dictionary = {}
var selected_action := ""
var pinch_start_distance := 0.0
var pinch_start_scale := 1.0
const ACTION_NAMES = {"tiro":"TIRO", "mirar":"MIRAR", "modo":"MODO", "correr":"CORRER", "recarregar":"RECARREGAR", "agachar":"AGACHAR", "pular":"PULAR", "pausa":"PAUSA", "zoom":"ZOOM"}

func setup(owner_game: Node3D) -> void:
	game = owner_game
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	hud = game.get_node_or_null("MobileHUD")
	if hud == null:
		hud = game.find_child("MobileHUD2", true, false)
	# HUD criado na CanvasLayer; localizar pelo script / nome.
	if hud == null:
		for child in game.get_children():
			if child is CanvasLayer:
				for item in child.get_children():
					if item is Control and item.has_method("save_current_layout"):
						hud = item
	var saved := ConfigFile.new()
	if saved.load("user://mapontes_mobile_hud.cfg") == OK:
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(saved.get_value("audio", "master", 1.0)), 0.0001)))
	_build_ui()

func _build_ui() -> void:
	backdrop = ColorRect.new()
	backdrop.color = Color(0.015, 0.04, 0.055, 0.88)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(680, 610)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	_show_main()

func _clear_content() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

func _heading(label: String) -> void:
	var heading := Label.new()
	heading.text = label
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 36)
	content.add_child(heading)

func _button(label: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size.y = 66
	b.add_theme_font_size_override("font_size", 29)
	b.pressed.connect(callback)
	content.add_child(b)

func _show_main() -> void:
	_clear_content()
	_heading("MAPONTES FPS  |  PAUSADO")
	_button("CONTINUAR", toggle)
	_button("AUDIO", _show_audio)
	_button("SENSIBILIDADE", _show_sensitivity)
	_button("HUD  -  EDITAR BOTOES", _begin_edit)
	_button("REINICIAR", game._restart_game)
	_button("SAIR", game._exit_game)

func _slider_row(label: String, initial: float, low: float, high: float, step: float) -> HSlider:
	var title := Label.new()
	title.text = label
	title.add_theme_font_size_override("font_size", 27)
	content.add_child(title)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = initial
	slider.custom_minimum_size = Vector2(420, 38)
	content.add_child(slider)
	return slider

func _show_audio() -> void:
	_clear_content()
	_heading("CONFIGURACOES DE AUDIO")
	var db := AudioServer.get_bus_volume_db(0)
	audio_slider = _slider_row("Volume geral", db_to_linear(db) * 100.0, 0.0, 100.0, 1.0)
	audio_slider.value_changed.connect(func(value: float): AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value / 100.0, 0.0001))))
	_button("SALVAR E VOLTAR", func():
		var cfg := ConfigFile.new()
		cfg.load("user://mapontes_mobile_hud.cfg")
		cfg.set_value("audio", "master", audio_slider.value / 100.0)
		cfg.save("user://mapontes_mobile_hud.cfg")
		_show_main())

func _show_sensitivity() -> void:
	_clear_content()
	_heading("SENSIBILIDADE DO MOVIMENTO")
	if hud == null:
		_button("VOLTAR", _show_main)
		return
	var explanation := Label.new()
	explanation.text = "Ajuste a resposta do joystick virtual."
	explanation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	explanation.add_theme_font_size_override("font_size", 25)
	content.add_child(explanation)
	sensitivity_value = Label.new()
	sensitivity_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sensitivity_value.add_theme_font_size_override("font_size", 31)
	content.add_child(sensitivity_value)
	joy_slider = _slider_row("Sensibilidade do joystick", hud.joystick_sensitivity, 0.4, 2.0, 0.05)
	_update_sensitivity_label(joy_slider.value)
	joy_slider.value_changed.connect(func(value: float):
		hud.joystick_sensitivity = value
		_update_sensitivity_label(value))
	_button("SALVAR", func():
		hud.save_settings()
		_show_main())
	_button("VOLTAR", _show_main)

func _update_sensitivity_label(value: float) -> void:
	if sensitivity_value != null:
		sensitivity_value.text = "%d%%" % roundi(value * 100.0)

func _begin_edit() -> void:
	if hud == null:
		_clear_content()
		_heading("HUD NAO ENCONTRADO")
		_button("VOLTAR", _show_main)
		return
	original_positions.clear()
	original_sizes.clear()
	edit_touches.clear()
	selected_action = ""
	for action in ACTION_NAMES:
		original_positions[action] = hud.get_action_center(action)
		original_sizes[action] = hud.get_action_scale(action)
	panel.visible = false
	backdrop.visible = false
	edit_overlay = Control.new()
	edit_overlay.name = "EditorHUD"
	edit_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	edit_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	edit_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(edit_overlay)
	edit_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	edit_overlay.gui_input.connect(_edit_input)
	edit_overlay.draw.connect(_draw_edit)
	var toolbar := PanelContainer.new()
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	toolbar.custom_minimum_size.y = 82.0
	toolbar.offset_bottom = 82.0
	edit_overlay.add_child(toolbar)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	toolbar.add_child(top)
	editor_title = Label.new()
	editor_title.text = "HUD: ARRASTE / PINCA"
	editor_title.add_theme_font_size_override("font_size", 26)
	top.add_child(editor_title)
	var save := Button.new()
	save.text = "SALVAR"
	save.add_theme_font_size_override("font_size", 27)
	save.custom_minimum_size = Vector2(116, 55)
	save.pressed.connect(_save_edit)
	top.add_child(save)
	var defaults := Button.new()
	defaults.text = "RESETAR"
	defaults.add_theme_font_size_override("font_size", 27)
	defaults.custom_minimum_size = Vector2(116, 55)
	defaults.pressed.connect(func():
		hud.restore_default_layout()
		edit_overlay.queue_redraw())
	top.add_child(defaults)
	var close := Button.new()
	close.text = "FECHAR"
	close.add_theme_font_size_override("font_size", 27)
	close.custom_minimum_size = Vector2(116, 55)
	close.pressed.connect(_cancel_edit)
	top.add_child(close)
	edit_overlay.queue_redraw()

func _draw_edit() -> void:
	if hud == null:
		return
	for action in ACTION_NAMES:
		var center: Vector2 = hud.get_action_center(action)
		if action == "zoom":
			var track_half: float = hud.zoom_height * hud.get_action_scale("zoom") * 0.5
			edit_overlay.draw_line(center - Vector2(0, track_half), center + Vector2(0, track_half), Color(0.04, 0.16, 0.22, 0.95), 26.0 * hud.scale_factor)
			edit_overlay.draw_line(center - Vector2(0, track_half), center + Vector2(0, track_half), Color(0.42, 0.9, 0.98, 0.95), 6.0 * hud.scale_factor)
			edit_overlay.draw_circle(center - Vector2(0, track_half), 15.0 * hud.scale_factor, Color(0.95, 0.78, 0.25))
			edit_overlay.draw_circle(center + Vector2(0, track_half), 15.0 * hud.scale_factor, Color(0.95, 0.78, 0.25))
		var radius: float = hud.get_action_radius(action) * (0.85 if action != "zoom" else 1.1)
		edit_overlay.draw_circle(center, radius, Color(0.04, 0.17, 0.22, 0.78))
		edit_overlay.draw_arc(center, radius, 0.0, TAU, 50, Color(1.0, 0.76, 0.3) if action == selected_action else Color(0.48, 0.94, 0.94), 3.0)
		var label: String = ACTION_NAMES[action]
		var font := ThemeDB.fallback_font
		var font_size := maxi(22, roundi(27.0 * hud.scale_factor))
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		edit_overlay.draw_string(font, center - Vector2(width * 0.5, -8.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

func _edit_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			edit_touches[event.index] = event.position
			if edit_touches.size() == 1:
				_select_drag(event.position, event.index)
			elif edit_touches.size() == 2 and selected_action != "":
				_start_pinch()
		else:
			edit_touches.erase(event.index)
			if event.index == drag_finger:
				drag_finger = -1
				drag_action = ""
			if edit_touches.size() < 2:
				pinch_start_distance = 0.0
	elif event is InputEventScreenDrag:
		if edit_touches.has(event.index):
			edit_touches[event.index] = event.position
		if edit_touches.size() == 2 and selected_action != "":
			_apply_pinch()
		elif event.index == drag_finger:
			_move_drag(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_select_drag(event.position, -2)
		else:
			drag_action = ""
			drag_finger = -1
	elif event is InputEventMouseMotion and drag_finger == -2 and drag_action != "":
		_move_drag(event.position)

func _start_pinch() -> void:
	var points := edit_touches.values()
	pinch_start_distance = maxf((points[0] as Vector2).distance_to(points[1] as Vector2), 1.0)
	pinch_start_scale = hud.get_action_scale(selected_action)

func _apply_pinch() -> void:
	if pinch_start_distance <= 0.0:
		_start_pinch()
	var points := edit_touches.values()
	var distance := (points[0] as Vector2).distance_to(points[1] as Vector2)
	hud.set_action_scale(selected_action, pinch_start_scale * distance / pinch_start_distance)
	edit_overlay.queue_redraw()

func _select_drag(pos: Vector2, finger: int) -> void:
	var best_action := ""
	var best_distance := INF
	for action in ACTION_NAMES:
		var center: Vector2 = hud.get_action_center(action)
		var distance := pos.distance_to(center)
		if action == "zoom":
			distance = absf(pos.x - center.x) if absf(pos.y - center.y) <= hud.zoom_height * hud.get_action_scale("zoom") * 0.5 + 35.0 else INF
		if distance < hud.get_action_radius(action) * 1.35 and distance < best_distance:
			best_action = action
			best_distance = distance
	if best_action != "":
		selected_action = best_action
		drag_action = best_action
		drag_finger = finger
		edit_overlay.queue_redraw()

func _move_drag(pos: Vector2) -> void:
	if drag_action == "":
		return
	hud.set_action_center(drag_action, pos)
	edit_overlay.queue_redraw()

func _close_edit() -> void:
	if edit_overlay != null:
		remove_child(edit_overlay)
		edit_overlay.queue_free()
		edit_overlay = null
	edit_touches.clear()
	selected_action = ""
	panel.visible = true
	backdrop.visible = true
	_show_main()

func _save_edit() -> void:
	hud.save_current_layout()
	_close_edit()

func _cancel_edit() -> void:
	hud.custom_positions.clear()
	hud.custom_sizes.clear()
	hud.load_settings()
	hud._layout_controls()
	_close_edit()

func toggle() -> void:
	if not visible:
		visible = true
		game.aiming = false
		game._set_trigger(false)
		game.burst_remaining = 0
		game.move_flags["run"] = false
		game.move_flags["forward"] = false
		if hud != null:
			hud.auto_run_forward = false
		game.mobile_joystick_axis = Vector2.ZERO
		_show_main()
		var cfg := ConfigFile.new()
		if cfg.load("user://mapontes_mobile_hud.cfg") == OK:
			AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(cfg.get_value("audio", "master", 1.0)), 0.0001)))
		get_tree().paused = true
	else:
		if edit_overlay != null:
			_cancel_edit()
		visible = false
		get_tree().paused = false
