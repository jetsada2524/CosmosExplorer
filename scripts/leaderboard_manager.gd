extends Node
# ==============================================================
#  leaderboard_manager.gd  —  Autoload Singleton
#  ลงทะเบียนใน Project → Autoload  ชื่อ "LeaderboardManager"
#  บันทึก/โหลดคะแนนลงไฟล์ user://leaderboard.json
# ==============================================================

const SAVE_PATH:   String = "user://leaderboard.json"
const MAX_ENTRIES: int    = 20

var entries: Array[Dictionary] = []
# ผลของรอบล่าสุดที่เพิ่งบันทึก (อ้างอิง Dictionary ตัวเดียวกับใน entries)
# ใช้ไฮไลต์แถวสีเขียวในตารางอันดับ — แถวที่ "เปลี่ยนแปลงอันดับ" จากคะแนนใหม่
var last_entry: Dictionary = {}

func _ready() -> void:
	load_data()

# ──────────────────────────────────────────────────────────────
func save_result() -> void:
	var entry := {
		"name":     GameManager.player_name,
		"avatar":   GameManager.player_avatar,
		"planet":   GameManager.selected_planet.get("name_th", "?"),
		"planet_id":GameManager.selected_planet.get("id", ""),
		"score":    GameManager.current_score,
		"time_used": _calc_time_used(),
		"hp_left":  GameManager.current_hp,
		"stars":    _calc_stars(),
		"badges":   GameManager.badges_earned.duplicate(),
		"timestamp": Time.get_datetime_string_from_system(),
	}
	entries.append(entry)
	last_entry = entry
	_sort_entries()
	if entries.size() > MAX_ENTRIES:
		entries = entries.slice(0, MAX_ENTRIES)
	_save_to_file()

func _calc_time_used() -> float:
	var limit: float = GameManager.selected_planet.get("time_limit", 300.0)
	return limit - GameManager.time_remaining

func _calc_stars() -> int:
	var planet   := GameManager.selected_planet
	var time_used := _calc_time_used()
	var thresholds: Array = planet.get("star_rating_time", [9999, 9999, 9999])
	if time_used <= thresholds[0]: return 3
	if time_used <= thresholds[1]: return 2
	return 1

# ──────────────────────────────────────────────────────────────
# แถวนี้คือคะแนนใหม่ล่าสุดที่เพิ่งเข้าตารางหรือไม่ (เทียบตัวอ้างอิงเดียวกัน ไม่ใช่เทียบค่า)
func is_latest(entry: Dictionary) -> bool:
	return not last_entry.is_empty() and is_same(entry, last_entry)

func get_top(n: int = 10) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in mini(n, entries.size()):
		result.append(entries[i])
	return result

func get_player_rank() -> int:
	for i in entries.size():
		if entries[i]["name"] == GameManager.player_name:
			return i + 1
	return -1

# หาอันดับของ "คะแนนรอบนี้" โดยเฉพาะ (ไม่ใช่อันดับที่ดีที่สุดที่เคยทำได้)
# ใช้ตอนแสดงผลหน้า Win เพื่อให้อันดับที่เห็นตรงกับคะแนนที่ผู้เล่นเพิ่งได้จริง
func get_rank_for_score(player_name: String, score: int) -> int:
	for i in entries.size():
		if entries[i]["name"] == player_name and int(entries[i]["score"]) == score:
			return i + 1
	return -1

func get_player_best() -> Dictionary:
	for e in entries:
		if e["name"] == GameManager.player_name:
			return e
	return {}

# ──────────────────────────────────────────────────────────────
func _sort_entries() -> void:
	entries.sort_custom(func(a, b): return a["score"] > b["score"])

func _save_to_file() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("LeaderboardManager: ไม่สามารถเปิดไฟล์เพื่อบันทึก")
		return
	f.store_string(JSON.stringify(entries, "\t"))

func load_data() -> void:
	entries.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Array:
		for item in parsed:
			if item is Dictionary:
				entries.append(item)

func clear_all() -> void:
	entries.clear()
	last_entry = {}
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
