extends Node
# ==============================================================
#  game_manager.gd  —  Autoload Singleton  ชื่อ "GameManager"
# ==============================================================

signal hp_changed(new_hp: float)
signal energy_changed(new_energy: float)
signal score_changed(new_score: int)
signal game_over_triggered
signal mission_complete
signal coin_overflow_awarded(amount: int)   # พลัง/energy เต็มแล้วได้ coin แทน — ใช้ trigger popup +coin

const SCENES: Dictionary = {
    "attract":       "res://scenes/attract.tscn",
    "login":         "res://scenes/login.tscn",
    "how_to_play":   "res://scenes/how_to_play.tscn",
    "planet_select": "res://scenes/planet_select.tscn",
    "gameplay":      "res://scenes/gameplay.tscn",
    "win":           "res://scenes/win.tscn",
    "game_over":     "res://scenes/game_over.tscn",
    "leaderboard":   "res://scenes/leaderboard.tscn",
    "landing":       "res://scenes/landing.tscn",
    "main_menu":     "res://scenes/planet_select.tscn",
}

var player_name:    String     = ""
var player_avatar:  int        = 0
var selected_planet:Dictionary = {}
var badges_earned:  Array[String] = []
var first_play:     bool       = true
var is_admin:       bool       = false   # โหมดผู้ดูแลระบบ (ล็อกอินด้วย superadmin)
var last_player_name: String   = ""      # ชื่อผู้เล่นล่าสุดที่ login — ใช้เช็คว่าเป็นคนละคนกับครั้งก่อน

var current_hp:        float = 100.0
var current_energy:    float = 100.0
var current_score:     int   = 0
var time_remaining:    float = 0.0
var journey_progress:  float = 0.0
var is_game_running:   bool  = false

const MAX_HP:     float = 100.0
const MAX_ENERGY: float = 100.0

func go_to_scene(key: String) -> void:
    if not SCENES.has(key):
        push_error("GameManager: scene key '%s' ไม่มีใน SCENES" % key)
        return
    # ใช้ call_deferred เพื่อเลี่ยงการเปลี่ยนฉาก (ซึ่งจะลบ CollisionObject
    # ของฉากเดิม) ขณะที่ยังอยู่ใน physics callback (เช่น ถูกเรียกจาก
    # _on_obstacle_entered ตอนชน) — ป้องกัน error/จอดำ
    get_tree().call_deferred("change_scene_to_file", SCENES[key])

func start_mission(planet: Dictionary) -> void:
    selected_planet  = planet.duplicate()
    # ใช้เวลาที่ admin ตั้งค่าไว้ (ถ้ามี) แทนค่า time_limit เดิมจาก planets.json
    var time_limit: float = GameSettings.get_planet_time(
        selected_planet.get("id", ""), float(planet.get("time_limit", 300)))
    selected_planet["time_limit"] = time_limit
    current_hp       = MAX_HP
    current_energy   = MAX_ENERGY
    current_score    = 0
    journey_progress = 0.0
    time_remaining   = time_limit
    badges_earned.clear()
    is_game_running  = true

func take_damage(dmg: float) -> void:
    current_hp = maxf(0.0, current_hp - dmg)
    hp_changed.emit(current_hp)
    if current_hp <= 0.0:
        _trigger_game_over()

func heal(amount: float) -> void:
    current_hp = minf(MAX_HP, current_hp + amount)
    hp_changed.emit(current_hp)

func use_energy(amount: float) -> void:
    current_energy = maxf(0.0, current_energy - amount)
    energy_changed.emit(current_energy)
    if current_energy <= 0.0:
        _trigger_game_over()

func restore_energy(amount: float) -> void:
    current_energy = minf(MAX_ENERGY, current_energy + amount)
    energy_changed.emit(current_energy)

func add_score(pts: int) -> void:
    current_score += pts
    score_changed.emit(current_score)

# ── ถ้าพลัง/energy เต็มอยู่แล้ว ให้แปลงเป็น coin แทนของที่จะเสียเปล่า ──
func heal_or_score(amount: float, score_value: int) -> void:
    if current_hp >= MAX_HP:
        add_score(score_value)
        coin_overflow_awarded.emit(score_value)
    else:
        heal(amount)

func restore_energy_or_score(amount: float, score_value: int) -> void:
    if current_energy >= MAX_ENERGY:
        add_score(score_value)
        coin_overflow_awarded.emit(score_value)
    else:
        restore_energy(amount)

func tick_timer(delta: float) -> void:
    if not is_game_running:
        return
    time_remaining = maxf(0.0, time_remaining - delta)
    var total_time: float = maxf(1.0, selected_planet.get("time_limit", 60.0))
    journey_progress = clampf(1.0 - (time_remaining / total_time), 0.0, 1.0)
    if time_remaining <= 0.0:
        complete_mission()

func complete_mission() -> void:
    is_game_running = false
    _check_badges()
    LeaderboardManager.save_result()
    # หมายเหตุ: ไม่เรียก go_to_scene() ที่นี่ — ผู้ฟัง signal (gameplay.gd)
    # เป็นผู้รับผิดชอบการเปลี่ยนฉากแต่เพียงผู้เดียว เพื่อป้องกันการเปลี่ยนฉากซ้ำ
    mission_complete.emit()

func _trigger_game_over() -> void:
    is_game_running = false
    game_over_triggered.emit()
    go_to_scene("game_over")

func _check_badges() -> void:
    if journey_progress >= 1.0: _award("Mission Complete")
    if current_hp >= 80.0:      _award("Iron Shield")
    if current_energy >= 50.0:  _award("Eco Pilot")
    if current_score >= 50000:  _award("Star Collector")
    if first_play:
        _award("First Flight")
        first_play = false
    var diff: int = selected_planet.get("difficulty", 1)
    if diff >= 4: _award("Deep Space Pioneer")
    if diff >= 5: _award("Pluto Legend")

func _award(badge_name: String) -> void:
    if not badges_earned.has(badge_name):
        badges_earned.append(badge_name)
