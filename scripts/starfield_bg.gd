extends Node2D
# ==============================================================
#  starfield_bg.gd — Component พื้นหลังดาวระยิบระยับ + ยานบินช้าๆ
#  ใช้แทรกเป็นลูกของ scene พื้นหลัง (เช่น attract.tscn, login.tscn)
#  สร้างดาวจุดเล็กๆ กระพริบแบบสุ่ม + ยานอวกาศบินผ่านจอแบบ
#  ไป-กลับ (ping-pong) ช้าๆ ล่องลอยอยู่เบื้องหลัง
#  หมายเหตุ: ไม่ใช้ mouse/touch ใดๆ ทั้งสิ้น (ไม่บัง input ของ UI ด้านหน้า)
# ==============================================================

@export var star_count: int = 45
@export var ship_count: int = 3
@export var viewport_size: Vector2 = Vector2(1920, 1080)

const SHIP_TEXTURES: Array[String] = [
    "res://assets/sprites/ships/ship1.png",
    "res://assets/sprites/ships/ship2.png",
    "res://assets/sprites/ships/ship3.png",
]

func _ready() -> void:
    z_index = -5
    _spawn_stars()
    _spawn_ships()

# ── ดาวระยิบระยับ ──────────────────────────────────────────────
func _spawn_stars() -> void:
    for i in star_count:
        var star := ColorRect.new()
        var sz: float = randf_range(2.0, 4.0)
        star.size = Vector2(sz, sz)
        star.color = Color(1, 1, 1, 1)
        star.mouse_filter = Control.MOUSE_FILTER_IGNORE
        star.position = Vector2(
            randf_range(0.0, viewport_size.x),
            randf_range(0.0, viewport_size.y))
        add_child(star)
        _twinkle(star)

func _twinkle(star: ColorRect) -> void:
    var dim: float = randf_range(0.1, 0.35)
    var dur: float = randf_range(0.8, 2.4)
    star.modulate.a = randf_range(dim, 1.0)
    var tween := create_tween().set_loops()
    tween.tween_property(star, "modulate:a", dim, dur) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tween.tween_interval(randf_range(0.0, 1.2))
    tween.tween_property(star, "modulate:a", 1.0, dur) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tween.tween_interval(randf_range(0.0, 1.2))

# ── ยานอวกาศบินไป-กลับช้าๆ ─────────────────────────────────────
func _spawn_ships() -> void:
    for i in ship_count:
        var tex: Texture2D = load(SHIP_TEXTURES[i % SHIP_TEXTURES.size()])
        if tex == null:
            continue
        var ship := Sprite2D.new()
        ship.texture = tex
        ship.scale = Vector2(0.25, 0.25)
        ship.modulate.a = 0.5
        ship.z_index = -4
        # ภาพต้นฉบับหันหัวขึ้น (rotation = 0) — เริ่มบินไปทางขวาก่อน
        # จึงหมุนหัวยานให้ชี้ขวา (+90°)
        ship.rotation = PI / 2.0
        var y: float = randf_range(viewport_size.y * 0.12, viewport_size.y * 0.8)
        ship.position = Vector2(-120.0, y)
        add_child(ship)
        _fly_ping_pong(ship, randf_range(20.0, 30.0))

func _fly_ping_pong(ship: Sprite2D, duration: float) -> void:
    var tween := create_tween().set_loops()
    tween.tween_property(ship, "position:x", viewport_size.x + 120.0, duration) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    # ถึงขอบขวาแล้วจะบินกลับ (ไปทางซ้าย) — หมุนหัวให้ชี้ซ้าย (-90°)
    tween.tween_callback(func(): ship.rotation = -PI / 2.0)
    tween.tween_property(ship, "position:x", -120.0, duration) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    # กลับมาขอบซ้าย จะบินไปทางขวาอีกครั้ง — หมุนหัวกลับไปชี้ขวา (+90°)
    tween.tween_callback(func(): ship.rotation = PI / 2.0)
