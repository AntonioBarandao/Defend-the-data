class_name RedVirus
extends AnimatedSprite2D

const IDLE_ANIMATION := &"idle"
const DESTROY_ANIMATION := &"destroy"
const GRAB_SIZE := Vector2(128, 128)

@export var path_speed := 200.0
@export var destroy_duration := 0.5
@export var destroy_scale_multiplier := 1.35


func _ready() -> void:
	if sprite_frames != null and sprite_frames.has_animation(IDLE_ANIMATION):
		play_idle()


func reset_for_spawn() -> void:
	modulate = Color.WHITE
	play_idle()
	show()


func play_idle() -> void:
	if sprite_frames == null or not sprite_frames.has_animation(IDLE_ANIMATION):
		return

	animation = IDLE_ANIMATION
	frame = 0
	frame_progress = 0.0
	play()


func play_destroy_and_queue_owner(owner: Node) -> void:
	var final_duration := destroy_duration
	var has_destroy_animation := false
	if sprite_frames != null and sprite_frames.has_animation(DESTROY_ANIMATION):
		has_destroy_animation = true
		var animation_speed := sprite_frames.get_animation_speed(DESTROY_ANIMATION)
		var frame_count := sprite_frames.get_frame_count(DESTROY_ANIMATION)
		if animation_speed > 0.0 and frame_count > 0:
			final_duration = float(frame_count) / animation_speed
		animation = DESTROY_ANIMATION
		frame = 0
		frame_progress = 0.0
		play()

	var tween := create_tween()
	if has_destroy_animation:
		tween.tween_interval(final_duration)
	else:
		tween.set_parallel(true)
		tween.tween_property(self, "scale", scale * destroy_scale_multiplier, final_duration)
		tween.tween_property(self, "modulate", Color(1, 1, 1, 0), final_duration)
		tween.set_parallel(false)

	if owner != null:
		tween.tween_callback(Callable(owner, "queue_free"))
	else:
		tween.tween_callback(Callable(self, "queue_free"))


func get_path_speed() -> float:
	return path_speed


func contains_global_point(pointer_position: Vector2) -> bool:
	return get_grab_rect().has_point(pointer_position)


func get_grab_rect() -> Rect2:
	var size := GRAB_SIZE
	if sprite_frames != null and sprite_frames.has_animation(animation):
		var texture := sprite_frames.get_frame_texture(animation, frame)
		if texture != null:
			var current_scale := global_scale
			size = texture.get_size() * Vector2(abs(current_scale.x), abs(current_scale.y))

	size.x = max(size.x, GRAB_SIZE.x)
	size.y = max(size.y, GRAB_SIZE.y)

	var top_left := global_position - size * 0.5
	if not centered:
		top_left = global_position

	return Rect2(top_left, size)
