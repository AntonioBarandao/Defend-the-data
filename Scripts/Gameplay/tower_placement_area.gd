@tool
class_name TowerPlacementArea
extends Area2D

@export var placement_group := "tower_placement_area":
	set(value):
		if placement_group != "" and is_inside_tree():
			remove_from_group(placement_group)
		placement_group = value
		if placement_group != "" and is_inside_tree():
			add_to_group(placement_group)

@export var placement_size := Vector2(96.0, 96.0):
	set(value):
		placement_size = Vector2(maxf(1.0, value.x), maxf(1.0, value.y))
		_sync_nodes()

@export var placement_offset := Vector2.ZERO:
	set(value):
		placement_offset = value
		_sync_nodes()

@export var visual_color := Color(0.1, 0.9, 0.25, 0.22):
	set(value):
		visual_color = value
		_sync_nodes()

@export var show_visual_in_editor := true:
	set(value):
		show_visual_in_editor = value
		_sync_nodes()

@export var collision_shape_path: NodePath = ^"CollisionShape2D":
	set(value):
		collision_shape_path = value
		_sync_nodes()

@export var visual_path: NodePath = ^"PlacementAreaVisual":
	set(value):
		visual_path = value
		_sync_nodes()


func _ready() -> void:
	if placement_group != "":
		add_to_group(placement_group)
	_sync_nodes()


func _sync_nodes() -> void:
	if not is_inside_tree():
		return

	var collision_shape := get_node_or_null(collision_shape_path) as CollisionShape2D
	if collision_shape != null:
		collision_shape.position = placement_offset
		var rectangle_shape := collision_shape.shape as RectangleShape2D
		if rectangle_shape == null:
			rectangle_shape = RectangleShape2D.new()
			collision_shape.shape = rectangle_shape
		elif not rectangle_shape.resource_local_to_scene:
			rectangle_shape = rectangle_shape.duplicate() as RectangleShape2D
			rectangle_shape.resource_local_to_scene = true
			collision_shape.shape = rectangle_shape
		rectangle_shape.size = placement_size

	var visual := get_node_or_null(visual_path) as ColorRect
	if visual == null:
		return

	visual.visible = show_visual_in_editor and Engine.is_editor_hint()
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.color = visual_color
	visual.offset_left = placement_offset.x - placement_size.x * 0.5
	visual.offset_top = placement_offset.y - placement_size.y * 0.5
	visual.offset_right = placement_offset.x + placement_size.x * 0.5
	visual.offset_bottom = placement_offset.y + placement_size.y * 0.5
