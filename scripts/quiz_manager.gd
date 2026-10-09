extends Node
# ==============================================================
#  quiz_manager.gd  —  Autoload Singleton
#  ลงทะเบียนใน Project → Autoload  ชื่อ "QuizManager"
# ==============================================================

var questions: Array[Dictionary] = []
var science_tips: Array[String]   = []
var last_question: Dictionary     = {}
var _used_indices: Array[int]     = []

func _ready() -> void:
    _load_data()

func _load_data() -> void:
    var path := "res://data/quiz_questions.json"
    if FileAccess.file_exists(path):
        var f    := FileAccess.open(path, FileAccess.READ)
        var data  = JSON.parse_string(f.get_as_text())
        if data is Dictionary:
            if data.has("questions"):
                for q in data["questions"]:
                    questions.append(q)
            if data.has("tips"):
                for t in data["tips"]:
                    science_tips.append(t)
            return
    _load_fallback()

func get_random_question() -> Dictionary:
    if questions.is_empty():
        return {}
    # ไม่ซ้ำจนกว่าจะครบ
    if _used_indices.size() >= questions.size():
        _used_indices.clear()
    var available: Array[int] = []
    for i in questions.size():
        if not _used_indices.has(i):
            available.append(i)
    var idx: int = available[randi() % available.size()]
    _used_indices.append(idx)
    last_question = questions[idx]
    return last_question

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
