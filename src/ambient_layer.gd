extends Node2D

var motes: Array[Dictionary] = []
var elapsed := 0.0

func _ready() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 2026
	for i in 18:
		motes.append({
			"p": Vector2(random.randf_range(10.0, 530.0), random.randf_range(80.0, 610.0)),
			"s": random.randf_range(4.0, 10.0),
			"v": random.randf_range(5.0, 13.0),
			"phase": random.randf_range(0.0, TAU),
			"alpha": random.randf_range(0.16, 0.42),
		})
	set_process(true)

func _process(delta: float) -> void:
	elapsed += delta
	for mote in motes:
		mote.p.y += mote.v * delta
		mote.p.x += sin(elapsed * 0.8 + mote.phase) * 4.0 * delta
		if mote.p.y > 640.0:
			mote.p.y = 80.0
			mote.p.x = fmod(mote.p.x + 173.0, 520.0) + 10.0
	queue_redraw()

func _draw() -> void:
	for mote in motes:
		var color := Color(0.96, 0.66, 0.67, mote.alpha)
		draw_circle(mote.p, mote.s * 0.42, color)
		draw_line(mote.p, mote.p + Vector2(mote.s * 0.7, mote.s * 0.18), Color(color, mote.alpha * 0.7), 1.2, true)

