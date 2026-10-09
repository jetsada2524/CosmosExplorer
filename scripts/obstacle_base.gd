extends RigidBody2D
# ==============================================================
#  obstacle_base.gd  —  Base script สำหรับ obstacle ทุกชนิด
#  attach กับ RigidBody2D ของแต่ละ obstacle scene
#  (asteroid.tscn, comet.tscn, meteor.tscn, space_debris.tscn)
# ==============================================================

@export var damage:           float = 25.0
@export var speed_base:       float = 200.0
@export var rotate_speed:     float = 1.5    # rad/s
@export var obstacle_type:    String = "asteroid"

# กด boost แล้วยานเหมือนพุ่งไปข้างหน้าเร็วขึ้น -> จำลองด้วยการให้อุกาบาตตกไวขึ้น
# (ปรับได้ผ่าน GameSettings.boost_fall_mult ในเมนูตั้งค่า admin)

var speed_multiplier: float = 1.0
var _x_drift: float = 0.0

# ── clamp bounds (set โดย ObstacleSpawner) ───────────────────
var clamp_x_min: float = 0.0
var clamp_x_max: float = 1920.0

func _ready() -> void:
	_x_drift = randf_range(-15.0, 15.0)   # ลด drift จาก ±60 เป็น ±30
	linear_velocity = Vector2(_x_drift, speed_base * speed_multiplier)
	angular_velocity = randf_range(-rotate_speed, rotate_speed)

func _process(_delta: float) -> void:
	var mult: float = 1.0
	if TouchInput.is_boosting and GameManager.current_energy > 0.0:
		mult = GameSettings.boost_fall_mult
	linear_velocity = Vector2(_x_drift, speed_base * speed_multiplier * mult)

	# ── Clamp X position ให้อยู่ในช่องมอง cockpit ──────────
	if clamp_x_max > clamp_x_min:
		position.x = clampf(position.x, clamp_x_min, clamp_x_max)

	# ถ้าออกนอกจอ ลบทันที
	if position.y > get_viewport_rect().size.y + 150.0:
		queue_free()
