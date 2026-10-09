extends Node2D
# ==============================================================
#  shield_visual.gd  —  attach กับ Node2D "ShieldVisual" (ลูกของ Player)
#  วาดวงแหวนพลังงาน (barrier) ล้อมรอบยานอวกาศตอนมีโล่ป้องกัน
#  (โหนดนี้เดิมไม่มี sprite/child ใดๆ จึงวาดด้วย _draw() เอง)
# ==============================================================

const RADIUS:      float = 52.0   # ตรงกับ circle_shield (CircleShape2D) ของ ShieldArea
const RING_COLOR:  Color = Color(0.40, 0.80, 1.0, 0.95)
const FILL_COLOR:  Color = Color(0.35, 0.75, 1.0, 0.16)
const SPARK_COLOR: Color = Color(1.0, 1.0, 1.0, 0.85)
const SPARK_COUNT: int   = 10

var _spin: float = 0.0

func _ready() -> void:
    set_process(true)

func _process(delta: float) -> void:
    if visible:
        _spin += delta * 1.4
        queue_redraw()

func _draw() -> void:
    draw_circle(Vector2.ZERO, RADIUS, FILL_COLOR)
    draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, RING_COLOR, 3.0, true)
    # เส้นพลังงานหมุนรอบวงแหวน ให้ดูเหมือนโล่กำลังทำงาน
    for i in SPARK_COUNT:
        var a0: float = _spin + i * TAU / SPARK_COUNT
        var a1: float = a0 + 0.22
        draw_arc(Vector2.ZERO, RADIUS, a0, a1, 6, SPARK_COLOR, 4.0, true)
