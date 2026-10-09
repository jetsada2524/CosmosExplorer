extends Area2D
# ==============================================================
#  powerup_base.gd  —  Base script สำหรับ powerup ทุกชนิด
#  attach กับ Area2D ของ shield_item.tscn, quiz_item.tscn ฯลฯ
#
#  แสดงผล: ลองใช้ 3D model จาก Blender ก่อน
#           ถ้าโหลดไม่ได้ → fallback เป็น 2D sprite เดิม
# ==============================================================

@export var powerup_type: String = "energy"
@export var fall_speed:   float  = 120.0
@export var bob_speed:    float  = 2.0
@export var bob_amount:   float  = 10.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var label:  Label    = $TypeLabel

const POWERUP_ICONS: Dictionary = {
    "shield": "🛡",
    "quiz":   "❓",
    "energy": "⚡",
    "score":  "⭐",
}

# powerup_type → model_id ที่ใช้กับ Powerup3DView
const TYPE_TO_MODEL: Dictionary = {
    "energy": "energy_tank",
    "quiz":   "mystery_box",
    "shield": "roman_shield",
    "score":  "star",
}

var _model_node: Node3D  = null  # 3D model node สำหรับ rotate
var _display:   Sprite2D = null  # Sprite2D แสดง SubViewport texture

func _ready() -> void:
    body_entered.connect(_on_collected)

    if label:
        label.text = POWERUP_ICONS.get(powerup_type, "?")

    # ลองตั้ง 3D display ก่อน, fallback เป็น 2D sprite ถ้าโหลดไม่ได้
    var use_3d := _setup_3d()

    # Glow pulse
    var glow_target: Sprite2D = _display if use_3d else sprite
    var tween := create_tween().set_loops()
    tween.tween_property(glow_target, "modulate:a", 0.45, 0.6)
    tween.tween_property(glow_target, "modulate:a", 1.0,  0.6)

# ── ตั้งค่า 3D model ────────────────────────────────────────────
func _setup_3d() -> bool:
    var model_id: String = TYPE_TO_MODEL.get(powerup_type, "")
    if model_id.is_empty():
        return false

    var vp_data := Powerup3DView.make_powerup_vp(self, model_id, Vector2i(96, 96))
    if vp_data.is_empty():
        return false

    _model_node = vp_data["model_node"]

    sprite.visible = false
    _display = Sprite2D.new()
    _display.texture = (vp_data["vp"] as SubViewport).get_texture()
    add_child(_display)
    return true

# ── Game loop ───────────────────────────────────────────────────
func _process(delta: float) -> void:
    # เคลื่อนลง + bob ขึ้นลง
    position.y += fall_speed * delta
    position.y += sin(Time.get_ticks_msec() * 0.001 * bob_speed) * bob_amount * delta

    if position.y > get_viewport_rect().size.y + 100.0:
        queue_free()

    # หมุน 3D model รอบแกน Y
    if _model_node:
        _model_node.rotation_degrees.y += 90.0 * delta

func _on_collected(body: Node) -> void:
    if not body.is_in_group("player"):
        return
    SoundManager.play_sfx("powerup")
    queue_free()
