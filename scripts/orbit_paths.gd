extends Node2D
# ==============================================================
#  orbit_paths.gd — วาดวงโคจรรูปวงรีเส้นประรอบดวงอาทิตย์
#  attach กับ Node2D "OrbitPaths" ใต้ SolarSystemMap
# ==============================================================

var radii: Array = []   # Array[Vector2] (rx, ry) ต่อวงโคจร 1 วง
var dash_color: Color = Color(0.55, 0.60, 0.78, 0.35)

func set_radii(r: Array) -> void:
	radii = r
	queue_redraw()

func _draw() -> void:
	for r in radii:
		_draw_glow_ellipse(r.x, r.y)

# วงโคจรเส้นทึบเรืองแสง 3 ชั้น (เรืองกว้าง → เรืองกลาง → เส้นสว่างบาง)
func _draw_glow_ellipse(rx: float, ry: float) -> void:
	var pts := PackedVector2Array()
	var segments := 160
	for i in range(segments + 1):
		var t := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(t) * rx, sin(t) * ry))
	draw_polyline(pts, Color(1.0, 0.86, 0.62, 0.07), 12.0, true)
	draw_polyline(pts, Color(1.0, 0.90, 0.72, 0.16), 5.0, true)
	draw_polyline(pts, Color(1.0, 0.96, 0.88, 0.70), 1.8, true)
