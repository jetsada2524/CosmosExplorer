extends CharacterBody2D
# ==============================================================
#  player.gd  —  attach กับ Node "Player" (CharacterBody2D)
#  ใน gameplay.tscn
# ==============================================================

signal shield_changed(active: bool)   # แจ้ง HUD ให้อัปเดตป้ายโล่

# ── เชื่อม Child Nodes (ตั้งชื่อใน scene ตรงกัน) ──────────────
@onready var ship_sprite:    Sprite2D            = $ShipSprite
@onready var thruster_fx:    GPUParticles2D      = $ThrusterParticles
@onready var hit_fx:         GPUParticles2D      = $HitParticles
@onready var boost_sfx:      AudioStreamPlayer2D = $BoostSFX
@onready var hit_sfx:        AudioStreamPlayer2D = $HitSFX
@onready var shield_area:    Area2D              = $ShieldArea
@onready var shield_visual:  Node2D              = $ShieldVisual    # Sprite วงกลมสีฟ้า

const SHIP_TEXTURES: Array[String] = [
    "res://assets/sprites/ships/ship_rocket.png",
    "res://assets/sprites/ships/ship_ufo.png",
    "res://assets/sprites/ships/ship_star.png",
]

# ยานควรมีขนาดแสดงผล = 80% ของอุกกาบาต (meteor) — อ้างอิงจาก
# CircleShape2D radius=45 ใน meteor.tscn (เส้นผ่านศูนย์กลาง 90px)
const METEOR_DIAMETER_PX: float = 90.0
const SHIP_SIZE_RATIO:    float = 0.8

# ── Movement Constants ─────────────────────────────────────────
const BASE_SPEED:         float = 400.0   # px/s ซ้าย-ขวา
# BOOST_MULTIPLIER ปรับได้ผ่าน GameSettings.boost_speed_mult (เมนูตั้งค่า admin)
const FORWARD_SPEED:      float = 80.0    # px/s ขึ้นบน (auto-advance)
const TILT_MAX_DEG:       float = 22.0    # องศาเอียงยานสูงสุด
const TILT_SMOOTH:        float = 8.0     # ความเร็วเอียง (lerp speed)
const SCREEN_MARGIN:      float = 70.0    # ระยะขอบจอ px

# ── Energy Constants ───────────────────────────────────────────
# ปรับได้ผ่าน GameSettings.energy_drain_boost / energy_idle_regen (เมนูตั้งค่า admin)

# ── Damage Constants ───────────────────────────────────────────
const INVINCIBLE_DURATION: float = 1.8   # วินาทีหลังโดนชน (กระพริบ)

# ── State ──────────────────────────────────────────────────────
var is_boosting:    bool  = false
var has_shield:     bool  = false
var is_invincible:  bool  = false
var current_tilt:   float = 0.0
var vp_size:        Vector2 = Vector2.ZERO

# ──────────────────────────────────────────────────────────────
func _ready() -> void:
    vp_size = get_viewport_rect().size

    # เชื่อม signal จาก ShieldArea
    shield_area.body_entered.connect(_on_obstacle_entered)
    shield_area.area_entered.connect(_on_powerup_entered)

    shield_visual.hide()
    _load_ship_texture()
    GameManager.coin_overflow_awarded.connect(_show_coin_popup)

func _load_ship_texture() -> void:
    var idx: int = clampi(GameManager.player_avatar, 0, SHIP_TEXTURES.size() - 1)
    var path: String = SHIP_TEXTURES[idx]
    if ResourceLoader.exists(path):
        var tex: Texture2D = load(path)
        ship_sprite.texture = tex
        # คำนวณ scale ให้ยานมีขนาด (ด้านที่ยาวสุดของภาพ) = 80% ของ
        # ขนาดอุกกาบาต โดยไม่ขึ้นกับสัดส่วนภาพต้นฉบับของแต่ละยาน
        var tex_size: Vector2 = tex.get_size()
        var longest_side: float = max(tex_size.x, tex_size.y)
        var target_size: float = METEOR_DIAMETER_PX * SHIP_SIZE_RATIO
        var s: float = target_size / longest_side if longest_side > 0.0 else 0.12
        ship_sprite.scale = Vector2(s, s)

# ──────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
    if not GameManager.is_game_running:
        return

    _handle_movement(delta)
    _handle_energy(delta)
    _handle_journey_progress(delta)
    move_and_slide()

# ──────────────────────────────────────────────────────────────
func _handle_movement(delta: float) -> void:
    # อ่านจาก TouchInput Autoload (แนวทาง B)
    var dir: float = 0.0
    if TouchInput.is_steering_left:  dir = -1.0
    if TouchInput.is_steering_right: dir =  1.0

    # Boost ใช้ได้เมื่อ energy > 0
    is_boosting = TouchInput.is_boosting and GameManager.current_energy > 0.0

    var boost_mult: float = GameSettings.boost_speed_mult
    var h_speed: float = BASE_SPEED * (boost_mult if is_boosting else 1.0)
    var v_speed: float = -FORWARD_SPEED * (boost_mult if is_boosting else 1.0)

    velocity = Vector2(dir * h_speed, v_speed)

    # จำกัดขอบจอ
    position.x = clampf(
        position.x + velocity.x * delta,
        SCREEN_MARGIN,
        vp_size.x - SCREEN_MARGIN
    )
    # ล็อก Y ให้อยู่แถวล่าง (จอ scroll แทน)
    position.y = clampf(position.y, vp_size.y * 0.5, vp_size.y - SCREEN_MARGIN)

    # เอียงยานตามทิศทาง (smooth lerp)
    var target_tilt: float = dir * TILT_MAX_DEG
    current_tilt = lerpf(current_tilt, target_tilt, TILT_SMOOTH * delta)
    rotation_degrees = current_tilt

    # Thruster Particles
    thruster_fx.emitting = true
    thruster_fx.amount_ratio = 2.0 if is_boosting else 1.0
    if is_boosting and not boost_sfx.playing:
        boost_sfx.play()
    elif not is_boosting:
        boost_sfx.stop()

# ──────────────────────────────────────────────────────────────
func _handle_energy(delta: float) -> void:
    if is_boosting:
        GameManager.use_energy(GameSettings.energy_drain_boost * delta)
    else:
        # regen ช้าๆ ขณะไม่ boost
        GameManager.restore_energy(GameSettings.energy_idle_regen * delta)

# ──────────────────────────────────────────────────────────────
func _handle_journey_progress(delta: float) -> void:
    # ระยะทางที่ต้องเดินทางทั้งหมด = time_limit * FORWARD_SPEED
    var total: float = GameManager.selected_planet.get("time_limit", 300.0) * FORWARD_SPEED
    var speed: float = FORWARD_SPEED * (GameSettings.boost_speed_mult if is_boosting else 1.0)
    GameManager.journey_progress = minf(
        1.0,
        GameManager.journey_progress + (speed * delta) / total
    )
    GameManager.add_score(int(speed * delta * 0.5))

    if GameManager.journey_progress >= 1.0:
        GameManager.complete_mission()

# ──────────────────────────────────────────────────────────────
func _on_obstacle_entered(body: Node2D) -> void:
    if is_invincible or not body.is_in_group("obstacles"):
        return

    if has_shield:
        _break_shield()
        return

    var dmg: float = body.get("damage") if body.get("damage") != null else 25.0
    GameManager.take_damage(dmg)

    # ถ้าโดนแล้ว HP หมดจน GameManager เริ่ม game over ไปแล้ว (is_game_running
    # กลายเป็น false) ห้ามเล่นเอฟเฟกต์/tween ต่อ เพราะฉากกำลังจะถูกเปลี่ยน
    # (deferred) — ทำต่อจะชน get_tree() เป็น null (node กำลังถูกลบ)
    if not GameManager.is_game_running:
        return

    _start_invincible()
    hit_sfx.play()
    hit_fx.restart()
    _play_hit_flash()

func _on_powerup_entered(area: Area2D) -> void:
    if not area.is_in_group("powerups"):
        return
    var type: String = area.get("powerup_type") if area.get("powerup_type") != null else ""
    match type:
        "shield":
            activate_shield()
        "quiz":
            # ส่งสัญญาณให้ Gameplay scene เปิด QuizPopup
            get_parent().get_node("QuizPopup").show_quiz()
        "energy":
            # ถ้า energy เต็มอยู่แล้ว แปลงเป็น coin แทน
            GameManager.restore_energy_or_score(25.0, GameSettings.overflow_coin_bonus)
        "score":
            GameManager.add_score(500)
            _show_coin_popup(500)
    area.queue_free()

# ──────────────────────────────────────────────────────────────
func activate_shield() -> void:
    has_shield = true
    shield_changed.emit(true)
    shield_visual.show()
    shield_visual.scale = Vector2(0.5, 0.5)
    shield_visual.modulate.a = 0.0
    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(shield_visual, "scale", Vector2(1.0, 1.0), 0.25) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    tween.tween_property(shield_visual, "modulate:a", 1.0, 0.2)

func _break_shield() -> void:
    has_shield = false
    shield_changed.emit(false)
    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(shield_visual, "scale", Vector2(1.4, 1.4), 0.2)
    tween.tween_property(shield_visual, "modulate:a", 0.0, 0.2)
    tween.chain().tween_callback(shield_visual.hide)

# ── ป้าย "+coin" ลอยขึ้นข้างยานเมื่อเก็บไอเทมแล้วได้ coin ──────────
func _show_coin_popup(amount: int) -> void:
    var lbl := Label.new()
    lbl.text = "+%d 🪙" % amount
    lbl.add_theme_font_size_override("font_size", 30)
    lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.45))
    lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.25, 0.05))
    lbl.add_theme_constant_override("outline_size", 6)
    lbl.top_level = true   # ไม่หมุน/เอียงตามยาน (rotation_degrees ของ Player)
    lbl.z_index = 100
    lbl.position = global_position + Vector2(55.0, -40.0)
    get_parent().add_child(lbl)
    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(lbl, "position:y", lbl.position.y - 70.0, 1.0) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(lbl, "modulate:a", 0.0, 0.6).set_delay(0.4)
    tween.chain().tween_callback(lbl.queue_free)

func _play_hit_flash() -> void:
    var tween := create_tween()
    tween.tween_property(ship_sprite, "modulate", Color(1.0, 0.3, 0.3), 0.08)
    tween.tween_property(ship_sprite, "modulate", Color.WHITE, 0.12)

func _start_invincible() -> void:
    is_invincible = true
    var blink_tween := create_tween()
    blink_tween.set_loops(int(INVINCIBLE_DURATION / 0.2))
    blink_tween.tween_property(ship_sprite, "modulate:a", 0.3, 0.1)
    blink_tween.tween_property(ship_sprite, "modulate:a", 1.0, 0.1)
    await get_tree().create_timer(INVINCIBLE_DURATION).timeout
    is_invincible = false
    ship_sprite.modulate = Color.WHITE
