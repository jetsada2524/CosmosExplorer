extends Node2D
# ==============================================================
#  obstacle_spawner.gd  —  attach กับ Node "ObstacleSpawner"
#  ใน gameplay.tscn
# ==============================================================

@onready var spawn_timer:      Timer  = $SpawnTimer
@onready var difficulty_timer: Timer  = $DifficultyTimer
@onready var pool:             Node2D = $ObstaclePool

# ── Obstacle Scene Paths ────────────────────────────────────────
const OBSTACLE_SCENES: Array[String] = [
    "res://scenes/obstacles/asteroid.tscn",
    "res://scenes/obstacles/comet.tscn",
    "res://scenes/obstacles/meteor.tscn",
    "res://scenes/obstacles/space_debris.tscn",
    "res://scenes/obstacles/stardust_cloud.tscn",
]

# ── ข้อมูล damage ของแต่ละ obstacle ───────────────────────────
const OBSTACLE_DAMAGE: Dictionary = {
    "asteroid":      30.0,
    "comet":         40.0,
    "meteor":        20.0,
    "space_debris":  15.0,
    "stardust_cloud": 8.0,
}

# ── Difficulty ─────────────────────────────────────────────────
var difficulty_level: int   = 1
var spawn_interval:   float = 1.8   # วินาที/ครั้ง

# ── พื้นที่ Spawn ──────────────────────────────────────────────
const SPAWN_Y_OFFSET: float = -180.0   # สูงขึ้น 50% จากเดิม (-120 → -180)
const SIDE_MARGIN:    float = 80.0
const SPAWN_MARGIN:   float = 80.0   # inset เพิ่มเพื่อไม่ให้ asteroid ใหญ่โผล่ขอบ
# ── Spawn bounds จาก ShipLayout (fraction ของ viewport) ──────
var _spawn_x_min_px: float = 80.0
var _spawn_x_max_px: float = 1840.0

# ──────────────────────────────────────────────────────────────
func _ready() -> void:
    # ── โหลด spawn bounds จาก ShipLayout ────────────────────
    var layout := ShipLayout.get_layout(GameManager.player_avatar)
    var vp_size := get_viewport_rect().size
    _spawn_x_min_px = vp_size.x * float(layout.get("spawn_x_min", 0.05)) + SPAWN_MARGIN
    _spawn_x_max_px = vp_size.x * float(layout.get("spawn_x_max", 0.95)) - SPAWN_MARGIN
    print("[ObstacleSpawner] spawn X bounds: %.0f – %.0f  (vp=%.0f)" % [_spawn_x_min_px, _spawn_x_max_px, vp_size.x])

    # ปรับ interval ตาม difficulty ของดาวที่เลือก
    var planet_diff: int = GameManager.selected_planet.get("difficulty", 1)
    spawn_interval = maxf(0.5, 1.8 - (planet_diff - 1) * 0.3)

    spawn_timer.wait_time = spawn_interval
    spawn_timer.timeout.connect(_spawn_wave)
    spawn_timer.start()

    difficulty_timer.wait_time = 45.0  # เพิ่มความยากทุก 45 วินาที
    difficulty_timer.timeout.connect(_increase_difficulty)
    difficulty_timer.start()

# ──────────────────────────────────────────────────────────────
func _spawn_wave() -> void:
    if not GameManager.is_game_running:
        return

    var count: int = difficulty_level + GameManager.selected_planet.get("difficulty", 1) - 1
    count = clampi(count, 1, 5)

    var vp_width: float = get_viewport_rect().size.x

    for i in count:
        var scene_path: String = OBSTACLE_SCENES[randi() % OBSTACLE_SCENES.size()]
        var ob: Node2D = load(scene_path).instantiate()

        # กระจาย spawn เฉพาะภายในช่องมองของ cockpit
        ob.position = Vector2(
            randf_range(_spawn_x_min_px, _spawn_x_max_px),
            SPAWN_Y_OFFSET - (i * 80.0)   # เหลื่อมกัน
        )

        # ตั้ง damage ให้ obstacle
        var ob_type: String = scene_path.get_file().get_basename()
        ob.set("damage", OBSTACLE_DAMAGE.get(ob_type, 20.0))

        # ความเร็วตาม difficulty
        var speed_mult: float = 1.0 + (difficulty_level - 1) * 0.15
        ob.set("speed_multiplier", speed_mult)

        # ส่ง bounds ให้ obstacle เพื่อ clamp drift
        ob.set("clamp_x_min", _spawn_x_min_px)
        ob.set("clamp_x_max", _spawn_x_max_px)
        ob.add_to_group("obstacles")
        pool.add_child(ob)

# ──────────────────────────────────────────────────────────────
func _increase_difficulty() -> void:
    difficulty_level = mini(difficulty_level + 1, 6)
    spawn_interval   = maxf(0.35, spawn_interval - 0.15)
    spawn_timer.wait_time = spawn_interval

# ──────────────────────────────────────────────────────────────
func pause_spawning() -> void:
    spawn_timer.paused     = true
    difficulty_timer.paused = true

func resume_spawning() -> void:
    spawn_timer.paused     = false
    difficulty_timer.paused = false
