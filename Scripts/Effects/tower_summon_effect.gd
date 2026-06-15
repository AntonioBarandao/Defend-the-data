class_name TowerSummonEffect
extends Node2D

const STAR_COUNT := 22
const PARTICLE_COUNT := 42
const EFFECT_DURATION := 0.72
const STAR_COLOR := Color(0.58, 0.92, 1.0, 1.0)
const TOP_DOWN_Y_SCALE := 0.46


func _ready() -> void:
	z_as_relative = false
	_spawn_particle_burst()
	_spawn_stars()

	var cleanup_tween := create_tween()
	cleanup_tween.tween_interval(EFFECT_DURATION + 0.16)
	cleanup_tween.tween_callback(queue_free)


func _spawn_particle_burst() -> void:
	var particles := CPUParticles2D.new()
	particles.name = "BlueSummonParticles"
	particles.amount = PARTICLE_COUNT
	particles.lifetime = EFFECT_DURATION
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.randomness = 0.58
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2(0, 8)
	particles.initial_velocity_min = 70.0
	particles.initial_velocity_max = 210.0
	particles.angular_velocity_min = -180.0
	particles.angular_velocity_max = 180.0
	particles.scale_amount_min = 1.6
	particles.scale_amount_max = 4.2
	particles.color = Color(0.42, 0.84, 1.0, 0.95)
	particles.scale = Vector2(1.0, TOP_DOWN_Y_SCALE)
	add_child(particles)
	particles.emitting = true


func _spawn_stars() -> void:
	for _index in range(STAR_COUNT):
		var star := Polygon2D.new()
		star.name = "SummonStar"
		star.polygon = _build_top_down_star_points(randf_range(13.0, 22.0), randf_range(5.5, 9.0))
		star.color = STAR_COLOR
		var direction := Vector2.RIGHT.rotated(randf() * TAU)
		direction.y *= TOP_DOWN_Y_SCALE
		direction = direction.normalized()
		star.position = direction * randf_range(24.0, 84.0)
		star.rotation = randf_range(-0.55, 0.55)
		star.scale = Vector2.ONE * randf_range(0.9, 1.45)
		add_child(star)

		var target_position := star.position + direction * randf_range(28.0, 72.0)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(star, "position", target_position, EFFECT_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(star, "rotation", star.rotation + randf_range(0.28, 0.82), EFFECT_DURATION)
		tween.tween_property(star, "modulate", Color(1, 1, 1, 0), EFFECT_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


func _build_top_down_star_points(outer_radius: float, inner_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(10):
		var radius := outer_radius if index % 2 == 0 else inner_radius
		var angle := -PI * 0.5 + PI * 0.25 + TAU * float(index) / 10.0
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius * TOP_DOWN_Y_SCALE))

	return points
