extends Node2D
# ==============================================================
#  powerup_spawner.gd  —  attach กับ "PowerupSpawner" ใน gameplay.tscn
# ==============================================================

@onready var powerup_timer: Timer = $PowerupTimer

const POWERUP_SCENES: Dictionary = {
	"shield": "res://scenes/powerups/shield_item.tscn",
	"quiz":   "res://scenes/powerups/quiz_item.tscn",
	"energy": "res://scenes/powerups/energy_item.tscn",
	"score":  "res://scenes/powerups/score_item.tscn",
}

# โอกาสออก (รวม = 100)
const SPAWN_WEIGHTS: Dictionary = {
	"energy": 40,
	"shield": 25,
	"quiz":   25,
	"score":  10,
}

const SPAWN_MARGIN: float = 100.0

func _ready() -> void:
	powerup_timer.wait_time = GameSettings.powerup_drop_interval
	powerup_timer.timeout.connect(_spawn_powerup)
	GameSettings.settings_changed.connect(_on_settings_changed)

func _on_settings_changed() -> void:
	powerup_timer.wait_time = GameSettings.powerup_drop_interval

func _spawn_powerup() -> void:
	if not GameManager.is_game_running:
		return
	var type: String = _weighted_random()
	print("[PowerupSpawner] roll -> ", type)   # DEBUG: เช็คว่า roll ออก shield จริงไหม — เอาออกได้หลังตรวจสอบเสร็จ
	if not POWERUP_SCENES.has(type):
		push_warning("[PowerupSpawner] type '%s' ไม่มีใน POWERUP_SCENES — ข้ามรอบนี้" % type)
		return
	var scene: PackedScene = load(POWERUP_SCENES[type])
	if scene == null:
		push_warning("[PowerupSpawner] โหลดไฟล์ของ '%s' ไม่สำเร็จ: %s" % [type, POWERUP_SCENES[type]])
		return
	var vp_width: float = get_viewport_rect().size.x
	var item: Node2D = scene.instantiate()
	item.position = Vector2(
		randf_range(SPAWN_MARGIN, vp_width - SPAWN_MARGIN),
		-80.0
	)
	item.set("powerup_type", type)
	item.add_to_group("powerups")
	add_child(item)
	print("[PowerupSpawner] spawned '%s' at %s" % [type, item.position])   # DEBUG

func _weighted_random() -> String:
	var total: int = 0
	for w in SPAWN_WEIGHTS.values():
		total += w
	var roll: int = randi() % total
	var cumulative: int = 0
	for key in SPAWN_WEIGHTS:
		cumulative += SPAWN_WEIGHTS[key]
		if roll < cumulative:
			return key
	return "energy"
