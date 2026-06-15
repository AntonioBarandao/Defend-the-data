class_name TrojanHorse
extends RedVirus

const HORSE_MOVE_ANIMATION := &"Horse_Move"
const HORSE_TRANSFORM_ANIMATION := &"Horse_Transform"
const HORSE_DECAMO_TRANSFORM_ANIMATION := &"Horse_De-Camo_Transform"
const CLOAKED_HORSE_MOVE_ANIMATION := &"Cloaked_Horse_Move"
const HORSE_DESTROY_ANIMATION := &"Horse_Destroy"

@export var cloak_delay_seconds := 4.0
@export var cloaked := false
@export var cloaked_move_scale_bonus := 0.1
@export_group("Destroy Cutscene")
@export var destroy_cutscene_slow_seconds := 2.0
@export var destroy_cutscene_stop_seconds := 2.0
@export var destroy_cutscene_slow_speed := 8.0
@export_group("Health Bar")
@export var health_bar_root_path: NodePath = ^"MinibossHealthBar"
@export var health_bar_follow_sprite_bounds := true
@export var health_bar_offset := Vector2.ZERO
@export_range(0.0, 160.0, 1.0) var health_bar_vertical_gap := 18.0
@export_group("")
@export_group("Path Rotation")
@export var rotate_with_path := true
@export_range(1.0, 96.0, 1.0) var path_direction_sample_distance := 10.0
@export_range(-360.0, 360.0, 0.1) var sprite_forward_reference_degrees := 90.0
@export_range(-360.0, 360.0, 0.1) var path_rotation_offset_degrees := 0.0
@export_group("")
@export_group("Audio")
@export var enter_sfx_path: NodePath = ^"Audio/EnterSfx"
@export var transform_sfx_path: NodePath = ^"Audio/TransformSfx"
@export_group("")

var _deployed := false
var _transforming := false
var _cloak_elapsed := 0.0
var _destroy_cutscene_active := false
var _destroy_cutscene_elapsed := 0.0
var _scanner_revealed := false
var _health_bar: TrojanHorseProgressBar
var _enter_sfx: AudioStreamPlayer
var _transform_sfx: AudioStreamPlayer
var _base_visual_scale := Vector2.ONE


func _ready() -> void:
	_base_visual_scale = scale
	current_health = maxi(1, max_health)
	_cache_audio_players()
	if not health_changed.is_connected(_on_health_changed):
		health_changed.connect(_on_health_changed)
	_ensure_health_bar()
	_set_health_bar_visible(false)
	set_process(false)
	play_idle()


func _process(delta: float) -> void:
	if _destroy_cutscene_active:
		_destroy_cutscene_elapsed += delta
		_update_path_rotation()
		_position_health_bar()
		return

	if not _deployed:
		return

	_position_health_bar()
	if not _transforming:
		_update_path_rotation()

	if _transforming or cloaked:
		return

	_cloak_elapsed += delta
	if _cloak_elapsed >= cloak_delay_seconds:
		_start_cloak_transform()


func reset_for_spawn() -> void:
	_base_visual_scale = scale
	current_health = maxi(1, max_health)
	_destroying = false
	modulate = Color.WHITE
	show()
	cloaked = false
	_deployed = true
	_transforming = false
	_scanner_revealed = false
	_destroy_cutscene_active = false
	_destroy_cutscene_elapsed = 0.0
	_cloak_elapsed = 0.0
	_ensure_health_bar()
	_set_health_bar_health(current_health, max_health, false)
	_set_health_bar_visible(true)
	_position_health_bar()
	play_idle()
	set_process(true)
	_update_path_rotation()
	_play_audio_player(_enter_sfx)


func play_idle() -> void:
	if _destroying or _destroy_cutscene_active:
		return

	if cloaked:
		_play_animation(CLOAKED_HORSE_MOVE_ANIMATION)
		return

	_play_animation(HORSE_MOVE_ANIMATION)


func play_destroy_and_queue_owner(owner: Node) -> void:
	if _destroy_cutscene_active:
		return

	_destroying = true
	_transforming = false
	cloaked = false
	_destroy_cutscene_active = true
	_destroy_cutscene_elapsed = 0.0
	_ensure_health_bar()
	_set_health_bar_visible(true)
	_position_health_bar()
	set_process(true)

	if _has_animation(HORSE_DESTROY_ANIMATION):
		_play_animation(HORSE_DESTROY_ANIMATION)

	var cutscene_seconds := maxf(0.0, destroy_cutscene_slow_seconds) + maxf(0.0, destroy_cutscene_stop_seconds)
	if cutscene_seconds > 0.0:
		await get_tree().create_timer(cutscene_seconds).timeout

	if owner != null:
		owner.queue_free()
	else:
		queue_free()


func get_path_speed() -> float:
	if _destroy_cutscene_active:
		if _destroy_cutscene_elapsed < destroy_cutscene_slow_seconds:
			return destroy_cutscene_slow_speed
		return 0.0

	if _transforming:
		return 0.0

	return super.get_path_speed()


func is_cloaked() -> bool:
	return cloaked


func reveal_from_scanner(_scanner: Node = null) -> bool:
	if not cloaked or _transforming or _destroying or _destroy_cutscene_active:
		return false

	_scanner_revealed = true
	_start_decamo_transform()
	return true


func take_damage(amount: int) -> bool:
	_ensure_health_bar()
	return super.take_damage(amount)


func can_be_targeted_by(attacker: Node) -> bool:
	if not super.can_be_targeted_by(attacker):
		return false

	if cloaked and not _attacker_has_scanner(attacker):
		return false

	return true


func should_remain_active_during_destroy() -> bool:
	return true


func _start_cloak_transform() -> void:
	if _scanner_revealed or _transforming or cloaked or _destroying or _destroy_cutscene_active:
		return

	_transforming = true
	set_process(false)
	if _has_animation(HORSE_TRANSFORM_ANIMATION):
		_play_audio_player(_transform_sfx)
		_play_animation(HORSE_TRANSFORM_ANIMATION)
		await animation_finished

	if _destroying or _destroy_cutscene_active:
		return

	cloaked = true
	_transforming = false
	_play_animation(CLOAKED_HORSE_MOVE_ANIMATION)
	if _deployed:
		set_process(true)


func _start_decamo_transform() -> void:
	_transforming = true
	cloaked = false
	set_process(false)
	if _has_animation(HORSE_DECAMO_TRANSFORM_ANIMATION):
		_play_animation(HORSE_DECAMO_TRANSFORM_ANIMATION)
		await animation_finished

	if _destroying or _destroy_cutscene_active:
		return

	_transforming = false
	_cloak_elapsed = 0.0
	_play_animation(HORSE_MOVE_ANIMATION)
	if _deployed:
		set_process(true)


func _play_animation(animation_name: StringName) -> void:
	if not _has_animation(animation_name):
		return

	if animation_name == CLOAKED_HORSE_MOVE_ANIMATION:
		scale = _base_visual_scale * (1.0 + cloaked_move_scale_bonus)
	else:
		scale = _base_visual_scale

	animation = animation_name
	frame = 0
	frame_progress = 0.0
	play()


func _has_animation(animation_name: StringName) -> bool:
	return sprite_frames != null and sprite_frames.has_animation(animation_name)


func _attacker_has_scanner(attacker: Node) -> bool:
	return attacker != null \
		and attacker.has_method("can_scan_cloaked_viruses") \
		and attacker.call("can_scan_cloaked_viruses") == true


func _on_health_changed(new_health: int, new_max_health: int) -> void:
	_ensure_health_bar()
	_set_health_bar_health(new_health, new_max_health, true)


func _ensure_health_bar() -> void:
	if is_instance_valid(_health_bar):
		return

	_health_bar = get_node_or_null(health_bar_root_path) as TrojanHorseProgressBar
	if not is_instance_valid(_health_bar):
		return

	_health_bar.top_level = true
	_health_bar.z_index = maxi(_health_bar.z_index, 700)
	_health_bar.modulate = Color.WHITE
	_set_health_bar_health(current_health, max_health, false)


func _set_health_bar_visible(value: bool) -> void:
	_ensure_health_bar()
	if not is_instance_valid(_health_bar):
		return

	_health_bar.set_bar_visible(value)


func _set_health_bar_health(current: int, maximum: int, animate: bool) -> void:
	_ensure_health_bar()
	if not is_instance_valid(_health_bar):
		return

	_health_bar.set_health(current, maxi(1, maximum), animate)


func _position_health_bar() -> void:
	if not is_instance_valid(_health_bar):
		return

	var target_position := global_position
	if health_bar_follow_sprite_bounds:
		target_position = _get_health_bar_follow_position()

	_health_bar.global_position = target_position + health_bar_offset
	_health_bar.global_rotation = 0.0


func _get_health_bar_follow_position() -> Vector2:
	var sprite_bounds := _get_current_frame_global_bounds()
	return Vector2(
		sprite_bounds.position.x + sprite_bounds.size.x * 0.5,
		sprite_bounds.position.y - health_bar_vertical_gap
	)


func _get_current_frame_global_bounds() -> Rect2:
	var texture: Texture2D
	if sprite_frames != null and sprite_frames.has_animation(animation):
		texture = sprite_frames.get_frame_texture(animation, frame)

	if texture == null:
		var fallback_size := Vector2(128, 128) * global_scale.abs()
		return Rect2(global_position - fallback_size * 0.5, fallback_size)

	var frame_size := texture.get_size()
	var local_top_left := Vector2.ZERO
	if centered:
		local_top_left = -frame_size * 0.5
	local_top_left += offset

	var corners := [
		local_top_left,
		local_top_left + Vector2(frame_size.x, 0.0),
		local_top_left + frame_size,
		local_top_left + Vector2(0.0, frame_size.y)
	]
	var bounds := Rect2(global_transform * corners[0], Vector2.ZERO)
	for corner in corners:
		bounds = bounds.expand(global_transform * corner)

	return bounds


func _update_path_rotation() -> void:
	if not rotate_with_path:
		return

	var follow := get_parent() as PathFollow2D
	if follow == null:
		return

	var path := follow.get_parent() as Path2D
	if path == null or path.curve == null:
		return

	var path_length := path.curve.get_baked_length()
	if path_length <= 0.0:
		return

	var sample_distance := maxf(1.0, path_direction_sample_distance)
	var current_progress := clampf(follow.progress, 0.0, path_length)
	var before_progress := maxf(0.0, current_progress - sample_distance)
	var after_progress := minf(path_length, current_progress + sample_distance)
	if is_equal_approx(before_progress, after_progress):
		return

	var before_position := path.to_global(path.curve.sample_baked(before_progress))
	var after_position := path.to_global(path.curve.sample_baked(after_progress))
	var direction := after_position - before_position
	if direction.length_squared() <= 0.001:
		return

	var reference_angle := deg_to_rad(sprite_forward_reference_degrees)
	var manual_offset := deg_to_rad(path_rotation_offset_degrees)
	global_rotation = direction.angle() - reference_angle + manual_offset


func _cache_audio_players() -> void:
	_enter_sfx = get_node_or_null(enter_sfx_path) as AudioStreamPlayer
	_transform_sfx = get_node_or_null(transform_sfx_path) as AudioStreamPlayer


func _play_audio_player(player: AudioStreamPlayer) -> void:
	if player == null:
		return

	player.stop()
	player.play()
