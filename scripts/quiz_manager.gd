extends Node
# ==============================================================
#  quiz_manager.gd  —  Autoload Singleton
#  ลงทะเบียนใน Project → Autoload  ชื่อ "QuizManager"
# ==============================================================

# คำถามแยกตามดาว: planet_id → Array ของคำถาม (จาก "planet_questions" ใน JSON)
var planet_questions: Dictionary  = {}
# คำถามทั่วไป (กลุ่ม "general") — คำถามง่าย แทรกช่วยผู้เล่น
var questions: Array[Dictionary] = []
var science_tips: Array[String]   = []
var last_question: Dictionary     = {}

# ── รูปแบบการหยิบ: คำถามของดาว 3 ข้อ → general 1 ข้อ → วนซ้ำจนจบด่าน ──
const PLANET_PER_GENERAL := 3

# ── สำรับคำถามแบบสุ่มที่บันทึกไว้ (ข้ามผู้เล่น/ข้ามการเปิดเกม) ──
# แต่ละกลุ่มมีลำดับที่สับไว้ + ตำแหน่งที่หยิบถึง:
#   "planet:moon" → { "order": [7, 2, 9, ...], "pos": 3 },  "general" → {...}
# คนถัดไปหยิบต่อจากตำแหน่งเดิม → ได้ข้อที่ยังไม่ถูกถามแบบสุ่ม
# หยิบครบทุกข้อแล้ว → สับลำดับใหม่
const PROGRESS_PATH := "user://quiz_progress.json"
const GENERAL_KEY   := "general"
var _decks: Dictionary = {}

# ── สถานะของด่านปัจจุบัน ──
var _stage_planet_id: String = ""
var _stage_started:   bool   = false
var _planet_streak:   int    = 0     # หยิบคำถามดาวติดกันมาแล้วกี่ข้อ
var _asked_in_stage:  Dictionary = {}   # ข้อความคำถามที่ถามไปแล้วในด่านนี้ (กันซ้ำ)

func _ready() -> void:
    _load_data()
    _load_progress()

func _load_data() -> void:
    var path := "res://data/quiz_questions.json"
    if FileAccess.file_exists(path):
        var f    := FileAccess.open(path, FileAccess.READ)
        var data  = JSON.parse_string(f.get_as_text())
        if data is Dictionary:
            if data.get("planet_questions") is Dictionary:
                planet_questions = data["planet_questions"]
            # "general" = รูปแบบใหม่, "questions" = รูปแบบเดิม (ยังอ่านได้)
            var general = data.get("general", data.get("questions", []))
            if general is Array:
                for q in general:
                    questions.append(q)
            if data.has("tips"):
                for t in data["tips"]:
                    science_tips.append(t)
            return
    _load_fallback()

# ── บันทึก/โหลดสำรับ ─────────────────────────────────────────
func _load_progress() -> void:
    if not FileAccess.file_exists(PROGRESS_PATH):
        return
    var data = JSON.parse_string(FileAccess.get_file_as_string(PROGRESS_PATH))
    if not (data is Dictionary and data.get("decks") is Dictionary):
        return   # ไฟล์รูปแบบเก่า/เสีย → เริ่มสับใหม่
    for key in data["decks"]:
        var d = data["decks"][key]
        if d is Dictionary and d.get("order") is Array:
            var order: Array = []
            for i in d["order"]:
                order.append(int(i))
            _decks[str(key)] = {"order": order, "pos": int(d.get("pos", 0))}

func _save_progress() -> void:
    var f := FileAccess.open(PROGRESS_PATH, FileAccess.WRITE)
    if f == null:
        push_warning("QuizManager: บันทึก %s ไม่ได้" % PROGRESS_PATH)
        return
    f.store_string(JSON.stringify({"decks": _decks}))

# ล้างสำรับทั้งหมด → สับใหม่ทุกกลุ่ม (เผื่อใช้ในหน้า admin)
func reset_progress() -> void:
    _decks.clear()
    _save_progress()

# ── เริ่มด่านใหม่ ─────────────────────────────────────────────
# เรียกจาก GameManager.start_mission() (ทั้งเริ่มด่านและกดเล่นซ้ำ)
func start_stage(planet_id: String) -> void:
    _stage_planet_id = planet_id
    _stage_started   = true
    _planet_streak   = 0
    _asked_in_stage.clear()

func _ensure_stage() -> void:
    if not _stage_started:
        start_stage(str(GameManager.selected_planet.get("id", "")))

func _planet_key() -> String:
    return "planet:" + _stage_planet_id

func _planet_pool() -> Array:
    return planet_questions.get(_stage_planet_id, []) as Array

func _pool_for(key: String) -> Array:
    return questions if key == GENERAL_KEY else _planet_pool()

# จำนวนคำถามของดาวในด่านนี้ (ใช้คำนวณรอบการออกกล่องคำถาม)
# ถ้าดาวนี้ไม่มีคำถามเฉพาะ → ใช้จำนวนคำถามทั่วไปแทน
func stage_question_count() -> int:
    _ensure_stage()
    var n: int = _planet_pool().size()
    return n if n > 0 else questions.size()

# สับลำดับใหม่ — ข้อที่ถามไปแล้วในด่านนี้ไว้ท้ายสำรับ (กันซ้ำในด่านเดียวกัน)
func _new_deck(key: String, pool: Array) -> Dictionary:
    var fresh: Array = []
    var asked: Array = []
    var order: Array = range(pool.size())
    order.shuffle()
    for i in order:
        if _asked_in_stage.has(pool[i].get("question", "")):
            asked.append(i)
        else:
            fresh.append(i)
    var d := {"order": fresh + asked, "pos": 0}
    _decks[key] = d
    return d

func _deck_for(key: String, pool: Array) -> Dictionary:
    var d: Dictionary = _decks.get(key, {})
    var order: Array = d.get("order", [])
    # ยังไม่มีสำรับ / จำนวนคำถามในไฟล์เปลี่ยน / หยิบครบแล้ว → สับใหม่
    if order.size() != pool.size() or int(d.get("pos", 0)) >= order.size():
        return _new_deck(key, pool)
    return d

# ข้อถัดไปของกลุ่มนั้น ({} = กลุ่มนี้หมดสำหรับด่านนี้)
func _peek(key: String) -> Dictionary:
    var pool := _pool_for(key)
    if pool.is_empty():
        return {}
    var d := _deck_for(key, pool)
    var q: Dictionary = pool[d["order"][d["pos"]]]
    return {} if _asked_in_stage.has(q.get("question", "")) else q

# ยังมีคำถามที่ยังไม่ได้ถามในด่านนี้เหลืออยู่ไหม (ดาว + ทั่วไป)
func has_question_left() -> bool:
    _ensure_stage()
    return not (_peek(_planet_key()).is_empty() and _peek(GENERAL_KEY).is_empty())

# หยิบคำถามถัดไปตามรูปแบบ ดาว 3 → general 1 → ดาว 3 → ...
# - ลำดับในแต่ละกลุ่มเป็นแบบสุ่ม และหยิบต่อจากที่ผู้เล่นคนก่อนค้างไว้
# - ถ้ากลุ่มที่ถึงคิวหมดแล้วในด่านนี้ → ใช้อีกกลุ่มแทน, หมดทั้งคู่ → คืน {}
# คำตอบถูกสลับตำแหน่งทุกครั้ง (ค่า "correct" ปรับตามให้แล้ว)
func get_random_question() -> Dictionary:
    _ensure_stage()
    var first  := GENERAL_KEY if _planet_streak >= PLANET_PER_GENERAL else _planet_key()
    var second := _planet_key() if first == GENERAL_KEY else GENERAL_KEY
    var key := first
    var q := _peek(first)
    if q.is_empty():
        key = second
        q = _peek(second)
    if q.is_empty():
        return {}

    _decks[key]["pos"] = int(_decks[key]["pos"]) + 1
    _planet_streak = 0 if key == GENERAL_KEY else _planet_streak + 1
    _asked_in_stage[q.get("question", "")] = true
    _save_progress()

    last_question = _shuffle_answers(q)
    return last_question

func _shuffle_answers(q: Dictionary) -> Dictionary:
    var out: Dictionary = q.duplicate(true)
    var answers: Array = out.get("answers", [])
    var correct: int = int(out.get("correct", 0))
    if answers.size() < 2 or correct < 0 or correct >= answers.size():
        return out
    var order: Array = range(answers.size())
    order.shuffle()
    var shuffled: Array = []
    for i in order:
        shuffled.append(answers[i])
    out["answers"] = shuffled
    out["correct"] = order.find(correct)
    return out

func get_random_tips(count: int) -> Array[String]:
    if science_tips.is_empty():
        return []
    var result: Array[String] = []
    var pool := science_tips.duplicate()
    pool.shuffle()
    for i in mini(count, pool.size()):
        result.append(pool[i])
    return result

func _load_fallback() -> void:
    questions = [
        {
            "question": "ดาวเคราะห์ใดใหญ่ที่สุดในระบบสุริยะ?",
            "answers": ["ดาวเสาร์", "ดาวพฤหัสบดี", "ดาวอังคาร", "ดาวศุกร์"],
            "correct": 1,
            "fun_fact": "ดาวพฤหัสบดีใหญ่กว่าโลกถึง 1,321 เท่า!"
        },
        {
            "question": "แสงอาทิตย์ใช้เวลานานแค่ไหนเดินทางถึงโลก?",
            "answers": ["8 วินาที", "8 นาที", "8 ชั่วโมง", "8 วัน"],
            "correct": 1,
            "fun_fact": "แสงเดินทางด้วยความเร็ว 300,000 กม./วินาที ใช้เวลา 8.3 นาทีถึงโลก"
        },
        {
            "question": "ดาวเคราะห์ใดมีวงแหวนที่โดดเด่นที่สุด?",
            "answers": ["ดาวอังคาร", "ดาวพฤหัสบดี", "ดาวเสาร์", "ดาวพุธ"],
            "correct": 2,
            "fun_fact": "วงแหวนดาวเสาร์ประกอบด้วยน้ำแข็งและหินขนาดต่างๆ"
        },
        {
            "question": "อุกกาบาตเคลื่อนที่ด้วยความเร็วประมาณเท่าไหร่?",
            "answers": ["2 กม./วินาที", "20 กม./วินาที", "200 กม./วินาที", "2,000 กม./วินาที"],
            "correct": 1,
            "fun_fact": "อุกกาบาตเฉลี่ยเคลื่อนที่ 20 กม./วินาที หรือ 72,000 กม./ชั่วโมง!"
        },
        {
            "question": "ดาวหางมีหางกี่เส้น?",
            "answers": ["1 เส้น", "2 เส้น", "3 เส้น", "ไม่มีหาง"],
            "correct": 1,
            "fun_fact": "ดาวหางมี 2 หาง คือหางฝุ่น (สีเหลือง) และหางไอออน (สีฟ้า)"
        },
        {
            "question": "ดาวเคราะห์ใดหมุนรอบตัวเองเร็วที่สุด?",
            "answers": ["โลก", "ดาวอังคาร", "ดาวพฤหัสบดี", "ดาวศุกร์"],
            "correct": 2,
            "fun_fact": "ดาวพฤหัสบดีหมุนรอบตัวเองครบรอบในเวลาเพียง 10 ชั่วโมง!"
        },
        {
            "question": "ขยะอวกาศมีจำนวนชิ้นส่วนที่โคจรรอบโลกประมาณกี่ชิ้น?",
            "answers": ["100 ชิ้น", "10,000 ชิ้น", "500,000 ชิ้น", "27,000+ ชิ้น"],
            "correct": 3,
            "fun_fact": "มีขยะอวกาศขนาดใหญ่กว่า 10 ซม. กว่า 27,000 ชิ้นโคจรรอบโลก!"
        },
        {
            "question": "โลกอยู่ห่างจากดวงอาทิตย์ประมาณเท่าไหร่?",
            "answers": ["15 ล้าน กม.", "150 ล้าน กม.", "1,500 ล้าน กม.", "15,000 ล้าน กม."],
            "correct": 1,
            "fun_fact": "ระยะทางนี้เรียกว่า 1 AU (Astronomical Unit) = 149.6 ล้าน กม."
        },
    ]
    science_tips = [
        "อุกกาบาตเคลื่อนที่เร็วกว่าหัวกระสุน 20 เท่า!",
        "ดาวหางมีหาง 2 เส้น: หางฝุ่นและหางไอออน",
        "ขยะอวกาศมีกว่า 27,000 ชิ้นโคจรรอบโลกอยู่ตอนนี้!",
        "แรงโน้มถ่วงบนดวงจันทร์น้อยกว่าโลก 6 เท่า",
        "ดาวพฤหัสบดีมีพายุ Great Red Spot ใหญ่กว่าโลก!",
        "ดาวศุกร์ร้อนที่สุดในระบบสุริยะ อุณหภูมิ 465°C",
        "เสียงไม่สามารถเดินทางในอวกาศได้ เพราะไม่มีอากาศ",
        "ดวงอาทิตย์มีมวลถึง 99.86% ของมวลระบบสุริยะทั้งหมด!",
        "สะเก็ดดาวคือชิ้นส่วนของดาวเคราะห์น้อยที่แตกออกมา",
        "ดาวตกคืออุกกาบาตที่เผาไหม้ในชั้นบรรยากาศ",
    ]
