extends Node

signal resource_loaded(path: String, resource: Resource)
signal cyber_guardian_idle_ready(sprite_frames: SpriteFrames)

const CYBER_GUARDIAN_IDLE_ATLAS_PATH := "res://assets/Cyber-Guardian_Idle1_atlas_30fps.png"
const CYBER_GUARDIAN_IDLE_ANIMATION := &"idle"
const CYBER_GUARDIAN_IDLE_FPS := 30.0
const CYBER_GUARDIAN_IDLE_FRAME_COUNT := 151
const CYBER_GUARDIAN_IDLE_COLUMNS := 13
const CYBER_GUARDIAN_IDLE_FRAME_SIZE := Vector2i(1073, 949)

var cyber_guardian_idle_atlas: Texture2D
var cyber_guardian_idle_sprite_frames: SpriteFrames

var _pending_paths: Dictionary = {}


func _ready() -> void:
	set_process(false)
	load_startup_resources()


func load_startup_resources() -> void:
	_request_threaded_load(CYBER_GUARDIAN_IDLE_ATLAS_PATH)
	set_process(not _pending_paths.is_empty())


func has_cyber_guardian_idle() -> bool:
	return cyber_guardian_idle_sprite_frames != null


func _process(_delta: float) -> void:
	var finished_paths: Array = []

	for path in _pending_paths.keys():
		var status := ResourceLoader.load_threaded_get_status(path)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				var resource := ResourceLoader.load_threaded_get(path)
				_accept_loaded_resource(path, resource)
				resource_loaded.emit(path, resource)
				finished_paths.append(path)
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				push_error("Failed to load startup resource: %s" % path)
				finished_paths.append(path)

	for path in finished_paths:
		_pending_paths.erase(path)

	if _pending_paths.is_empty():
		set_process(false)


func _request_threaded_load(path: String) -> void:
	if path == CYBER_GUARDIAN_IDLE_ATLAS_PATH and has_cyber_guardian_idle():
		return

	if _pending_paths.has(path):
		return

	var error := ResourceLoader.load_threaded_request(path)
	if error == OK or error == ERR_BUSY:
		_pending_paths[path] = true
	else:
		push_error("Could not request threaded load for %s. Error: %s" % [path, error])


func _accept_loaded_resource(path: String, resource: Resource) -> void:
	if path != CYBER_GUARDIAN_IDLE_ATLAS_PATH:
		return

	cyber_guardian_idle_atlas = resource as Texture2D
	if cyber_guardian_idle_atlas == null:
		push_error("Cyber Guardian idle atlas did not load as a Texture2D.")
		return

	cyber_guardian_idle_sprite_frames = _build_cyber_guardian_idle_frames(cyber_guardian_idle_atlas)
	cyber_guardian_idle_ready.emit(cyber_guardian_idle_sprite_frames)


func _build_cyber_guardian_idle_frames(atlas: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	for animation_name in frames.get_animation_names():
		frames.remove_animation(animation_name)

	frames.add_animation(CYBER_GUARDIAN_IDLE_ANIMATION)
	frames.set_animation_loop(CYBER_GUARDIAN_IDLE_ANIMATION, true)
	frames.set_animation_speed(CYBER_GUARDIAN_IDLE_ANIMATION, CYBER_GUARDIAN_IDLE_FPS)

	for index in range(CYBER_GUARDIAN_IDLE_FRAME_COUNT):
		var atlas_texture := AtlasTexture.new()
		atlas_texture.atlas = atlas

		var column := index % CYBER_GUARDIAN_IDLE_COLUMNS
		var row := int(index / CYBER_GUARDIAN_IDLE_COLUMNS)
		atlas_texture.region = Rect2(
			column * CYBER_GUARDIAN_IDLE_FRAME_SIZE.x,
			row * CYBER_GUARDIAN_IDLE_FRAME_SIZE.y,
			CYBER_GUARDIAN_IDLE_FRAME_SIZE.x,
			CYBER_GUARDIAN_IDLE_FRAME_SIZE.y
		)

		frames.add_frame(CYBER_GUARDIAN_IDLE_ANIMATION, atlas_texture, 1.0)

	return frames
