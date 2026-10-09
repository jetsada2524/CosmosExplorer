extends Node
# ==============================================================
#  TouchInput.gd  —  Autoload Singleton
#  เดิม: ใช้ตำแหน่งสัมผัสแบ่งโซนซ้าย/กลาง/ขวาบนจอเพื่อเลี้ยว/บูสต์
#  ตอนนี้: ใช้ปุ่มกดจริงบน HUD (SteerLeftBtn / SteerRightBtn / BoostBtn
#  ใน gameplay.tscn → HUD/ControlBar) ที่ผูกกับ
#  Input.action_press/release("steer_left"/"steer_right"/"boost")
#  ใน hud.gd แทน — เลิกใช้การตรวจจับตำแหน่งสัมผัสแบบเดิม เพื่อแก้บัค
#  ที่กดปุ่ม Boost (อยู่ฝั่งขวาของจอ) แล้วดันไปโดนโซน "เลี้ยวขวา" ด้วย
#  สถานะด้านล่างยังอ่านจาก Input action เดิม จึงรองรับคีย์บอร์ดด้วย
# ==============================================================

var is_steering_left:  bool  = false
var is_steering_right: bool  = false
var is_boosting:       bool  = false
var steer_x_norm:      float = 0.0   # -1.0 (ซ้ายสุด) .. 0 (กลาง) .. +1.0 (ขวาสุด)

const _ACTIONS: Array[String] = ["steer_left", "steer_right", "boost"]

# ──────────────────────────────────────────────────────────────
func _ready() -> void:
    # รับ input ทุก frame แม้ game pause
    process_mode = Node.PROCESS_MODE_ALWAYS

# ──────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
    is_steering_left  = Input.is_action_pressed("steer_left")
    is_steering_right = Input.is_action_pressed("steer_right")
    is_boosting        = Input.is_action_pressed("boost")

# ──────────────────────────────────────────────────────────────
# Helper: รีเซ็ต state ทั้งหมด (ใช้ตอน pause หรือ scene เปลี่ยน)
# กันปุ่มค้าง (action_press ไม่ถูกปล่อยเพราะฉากเปลี่ยน/ปุ่มถูกลบกลางทาง)
func reset() -> void:
    is_steering_left  = false
    is_steering_right = false
    is_boosting       = false
    steer_x_norm      = 0.0
    for action in _ACTIONS:
        if Input.is_action_pressed(action):
            Input.action_release(action)
