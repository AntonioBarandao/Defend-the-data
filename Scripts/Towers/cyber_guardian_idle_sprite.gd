extends AnimatedSprite2D

const IDLE_ANIMATION := &"idle"
const SUMMON_ANIMATION := &"SummonAnim"
const SHOOT_ANIMATION := &"ShootAnim"

var _asset_cache: Node


func _ready() -> void:
	if not animation_finished.is_connected(_return_to_idle):
		animation_finished.connect(_return_to_idle)

	if _has_required_animations(sprite_frames):
		play_animation(IDLE_ANIMATION)
		return

	_asset_cache = get_node_or_null("/root/AssetCache")
	if _asset_cache == null:
		push_error("AssetCache autoload was not found.")
		return

	if _asset_cache.has_cyber_guardian_animations():
		_apply_sprite_frames(_asset_cache.cyber_guardian_sprite_frames)
		return

	_asset_cache.cyber_guardian_animations_ready.connect(_apply_sprite_frames, CONNECT_ONE_SHOT)
	_asset_cache.load_startup_resources()


func play_animation(animation_name: StringName) -> void:
	if sprite_frames == null or not sprite_frames.has_animation(animation_name):
		return

	animation = animation_name
	frame = 0
	frame_progress = 0.0
	play()


func play_summon() -> void:
	play_animation(SUMMON_ANIMATION)


func play_shoot() -> void:
	play_animation(SHOOT_ANIMATION)


func _apply_sprite_frames(frames: SpriteFrames) -> void:
	sprite_frames = frames
	play_animation(IDLE_ANIMATION)


func _has_required_animations(frames: SpriteFrames) -> bool:
	return frames != null \
		and frames.has_animation(IDLE_ANIMATION) \
		and frames.has_animation(SUMMON_ANIMATION) \
		and frames.has_animation(SHOOT_ANIMATION)


func _return_to_idle() -> void:
	if animation != IDLE_ANIMATION:
		play_animation(IDLE_ANIMATION)
