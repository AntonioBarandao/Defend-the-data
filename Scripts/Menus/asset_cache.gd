extends Node

signal resource_loaded(path: String, resource: Resource)
signal cyber_guardian_idle_ready(sprite_frames: SpriteFrames)
signal cyber_guardian_animations_ready(sprite_frames: SpriteFrames)

const CYBER_GUARDIAN_SPRITE_FRAMES_PATH := "res://assets/Towers/CyberGuardian/CyberGuardianSpriteFrames.res"
const CYBER_GUARDIAN_IDLE_ANIMATION := &"idle"
const CYBER_GUARDIAN_SUMMON_ANIMATION := &"SummonAnim"
const CYBER_GUARDIAN_SHOOT_ANIMATION := &"ShootAnim"

var cyber_guardian_idle_sprite_frames: SpriteFrames
var cyber_guardian_sprite_frames: SpriteFrames

var _pending_paths: Dictionary = {}


func _ready() -> void:
	set_process(false)
	load_startup_resources()


func load_startup_resources() -> void:
	_request_threaded_load(CYBER_GUARDIAN_SPRITE_FRAMES_PATH)
	set_process(not _pending_paths.is_empty())


func has_cyber_guardian_idle() -> bool:
	return cyber_guardian_idle_sprite_frames != null


func has_cyber_guardian_animations() -> bool:
	return cyber_guardian_sprite_frames != null


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
	if path == CYBER_GUARDIAN_SPRITE_FRAMES_PATH and has_cyber_guardian_animations():
		return

	if _pending_paths.has(path):
		return

	var error := ResourceLoader.load_threaded_request(path)
	if error == OK or error == ERR_BUSY:
		_pending_paths[path] = true
	else:
		push_error("Could not request threaded load for %s. Error: %s" % [path, error])


func _accept_loaded_resource(path: String, resource: Resource) -> void:
	if path != CYBER_GUARDIAN_SPRITE_FRAMES_PATH:
		return

	var frames := resource as SpriteFrames
	if frames == null:
		push_error("Cyber Guardian sprite frames did not load as SpriteFrames: %s" % path)
		return

	cyber_guardian_sprite_frames = frames
	cyber_guardian_idle_sprite_frames = frames
	cyber_guardian_idle_ready.emit(frames)
	cyber_guardian_animations_ready.emit(frames)
