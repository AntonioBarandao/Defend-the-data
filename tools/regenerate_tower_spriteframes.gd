extends SceneTree


func _init() -> void:
	_save_sprite_frames(
		"res://assets/Towers/CyberGuardian/CyberGuardianSpriteFrames.res",
		[
			{
				"name": &"idle",
				"atlas": "res://assets/Towers/CyberGuardian/Idle/Cyber-Guardian_Idle1_atlas_30fps.png",
				"frame_count": 151,
				"columns": 13,
				"frame_size": Vector2i(720, 720),
				"fps": 30.0,
				"loop": true
			},
			{
				"name": &"SummonAnim",
				"atlas": "res://assets/Towers/CyberGuardian/SummonAnim/CyberGuardian_Summon1_atlas_30fps.png",
				"frame_count": 91,
				"columns": 10,
				"frame_size": Vector2i(720, 720),
				"fps": 30.0,
				"loop": false
			},
			{
				"name": &"ShootAnim",
				"atlas": "res://assets/Towers/CyberGuardian/ShootAnim/CyberGuardian_Attack1_atlas_30fps.png",
				"frame_count": 151,
				"columns": 13,
				"frame_size": Vector2i(720, 720),
				"fps": 30.0,
				"loop": false
			}
		]
	)
	_save_sprite_frames(
		"res://assets/Towers/Laser-Turret/LaserTurretSpriteFrames.res",
		[
			{
				"name": &"level_1",
				"atlas": "res://assets/Towers/Laser-Turret/Idle/Cybertower_LV1_idle_atlas_30fps.png",
				"frame_count": 91,
				"columns": 10,
				"frame_size": Vector2i(720, 720),
				"fps": 30.0,
				"loop": true
			},
			{
				"name": &"level_2",
				"fps": 30.0,
				"loop": true,
				"pages": [
					{
						"atlas": "res://assets/Towers/Laser-Turret/Idle/Cybertower_LV2_idle_atlas_30fps_p01.png",
						"frame_count": 64,
						"columns": 8,
						"frame_size": Vector2i(720, 720)
					},
					{
						"atlas": "res://assets/Towers/Laser-Turret/Idle/Cybertower_LV2_idle_atlas_30fps_p02.png",
						"frame_count": 64,
						"columns": 8,
						"frame_size": Vector2i(720, 720)
					},
					{
						"atlas": "res://assets/Towers/Laser-Turret/Idle/Cybertower_LV2_idle_atlas_30fps_p03.png",
						"frame_count": 53,
						"columns": 8,
						"frame_size": Vector2i(720, 720)
					}
				]
			},
			{
				"name": &"level_3",
				"atlas": "res://assets/Towers/Laser-Turret/Idle/Cybertower_LV3_idle_atlas_30fps.png",
				"frame_count": 91,
				"columns": 10,
				"frame_size": Vector2i(720, 720),
				"fps": 30.0,
				"loop": true
			},
			{
				"name": &"level_4",
				"fps": 30.0,
				"loop": true,
				"pages": [
					{
						"atlas": "res://assets/Towers/Laser-Turret/Idle/Cybertower_LV4_idle_atlas_30fps_p01.png",
						"frame_count": 64,
						"columns": 8,
						"frame_size": Vector2i(720, 720)
					},
					{
						"atlas": "res://assets/Towers/Laser-Turret/Idle/Cybertower_LV4_idle_atlas_30fps_p02.png",
						"frame_count": 64,
						"columns": 8,
						"frame_size": Vector2i(720, 720)
					},
					{
						"atlas": "res://assets/Towers/Laser-Turret/Idle/Cybertower_LV4_idle_atlas_30fps_p03.png",
						"frame_count": 53,
						"columns": 8,
						"frame_size": Vector2i(720, 720)
					}
				]
			},
			{
				"name": &"level_5",
				"fps": 30.0,
				"loop": true,
				"pages": [
					{
						"atlas": "res://assets/Towers/Laser-Turret/Idle/Cybertower_LV5_idle_atlas_30fps_p01.png",
						"frame_count": 64,
						"columns": 8,
						"frame_size": Vector2i(720, 720)
					},
					{
						"atlas": "res://assets/Towers/Laser-Turret/Idle/Cybertower_LV5_idle_atlas_30fps_p02.png",
						"frame_count": 64,
						"columns": 8,
						"frame_size": Vector2i(720, 720)
					},
					{
						"atlas": "res://assets/Towers/Laser-Turret/Idle/Cybertower_LV5_idle_atlas_30fps_p03.png",
						"frame_count": 53,
						"columns": 8,
						"frame_size": Vector2i(720, 720)
					}
				]
			}
		]
	)
	_save_sprite_frames(
		"res://assets/Enemies/RedVirus/RedVirusSpriteFrames.res",
		[
			{
				"name": &"idle",
				"atlas": "res://assets/Enemies/RedVirus/Idle/Red_Virus_Idle_720.png",
				"frame_count": 1,
				"columns": 1,
				"frame_size": Vector2i(720, 720),
				"fps": 1.0,
				"loop": true
			},
			{
				"name": &"destroy",
				"fps": 30.0,
				"loop": false,
				"pages": [
					{
						"atlas": "res://assets/Enemies/RedVirus/Destroy/Red_Virus_Destroy_atlas_30fps_p01.png",
						"frame_count": 25,
						"columns": 5,
						"frame_size": Vector2i(720, 720)
					},
					{
						"atlas": "res://assets/Enemies/RedVirus/Destroy/Red_Virus_Destroy_atlas_30fps_p02.png",
						"frame_count": 25,
						"columns": 5,
						"frame_size": Vector2i(720, 720)
					},
					{
						"atlas": "res://assets/Enemies/RedVirus/Destroy/Red_Virus_Destroy_atlas_30fps_p03.png",
						"frame_count": 25,
						"columns": 5,
						"frame_size": Vector2i(720, 720)
					},
					{
						"atlas": "res://assets/Enemies/RedVirus/Destroy/Red_Virus_Destroy_atlas_30fps_p04.png",
						"frame_count": 16,
						"columns": 4,
						"frame_size": Vector2i(720, 720)
					}
				]
			}
		]
	)
	quit()


func _save_sprite_frames(path: String, animation_defs: Array) -> void:
	var sprite_frames := SpriteFrames.new()
	for animation_name in sprite_frames.get_animation_names():
		sprite_frames.remove_animation(animation_name)

	for animation_def in animation_defs:
		_add_animation(sprite_frames, animation_def)

	var error := ResourceSaver.save(sprite_frames, path)
	if error != OK:
		push_error("Failed to save %s. Error: %s" % [path, error])


func _add_animation(sprite_frames: SpriteFrames, animation_def: Dictionary) -> void:
	var animation_name: StringName = animation_def["name"]

	sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_loop(animation_name, animation_def["loop"])
	sprite_frames.set_animation_speed(animation_name, animation_def["fps"])

	if animation_def.has("pages"):
		for page_def in animation_def["pages"]:
			_add_frames_from_page(sprite_frames, animation_name, page_def)
		return

	_add_frames_from_page(sprite_frames, animation_name, animation_def)


func _add_frames_from_page(sprite_frames: SpriteFrames, animation_name: StringName, page_def: Dictionary) -> void:
	var atlas := load(page_def["atlas"]) as Texture2D
	if atlas == null:
		push_error("Could not load atlas: %s" % page_def["atlas"])
		return

	var frame_count: int = page_def["frame_count"]
	var columns: int = page_def["columns"]
	var frame_size: Vector2i = page_def["frame_size"]

	for index in range(frame_count):
		var atlas_texture := AtlasTexture.new()
		atlas_texture.atlas = atlas
		atlas_texture.region = Rect2(
			(index % columns) * frame_size.x,
			int(index / columns) * frame_size.y,
			frame_size.x,
			frame_size.y
		)
		sprite_frames.add_frame(animation_name, atlas_texture, 1.0)
