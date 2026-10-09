extends Control
# ==============================================================
#  arc_gauge.gd  —  Circular arc gauge for cockpit HUD
#  Draws a clockwise arc from 12 o'clock proportional to `fill`
# ==============================================================

## Fill color of the active arc
@export var arc_color:  Color = Color(0.08, 0.93, 0.33, 1.0)
## Background ring color
@export var ring_color: Color = Color(0.02, 0.08, 0.02, 0.88)
## Fill level 0.0 – 1.0
@export var fill:       float = 1.0
## Stroke thickness in pixels
@export var thickness:  float = 7.0

func _draw() -> void:
	var cx   := size.x * 0.5
	var cy   := size.y * 0.5
	var r    := minf(cx, cy) - thickness * 0.5 - 2.0
	if r < 4.0:
		return
	var center := Vector2(cx, cy)
	var start  := -PI * 0.5          # 12 o'clock

	# Full background ring
	draw_arc(center, r, start, start + TAU, 72, ring_color, thickness, true)

	# Filled arc — clockwise from top
	var f := clampf(fill, 0.005, 1.0)
	draw_arc(center, r, start, start + TAU * f, 72, arc_color, thickness, true)

## Call this to update the fill and trigger a redraw
func set_fill(v: float) -> void:
	fill = clampf(v, 0.0, 1.0)
	queue_redraw()
