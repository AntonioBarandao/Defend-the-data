extends AnimatedSprite2D


func _ready() -> void:
	if AssetCache.has_cyber_guardian_idle():
		_apply_sprite_frames(AssetCache.cyber_guardian_idle_sprite_frames)
		return

	AssetCache.cyber_guardian_idle_ready.connect(_apply_sprite_frames, CONNECT_ONE_SHOT)
	AssetCache.load_startup_resources()


func _apply_sprite_frames(frames: SpriteFrames) -> void:
	sprite_frames = frames
	animation = AssetCache.CYBER_GUARDIAN_IDLE_ANIMATION
	play()
