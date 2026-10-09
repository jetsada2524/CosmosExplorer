extends Node2D
# ==============================================================
#  orbit_ring.gd  —  วาดวงแหวนวงโคจรสีน้ำเงิน/ม่วงเข้มหลังดวงอาทิตย์
#  ใช้ใน attract.tscn (S-01) ให้ตรงกับภาพ mockup
# ==============================================================

@export var radius: float = 220.0
@export var fill_color: Color = Color(0.10, 0.14, 0.40, 0.55)
@export var ring_color: Color = Color(0.32, 0.40, 0.78, 0.85)
@export var ring_width: float = 3.0

func _draw() -> void:
    draw_circle(Vector2.ZERO, radius, fill_color)
    draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, ring_color, ring_width, true)
