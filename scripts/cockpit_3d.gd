extends Node3D
# ==============================================================
#  cockpit_3d.gd  —  3D First-Person Cockpit Controller
#
#  กล้อง (ยาน) เคลื่อนที่ไปข้างหน้าตาม -Z ตลอดเวลา
#  อุกกาบาตอยู่คงที่ในโลก  ผู้เล่นหลบด้วยการเลี้ยวซ้าย/ขวา
#  Cockpit 3D จาก Blender (spaceship.glb) เชื่อมกับ game state
# ==============================================================

signal quiz_triggered
signal shield_changed(active: bool)

# ── Field ────────────────────────────────────────────────────────
const SPAWN_AHEAD      := 80.0    # มองเห็นล่วงหน้า ~2–3 แถว (แถวห่างขึ้นแล้ว)
const KILL_BEHIND      :=  6.0
const HIT_DEPTH        :=  2.5
const HIT_RADIUS_BASE  :=  2.0

const SPREAD_X         :=  8.0    # กว้างเท่า STEER_RANGE → ครอบคลุมเต็มสนาม
const SPREAD_Y_MIN     := -2.2
const SPREAD_Y_MAX     :=  3.2

# ── Cockpit viewport zone ─────────────────────────────────────────
# spawn เฉพาะในกรอบมองเห็นของ cockpit
const ZONE_MID_MIN     :=  0.4    # ใกล้ระดับกล้อง (CAM_Y 1.2) → ชนได้จริง
const ZONE_MID_MAX     :=  2.0
const FPS_PITCH_DEG    := -18.0   # ก้มกล้อง → เส้นขอบฟ้าอยู่กลางช่องมอง (~30% จากบนจอ) ไม่ถูก dashboard บัง

const PREPOPULATE_COUNT  :=  0    # no pre-spawn — start with clear space

# ── Spawn intervals (difficulty-scaled) ──────────────────────────
# ถี่ขึ้นเพื่อให้มีหลายแถวข้างหน้า → เกิด pattern หลบแบบ weaving
const MID_INTERVAL_BASE_MIN := 1.20  # difficulty 1 → 3-4 แถวข้างหน้า
const MID_INTERVAL_BASE_MAX := 1.80
const MID_INTERVAL_HARD_MIN := 0.50  # difficulty 5 → 7-10 แถวข้างหน้า
const MID_INTERVAL_HARD_MAX := 0.80

# ── Spawn count per wave ──────────────────────────────────────────
const WAVE_COUNT_MIN    :=  1    # 1–2 ก้อนต่อแถว (เหลือช่องให้ลอดผ่าน)
const WAVE_COUNT_MAX    :=  2

# ── Row / Bar spawn system (ตาม top-view design) ─────────────────
# สนามคือเลนกว้าง ±LANE_HALF (= ขอบที่ยานเลี้ยวไปได้สุด)
# อุกกาบาตเกิดเป็น "แถว" ตามแกน Z ทุก ๆ ROW_GAP หน่วย
# แต่ละแถวมี 1–2 "แท่ง" (bar) = อุกกาบาตหลายก้อนเรียงเป็นกำแพงแนวนอน
# ทุกแถวรับประกันว่ามี "ทางรอด" (safe corridor) ที่เลี้ยวไปทันเสมอ
const LANE_HALF          := 8.0     # = STEER_RANGE (ขอบซ้าย/ขวาสุดที่ยานไปได้)
const ROW_GAP_EASY       := 48.0    # ระยะห่างแถว (difficulty 1) — ห่างขึ้น 2 เท่า = spawn น้อยลงครึ่งหนึ่ง
const ROW_GAP_HARD       := 28.0    # ระยะห่างแถว (difficulty 5)
const SAFE_HALF_EASY     := 1.70    # ครึ่งความกว้างทางรอด (easy)
const SAFE_HALF_HARD     := 1.20    # ครึ่งความกว้างทางรอด (hard)
const BAR_W_MIN_EASY     := 0.20    # ความกว้าง bar เป็นสัดส่วนของเลน
const BAR_W_MAX_EASY     := 0.35
const BAR_W_MIN_HARD     := 0.25
const BAR_W_MAX_HARD     := 0.48
const BAR_W_SHORT        := 0.15    # bar สั้น (ใช้ในแถวคู่)
const DOUBLE_CHANCE_EASY := 0.20    # โอกาสแถวที่มี 2 bar
const DOUBLE_CHANCE_HARD := 0.45
const BAR_STEP           := 1.10    # ระยะห่างก้อนใน bar
const BAR_Y              := 1.2     # = CAM_Y → อยู่บนเส้นขอบฟ้า กลางช่องมองพอดี
const BAR_DEPTH          := 1.0     # ความหนา hitbox ตามแกน Z
const SHIP_HALF_W        := 0.70    # ครึ่งความกว้าง hitbox ยาน
const ITEM_CHANCE        := 0.35    # โอกาสมี item อยู่บนทางรอด
const ITEM_EMISSION      := 0.6     # ความเรืองแสงของผิว item (เดิม 5.0)
const ITEM_LIGHT_ENERGY  := 1.2     # ความสว่างไฟรอบ item (เดิม 8.0)
const ITEM_PICKUP_R      := 1.80    # รัศมีเก็บ item (แกน X) — ขยายตาม item ที่ใหญ่ขึ้น 3 เท่า
const STEER_SAFETY       := 0.65    # เผื่อเวลาเลี้ยว (0–1)

# ── Movement ─────────────────────────────────────────────────────
const STEER_RANGE     :=  8.0
const STEER_SPEED     := 12.0
const CAM_Y           :=  1.2

const FLY_SPEED_BASE  := 18.0   # (legacy — ใช้ _fly_speed() แทน)
const FLY_SPEED_BOOST := 32.0
# ── ความเร็วยานตามระดับความยาก (ยานบินไปข้างหน้าเอง) ─────────────
const FLY_SPEED_EASY  := 14.0   # difficulty 1
const FLY_SPEED_HARD  := 26.0   # difficulty 5
const BOOST_MULT      := 1.75   # BOOST = ความเร็วปกติ × 1.75
const BOOST_DRAIN     := 20.0
const ENERGY_REGEN    :=  6.0    # energy per second when not boosting

# ── Obstacle type weights ─────────────────────────────────────────
const TYPE_WEIGHTS := {
    "threat": 0.55,
    "quiz":   0.15,
    "shield": 0.12,
    "energy": 0.10,
    "score":  0.08,
}

const TINT_COLORS := {
    "threat": Color(1.00, 0.55, 0.30),
    "quiz":   Color(0.30, 0.70, 1.00),
    "shield": Color(0.55, 0.30, 1.00),
    "energy": Color(0.15, 1.00, 0.55),
    "score":  Color(1.00, 0.88, 0.20),
}

# ── Ship cockpit constants ────────────────────────────────────────
# ตำแหน่งยาน relative to camera (camera child) — ปรับตรงนี้เพื่อ frame cockpit
const SHIP_SCALE  := 0.60
const SHIP_OFFSET := Vector3(0.0, -0.76, 0.0)

# ── Powerup 3D model mapping ──────────────────────────────────────
# เมื่อ spawn type ≠ threat ให้ใช้ GLB โมเดลจริง แทนก้อนหินสีทา
const TYPE_TO_POWERUP_MODEL: Dictionary = {
    "quiz":   "mystery_box",
    "shield": "roman_shield",
    "energy": "energy_tank",
    "score":  "star",
}
# สเกลในโลก 3D สำหรับแต่ละโมเดล (พอดีให้เห็นชัด + hit-box สมเหตุสมผล)
const POWERUP_SCALE_3D: Dictionary = {
    "mystery_box":  3.30,
    "roman_shield": 3.00,
    "energy_tank":  3.30,
    "star":         2.70,
}
# ── Capsule GLB (ใหม่) — ถ้ามีไฟล์จะใช้แทนโมเดลเดิมอัตโนมัติ ─────
# ใช้วัสดุจาก Blender ตามเดิม (ไม่ทาสีทับ) และปรับขนาดให้สูง CAPSULE_HEIGHT
const TYPE_TO_CAPSULE_MODEL: Dictionary = {
    "quiz":   "quiz_capsule",
    "shield": "shield_capsule",
    "energy": "energy_capsule",
    "score":  "star_capsule",
}
const CAPSULE_HEIGHT := 2.0    # ความสูงในโลก 3D (≈ 3 เท่าของ item เดิม)
const CAPSULE_LIGHT_COLOR: Dictionary = {
    "quiz_capsule":   Color(0.70, 0.35, 1.00),   # ม่วง
    "shield_capsule": Color(0.35, 0.70, 1.00),   # ฟ้า
    "energy_capsule": Color(1.00, 0.85, 0.25),   # เหลือง
    "star_capsule":   Color(1.00, 0.80, 0.20),   # ทอง
}

# สีแสงเรืองรองของแต่ละ powerup (emissive + OmniLight)
const POWERUP_GLOW_COLOR: Dictionary = {
    "mystery_box":  Color(0.30, 0.70, 1.00),   # ฟ้า — quiz
    "roman_shield": Color(0.60, 0.25, 1.00),   # ม่วง — shield
    "energy_tank":  Color(0.10, 1.00, 0.55),   # เขียว — energy
    "star":         Color(1.00, 0.88, 0.15),   # ทอง — score
}

# gauge needle rotation range (radians) — ซ้ายสุด=0%  ขวาสุด=100%
const NEEDLE_MIN_ANGLE := -0.75   # radians (≈ -43°)
const NEEDLE_MAX_ANGLE :=  0.75   # radians (≈ +43°)

# ── Node refs ─────────────────────────────────────────────────────
@onready var camera:      Camera3D = $Camera3D
@onready var meteor_root: Node3D   = $MeteoriteRoot

# ── State ─────────────────────────────────────────────────────────
var quiz_active:    bool  = false
var _shield_active: bool  = false

var _spawn_timer:   float = 0.0   # middle zone timer
var _next_interval: float = 1.5   # set properly in _ready after difficulty read
var _deco_timer:    float = 0.0   # decorative (top/bottom) zone timer
var _deco_next:     float = 0.35
var _next_row_z:    float = -SPAWN_AHEAD   # Z ของแถวถัดไปที่จะ spawn
var _path_x:        float = 0.0            # กลางทางรอดของแถวล่าสุด
var _prev_cam_z:    float = 0.0            # กันทะลุ hitbox ตอน fps ต่ำ

var _active_meteors: Array[Node3D] = []
var _glb:      PackedScene = null
var _ship_glb: PackedScene = null
var _powerup_packed: Dictionary = {}   # model_id → PackedScene

# ── Zone system ───────────────────────────────────────────────────
var _zone_idx:        int              = 0
var _zone_pitch:      float            = 0.0
var _zone_roll_extra: float            = 0.0   # wormhole oscillation offset
var _zone_roll_acc:   float            = 0.0   # accumulator for sin oscillation
var _env:             Environment      = null
var _we:              WorldEnvironment = null
# ── Background scene ──────────────────────────────────────────────
var _star_root: Node3D         = null
var _bg_planet: MeshInstance3D = null

# ยาน 3 แบบ: avatar 0 = Rocket (spaceship.glb), 1 = UFO (ufo.glb), 2 = Comet (ship_comet.glb)
const COMET_SHIP_PATH := "res://assets/models/ship_comet.glb"
var _is_ufo:     bool = false
var _is_special: bool = false

# Ship cockpit node refs (populated after GLB instantiate)
var _ship_node:        Node3D         = null
# ── Rocket-specific refs ────────────────────────────────────────────────
var _needle_hp:        Node3D         = null
var _needle_energy:    Node3D         = null
var _progress_fill:    Node3D         = null
var _screen_shield:    MeshInstance3D = null
var _thruster_l:       MeshInstance3D = null
var _thruster_r:       MeshInstance3D = null
var _btn_boost:        Node3D         = null
var _btn_left:         Node3D         = null
var _btn_right:        Node3D         = null
# ── UFO-specific refs ──────────────────────────────────────────────────
var _ufo_hp_gauge:     MeshInstance3D = null   # UFO_HPGauge
var _ufo_eng_gauge:    MeshInstance3D = null   # UFO_EnergyGauge
var _ufo_progress:     Node3D         = null   # UFO_MissionProgressBar
var _ufo_shield:       MeshInstance3D = null   # UFO_ShieldScreen
var _ufo_engine:       MeshInstance3D = null   # UFO_EngineGlow
var _ufo_btn_boost:    Node3D         = null   # UFO_BoostButton
var _ufo_btn_left:     Node3D         = null   # UFO_TurnLeftButton
var _ufo_btn_right:    Node3D         = null   # UFO_TurnRightButton
# ── Special-specific refs ──────────────────────────────────────────────
var _spc_hp_gauge:     MeshInstance3D = null   # Special_HPGauge
var _spc_eng_gauge:    MeshInstance3D = null   # Special_EnergyGauge
var _spc_progress:     Node3D         = null   # Special_MissionProgressBar
var _spc_shield:       MeshInstance3D = null   # Special_ShieldScreen
var _spc_nozzle_l:     MeshInstance3D = null   # Special_EngineNozzleL
var _spc_nozzle_r:     MeshInstance3D = null   # Special_EngineNozzleR
var _spc_btn_boost:    Node3D         = null   # Special_BoostButton
var _spc_btn_left:     Node3D         = null   # Special_TurnLeftButton
var _spc_btn_right:    Node3D         = null   # Special_TurnRightButton

# Cached "rest" positions for button press offset
var _btn_boost_rest_y:  float = 0.0
var _btn_left_rest_y:   float = 0.0
var _btn_right_rest_y:  float = 0.0
var _fill_rest_x:       float = 0.0
var _fill_half_width:   float = 0.0

# Materials for live updates (Rocket)
var _mat_thruster_l: StandardMaterial3D = null
var _mat_thruster_r: StandardMaterial3D = null
var _mat_shield:     StandardMaterial3D = null
# Materials for live updates (UFO)
var _mat_ufo_hp:     StandardMaterial3D = null
var _mat_ufo_energy: StandardMaterial3D = null
var _mat_ufo_shield: StandardMaterial3D = null
var _mat_ufo_engine: StandardMaterial3D = null
# Materials for live updates (Special)
var _mat_spc_hp:       StandardMaterial3D = null
var _mat_spc_energy:   StandardMaterial3D = null
var _mat_spc_shield:   StandardMaterial3D = null
var _mat_spc_nozzle_l: StandardMaterial3D = null
var _mat_spc_nozzle_r: StandardMaterial3D = null

# ── Ready ──────────────────────────────────────────────────────────
func _ready() -> void:
    _glb      = load("res://assets/models/meteorites.glb")
    # เลือกโมเดลยานตาม avatar (0=Rocket, 1=UFO, 2=Special)
    var _avatar := GameManager.player_avatar
    _is_ufo     = (_avatar == 1)
    _is_special = (_avatar == 2)
    var ship_path: String
    match _avatar:
        1: ship_path = "res://assets/models/ufo.glb"
        2: ship_path = COMET_SHIP_PATH if ResourceLoader.exists(COMET_SHIP_PATH) else "res://assets/models/star.glb"
        _: ship_path = "res://assets/models/spaceship.glb"
    _ship_glb  = load(ship_path)
    # โหลด powerup GLBs (energy_tank / mystery_box / roman_shield / star)
    for model_id: String in TYPE_TO_POWERUP_MODEL.values():
        var path := "res://assets/models/powerups/%s.glb" % model_id
        if ResourceLoader.exists(path):
            _powerup_packed[model_id] = load(path)
        else:
            push_warning("cockpit_3d: powerup GLB missing: %s" % path)
    for model_id: String in TYPE_TO_CAPSULE_MODEL.values():
        var cpath := "res://assets/models/powerups/%s.glb" % model_id
        if ResourceLoader.exists(cpath):
            _powerup_packed[model_id] = load(cpath)
    camera.position = Vector3(0.0, CAM_Y, 0.0)
    _next_interval  = randf_range(_mid_interval_min(), _mid_interval_max())
    _spawn_cockpit_ship()
    _register_keyboard_inputs()
    _apply_camera_mode()
    _setup_nebula_sky()
    _setup_starfield()
    _setup_bg_planets()
    _build_route()
    _update_route(0.0)
    _prepopulate_asteroids()

# ────────────────────────────────────────────────────────────────
# COCKPIT SHIP SETUP
# ────────────────────────────────────────────────────────────────

func _spawn_cockpit_ship() -> void:
    if _ship_glb == null:
        push_warning("cockpit_3d: spaceship.glb not found")
        return

    _ship_node = _ship_glb.instantiate() as Node3D
    _ship_node.scale    = Vector3.ONE * SHIP_SCALE
    _ship_node.position = SHIP_OFFSET
    camera.add_child(_ship_node)   # ship เป็น child ของ camera → เคลื่อนที่ตามกล้อง

    _cache_ship_nodes()
    _setup_ship_materials()

func _cache_ship_nodes() -> void:
    if _is_ufo:
        # ── UFO node names ───────────────────────────────────────────────
        _ufo_hp_gauge   = _ship_node.find_child("UFO_HPGauge",            true, false) as MeshInstance3D
        _ufo_eng_gauge  = _ship_node.find_child("UFO_EnergyGauge",        true, false) as MeshInstance3D
        _ufo_progress   = _ship_node.find_child("UFO_MissionProgressBar", true, false)
        _ufo_shield     = _ship_node.find_child("UFO_ShieldScreen",       true, false) as MeshInstance3D
        _ufo_engine     = _ship_node.find_child("UFO_EngineGlow",         true, false) as MeshInstance3D
        _ufo_btn_boost  = _ship_node.find_child("UFO_BoostButton",        true, false)
        _ufo_btn_left   = _ship_node.find_child("UFO_TurnLeftButton",     true, false)
        _ufo_btn_right  = _ship_node.find_child("UFO_TurnRightButton",    true, false)
        # Cache rest positions (reuse same float vars)
        if _ufo_btn_boost:  _btn_boost_rest_y = _ufo_btn_boost.position.y
        if _ufo_btn_left:   _btn_left_rest_y  = _ufo_btn_left.position.y
        if _ufo_btn_right:  _btn_right_rest_y = _ufo_btn_right.position.y
        if _ufo_progress:
            _fill_rest_x     = _ufo_progress.position.x
            _fill_half_width = _ufo_progress.scale.x * 0.155
    elif _is_special:
        # ── Special (star.glb) node names ────────────────────────────────
        _spc_hp_gauge   = _ship_node.find_child("Special_HPGauge",            true, false) as MeshInstance3D
        _spc_eng_gauge  = _ship_node.find_child("Special_EnergyGauge",        true, false) as MeshInstance3D
        _spc_progress   = _ship_node.find_child("Special_MissionProgressBar", true, false)
        _spc_shield     = _ship_node.find_child("Special_ShieldScreen",       true, false) as MeshInstance3D
        _spc_nozzle_l   = _ship_node.find_child("Special_EngineNozzleL",      true, false) as MeshInstance3D
        _spc_nozzle_r   = _ship_node.find_child("Special_EngineNozzleR",      true, false) as MeshInstance3D
        _spc_btn_boost  = _ship_node.find_child("Special_BoostButton",        true, false)
        _spc_btn_left   = _ship_node.find_child("Special_TurnLeftButton",     true, false)
        _spc_btn_right  = _ship_node.find_child("Special_TurnRightButton",    true, false)
        if _spc_btn_boost:  _btn_boost_rest_y = _spc_btn_boost.position.y
        if _spc_btn_left:   _btn_left_rest_y  = _spc_btn_left.position.y
        if _spc_btn_right:  _btn_right_rest_y = _spc_btn_right.position.y
        if _spc_progress:
            _fill_rest_x     = _spc_progress.position.x
            _fill_half_width = _spc_progress.scale.x * 0.155
    else:
        # ── Rocket (spaceship.glb) node names ───────────────────────────
        _needle_hp     = _ship_node.find_child("Gauge_HP_Needle",          true, false)
        _needle_energy = _ship_node.find_child("Gauge_Energy_Needle",      true, false)
        _progress_fill = _ship_node.find_child("ProgressBar_Mission_Fill", true, false)
        _screen_shield = _ship_node.find_child("Screen_ShieldReady",       true, false) as MeshInstance3D
        _thruster_l    = _ship_node.find_child("ThrusterGlow_L",           true, false) as MeshInstance3D
        _thruster_r    = _ship_node.find_child("ThrusterGlow_R",           true, false) as MeshInstance3D
        _btn_boost     = _ship_node.find_child("Button_Boost",             true, false)
        _btn_left      = _ship_node.find_child("Button_TurnLeft",          true, false)
        _btn_right     = _ship_node.find_child("Button_TurnRight",         true, false)
        if _btn_boost:  _btn_boost_rest_y  = _btn_boost.position.y
        if _btn_left:   _btn_left_rest_y   = _btn_left.position.y
        if _btn_right:  _btn_right_rest_y  = _btn_right.position.y
        if _progress_fill:
            _fill_rest_x     = _progress_fill.position.x
            _fill_half_width = _progress_fill.scale.x * 0.155

func _setup_ship_materials() -> void:
    if _is_ufo:
        # ── UFO materials ─────────────────────────────────────────────────
        # HP Gauge face — glow color changes green→red with HP level
        _mat_ufo_hp = StandardMaterial3D.new()
        _mat_ufo_hp.albedo_color              = Color(0.95, 0.95, 0.90)
        _mat_ufo_hp.emission_enabled          = true
        _mat_ufo_hp.emission                  = Color(0.2, 1.0, 0.3)
        _mat_ufo_hp.emission_energy_multiplier = 2.0
        if _ufo_hp_gauge: _ufo_hp_gauge.material_override = _mat_ufo_hp

        # Energy Gauge face — glow color changes cyan→dim with energy level
        _mat_ufo_energy = StandardMaterial3D.new()
        _mat_ufo_energy.albedo_color              = Color(0.92, 0.95, 0.98)
        _mat_ufo_energy.emission_enabled          = true
        _mat_ufo_energy.emission                  = Color(0.1, 0.7, 1.0)
        _mat_ufo_energy.emission_energy_multiplier = 2.0
        if _ufo_eng_gauge: _ufo_eng_gauge.material_override = _mat_ufo_energy

        # Shield screen — green ready / red inactive
        _mat_ufo_shield = StandardMaterial3D.new()
        _mat_ufo_shield.albedo_color              = Color(0.02, 0.06, 0.12)
        _mat_ufo_shield.emission_enabled          = true
        _mat_ufo_shield.emission                  = Color(0.15, 0.15, 0.15)
        _mat_ufo_shield.emission_energy_multiplier = 0.4
        if _ufo_shield: _ufo_shield.material_override = _mat_ufo_shield

        # Engine glow — single cyan plasma disc
        _mat_ufo_engine = StandardMaterial3D.new()
        _mat_ufo_engine.albedo_color              = Color(0.2, 0.9, 1.0, 0.9)
        _mat_ufo_engine.emission_enabled          = true
        _mat_ufo_engine.emission                  = Color(0.1, 0.85, 1.0)
        _mat_ufo_engine.emission_energy_multiplier = 5.0
        _mat_ufo_engine.transparency              = BaseMaterial3D.TRANSPARENCY_ALPHA
        if _ufo_engine: _ufo_engine.material_override = _mat_ufo_engine
    elif _is_special:
        # ── Special (star.glb) materials ─────────────────────────────────
        # HP gauge — green at full health, changes at runtime
        _mat_spc_hp = StandardMaterial3D.new()
        _mat_spc_hp.albedo_color               = Color(0.1, 0.95, 0.5)
        _mat_spc_hp.emission_enabled           = true
        _mat_spc_hp.emission                   = Color(0.1, 1.0, 0.4)
        _mat_spc_hp.emission_energy_multiplier = 6.0
        if _spc_hp_gauge: _spc_hp_gauge.material_override = _mat_spc_hp

        # Energy gauge — bright cyan at full energy
        _mat_spc_energy = StandardMaterial3D.new()
        _mat_spc_energy.albedo_color               = Color(0.0, 0.85, 1.0)
        _mat_spc_energy.emission_enabled           = true
        _mat_spc_energy.emission                   = Color(0.0, 0.9, 1.0)
        _mat_spc_energy.emission_energy_multiplier = 6.0
        if _spc_eng_gauge: _spc_eng_gauge.material_override = _mat_spc_energy

        # Shield screen — dim until activated
        _mat_spc_shield = StandardMaterial3D.new()
        _mat_spc_shield.albedo_color               = Color(0.02, 0.03, 0.05)
        _mat_spc_shield.emission_enabled           = true
        _mat_spc_shield.emission                   = Color(0.15, 0.15, 0.15)
        _mat_spc_shield.emission_energy_multiplier = 0.4
        if _spc_shield: _spc_shield.material_override = _mat_spc_shield

        # Engine nozzles — white-hot glow (both L+R share similar material)
        _mat_spc_nozzle_l = StandardMaterial3D.new()
        _mat_spc_nozzle_l.albedo_color               = Color(0.95, 0.97, 1.0, 0.9)
        _mat_spc_nozzle_l.emission_enabled           = true
        _mat_spc_nozzle_l.emission                   = Color(1.0, 1.0, 1.0)
        _mat_spc_nozzle_l.emission_energy_multiplier = 8.0
        _mat_spc_nozzle_l.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
        _mat_spc_nozzle_r = _mat_spc_nozzle_l.duplicate() as StandardMaterial3D
        if _spc_nozzle_l: _spc_nozzle_l.material_override = _mat_spc_nozzle_l
        if _spc_nozzle_r: _spc_nozzle_r.material_override = _mat_spc_nozzle_r
    else:
        # ── Rocket (spaceship.glb) materials ─────────────────────────────
        var t_mat := StandardMaterial3D.new()
        t_mat.albedo_color              = Color(0.45, 0.70, 1.0, 0.9)
        t_mat.emission_enabled          = true
        t_mat.emission                  = Color(0.30, 0.60, 1.0)
        t_mat.emission_energy_multiplier = 1.5
        t_mat.transparency              = BaseMaterial3D.TRANSPARENCY_ALPHA
        _mat_thruster_l = t_mat
        _mat_thruster_r = t_mat.duplicate() as StandardMaterial3D
        if _thruster_l: _thruster_l.material_override = _mat_thruster_l
        if _thruster_r: _thruster_r.material_override = _mat_thruster_r

        var s_mat := StandardMaterial3D.new()
        s_mat.albedo_color              = Color(0.10, 0.10, 0.10)
        s_mat.emission_enabled          = true
        s_mat.emission                  = Color(0.15, 0.15, 0.15)
        s_mat.emission_energy_multiplier = 0.4
        _mat_shield = s_mat
        if _screen_shield: _screen_shield.material_override = _mat_shield

# ────────────────────────────────────────────────────────────────
# COCKPIT UPDATE (every frame)
# ────────────────────────────────────────────────────────────────

func _update_ship_cockpit(delta: float) -> void:
    if _ship_node == null or not _ship_node.visible:
        return   # ไม่ต้องอัปเดต animation เมื่อ ship ซ่อนอยู่ (FPS mode)

    var hp_pct   := GameManager.current_hp     / 100.0
    var eng_pct  := GameManager.current_energy / 100.0
    var progress := clampf(GameManager.journey_progress, 0.0, 1.0)
    var boosting := TouchInput.is_boosting and GameManager.current_energy > 0.0

    if _is_ufo:
        # ── UFO: gauge faces change emission color to indicate level ──────
        if _mat_ufo_hp:
            # HP: green (full) → yellow → red (critical)
            var hp_col: Color
            if hp_pct > 0.5:
                hp_col = Color(0.2, 1.0, 0.3).lerp(Color(1.0, 0.85, 0.0), 1.0 - (hp_pct - 0.5) * 2.0)
            else:
                hp_col = Color(1.0, 0.85, 0.0).lerp(Color(1.0, 0.08, 0.05), 1.0 - hp_pct * 2.0)
            _mat_ufo_hp.emission = _mat_ufo_hp.emission.lerp(hp_col, delta * 4.0)
            var hp_intensity := lerpf(1.0, 3.5, hp_pct)
            _mat_ufo_hp.emission_energy_multiplier = lerpf(
                _mat_ufo_hp.emission_energy_multiplier, hp_intensity, delta * 4.0)

        if _mat_ufo_energy:
            # Energy: bright cyan (full) → dim grey (empty)
            var eng_col := Color(0.05, 0.15, 0.2).lerp(Color(0.1, 0.7, 1.0), eng_pct)
            _mat_ufo_energy.emission = _mat_ufo_energy.emission.lerp(eng_col, delta * 4.0)
            var eng_intensity := lerpf(0.2, 3.0, eng_pct)
            _mat_ufo_energy.emission_energy_multiplier = lerpf(
                _mat_ufo_energy.emission_energy_multiplier, eng_intensity, delta * 4.0)

        # ── UFO: mission progress bar scale ──────────────────────────────
        if _ufo_progress:
            var target_sx := maxf(0.01, progress)
            _ufo_progress.scale.x = lerpf(_ufo_progress.scale.x, target_sx, delta * 3.0)
            _ufo_progress.position.x = _fill_rest_x - _fill_half_width * (1.0 - _ufo_progress.scale.x)

        # ── UFO: engine glow ─────────────────────────────────────────────
        if _mat_ufo_engine:
            var eng_boost := 12.0 if boosting else 5.0
            _mat_ufo_engine.emission_energy_multiplier = lerpf(
                _mat_ufo_engine.emission_energy_multiplier, eng_boost, delta * 8.0)

        # ── UFO: shield screen ───────────────────────────────────────────
        if _mat_ufo_shield:
            var target_emit := Color(0.20, 0.90, 0.50) if _shield_active else Color(0.50, 0.10, 0.10)
            var target_energy := 3.0 if _shield_active else 0.4
            _mat_ufo_shield.emission = _mat_ufo_shield.emission.lerp(target_emit, delta * 5.0)
            _mat_ufo_shield.emission_energy_multiplier = lerpf(
                _mat_ufo_shield.emission_energy_multiplier, target_energy, delta * 5.0)

        # ── UFO: button press animations ─────────────────────────────────
        if _ufo_btn_boost:
            var ty := _btn_boost_rest_y - 0.006 if boosting else _btn_boost_rest_y
            _ufo_btn_boost.position.y = lerpf(_ufo_btn_boost.position.y, ty, delta * 25.0)
        if _ufo_btn_left:
            var ty := _btn_left_rest_y - 0.006 if TouchInput.is_steering_left else _btn_left_rest_y
            _ufo_btn_left.position.y = lerpf(_ufo_btn_left.position.y, ty, delta * 25.0)
        if _ufo_btn_right:
            var ty := _btn_right_rest_y - 0.006 if TouchInput.is_steering_right else _btn_right_rest_y
            _ufo_btn_right.position.y = lerpf(_ufo_btn_right.position.y, ty, delta * 25.0)
    elif _is_special:
        # ── Special: gauge faces change emission color like UFO ────────────
        if _mat_spc_hp:
            var hp_col: Color
            if hp_pct > 0.5:
                hp_col = Color(0.2, 1.0, 0.3).lerp(Color(1.0, 0.85, 0.0), 1.0 - (hp_pct - 0.5) * 2.0)
            else:
                hp_col = Color(1.0, 0.85, 0.0).lerp(Color(1.0, 0.08, 0.05), 1.0 - hp_pct * 2.0)
            _mat_spc_hp.emission = _mat_spc_hp.emission.lerp(hp_col, delta * 4.0)
            var hp_intensity := lerpf(1.0, 6.0, hp_pct)
            _mat_spc_hp.emission_energy_multiplier = lerpf(
                _mat_spc_hp.emission_energy_multiplier, hp_intensity, delta * 4.0)

        if _mat_spc_energy:
            var eng_col := Color(0.05, 0.15, 0.2).lerp(Color(0.0, 0.9, 1.0), eng_pct)
            _mat_spc_energy.emission = _mat_spc_energy.emission.lerp(eng_col, delta * 4.0)
            var eng_intensity := lerpf(0.2, 6.0, eng_pct)
            _mat_spc_energy.emission_energy_multiplier = lerpf(
                _mat_spc_energy.emission_energy_multiplier, eng_intensity, delta * 4.0)

        # ── Special: mission progress bar ─────────────────────────────────
        if _spc_progress:
            var target_sx := maxf(0.01, progress)
            _spc_progress.scale.x = lerpf(_spc_progress.scale.x, target_sx, delta * 3.0)
            _spc_progress.position.x = _fill_rest_x - _fill_half_width * (1.0 - _spc_progress.scale.x)

        # ── Special: engine nozzle glow (white — pulses brighter when boosting) ──
        var nozzle_energy := 16.0 if boosting else 8.0
        if _mat_spc_nozzle_l:
            _mat_spc_nozzle_l.emission_energy_multiplier = lerpf(
                _mat_spc_nozzle_l.emission_energy_multiplier, nozzle_energy, delta * 8.0)
        if _mat_spc_nozzle_r:
            _mat_spc_nozzle_r.emission_energy_multiplier = lerpf(
                _mat_spc_nozzle_r.emission_energy_multiplier, nozzle_energy, delta * 8.0)

        # ── Special: shield screen ─────────────────────────────────────────
        if _mat_spc_shield:
            var target_emit := Color(0.20, 0.90, 0.50) if _shield_active else Color(0.50, 0.10, 0.10)
            var target_energy := 3.0 if _shield_active else 0.4
            _mat_spc_shield.emission = _mat_spc_shield.emission.lerp(target_emit, delta * 5.0)
            _mat_spc_shield.emission_energy_multiplier = lerpf(
                _mat_spc_shield.emission_energy_multiplier, target_energy, delta * 5.0)

        # ── Special: button press animations ──────────────────────────────
        if _spc_btn_boost:
            var ty := _btn_boost_rest_y - 0.006 if boosting else _btn_boost_rest_y
            _spc_btn_boost.position.y = lerpf(_spc_btn_boost.position.y, ty, delta * 25.0)
        if _spc_btn_left:
            var ty := _btn_left_rest_y - 0.006 if TouchInput.is_steering_left else _btn_left_rest_y
            _spc_btn_left.position.y = lerpf(_spc_btn_left.position.y, ty, delta * 25.0)
        if _spc_btn_right:
            var ty := _btn_right_rest_y - 0.006 if TouchInput.is_steering_right else _btn_right_rest_y
            _spc_btn_right.position.y = lerpf(_spc_btn_right.position.y, ty, delta * 25.0)
    else:
        # ── Rocket: gauge needles (rotate Z) ─────────────────────────────
        if _needle_hp:
            var target := lerpf(NEEDLE_MIN_ANGLE, NEEDLE_MAX_ANGLE, hp_pct)
            _needle_hp.rotation.z = lerpf(_needle_hp.rotation.z, target, delta * 6.0)
        if _needle_energy:
            var target := lerpf(NEEDLE_MIN_ANGLE, NEEDLE_MAX_ANGLE, eng_pct)
            _needle_energy.rotation.z = lerpf(_needle_energy.rotation.z, target, delta * 6.0)

        # ── Rocket: mission progress fill ─────────────────────────────────
        if _progress_fill:
            var target_sx := maxf(0.01, progress)
            _progress_fill.scale.x = lerpf(_progress_fill.scale.x, target_sx, delta * 3.0)
            _progress_fill.position.x = _fill_rest_x - _fill_half_width * (1.0 - _progress_fill.scale.x)

        # ── Rocket: thruster glow ─────────────────────────────────────────
        var thruster_energy := 4.0 if boosting else 1.5
        if _mat_thruster_l:
            _mat_thruster_l.emission_energy_multiplier = lerpf(
                _mat_thruster_l.emission_energy_multiplier, thruster_energy, delta * 8.0)
        if _mat_thruster_r:
            _mat_thruster_r.emission_energy_multiplier = lerpf(
                _mat_thruster_r.emission_energy_multiplier, thruster_energy, delta * 8.0)

        # ── Rocket: shield screen ─────────────────────────────────────────
        if _mat_shield:
            var target_emit := Color(0.20, 0.90, 0.50) if _shield_active else Color(0.50, 0.10, 0.10)
            var target_energy := 3.0 if _shield_active else 0.4
            _mat_shield.emission = _mat_shield.emission.lerp(target_emit, delta * 5.0)
            _mat_shield.emission_energy_multiplier = lerpf(
                _mat_shield.emission_energy_multiplier, target_energy, delta * 5.0)

        # ── Rocket: button press animations ──────────────────────────────
        if _btn_boost:
            var ty := _btn_boost_rest_y - 0.006 if boosting else _btn_boost_rest_y
            _btn_boost.position.y = lerpf(_btn_boost.position.y, ty, delta * 25.0)
        if _btn_left:
            var ty := _btn_left_rest_y - 0.006 if TouchInput.is_steering_left else _btn_left_rest_y
            _btn_left.position.y = lerpf(_btn_left.position.y, ty, delta * 25.0)
        if _btn_right:
            var ty := _btn_right_rest_y - 0.006 if TouchInput.is_steering_right else _btn_right_rest_y
            _btn_right.position.y = lerpf(_btn_right.position.y, ty, delta * 25.0)

# ────────────────────────────────────────────────────────────────
# PROCESS
# ────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
    if not GameManager.is_game_running:
        return
    _handle_steering(delta)
    _move_ship(delta)
    _update_meteors(delta)
    _tick_spawn(delta)
    _update_ship_cockpit(delta)
    _update_zone(delta)
    _update_route(delta)

func _move_ship(delta: float) -> void:
    var boosting := TouchInput.is_boosting and GameManager.current_energy > 0.0
    var spd: float = _fly_speed() * (BOOST_MULT if boosting else 1.0)
    camera.position.z -= spd * delta
    if boosting:
        GameManager.use_energy(BOOST_DRAIN * delta)
    elif GameManager.current_energy < 100.0:
        GameManager.restore_energy(ENERGY_REGEN * delta)

# ความเร็วบินปกติ: ตามความยากของดาว + เร่งขึ้นเล็กน้อยตามความคืบหน้า (สูงสุด +30%)
func _fly_speed() -> float:
    return lerpf(FLY_SPEED_EASY, FLY_SPEED_HARD, _diff_frac()) \
            * (1.0 + GameManager.journey_progress * 0.3)

func _handle_steering(delta: float) -> void:
    var dir: int = (-1 if TouchInput.is_steering_left  else 0) \
                 + ( 1 if TouchInput.is_steering_right else 0)
    if dir != 0:
        var new_x := camera.position.x + dir * STEER_SPEED * delta
        camera.position.x = clampf(new_x, -STEER_RANGE, STEER_RANGE)
    camera.rotation.z = lerpf(camera.rotation.z, -dir * 0.06 + _zone_roll_extra, delta * 5.0)
    TouchInput.steer_x_norm = camera.position.x / STEER_RANGE

# ────────────────────────────────────────────────────────────────
# SPAWN
# ────────────────────────────────────────────────────────────────

# Difficulty 1→5 linearly interpolates between base and hard values
func _diff_frac() -> float:
    var diff: int = GameManager.selected_planet.get("difficulty", 1)
    return clampf((diff - 1) / 4.0, 0.0, 1.0)

func _mid_interval_min() -> float:
    return lerpf(MID_INTERVAL_BASE_MIN, MID_INTERVAL_HARD_MIN, _diff_frac())

func _mid_interval_max() -> float:
    return lerpf(MID_INTERVAL_BASE_MAX, MID_INTERVAL_HARD_MAX, _diff_frac())

func _mid_count_max() -> int:
    var diff: int = GameManager.selected_planet.get("difficulty", 1)
    return mini(diff, 3)   # 1 at diff-1, 2 at diff-2, 3 at diff-3+

func _tick_spawn(_delta: float) -> void:
    # ── Distance-based: spawn แถวใหม่เมื่อขอบมองเห็นเลยแถวถัดไป ──
    while _next_row_z > camera.position.z - SPAWN_AHEAD:
        _spawn_row(_next_row_z)
        _next_row_z -= _row_gap()

# ความยาก 0..1 = difficulty ของดาว + ความคืบหน้าของภารกิจ
func _row_diff() -> float:
    return clampf(_diff_frac() * 0.75 + GameManager.journey_progress * 0.25, 0.0, 1.0)

func _row_gap() -> float:
    return lerpf(ROW_GAP_EASY, ROW_GAP_HARD, _row_diff()) * randf_range(0.9, 1.15)

# ── สร้าง 1 แถว: เลือกทางรอดใหม่ → วาง bar ในพื้นที่ที่เหลือ ──────
func _spawn_row(z: float) -> void:
    var d         := _row_diff()
    var lane_w    := LANE_HALF * 2.0
    var safe_half := lerpf(SAFE_HALF_EASY, SAFE_HALF_HARD, d)

    # 1) ทางรอดใหม่ต้องอยู่ในระยะที่เลี้ยวไปทันจากทางรอดแถวก่อน
    var spd       := _fly_speed()
    var gap_z     := lerpf(ROW_GAP_EASY, ROW_GAP_HARD, d) * 0.9
    var max_shift := STEER_SPEED * (gap_z / spd) * STEER_SAFETY
    var lo := maxf(-LANE_HALF + safe_half, _path_x - max_shift)
    var hi := minf( LANE_HALF - safe_half, _path_x + max_shift)
    _path_x = randf_range(lo, hi)

    # 2) พื้นที่ว่างซ้าย/ขวาของทางรอด
    var free_l := Vector2(-LANE_HALF, _path_x - safe_half)   # (from, to)
    var free_r := Vector2(_path_x + safe_half, LANE_HALF)

    # 3) เลือก pattern
    var is_double := randf() < lerpf(DOUBLE_CHANCE_EASY, DOUBLE_CHANCE_HARD, d)
    if is_double:
        var w := lane_w * BAR_W_SHORT * randf_range(0.9, 1.3)
        _place_bar_in(free_l, w, z)
        _place_bar_in(free_r, w, z)
    else:
        var w := lane_w * randf_range(lerpf(BAR_W_MIN_EASY, BAR_W_MIN_HARD, d),
                                      lerpf(BAR_W_MAX_EASY, BAR_W_MAX_HARD, d))
        # เลือกฝั่งที่กว้างพอ (สุ่มถ้าพอทั้งคู่)
        var len_l := free_l.y - free_l.x
        var len_r := free_r.y - free_r.x
        var use_left := randf() < 0.5
        if len_l < w * 0.6: use_left = false
        if len_r < w * 0.6: use_left = true
        _place_bar_in(free_l if use_left else free_r, w, z)

    # 4) item วางบนทางรอด กึ่งกลางระหว่างแถวนี้กับแถวถัดไป → รางวัลคนที่เดินทางถูก
    if randf() < ITEM_CHANCE:
        _spawn_item_at(Vector3(_path_x, BAR_Y, z - gap_z * 0.5))

# วาง bar ความกว้าง w ลงในช่วง free (x from→to) แบบสุ่มตำแหน่ง
func _place_bar_in(free: Vector2, w: float, z: float) -> void:
    var room := free.y - free.x
    if room < BAR_STEP:            # ช่องแคบเกินจะใส่ก้อนได้
        return
    w = minf(w, room)
    var x0 := randf_range(free.x, free.y - w)
    _spawn_bar(x0 + w * 0.5, w, z)

# ── Bar = parent node + อุกกาบาต Medium หลายก้อนเรียงแนวนอน ─────
func _spawn_bar(center_x: float, width: float, z: float) -> void:
    if _glb == null:
        return
    var bar := Node3D.new()
    bar.position = Vector3(center_x, BAR_Y, z)
    var n := maxi(1, int(ceil(width / BAR_STEP)))
    var step := width / n
    for i in n:
        var rock := _make_meteor(false)
        if rock == null:
            continue
        rock.scale    = Vector3.ONE * randf_range(1.05, 1.40)
        rock.position = Vector3(-width * 0.5 + step * (i + 0.5) + randf_range(-0.12, 0.12),
                                randf_range(-0.25, 0.25),
                                randf_range(-0.30, 0.30))
        bar.add_child(rock)
    bar.set_meta("type",   "threat")
    bar.set_meta("hit",    false)
    bar.set_meta("zone",   "middle")
    bar.set_meta("half_w", width * 0.5)
    meteor_root.add_child(bar)
    _active_meteors.append(bar)

# item บนทางรอด (ไม่มี threat)
func _spawn_item_at(pos: Vector3) -> void:
    var t := "threat"
    while t == "threat":
        t = _pick_type()
    var model_id: String = _model_for(t)
    if model_id.is_empty() or not _powerup_packed.has(model_id):
        return
    _spawn_powerup_node(t, model_id, pos)

# ── Middle zone: spawns threats + items within [ZONE_MID_MIN, ZONE_MID_MAX] ──
func _spawn_middle() -> void:
    var obs_type := _pick_type()
    var spawn_pos := Vector3(
        randf_range(-SPREAD_X, SPREAD_X),
        randf_range(ZONE_MID_MIN, ZONE_MID_MAX),   # always middle zone
        camera.position.z - SPAWN_AHEAD
    )

    # Items → powerup GLB (middle zone only)
    if obs_type != "threat":
        var model_id: String = _model_for(obs_type)
        if not model_id.is_empty() and _powerup_packed.has(model_id):
            _spawn_powerup_node(obs_type, model_id, spawn_pos)
            return
        obs_type = "threat"   # fallback to threat if GLB missing

    _spawn_meteor_at(spawn_pos, "middle", true)   # medium+large, collision active

# ── Decorative zones: large/medium threats only, no collision ────────
func _spawn_deco() -> void:
    # Randomly pick top or bottom zone
    var in_top: bool = randf() > 0.5
    var y: float
    if in_top:
        y = randf_range(ZONE_MID_MAX + 0.1, SPREAD_Y_MAX)
    else:
        y = randf_range(SPREAD_Y_MIN, ZONE_MID_MIN - 0.1)
    var spawn_pos := Vector3(
        randf_range(-SPREAD_X, SPREAD_X),
        y,
        camera.position.z - SPAWN_AHEAD
    )
    _spawn_meteor_at(spawn_pos, "top" if in_top else "bottom", false)

# ── Core meteor instantiation ──────────────────────────────────────
func _spawn_meteor_at(spawn_pos: Vector3, zone: String, allow_small: bool) -> void:
    var root := _make_meteor(true, allow_small)
    if root == null:
        return
    var picked_large := root.get_meta("large", false) as bool
    root.scale    = Vector3.ONE * (randf_range(1.5, 2.2) if picked_large else randf_range(0.8, 1.4))
    root.position = spawn_pos
    root.set_meta("type", "threat")
    root.set_meta("hit",  false)
    root.set_meta("zone", zone)
    meteor_root.add_child(root)
    _active_meteors.append(root)

# สร้างอุกกาบาต 1 ก้อน (ยังไม่ add เข้า scene) — allow_large=false → Medium เท่านั้น
func _make_meteor(allow_large: bool, allow_small: bool = false) -> Node3D:
    if _glb == null:
        return null
    var root: Node3D = _glb.instantiate() as Node3D
    var children := root.get_children()
    if children.is_empty():
        root.queue_free()
        return null
    var valid_children: Array = []
    for ch in children:
        var nm: String = (ch as Node).name
        if ("Small" in nm and not allow_small) or ("Large" in nm and not allow_large):
            continue
        valid_children.append(ch)
    if valid_children.is_empty():
        valid_children = children
    var pick_idx: int = children.find(valid_children[randi() % valid_children.size()])
    for i in children.size():
        children[i].visible = (i == pick_idx)
    # ก้อนใน GLB วางเรียงห่างกันตามแกน X (0–19 หน่วย) → ย้ายก้อนที่เลือกมาไว้ตรงกลาง
    (children[pick_idx] as Node3D).position = Vector3.ZERO
    root.set_meta("large", "Large" in String(children[pick_idx].name))
    root.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
    var mi := children[pick_idx] as MeshInstance3D
    if mi and mi.mesh:
        var mat := StandardMaterial3D.new()
        _apply_zone_variant_to_mat(mat)
        mi.set_surface_override_material(0, mat)
    for anim_node in root.find_children("*", "AnimationPlayer", true, false):
        (anim_node as AnimationPlayer).stop()
    return root

# ── สร้าง powerup node จาก GLB จริง ─────────────────────────────────
func _spawn_powerup_node(obs_type: String, model_id: String, spawn_pos: Vector3) -> void:
    var packed: PackedScene = _powerup_packed[model_id]
    var node: Node3D = packed.instantiate() as Node3D

    var is_capsule := model_id.ends_with("_capsule")
    var sc: float
    if is_capsule:
        # ปรับให้สูง CAPSULE_HEIGHT ไม่ว่าโมเดลใน Blender จะขนาดเท่าไร
        var box := _local_aabb(node)
        sc = CAPSULE_HEIGHT / box.size.y if box.size.y > 0.001 else 1.0
        node.rotation = Vector3.ZERO     # หันสัญลักษณ์บนแคปซูลเข้าหาผู้เล่น
        spawn_pos -= box.get_center() * sc   # ให้จุดกึ่งกลางแคปซูลอยู่ที่ตำแหน่ง spawn
    else:
        sc = POWERUP_SCALE_3D.get(model_id, 1.2)
    # ── หันหน้าเข้าหาผู้เล่น: ตั้งโมเดลแบน (เช่นเหรียญ) ให้ด้านหน้าชี้ +Z ──
    node.set_meta("align", _face_align(node))
    node.rotation = node.get_meta("align")
    node.scale    = Vector3.ONE * sc
    node.position = spawn_pos

    node.set_meta("type", obs_type)
    node.set_meta("hit",  false)
    node.set_meta("is_powerup", true)
    # Zone assignment for 3-zone system
    var _pzone := "middle"
    if spawn_pos.y < ZONE_MID_MIN:
        _pzone = "bottom"
    elif spawn_pos.y > ZONE_MID_MAX:
        _pzone = "top"
    node.set_meta("zone", _pzone)

    # ทาสี emissive glow ทุก MeshInstance3D ใน hierarchy
    var glow: Color
    if is_capsule:
        glow = CAPSULE_LIGHT_COLOR.get(model_id, Color.WHITE)   # ใช้วัสดุเดิมจาก Blender
    else:
        glow = POWERUP_GLOW_COLOR.get(model_id, Color.WHITE)
        _apply_powerup_glow(node, glow)

    # วงแหวนทอง 3D ปิดไว้ — ใช้วงทอง 2D ขนาดคงที่จาก cockpit_overlay แทน
    # _add_gold_ring(node, sc)

    # หยุด AnimationPlayer ทุกตัวใน GLB — ป้องกัน auto-play ที่ทำให้ดูเหมือนเคลื่อนที่
    for anim_node in node.find_children("*", "AnimationPlayer", true, false):
        (anim_node as AnimationPlayer).stop()

    # เพิ่ม OmniLight3D เพื่อให้สว่างโดดเด่นในอวกาศมืด
    var light := OmniLight3D.new()
    light.light_color  = glow
    light.light_energy = ITEM_LIGHT_ENERGY
    light.omni_range   = 4.0
    light.light_bake_mode = Light3D.BAKE_DISABLED
    node.add_child(light)

    meteor_root.add_child(node)
    _active_meteors.append(node)

# มุมเอียงสูงสุดของ item เมื่อหันตามผู้เล่น (ไม่เกิน 30°)
const ITEM_MAX_YAW := 0.5236   # 30° (เรเดียน)

# หาแกนที่บางที่สุดของโมเดล → หมุนให้ "หน้า" ของโมเดลแบนชี้มาทาง +Z (หาผู้เล่น)
# เหรียญ/ดาวที่วางนอน (บางแกน Y) → ตั้งขึ้น, โมเดลที่บางแกน X → หมุน 90° รอบแกนตั้ง
func _face_align(node: Node3D) -> Vector3:
    var sz := _local_aabb(node).size
    var thinnest := minf(sz.x, minf(sz.y, sz.z))
    var others := (sz.x + sz.y + sz.z - thinnest) * 0.5
    if thinnest > others * 0.6:
        return Vector3.ZERO                       # ไม่แบน (กล่อง/ถัง/แคปซูล) — หันตรงอยู่แล้ว
    if is_equal_approx(thinnest, sz.y):
        return Vector3(PI * 0.5, 0.0, 0.0)        # นอนราบ → ตั้งขึ้น หน้าเข้าหาผู้เล่น
    if is_equal_approx(thinnest, sz.x):
        return Vector3(0.0, -PI * 0.5, 0.0)       # หน้าอยู่แกน X → หมุนมาแกน Z
    return Vector3.ZERO                           # หน้าอยู่แกน Z อยู่แล้ว

# เลือกโมเดลของ item: capsule ใหม่ถ้ามี, ไม่งั้นใช้โมเดลเดิม
func _model_for(obs_type: String) -> String:
    var cap: String = TYPE_TO_CAPSULE_MODEL.get(obs_type, "")
    if not cap.is_empty() and _powerup_packed.has(cap):
        return cap
    return TYPE_TO_POWERUP_MODEL.get(obs_type, "")

# AABB รวมของทุก mesh ใน node (พิกัด local ของ node)
func _local_aabb(root: Node3D) -> AABB:
    var box := AABB()
    var first := true
    for mi in root.find_children("*", "MeshInstance3D", true, false):
        var m := mi as MeshInstance3D
        if m.mesh == null:
            continue
        var xf := Transform3D.IDENTITY
        var n: Node = m
        while n != root and n is Node3D:
            xf = (n as Node3D).transform * xf
            n = n.get_parent()
        var b: AABB = xf * m.mesh.get_aabb()
        box = b if first else box.merge(b)
        first = false
    return box

# ── วงแหวนทอง (Torus) รอบ item → แยกแยะจากอุกกาบาตได้ง่าย ──────────
func _add_gold_ring(node: Node3D, item_scale: float) -> void:
    var ring := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 1.2 / item_scale   # ขนาดสัมพันธ์กับ item
    torus.outer_radius = 1.5 / item_scale
    torus.rings        = 24
    torus.ring_segments = 12
    ring.mesh = torus
    ring.rotation.x = deg_to_rad(90.0)   # วางแนวนอน รอบ item

    var mat := StandardMaterial3D.new()
    mat.albedo_color               = Color(1.00, 0.85, 0.20)  # สีทอง
    mat.emission_enabled           = true
    mat.emission                   = Color(1.00, 0.80, 0.10)  # เรืองแสงทอง
    mat.emission_energy_multiplier = 4.0
    mat.roughness                  = 0.15
    mat.metallic                   = 0.90
    ring.material_override = mat

    node.add_child(ring)

# ── ทา emissive glow แบบ recursive ลงทุก MeshInstance3D ──────────────
func _apply_powerup_glow(n: Node3D, glow: Color) -> void:
    for child in n.get_children():
        if child is MeshInstance3D:
            var mat := StandardMaterial3D.new()
            mat.albedo_color               = glow.lerp(Color.WHITE, 0.35)  # สีตามชนิด item → เห็นรูปทรงชัด
            mat.emission_enabled           = true
            mat.emission                   = glow
            mat.emission_energy_multiplier = ITEM_EMISSION   # เรืองแสงอ่อน ๆ พอให้เด่น ไม่กลบรูปทรง
            mat.roughness                  = 0.35
            mat.metallic                   = 0.30
            (child as MeshInstance3D).material_override = mat
        if child is Node3D and not (child is MeshInstance3D):
            _apply_powerup_glow(child as Node3D, glow)

func _pick_type() -> String:
    var r := randf()
    var cumulative := 0.0
    for t in TYPE_WEIGHTS:
        cumulative += TYPE_WEIGHTS[t]
        if r < cumulative:
            return t
    return "threat"

# ────────────────────────────────────────────────────────────────
# METEOR UPDATE
# ────────────────────────────────────────────────────────────────

func _update_meteors(delta: float) -> void:
    var cam_x := camera.position.x
    var cam_y := camera.position.y
    var cam_z := camera.position.z
    var to_remove: Array[Node3D] = []

    for m in _active_meteors:
        if not is_instance_valid(m):
            to_remove.append(m)
            continue

        # item หันหน้าตามผู้เล่น (หมุนรอบแกนตั้ง) แต่เอียงได้ไม่เกิน ±ITEM_MAX_YAW
        if m.has_meta("align"):
            var al: Vector3 = m.get_meta("align")
            var yaw := clampf(atan2(cam_x - m.position.x, cam_z - m.position.z),
                              -ITEM_MAX_YAW, ITEM_MAX_YAW)
            m.rotation = Vector3(al.x, al.y + yaw, al.z)

        # Objects are stationary in world space — no rotation applied
        if m.position.z > cam_z + KILL_BEHIND:
            if m.get_meta("type") == "threat" and not m.get_meta("hit"):
                GameManager.add_score(5)
            m.queue_free()
            to_remove.append(m)
            continue

        # Only check collision for middle-zone objects
        var m_zone: String = m.get_meta("zone", "middle")

        # ── Bar / item: hitbox แนวนอน (ยานเลื่อนแค่แกน X) + กันทะลุตอน fps ต่ำ ──
        if m.has_meta("half_w") or m.has_meta("is_powerup"):
            if not m.get_meta("hit") and m_zone == "middle":
                var mz: float = m.position.z
                if mz >= cam_z - BAR_DEPTH and mz <= _prev_cam_z + BAR_DEPTH:
                    var reach: float = ITEM_PICKUP_R
                    if m.has_meta("half_w"):
                        reach = float(m.get_meta("half_w")) + SHIP_HALF_W
                    if absf(m.position.x - cam_x) < reach:
                        m.set_meta("hit", true)
                        _on_hit(m)
                        m.queue_free()
                        to_remove.append(m)
            continue

        if not m.get_meta("hit") and m_zone == "middle":
            var sc_f: float  = m.scale.x
            var dz: float    = abs(m.position.z - cam_z)
            if dz < HIT_DEPTH * sc_f:
                var dx: float      = m.position.x - cam_x
                var dy: float      = m.position.y - cam_y
                var dist_xy: float = sqrt(dx * dx + dy * dy)
                if dist_xy < HIT_RADIUS_BASE * sc_f:
                    m.set_meta("hit", true)
                    _on_hit(m)
                    m.queue_free()
                    to_remove.append(m)

    for m in to_remove:
        _active_meteors.erase(m)
    _prev_cam_z = cam_z

# ────────────────────────────────────────────────────────────────
# COLLISION RESPONSE
# ────────────────────────────────────────────────────────────────

func _on_hit(meteor: Node3D) -> void:
    var t: String = meteor.get_meta("type")
    SoundManager.play_sfx("btn_click")
    match t:
        "threat":
            if _shield_active:
                _use_shield()
            else:
                GameManager.take_damage(20.0)
                SoundManager.play_sfx("hit")
                _shake_camera()
        "quiz":
            if not quiz_active:
                quiz_triggered.emit()
        "shield":
            _activate_shield()
        "energy":
            if GameManager.current_energy < 100.0:
                GameManager.restore_energy(25.0)
            else:
                GameManager.add_score(10)
            SoundManager.play_sfx("powerup")
        "score":
            GameManager.add_score(50)
            SoundManager.play_sfx("coin")

# ────────────────────────────────────────────────────────────────
# SHIELD
# ────────────────────────────────────────────────────────────────

func _activate_shield() -> void:
    _shield_active = true
    shield_changed.emit(true)
    SoundManager.play_sfx("shield_activate")

func _use_shield() -> void:
    _shield_active = false
    shield_changed.emit(false)
    SoundManager.play_sfx("shield_hit")

# ────────────────────────────────────────────────────────────────
# CAMERA SHAKE
# ────────────────────────────────────────────────────────────────

func _shake_camera() -> void:
    var tween := create_tween()
    for i in 5:
        tween.tween_property(camera, "rotation:z", randf_range(-0.18, 0.18), 0.05)
    tween.tween_property(camera, "rotation:z", 0.0, 0.12)

# ────────────────────────────────────────────────────────────────
# CAMERA  — มุมมอง FPS (จากภายในห้องนักบิน) อย่างเดียว
# ────────────────────────────────────────────────────────────────

func _apply_camera_mode() -> void:
    camera.fov        = 80.0
    camera.rotation.x = deg_to_rad(FPS_PITCH_DEG)
    if _ship_node:
        # ซ่อน 3D ship → cockpit_overlay.gd วาดกรอบ cockpit แทน
        _ship_node.visible  = false
        _ship_node.position = SHIP_OFFSET
        _ship_node.scale    = Vector3.ONE * SHIP_SCALE

# ── ซ่อน node ที่มีคำ keyword ในชื่อ (case-insensitive via two passes) ──
func _hide_nodes_by_keyword(root: Node3D, keyword: String) -> void:
    for n in root.find_children("*" + keyword + "*", "", true, false):
        if n is Node3D:
            (n as Node3D).visible = false

# ────────────────────────────────────────────────────────────────
# KEYBOARD INPUT MAPPING
# ────────────────────────────────────────────────────────────────

# ลงทะเบียน keyboard key เข้า InputMap action (Arrow ← → + Space)
# เรียก _ready() ครั้งเดียวก็พอ เพราะ HUD ปุ่มสัมผัสยังทำงานอยู่ใน action เดิม
func _register_keyboard_inputs() -> void:
    _map_key("steer_left",  GameSettings.key_steer_left)
    _map_key("steer_right", GameSettings.key_steer_right)
    _map_key("boost",       GameSettings.key_boost)

func _map_key(action: String, keycode: int) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    if not _action_has_key(action, keycode):
        var ev := InputEventKey.new()
        ev.keycode = keycode as Key
        InputMap.action_add_event(action, ev)

func _action_has_key(action: String, keycode: int) -> bool:
    if not InputMap.has_action(action):
        return false
    for ev: InputEvent in InputMap.action_get_events(action):
        if ev is InputEventKey:
            if int((ev as InputEventKey).keycode) == keycode:
                return true
    return false

# ────────────────────────────────────────────────────────────────
# NEBULA SKY SETUP
# ────────────────────────────────────────────────────────────────

func _setup_nebula_sky() -> void:
    # Look for an existing WorldEnvironment in the parent tree
    var existing_we: WorldEnvironment = null
    var parent := get_parent()
    if parent:
        for child in parent.get_children():
            if child is WorldEnvironment:
                existing_we = child as WorldEnvironment
                break

    var we: WorldEnvironment
    if existing_we:
        we = existing_we
    else:
        we = WorldEnvironment.new()
        we.name = "WorldEnvironment"
        get_parent().add_child.call_deferred(we)

    var nebula_tex: Texture2D = load("res://assets/ui/space_nebula.png")
    if nebula_tex == null:
        push_warning("cockpit_3d: space_nebula.png not found — sky unchanged")
        return

    var panorama := PanoramaSkyMaterial.new()
    panorama.panorama = nebula_tex

    var sky := Sky.new()
    sky.sky_material = panorama

    var env := Environment.new()
    env.background_mode        = Environment.BG_SKY
    env.sky                    = sky
    env.ambient_light_source   = Environment.AMBIENT_SOURCE_COLOR   # zone system animates this
    env.ambient_light_color    = Color(0.10, 0.12, 0.30)
    env.ambient_light_energy   = 0.22
    env.tonemap_mode           = Environment.TONE_MAPPER_FILMIC
    env.glow_enabled           = true
    env.glow_intensity         = 0.45
    env.glow_bloom             = 0.10
    # Fog defaults — zone system will enable/tune per zone
    env.fog_enabled            = false
    env.fog_density            = 0.0
    env.fog_light_color        = Color(0.02, 0.02, 0.08)

    we.environment = env
    _we  = we
    _env = env

# ────────────────────────────────────────────────────────────────
# PRE-POPULATE ASTEROID FIELD
# ────────────────────────────────────────────────────────────────

func _prepopulate_asteroids() -> void:
    # Spread PREPOPULATE_COUNT asteroids at varying depths ahead
    # so the field looks full immediately (not empty at game start)
    if _glb == null:
        return
    for i in PREPOPULATE_COUNT:
        # spread them from 15 to SPAWN_AHEAD units ahead
        var depth_frac := float(i) / float(PREPOPULATE_COUNT)
        var z_offset   := -15.0 - depth_frac * (SPAWN_AHEAD - 15.0)
        var spawn_pos  := Vector3(
            randf_range(-SPREAD_X, SPREAD_X),
            randf_range(SPREAD_Y_MIN, SPREAD_Y_MAX),
            camera.position.z + z_offset
        )
        _spawn_one_at(spawn_pos, "threat")

func _spawn_one_at(spawn_pos: Vector3, _obs_type: String) -> void:
    # Stripped-down version of _spawn_one for pre-population (threats only)
    if _glb == null:
        return
    var root: Node3D = _glb.instantiate() as Node3D
    var children := root.get_children()
    if children.is_empty():
        root.queue_free()
        return

    # Pre-population: medium+large only (filter out Small)
    var valid_pre: Array = []
    for ch in children:
        if not ("Small" in (ch as Node).name):
            valid_pre.append(ch)
    if valid_pre.is_empty():
        valid_pre = children

    var chosen_pre: Node = valid_pre[randi() % valid_pre.size()]
    var pick_idx: int = children.find(chosen_pre)
    for i in children.size():
        children[i].visible = (i == pick_idx)
    # ก้อนใน GLB วางเรียงห่างกันตามแกน X (0–19 หน่วย) → ย้ายก้อนที่เลือกมาไว้ตรงกลาง
    (children[pick_idx] as Node3D).position = Vector3.ZERO

    var picked_name: String = children[pick_idx].name
    var sc: float
    if "Large" in picked_name: sc = randf_range(1.4, 2.0)
    else:                       sc = randf_range(0.7, 1.3)
    root.scale    = Vector3.ONE * sc
    root.position = spawn_pos
    root.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
    root.set_meta("spin", Vector3(
        randf_range(-0.5, 0.5), randf_range(-0.5, 0.5), randf_range(-0.15, 0.15)
    ))
    root.set_meta("type", "threat")
    root.set_meta("hit",  false)
    # Zone assignment for pre-populated meteors
    var _pp_zone := "middle"
    if spawn_pos.y < ZONE_MID_MIN:
        _pp_zone = "bottom"
    elif spawn_pos.y > ZONE_MID_MAX:
        _pp_zone = "top"
    root.set_meta("zone", _pp_zone)

    var mi := children[pick_idx] as MeshInstance3D
    if mi and mi.mesh:
        var mat := StandardMaterial3D.new()
        _apply_zone_variant_to_mat(mat)
        mi.set_surface_override_material(0, mat)

    meteor_root.add_child(root)
    _active_meteors.append(root)

# ────────────────────────────────────────────────────────────────
# ZONE SYSTEM  (6 map zones driven by GameManager.journey_progress)
# ────────────────────────────────────────────────────────────────
# Each zone has its own atmosphere, asteroid variant, camera pitch/roll effect,
# and an optional background planet.  Transitions are smooth-lerped every frame.

const ZONE_DATA: Array[Dictionary] = [
    {   # Zone 0 · Asteroid Belt (start)
        "start": 0.00, "end": 0.17,
        "fog": 0.000, "fog_col": Color(0.02, 0.02, 0.08),
        "amb": Color(0.10, 0.12, 0.30), "amb_e": 0.22,
        "variant": "standard", "pitch": 0.00, "roll_spd": 0.00,
        "planet": {},
    },
    {   # Zone 1 · Nebula Tunnel
        "start": 0.17, "end": 0.34,
        "fog": 0.006, "fog_col": Color(0.12, 0.03, 0.26),
        "amb": Color(0.28, 0.06, 0.52), "amb_e": 0.30,
        "variant": "crystal", "pitch": 0.00, "roll_spd": 0.008,
        "planet": { "col": Color(0.25, 0.08, 0.55), "r": 16.0, "pos": Vector3(28.0, 7.0, -90.0), "glow": true },
    },
    {   # Zone 2 · Planet Descent
        "start": 0.34, "end": 0.51,
        "fog": 0.005, "fog_col": Color(0.04, 0.14, 0.32),
        "amb": Color(0.06, 0.20, 0.42), "amb_e": 0.28,
        "variant": "ice", "pitch": -0.08, "roll_spd": 0.00,
        "planet": { "col": Color(0.12, 0.45, 0.22), "r": 28.0, "pos": Vector3(-22.0, -6.0, -110.0), "glow": false },
    },
    {   # Zone 3 · Solar Storm
        "start": 0.51, "end": 0.68,
        "fog": 0.004, "fog_col": Color(0.24, 0.07, 0.01),
        "amb": Color(0.60, 0.16, 0.02), "amb_e": 0.38,
        "variant": "volcanic", "pitch": 0.04, "roll_spd": 0.00,
        "planet": { "col": Color(1.00, 0.55, 0.05), "r": 45.0, "pos": Vector3(18.0, -22.0, -130.0), "glow": true },
    },
    {   # Zone 4 · Space Station
        "start": 0.68, "end": 0.85,
        "fog": 0.002, "fog_col": Color(0.02, 0.12, 0.24),
        "amb": Color(0.05, 0.26, 0.44), "amb_e": 0.32,
        "variant": "metallic", "pitch": 0.00, "roll_spd": 0.00,
        "planet": { "col": Color(0.38, 0.48, 0.62), "r": 20.0, "pos": Vector3(-30.0, 9.0, -85.0), "glow": false },
    },
    {   # Zone 5 · Wormhole Sprint (final)
        "start": 0.85, "end": 1.01,
        "fog": 0.010, "fog_col": Color(0.14, 0.01, 0.30),
        "amb": Color(0.32, 0.02, 0.65), "amb_e": 0.42,
        "variant": "plasma", "pitch": 0.00, "roll_spd": 0.06,
        "planet": {},
    },
]

# ── Asteroid visual variant recipes ──────────────────────────────
const VARIANT_MAT: Dictionary = {
    "standard": { "col": Color(0.38, 0.35, 0.30), "emit": false, "ec": Color.WHITE,             "ee": 0.0, "rough": 0.92, "metal": 0.04 },
    "crystal":  { "col": Color(0.28, 0.14, 0.55), "emit": true,  "ec": Color(0.55, 0.20, 1.00), "ee": 2.8, "rough": 0.18, "metal": 0.50 },
    "ice":      { "col": Color(0.70, 0.84, 1.00), "emit": true,  "ec": Color(0.40, 0.65, 1.00), "ee": 1.6, "rough": 0.16, "metal": 0.06 },
    "volcanic": { "col": Color(0.22, 0.07, 0.05), "emit": true,  "ec": Color(1.00, 0.28, 0.00), "ee": 4.0, "rough": 0.88, "metal": 0.05 },
    "metallic": { "col": Color(0.50, 0.55, 0.60), "emit": false, "ec": Color.WHITE,             "ee": 0.0, "rough": 0.28, "metal": 0.90 },
    "plasma":   { "col": Color(0.18, 0.07, 0.32), "emit": true,  "ec": Color(0.80, 0.08, 1.00), "ee": 5.5, "rough": 0.10, "metal": 0.38 },
}

func _get_zone_idx() -> int:
    var p := clampf(GameManager.journey_progress, 0.0, 1.0)
    for i in ZONE_DATA.size():
        if p >= (ZONE_DATA[i]["start"] as float) and p < (ZONE_DATA[i]["end"] as float):
            return i
    return ZONE_DATA.size() - 1

func _get_current_variant() -> String:
    return ZONE_DATA[_zone_idx].get("variant", "standard") as String

func _apply_zone_variant_to_mat(mat: StandardMaterial3D) -> void:
    var vd: Dictionary = VARIANT_MAT.get(_get_current_variant(), VARIANT_MAT["standard"])
    var base_col: Color = vd["col"] as Color
    var v := randf_range(-0.06, 0.06)   # per-rock albedo micro-variation
    mat.albedo_color = Color(
        clampf(base_col.r + v,        0.0, 1.0),
        clampf(base_col.g + v * 0.6,  0.0, 1.0),
        clampf(base_col.b + v * 0.3,  0.0, 1.0)
    )
    mat.roughness = clampf((vd["rough"] as float) + randf_range(-0.05, 0.05), 0.05, 1.0)
    mat.metallic  = vd["metal"] as float
    if vd["emit"] as bool:
        mat.emission_enabled           = true
        mat.emission                   = vd["ec"] as Color
        mat.emission_energy_multiplier = (vd["ee"] as float) * randf_range(0.75, 1.35)

func _update_zone(delta: float) -> void:
    var new_idx := _get_zone_idx()
    if new_idx != _zone_idx:
        _zone_idx      = new_idx
        _zone_roll_acc = 0.0
        _on_zone_entered(new_idx)

    var z: Dictionary = ZONE_DATA[_zone_idx]

    # ── Environment: fog & ambient ────────────────────────────────
    if _env != null:
        var tfog := z["fog"] as float
        _env.fog_enabled = (tfog > 0.001)
        if _env.fog_enabled:
            _env.fog_density     = lerpf(_env.fog_density, tfog, delta * 1.2)
            _env.fog_light_color = _env.fog_light_color.lerp(z["fog_col"] as Color, delta * 1.2)
        _env.ambient_light_color  = _env.ambient_light_color.lerp(z["amb"] as Color, delta * 0.7)
        _env.ambient_light_energy = lerpf(_env.ambient_light_energy, z["amb_e"] as float, delta * 0.7)

    # ── Camera: pitch offset ──────────────────────────────────────
    _zone_pitch = lerpf(_zone_pitch, z["pitch"] as float, delta * 1.5)
    var base_cam_x := deg_to_rad(FPS_PITCH_DEG)
    camera.rotation.x = lerpf(camera.rotation.x, base_cam_x + _zone_pitch, delta * 2.0)

    # ── Camera: wormhole sway roll ────────────────────────────────
    var rspd := z["roll_spd"] as float
    if rspd > 0.0:
        _zone_roll_acc  += delta * 0.9
        _zone_roll_extra = sin(_zone_roll_acc) * rspd * 3.5
    else:
        _zone_roll_extra = lerpf(_zone_roll_extra, 0.0, delta * 2.5)

func _on_zone_entered(_idx: int) -> void:
    pass   # ดาวฉากหลังใช้ระบบ "เส้นทางภารกิจ" แทน (ดู _update_route)

# ────────────────────────────────────────────────────────────────
# BACKGROUND STARFIELD
# ────────────────────────────────────────────────────────────────

func _setup_starfield() -> void:
    _star_root      = Node3D.new()
    _star_root.name = "Starfield"

    var star_mat := StandardMaterial3D.new()
    star_mat.albedo_color              = Color.WHITE
    star_mat.emission_enabled          = true
    star_mat.emission                  = Color(0.96, 0.92, 0.84)
    star_mat.emission_energy_multiplier = 5.0
    star_mat.shading_mode              = BaseMaterial3D.SHADING_MODE_UNSHADED
    star_mat.cull_mode                 = BaseMaterial3D.CULL_DISABLED

    var star_mesh := SphereMesh.new()
    star_mesh.radius          = 0.07
    star_mesh.height          = 0.14
    star_mesh.radial_segments = 3
    star_mesh.rings           = 2

    var mm := MultiMesh.new()
    mm.mesh             = star_mesh
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.instance_count   = 300

    for i in 300:
        var phi   := randf() * TAU
        var theta := acos(randf_range(-0.5, 1.0))   # mostly forward hemisphere
        var r     := randf_range(55.0, 100.0)
        var pos   := Vector3(
            r * sin(theta) * cos(phi),
            r * sin(theta) * sin(phi) * 0.55,
            -r * abs(cos(theta)) - 8.0
        )
        if randf() < 0.25:
            pos.z = -pos.z + 25.0   # a quarter behind player too
        var xform := Transform3D.IDENTITY
        xform.origin = pos
        xform        = xform.scaled_local(Vector3.ONE * randf_range(0.35, 2.2))
        mm.set_instance_transform(i, xform)

    var mmi              := MultiMeshInstance3D.new()
    mmi.multimesh         = mm
    mmi.material_override = star_mat

    _star_root.add_child(mmi)
    camera.add_child(_star_root)   # child of camera → always surrounds player

# ────────────────────────────────────────────────────────────────
# BACKGROUND PLANETS
# ────────────────────────────────────────────────────────────────

func _setup_bg_planets() -> void:
    pass   # planets are spawned/swapped in _refresh_bg_planet on zone change

func _refresh_bg_planet(zone_idx: int) -> void:
    if _bg_planet != null and is_instance_valid(_bg_planet):
        _bg_planet.queue_free()
        _bg_planet = null

    if zone_idx < 0 or zone_idx >= ZONE_DATA.size():
        return
    var pdata: Dictionary = ZONE_DATA[zone_idx].get("planet", {}) as Dictionary
    if pdata.is_empty():
        return

    var r_val: float = pdata["r"] as float
    var sphere := SphereMesh.new()
    sphere.radius          = r_val
    sphere.height          = r_val * 2.0
    sphere.radial_segments = 32
    sphere.rings           = 16

    var col: Color = pdata["col"] as Color
    var mat := StandardMaterial3D.new()
    mat.albedo_color = col
    mat.roughness    = 0.72
    mat.metallic     = 0.04
    if pdata.get("glow", false) as bool:
        mat.emission_enabled           = true
        mat.emission                   = col * 0.6
        mat.emission_energy_multiplier = 1.8

    _bg_planet                   = MeshInstance3D.new()
    _bg_planet.name              = "BgPlanet"
    _bg_planet.mesh              = sphere
    _bg_planet.material_override = mat
    _bg_planet.position          = pdata["pos"] as Vector3

    camera.add_child(_bg_planet)


# ==============================================================
#  ROUTE PLANETS — ดาวที่ผ่านระหว่างทาง ตามเส้นทางจากฐานปฏิบัติการ (โลก) ถึงดาวปลายทาง
#  ตัวอย่าง: ภารกิจดาวเสาร์ → ดวงจันทร์ → ดาวอังคาร → ดาวพฤหัสบดี → (ลงจอด) ดาวเสาร์
#  ใช้โมเดลดาวชุดเดียวกับหน้าเลือกดาว (assets/models/planets/*.glb)
# ==============================================================
const ORBIT_ORDER: Array[String] = ["mercury", "venus", "earth", "mars", "jupiter",
                                    "saturn", "uranus", "neptune", "pluto"]
# รัศมีที่แสดงในฉาก (หน่วยโลก) — ดาวยักษ์ใหญ่กว่า
const ROUTE_PLANET_R: Dictionary = {
    "moon": 8.0, "mercury": 8.0, "venus": 12.0, "earth": 12.0, "mars": 10.0,
    "jupiter": 26.0, "saturn": 21.0, "uranus": 17.0, "neptune": 17.0, "pluto": 7.0,
}
const ROUTE_PASS_X   := 42.0     # ระยะด้านข้างของดาวที่บินผ่าน (สลับซ้าย/ขวา)
const ROUTE_PASS_Y   := 8.0
const ROUTE_Z_FAR    := -185.0   # เริ่มไกล (กล้อง far = 200)
const ROUTE_Z_NEAR   := 30.0     # ผ่านไปด้านหลัง
const TARGET_POS_X   := 16.0
const TARGET_POS_Y   := 18.0
const ROUTE_LIFT     := 0.40     # ≈ tan(18°+) — สัดส่วนยกสูงตามระยะ (พิกัดกล้อง)
const ROUTE_SCREEN_X := 0.50     # ตำแหน่งแนวนอนบนจอ (NDC 0=กลาง, 1=ขอบ) — สลับซ้าย/ขวา
const ROUTE_SCREEN_Y := 0.44     # ตำแหน่งแนวตั้ง (ช่องมองเหนือแผงหน้าปัด)
const ROUTE_DIST     := 120.0    # ระยะจากกล้อง (คงที่ — ขนาดบนจอคุมด้วย scale)
const ROUTE_PASS_START := 0.80   # ช่วงท้ายของแต่ละดาว = ขับผ่าน
const ROUTE_VP_PX    := 512      # ความละเอียดภาพดาวระหว่างทาง

var _route: Array[String] = []
var _route_idx: int = -1
var _route_node: Node3D = null
var _route_vp: SubViewport = null
var _route_spin: Node3D = null

func _build_route() -> void:
    _route.clear()
    var target: String = GameManager.selected_planet.get("id", "")
    if target.is_empty():
        return
    if target != "moon":
        _route.append("moon")   # ออกจากโลกผ่านดวงจันทร์ก่อนเสมอ
        var ei := ORBIT_ORDER.find("earth")
        var ti := ORBIT_ORDER.find(target)
        if ti >= 0 and ti != ei:
            var step := 1 if ti > ei else -1
            var i := ei + step
            while i != ti:
                _route.append(ORBIT_ORDER[i])
                i += step
    _route.append(target)
    print("[Route] ", " → ".join(_route))

func _update_route(delta: float) -> void:
    if _route.is_empty():
        return
    var n := _route.size()
    var seg := clampf(GameManager.journey_progress, 0.0, 0.9999) * float(n)
    var idx := mini(int(seg), n - 1)
    var t := seg - float(idx)
    if idx != _route_idx:
        _route_idx = idx
        _spawn_route_planet(_route[idx])
    if _route_node == null or not is_instance_valid(_route_node):
        return
    var is_target := (idx == n - 1)
    # วางดาวตามตำแหน่งบนจอ (ซ้าย/ขวา) แล้วค่อย ๆ ขยายเมื่อยานเข้าใกล้
    var side := 1.0 if idx % 2 == 0 else -1.0
    var sx := ROUTE_SCREEN_X
    var r_max := clampf(float(ROUTE_PLANET_R.get(_route[idx], 12.0)) / 26.0 * 0.34, 0.20, 0.34)
    if _route[idx] == "saturn":
        r_max *= 1.7   # ภาพดาวเสาร์รวมวงแหวน
    var r_ndc: float
    if is_target:
        # ดาวปลายทาง: ใหญ่ขึ้นเรื่อย ๆ จนถึงลงจอด และค่อย ๆ เข้ามาใกล้กลางจอ
        var e := smoothstep(0.0, 1.0, t)
        r_ndc = lerpf(r_max * 0.12, r_max * 1.25, e)
        sx = lerpf(ROUTE_SCREEN_X, 0.42, e)
    elif t < ROUTE_PASS_START:
        # เข้าใกล้: ขยายจากจุดเล็ก ๆ จนเต็มขนาด
        var e := smoothstep(0.0, 1.0, t / ROUTE_PASS_START)
        r_ndc = lerpf(r_max * 0.12, r_max, e)
    else:
        # ขับผ่าน: ดาวขยายต่อและเลื่อนออกด้านข้างจอ
        var p := (t - ROUTE_PASS_START) / (1.0 - ROUTE_PASS_START)
        var e := p * p
        r_ndc = r_max * (1.0 + 0.8 * e)
        sx = ROUTE_SCREEN_X + (1.0 + r_ndc * 2.0) * e
    _place_route_planet(Vector2(side * sx, ROUTE_SCREEN_Y), r_ndc)
    if _route_spin != null and is_instance_valid(_route_spin):
        _route_spin.rotation.y += 0.12 * delta

func _spawn_route_planet(pid: String) -> void:
    if _route_node != null and is_instance_valid(_route_node):
        _route_node.queue_free()
    if _route_vp != null and is_instance_valid(_route_vp):
        _route_vp.queue_free()
    _route_node = null
    _route_vp = null
    _route_spin = null
    # เรนเดอร์ดาว (โมเดลเดียวกับหน้าเลือกดาว) ใน SubViewport ของตัวเอง แล้วแสดงเป็น billboard
    # → ดาวกลมเสมอแม้อยู่ขอบจอ (ไม่ยืดเป็นวงรีจากมุมกล้องกว้าง) และยังอยู่หลังแผงหน้าปัด
    var res := Planet3DView.make_planet_vp(self, pid, Vector2i(ROUTE_VP_PX, ROUTE_VP_PX),
            12.0 if pid == "saturn" else -1.0)   # มองวงแหวนเฉียง ๆ จากด้านข้าง
    if res.is_empty():
        return
    _route_vp = res["vp"]
    _route_spin = res["planet_node"]
    var spr := Sprite3D.new()
    spr.name = "RoutePlanet_" + pid
    spr.texture = _route_vp.get_texture()
    spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    spr.shaded = false
    spr.double_sided = true
    spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
    spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    spr.pixel_size = 0.001
    # รัศมีดาวในภาพ ≈ 0.805 ของครึ่งภาพ (CAM_DIST = รัศมี×3, fov 45°)
    spr.set_meta("glb_r", ROUTE_VP_PX * 0.5 * 0.805)
    camera.add_child(spr)
    _route_node = spr

# วางดาวที่ตำแหน่งจอ ndc (x: -1..1 ซ้าย→ขวา, y: -1..1 ล่าง→บน) ให้มีรัศมีบนจอ r_ndc (สัดส่วนครึ่งความสูงจอ)
func _place_route_planet(ndc: Vector2, r_ndc: float) -> void:
    var vs := get_viewport().get_visible_rect().size
    var aspect := vs.x / maxf(vs.y, 1.0)
    var tv := tan(deg_to_rad(camera.fov) * 0.5)
    var dir := Vector3(ndc.x * tv * aspect, ndc.y * tv, -1.0)
    _route_node.position = dir * ROUTE_DIST
    var world_r := r_ndc * tv * ROUTE_DIST
    var px_r: float = _route_node.get_meta("glb_r", 1.0)
    (_route_node as Sprite3D).pixel_size = world_r / px_r
