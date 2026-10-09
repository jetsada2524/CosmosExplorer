extends Node
# ==============================================================
#  game_settings.gd  —  Autoload Singleton  ชื่อ "GameSettings"
#  เก็บค่าที่ admin (superadmin) ปรับแต่งได้ระหว่างเล่น/ทดสอบเกม
#  ปรับได้ผ่านหน้า "ตั้งค่า" (admin_settings.tscn) ในหน้า วิธีเล่น
# ==============================================================

signal settings_changed

# บันทึก/โหลดค่าตั้งค่าทั้งหมดลงไฟล์ user://game_settings.json
# — ทุกครั้งที่ admin เปลี่ยนค่า (settings_changed) จะเขียนไฟล์นี้ทันที
# — ตอนเริ่มเกม (_ready ของ autoload) จะโหลดค่าจากไฟล์นี้มาใช้เล่นจริง
const SAVE_PATH: String = "user://game_settings.json"

# 6.1 เวลาในการเล่นแต่ละดวงดาว (วินาที) — key = planet id
#     ถ้าไม่มี override จะใช้ค่า time_limit เดิมจาก planets.json
var planet_time_overrides: Dictionary = {}

# 6.2 เวลาในการ drop ของไอเทม (คำถาม/พลังงาน/ดาวคะแนน) หน่วยวินาที
var powerup_drop_interval: float = 15.0

# 6.3 จำนวน bonus coin ที่ได้ตอนเก็บไอเทมขณะพลัง/energy เต็มอยู่แล้ว
var overflow_coin_bonus: int = 150

# 6.4 ค่าอื่นๆ ที่ปรับแต่งได้อย่างสมเหตุสมผล
var boost_fall_mult:    float = 1.8    # อุกกาบาตตกไวขึ้นกี่เท่าตอนกด boost
var boost_speed_mult:   float = 2.2    # ยานเร่งไวขึ้นกี่เท่าตอนกด boost
var energy_drain_boost: float = 18.0   # energy ลด %/วินาที ตอน boost
var energy_idle_regen:  float = 1.5    # energy ฟื้น %/วินาที ตอนไม่ boost

# 6.5 keyboard bindings (มุมกล้องใช้ FPS อย่างเดียว — ลบการตั้งค่า camera mode แล้ว)
var key_steer_left:  int   = KEY_LEFT      # Arrow Left
var key_steer_right: int   = KEY_RIGHT     # Arrow Right
var key_boost:       int   = KEY_SPACE     # Space Bar

const DEFAULTS: Dictionary = {
    "powerup_drop_interval": 15.0,
    "overflow_coin_bonus":   150,
    "boost_fall_mult":       1.8,
    "boost_speed_mult":      2.2,
    "energy_drain_boost":    18.0,
    "energy_idle_regen":     1.5,
    "key_steer_left":        KEY_LEFT,
    "key_steer_right":       KEY_RIGHT,
    "key_boost":             KEY_SPACE,
}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS   # run even when game is paused
    load_data()
    # เซ็ตค่าเปลี่ยนทุกครั้ง (จากเมนูตั้งค่า admin) ให้บันทึกลงไฟล์ทันที
    settings_changed.connect(_save_to_file)

# ── 6.1 เวลาต่อดวงดาว ───────────────────────────────────────────
func get_planet_time(planet_id: String, default_time: float) -> float:
    return planet_time_overrides.get(planet_id, default_time)

func set_planet_time(planet_id: String, time_sec: float) -> void:
    planet_time_overrides[planet_id] = maxf(10.0, time_sec)
    settings_changed.emit()

# ── 6.2 ความถี่ drop ไอเทม ──────────────────────────────────────
func set_powerup_drop_interval(v: float) -> void:
    powerup_drop_interval = maxf(2.0, v)
    settings_changed.emit()

# ── 6.3 bonus coin เมื่อพลัง/energy เต็ม ──────────────────────
func set_overflow_coin_bonus(v: int) -> void:
    overflow_coin_bonus = maxi(0, v)
    settings_changed.emit()

# ── 6.4 ค่าอื่นๆ ────────────────────────────────────────────────
func set_boost_fall_mult(v: float) -> void:
    boost_fall_mult = maxf(1.0, v)
    settings_changed.emit()

func set_boost_speed_mult(v: float) -> void:
    boost_speed_mult = maxf(1.0, v)
    settings_changed.emit()

func set_energy_drain_boost(v: float) -> void:
    energy_drain_boost = maxf(0.0, v)
    settings_changed.emit()

func set_energy_idle_regen(v: float) -> void:
    energy_idle_regen = maxf(0.0, v)
    settings_changed.emit()

func reset_to_defaults() -> void:
    planet_time_overrides.clear()
    powerup_drop_interval = DEFAULTS["powerup_drop_interval"]
    overflow_coin_bonus   = DEFAULTS["overflow_coin_bonus"]
    boost_fall_mult        = DEFAULTS["boost_fall_mult"]
    boost_speed_mult       = DEFAULTS["boost_speed_mult"]
    energy_drain_boost     = DEFAULTS["energy_drain_boost"]
    energy_idle_regen      = DEFAULTS["energy_idle_regen"]
    key_steer_left         = DEFAULTS["key_steer_left"]
    key_steer_right        = DEFAULTS["key_steer_right"]
    key_boost              = DEFAULTS["key_boost"]
    settings_changed.emit()   # -> เขียนทับไฟล์ user://game_settings.json ด้วยค่าเริ่มต้น

# ── บันทึก/โหลดไฟล์ user://game_settings.json ──────────────────
func _to_save_dict() -> Dictionary:
    return {
        "planet_time_overrides": planet_time_overrides,
        "powerup_drop_interval": powerup_drop_interval,
        "overflow_coin_bonus":   overflow_coin_bonus,
        "boost_fall_mult":       boost_fall_mult,
        "boost_speed_mult":      boost_speed_mult,
        "energy_drain_boost":    energy_drain_boost,
        "energy_idle_regen":     energy_idle_regen,
        "key_steer_left":        key_steer_left,
        "key_steer_right":       key_steer_right,
        "key_boost":             key_boost,
    }

func _save_to_file() -> void:
    var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if f == null:
        push_error("GameSettings: ไม่สามารถเปิดไฟล์เพื่อบันทึก (%s)" % SAVE_PATH)
        return
    f.store_string(JSON.stringify(_to_save_dict(), "\t"))

# ── Auto Screenshot System ──────────────────────────────────────
const SCREENSHOT_DIR: String = "/Users/jetsada.sri/Claude/Projects/drive_avoid_meteorite/screenshots"
var _shot_counter: int = 0
var _last_scene_path: String = ""
var _is_auto_capturing: bool = false

func _process(_delta: float) -> void:
    if get_tree() == null or get_tree().current_scene == null:
        return
    var scene_path: String = get_tree().current_scene.scene_file_path
    if scene_path != _last_scene_path and not _is_auto_capturing:
        _last_scene_path = scene_path
        _auto_capture_scene(scene_path.get_file().get_basename())

func _auto_capture_scene(scene_name: String) -> void:
    _is_auto_capturing = true
    await get_tree().create_timer(0.8).timeout
    _take_screenshot(scene_name)
    _is_auto_capturing = false

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_F9:
            _take_screenshot()

func _take_screenshot(label: String = "") -> void:
    DirAccess.make_dir_recursive_absolute(SCREENSHOT_DIR)
    _shot_counter += 1
    var ts := label if label != "" else "shot_%02d" % _shot_counter
    var path := "%s/%s.png" % [SCREENSHOT_DIR, ts]
    # No await — capture current frame immediately (works during pause too)
    var img := get_viewport().get_texture().get_image()
    img.save_png(path)
    print("📸 Screenshot saved: ", path)

func load_data() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return   # ยังไม่เคยบันทึก — ใช้ค่า DEFAULTS ที่ตั้งไว้ใน var ตอนประกาศ
    var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if f == null:
        push_error("GameSettings: ไม่สามารถเปิดไฟล์เพื่อโหลด (%s)" % SAVE_PATH)
        return
    var parsed = JSON.parse_string(f.get_as_text())
    if not (parsed is Dictionary):
        push_warning("GameSettings: ไฟล์ %s เสียหายหรือรูปแบบไม่ถูกต้อง — ใช้ค่าเริ่มต้น" % SAVE_PATH)
        return
    var d: Dictionary = parsed
    if d.get("planet_time_overrides") is Dictionary:
        planet_time_overrides = (d["planet_time_overrides"] as Dictionary).duplicate()
    powerup_drop_interval = float(d.get("powerup_drop_interval", powerup_drop_interval))
    overflow_coin_bonus   = int(d.get("overflow_coin_bonus", overflow_coin_bonus))
    boost_fall_mult        = float(d.get("boost_fall_mult", boost_fall_mult))
    boost_speed_mult       = float(d.get("boost_speed_mult", boost_speed_mult))
    energy_drain_boost     = float(d.get("energy_drain_boost", energy_drain_boost))
    energy_idle_regen      = float(d.get("energy_idle_regen", energy_idle_regen))
    key_steer_left         = int(d.get("key_steer_left",  key_steer_left))
    key_steer_right        = int(d.get("key_steer_right", key_steer_right))
    key_boost              = int(d.get("key_boost",       key_boost))
