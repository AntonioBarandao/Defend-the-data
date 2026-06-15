extends SceneTree

const OUTPUT_PATH := "res://assets/Enemies/TrojanHorse/TrojanHorseSpriteFrames.res"
const FRAME_SIZE := Vector2i(720, 720)
const FRAME_COUNT := 91
const COLUMNS := 10
const FPS := 30.0

const ANIMATIONS := [
	{
		"name": &"Horse_Move",
		"atlas": "res://assets/Enemies/TrojanHorse/Horse_Move/Horse_Move_atlas_30fps.png",
		"loop": true
	},
	{
		"name": &"Horse_Transform",
		"atlas": "res://assets/Enemies/TrojanHorse/Horse_Transform/Horse_Transform_atlas_30fps.png",
		"loop": false
	},
	{
		"name": &"Horse_De-Camo_Transform",
		"atlas": "res://assets/Enemies/TrojanHorse/Horse_De-Camo_Transform/Horse_De-Camo_Transform_atlas_30fps.png",
		"loop": false
	},
	{
		"name": &"Cloaked_Horse_Move",
		"atlas": "res://assets/Enemies/TrojanHorse/Cloaked_Horse_Move/Cloaked_Horse_Move_atlas_30fps.png",
		"loop": true
	},
	{
		"name": &"Horse_Destroy",
		"atlas": "res://assets/Enemies/TrojanHorse/Horse_Destroy/Horse_Destroy_atlas_30fps.png",
		"loop": false
	}
]


func _init() -> void:
	var sprite_frames := SpriteFrames.new()
	for animation_name in sprite_frames.get_animation_names():
		sprite_frames.remove_animation(animation_name)

	for animation_def in ANIMATIONS:
		_add_animation(sprite_frames, animation_def)

	var error := ResourceSaver.save(sprite_frames, OUTPUT_PATH)
	if error != OK:
		push_error("Failed to save %s. Error: %s" % [OUTPUT_PATH, error])

	quit()


func _add_animation(sprite_frames: SpriteFrames, animation_def: Dictionary) -> void:
	var animation_name: StringName = animation_def["name"]
	sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_loop(animation_name, animation_def["loop"])
	sprite_frames.set_animation_speed(animation_name, FPS)

	var atlas := load(animation_def["atlas"]) as Texture2D
	if atlas == null:
		push_error("Could not load atlas: %s" % animation_def["atlas"])
		return

	for index in range(FRAME_COUNT):
		var atlas_texture := AtlasTexture.new()
		atlas_texture.atlas = atlas
		atlas_texture.region = Rect2(
			(index % COLUMNS) * FRAME_SIZE.x,
			int(index / COLUMNS) * FRAME_SIZE.y,
			FRAME_SIZE.x,
			FRAME_SIZE.y
		)
		sprite_frames.add_frame(animation_name, atlas_texture, 1.0)
