class_name TextCutscene
extends CanvasLayer

signal act_started(act_number: int)
signal phase_started(act_number: int, phase_name: StringName)
signal phase_finished(act_number: int, phase_name: StringName)
signal cutscene_finished

const ACT_ONE := 1
const PHASE_ONE := &"phase_1"
const PHASE_TWO := &"phase_2"
const PHASE_END := &"phase_end"
const PHASE_ONE_DESTROY_SFX := preload("res://assets/sfx/virus_destroy.wav")

@export var play_on_ready := true
@export var dialogue_lines: PackedStringArray = [
	"Our hardware is being under attack! Help us defeat the viruses and save our cpu!",
	"Deploy cybersecurity towers onto safe platforms and stop the viruses before they breach the system.",
	"After each wave, answer the security challenge to earn more Cyber Bucks. I will guide you through the first defense."
]
@export_group("Act 1 Phase 1")
@export var cutscene_camera_path: NodePath = ^"../CutsceneCamera"
@export var phase_one_target_path: NodePath = ^"../Otherground_Cutscene"
@export_range(0.2, 8.0, 0.05) var red_alert_duration := 3.0
@export_range(0.2, 5.0, 0.05) var camera_pan_duration := 1.35
@export_range(0.5, 8.0, 0.05) var enemy_hold_duration := 3.0
@export_range(0.2, 5.0, 0.05) var camera_return_duration := 1.2
@export_range(0.25, 4.0, 0.05) var phase_one_camera_zoom := 2.0
@export_range(2.0, 80.0, 1.0) var phase_one_virus_hover_distance := 18.0
@export_range(0.1, 2.0, 0.05) var phase_one_virus_hover_half_duration := 0.48
@export var enemy_camera_padding := Vector2(0, -40)
@export var red_alert_color := Color(1.0, 0.025, 0.025, 0.48)
@export_group("Act 1 Phase 2")
@export_range(8.0, 120.0, 1.0) var characters_per_second := 80.0
@export_range(0.1, 2.0, 0.01) var entry_duration := 0.72
@export_range(0.1, 2.0, 0.01) var exit_duration := 0.52
@export_range(40.0, 1400.0, 1.0) var text_box_slide_distance := 620.0
@export_range(40.0, 1400.0, 1.0) var mascot_slide_distance := 720.0
@export_range(2.0, 60.0, 1.0) var mascot_bob_distance := 18.0
@export_range(0.05, 0.8, 0.01) var mascot_bob_half_duration := 0.18
@export var dim_color := Color(0.055, 0.06, 0.075, 0.76)
@export_group("")

@onready var _root: Control = $Root
@onready var _dim_overlay: ColorRect = $Root/DimOverlay
@onready var _alert_overlay: ColorRect = $Root/AlertOverlay
@onready var _dialogue_panel: Control = $Root/DialoguePanel
@onready var _mascot: Control = $Root/Mascot
@onready var _speaker_label: Label = $Root/DialoguePanel/Margin/Content/SpeakerLabel
@onready var _dialogue_label: Label = $Root/DialoguePanel/Margin/Content/DialogueLabel
@onready var _continue_button: Button = $Root/DialoguePanel/Margin/Content/Footer/ContinueButton

var current_act := 0
var current_phase: StringName = &""
var _line_index := 0
var _typing := false
var _skip_typing := false
var _running := false
var _panel_final_global_position := Vector2.ZERO
var _mascot_final_global_position := Vector2.ZERO
var _mascot_bob_tween: Tween
var _cutscene_camera: Camera2D
var _camera_start_global_position := Vector2.ZERO
var _camera_start_zoom := Vector2.ONE
var _phase_one_hover_tweens: Array[Tween] = []
var _phase_one_hover_start_positions := {}
var _phase_one_destroy_sfx_players: Array[AudioStreamPlayer] = []
var _last_handled_cutscene_input_event_id := 0
var _skip_requested := false


func _ready() -> void:
	visible = true
	_continue_button.pressed.connect(_advance_dialogue)
	_root.gui_input.connect(_on_root_gui_input)
	_ensure_continue_button_styles()
	_speaker_label.text = "CYBER GUARDIAN"
	_cutscene_camera = get_node_or_null(cutscene_camera_path) as Camera2D
	_root.visible = false
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if play_on_ready:
		call_deferred("start_cutscene")


func start_cutscene() -> void:
	if _running:
		return

	_running = true
	_skip_requested = false
	visible = true
	current_act = ACT_ONE
	act_started.emit(current_act)
	_root.visible = true
	_root.modulate = Color.WHITE
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	await get_tree().process_frame
	_capture_ui_final_positions()
	_prepare_all_overlays_hidden()

	await _run_act_one_phase_one()
	if _skip_requested or not _running:
		return
	await _run_act_one_phase_two()


func _run_act_one_phase_one() -> void:
	_start_phase(PHASE_ONE)
	_prepare_phase_one_camera()
	_dim_overlay.hide()
	_dialogue_panel.hide()
	_mascot.hide()
	_continue_button.hide()
	_alert_overlay.show()
	_alert_overlay.color = Color(red_alert_color.r, red_alert_color.g, red_alert_color.b, 0.0)

	await _play_red_alert()
	if _skip_requested or not _running:
		return
	await _pan_camera_to_phase_one_target()
	if _skip_requested or not _running:
		return
	_start_phase_one_virus_hover()
	await get_tree().create_timer(enemy_hold_duration).timeout
	if _skip_requested or not _running:
		return
	_stop_phase_one_virus_hover()
	await _return_camera_to_start()
	if _skip_requested or not _running:
		return

	_alert_overlay.hide()
	_finish_phase(PHASE_ONE)


func _run_act_one_phase_two() -> void:
	_start_phase(PHASE_TWO)
	_line_index = 0
	_dialogue_label.text = ""
	_continue_button.hide()
	_dim_overlay.show()
	_dialogue_panel.show()
	_mascot.show()

	_dim_overlay.color = Color(dim_color.r, dim_color.g, dim_color.b, 0.0)
	_dialogue_panel.global_position = _panel_final_global_position + Vector2(-text_box_slide_distance, 0.0)
	_dialogue_panel.modulate = Color(1, 1, 1, 0)
	_mascot.global_position = _mascot_final_global_position + Vector2(mascot_slide_distance, 0.0)
	_mascot.modulate = Color(1, 1, 1, 0)

	var intro_tween := create_tween()
	intro_tween.set_parallel(true)
	intro_tween.tween_property(_dim_overlay, "color", dim_color, entry_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	intro_tween.tween_property(_dialogue_panel, "global_position", _panel_final_global_position, entry_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	intro_tween.tween_property(_dialogue_panel, "modulate", Color.WHITE, entry_duration * 0.8)
	intro_tween.tween_property(_mascot, "global_position", _mascot_final_global_position, entry_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro_tween.tween_property(_mascot, "modulate", Color.WHITE, entry_duration * 0.75)
	await intro_tween.finished
	if _skip_requested or not _running:
		return

	if dialogue_lines.is_empty():
		_finish_cutscene()
		return

	_play_current_line()


func _advance_dialogue() -> void:
	if not _running or current_phase != PHASE_TWO:
		return

	if _typing:
		_skip_typing = true
		return

	_line_index += 1
	if _line_index >= dialogue_lines.size():
		_finish_cutscene()
		return

	_play_current_line()


func _input(event: InputEvent) -> void:
	if handle_cutscene_advance_input(event):
		get_viewport().set_input_as_handled()


func handle_cutscene_advance_input(event: InputEvent) -> bool:
	if not _running or current_phase != PHASE_TWO:
		return false
	if not _is_enter_press(event) and not _is_primary_press(event):
		return false
	var event_id := event.get_instance_id()
	if event_id == _last_handled_cutscene_input_event_id:
		return true

	_last_handled_cutscene_input_event_id = event_id
	if _typing:
		_skip_typing = true
		return true
	if not _continue_button.visible:
		return true

	_advance_dialogue()
	return true


func _on_root_gui_input(event: InputEvent) -> void:
	if handle_cutscene_advance_input(event):
		_root.accept_event()


func _is_enter_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed \
			and not key_event.echo \
			and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER)

	return false


func _is_primary_press(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		return mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_LEFT

	if event is InputEventScreenTouch:
		var screen_touch := event as InputEventScreenTouch
		return screen_touch.pressed

	return false


func _play_current_line() -> void:
	_typing = true
	_skip_typing = false
	_continue_button.hide()
	_dialogue_label.text = ""
	_start_mascot_bob()

	var line := String(dialogue_lines[_line_index])
	var delay := 1.0 / maxf(1.0, characters_per_second)
	for index in range(line.length()):
		if _skip_typing:
			break

		_dialogue_label.text = line.substr(0, index + 1)
		await get_tree().create_timer(delay).timeout
		if _skip_requested or not _running:
			return

	_dialogue_label.text = line
	_typing = false
	_skip_typing = false
	_stop_mascot_bob()
	_continue_button.text = "Begin" if _line_index >= dialogue_lines.size() - 1 else "Continue"
	_continue_button.show()
	_animate_continue_button()


func is_cutscene_running() -> bool:
	return _running


func skip_cutscene() -> void:
	if not _running:
		return

	_skip_requested = true
	_stop_mascot_bob()
	_stop_phase_one_virus_hover()
	if _cutscene_camera != null:
		_cutscene_camera.global_position = _camera_start_global_position
		_cutscene_camera.zoom = _camera_start_zoom
	_dialogue_panel.global_position = _panel_final_global_position
	_mascot.global_position = _mascot_final_global_position
	_prepare_all_overlays_hidden()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.hide()
	_running = false
	current_phase = PHASE_END
	cutscene_finished.emit()


func _ensure_continue_button_styles() -> void:
	var normal_style := _continue_button.get_theme_stylebox("normal")
	if normal_style == null:
		return

	var hover_style := normal_style.duplicate() as StyleBoxFlat
	if hover_style != null:
		hover_style.border_color = Color(1.0, 0.82, 0.08, 1.0)
		hover_style.bg_color = Color(0.055, 0.1, 0.16, 0.96)
		_continue_button.add_theme_stylebox_override("hover", hover_style)
		_continue_button.add_theme_stylebox_override("pressed", hover_style)
		_continue_button.add_theme_stylebox_override("focus", hover_style)


func _finish_cutscene() -> void:
	if not _running:
		return

	_finish_phase(PHASE_TWO)
	_start_phase(PHASE_END)
	_stop_mascot_bob()
	_continue_button.hide()

	var outro_tween := create_tween()
	outro_tween.set_parallel(true)
	outro_tween.tween_property(_dim_overlay, "color", Color(dim_color.r, dim_color.g, dim_color.b, 0.0), exit_duration)
	outro_tween.tween_property(_dialogue_panel, "global_position", _panel_final_global_position + Vector2(-text_box_slide_distance, 0.0), exit_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	outro_tween.tween_property(_dialogue_panel, "modulate", Color(1, 1, 1, 0), exit_duration * 0.75)
	outro_tween.tween_property(_mascot, "global_position", _mascot_final_global_position + Vector2(mascot_slide_distance, 0.0), exit_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	outro_tween.tween_property(_mascot, "modulate", Color(1, 1, 1, 0), exit_duration * 0.75)
	await outro_tween.finished

	_dialogue_panel.global_position = _panel_final_global_position
	_mascot.global_position = _mascot_final_global_position
	_prepare_all_overlays_hidden()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.hide()
	_running = false
	_finish_phase(PHASE_END)
	cutscene_finished.emit()


func _play_red_alert() -> void:
	var alert_tween := create_tween()
	var half_pulse_duration := red_alert_duration / 4.0
	for _index in range(2):
		alert_tween.tween_property(_alert_overlay, "color", red_alert_color, half_pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		alert_tween.tween_property(_alert_overlay, "color", Color(red_alert_color.r, red_alert_color.g, red_alert_color.b, 0.0), half_pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await alert_tween.finished


func _prepare_phase_one_camera() -> void:
	if _cutscene_camera == null:
		return

	_cutscene_camera.make_current()
	_camera_start_global_position = _cutscene_camera.global_position
	_camera_start_zoom = _cutscene_camera.zoom


func _pan_camera_to_phase_one_target() -> void:
	if _cutscene_camera == null:
		await get_tree().create_timer(camera_pan_duration).timeout
		return

	var target_position := _get_phase_one_target_center()
	var camera_tween := create_tween()
	camera_tween.set_parallel(true)
	camera_tween.tween_property(_cutscene_camera, "global_position", target_position + enemy_camera_padding, camera_pan_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	camera_tween.tween_property(_cutscene_camera, "zoom", Vector2.ONE * phase_one_camera_zoom, camera_pan_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await camera_tween.finished


func _return_camera_to_start() -> void:
	if _cutscene_camera == null:
		await get_tree().create_timer(camera_return_duration).timeout
		return

	var camera_tween := create_tween()
	camera_tween.set_parallel(true)
	camera_tween.tween_property(_cutscene_camera, "global_position", _camera_start_global_position, camera_return_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	camera_tween.tween_property(_cutscene_camera, "zoom", _camera_start_zoom, camera_return_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await camera_tween.finished


func _get_phase_one_target_center() -> Vector2:
	var target := get_node_or_null(phase_one_target_path)
	if target == null:
		return _camera_start_global_position

	var target_rect := Rect2()
	var found_visual := false
	for canvas_item in _get_phase_one_visual_children():
		var child_position = canvas_item.global_position
		if not found_visual:
			target_rect = Rect2(child_position, Vector2.ZERO)
			found_visual = true
		else:
			target_rect = target_rect.expand(child_position)

	if found_visual:
		return target_rect.get_center()

	if target is CanvasItem:
		return (target as CanvasItem).global_position

	return _camera_start_global_position


func _get_phase_one_visual_children() -> Array[CanvasItem]:
	var visuals: Array[CanvasItem] = []
	var target := get_node_or_null(phase_one_target_path)
	if target == null:
		return visuals

	for child in target.get_children():
		var canvas_item := child as CanvasItem
		if canvas_item == null or not canvas_item.visible:
			continue

		visuals.append(canvas_item)

	return visuals


func _start_phase_one_virus_hover() -> void:
	_stop_phase_one_virus_hover(false)

	var visuals := _get_phase_one_visual_children()
	for index in range(visuals.size()):
		var canvas_item := visuals[index]
		var start_position = canvas_item.global_position
		_phase_one_hover_start_positions[canvas_item] = start_position

		var hover_tween := create_tween()
		hover_tween.set_loops()
		hover_tween.tween_interval(float(index) * 0.08)
		hover_tween.tween_property(canvas_item, "global_position:y", start_position.y - phase_one_virus_hover_distance, phase_one_virus_hover_half_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		hover_tween.tween_property(canvas_item, "global_position:y", start_position.y + phase_one_virus_hover_distance * 0.4, phase_one_virus_hover_half_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		hover_tween.tween_property(canvas_item, "global_position:y", start_position.y, phase_one_virus_hover_half_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_phase_one_hover_tweens.append(hover_tween)
		_play_phase_one_virus_destroy_sfx(float(index) * 0.12)


func _stop_phase_one_virus_hover(restore_positions := true) -> void:
	for hover_tween in _phase_one_hover_tweens:
		if hover_tween != null:
			hover_tween.kill()
	_phase_one_hover_tweens.clear()

	if restore_positions:
		for key in _phase_one_hover_start_positions.keys():
			var canvas_item := key as CanvasItem
			if is_instance_valid(canvas_item):
				canvas_item.global_position = _phase_one_hover_start_positions[key]
	_phase_one_hover_start_positions.clear()


func _play_phase_one_virus_destroy_sfx(delay: float) -> void:
	var player := AudioStreamPlayer.new()
	player.name = "PhaseOneVirusDestroySfx"
	player.stream = PHASE_ONE_DESTROY_SFX
	add_child(player)
	_phase_one_destroy_sfx_players.append(player)
	player.finished.connect(func() -> void:
		_phase_one_destroy_sfx_players.erase(player)
		player.queue_free()
	)

	if delay <= 0.0:
		player.play()
		return

	var sound_tween := create_tween()
	sound_tween.tween_interval(delay)
	sound_tween.tween_callback(func() -> void:
		if is_instance_valid(player):
			player.play()
	)


func _capture_ui_final_positions() -> void:
	_dialogue_panel.show()
	_mascot.show()
	_panel_final_global_position = _dialogue_panel.global_position
	_mascot_final_global_position = _mascot.global_position


func _prepare_all_overlays_hidden() -> void:
	_stop_phase_one_virus_hover()
	_alert_overlay.hide()
	_dim_overlay.hide()
	_dialogue_panel.hide()
	_mascot.hide()
	_dialogue_panel.modulate = Color.WHITE
	_mascot.modulate = Color.WHITE
	_dim_overlay.color = Color(dim_color.r, dim_color.g, dim_color.b, 0.0)
	_alert_overlay.color = Color(red_alert_color.r, red_alert_color.g, red_alert_color.b, 0.0)


func _start_phase(phase_name: StringName) -> void:
	current_phase = phase_name
	phase_started.emit(current_act, current_phase)


func _finish_phase(phase_name: StringName) -> void:
	phase_finished.emit(current_act, phase_name)


func _start_mascot_bob() -> void:
	_stop_mascot_bob()
	_mascot.global_position = _mascot_final_global_position
	_mascot_bob_tween = create_tween()
	_mascot_bob_tween.set_loops()
	_mascot_bob_tween.tween_property(_mascot, "global_position:y", _mascot_final_global_position.y - mascot_bob_distance, mascot_bob_half_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_mascot_bob_tween.tween_property(_mascot, "global_position:y", _mascot_final_global_position.y + mascot_bob_distance * 0.35, mascot_bob_half_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_mascot_bob_tween.tween_property(_mascot, "global_position:y", _mascot_final_global_position.y, mascot_bob_half_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _stop_mascot_bob() -> void:
	if _mascot_bob_tween != null:
		_mascot_bob_tween.kill()
		_mascot_bob_tween = null
	if is_instance_valid(_mascot):
		_mascot.global_position = _mascot_final_global_position


func _animate_continue_button() -> void:
	_continue_button.pivot_offset = _continue_button.size * 0.5
	_continue_button.scale = Vector2.ONE * 0.94
	var button_tween := create_tween()
	button_tween.tween_property(_continue_button, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
