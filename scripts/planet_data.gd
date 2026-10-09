extends Node
# ==============================================================
#  planet_data.gd  —  Autoload Singleton  ชื่อ "PlanetData"
#  โหลดข้อมูลดาวทั้งหมดจาก data/planets.json
#  ระบบสุริยะ: ดวงจันทร์, พุธ, ศุกร์, โลก, อังคาร,
#              พฤหัส, เสาร์, ยูเรนัส, เนปจูน, พลูโต
# ==============================================================

var planets: Array[Dictionary] = []

func _ready() -> void:
	_load_planets()

func _load_planets() -> void:
	var path := "res://data/planets.json"
	if not FileAccess.file_exists(path):
		push_warning("PlanetData: ไม่พบ planets.json — ใช้ข้อมูลสำรอง")
		_load_fallback()
		return
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Array:
		for item in parsed:
			planets.append(item)
	else:
		push_error("PlanetData: JSON format ผิดพลาด")
		_load_fallback()

func get_planet(id: String) -> Dictionary:
	for p in planets:
		if p.get("id", "") == id:
			return p
	return {}

func get_planets_sorted() -> Array[Dictionary]:
	var sorted := planets.duplicate()
	sorted.sort_custom(func(a, b): return a.get("difficulty", 1) < b.get("difficulty", 1))
	return sorted

func _load_fallback() -> void:
	planets = [
		{ "id":"moon",    "name_th":"ดวงจันทร์",    "name_en":"Moon",
		  "distance_km":384400,       "difficulty":1, "time_limit":120,
		  "gravity":1.62,  "temperature_avg":-53,  "diameter_km":3474,
		  "spawn_rate":2.0,"obstacle_speed_mult":0.8,"max_obstacles":2,
		  "star_rating_time":[70,95,120],  "color_hex":"#b0b8d0",
		  "fun_fact":"ดวงจันทร์ห่างจากโลก 384,400 กม. แสงใช้เวลา 1.28 วินาทีเดินทางถึง",
		  "difficulty_label":"ง่าย ★","difficulty_color":"#4ade80" },

		{ "id":"mercury", "name_th":"ดาวพุธ",       "name_en":"Mercury",
		  "distance_km":91700000,     "difficulty":2, "time_limit":210,
		  "gravity":3.70,  "temperature_avg":167,   "diameter_km":4879,
		  "spawn_rate":1.6,"obstacle_speed_mult":1.0,"max_obstacles":3,
		  "star_rating_time":[140,175,210], "color_hex":"#9a9080",
		  "fun_fact":"ดาวพุธโคจรรอบดวงอาทิตย์ครบรอบในเวลาเพียง 88 วัน เร็วที่สุดในระบบสุริยะ",
		  "difficulty_label":"ปานกลาง ★★","difficulty_color":"#fbbf24" },

		{ "id":"venus",   "name_th":"ดาวศุกร์",     "name_en":"Venus",
		  "distance_km":261000000,    "difficulty":2, "time_limit":240,
		  "gravity":8.87,  "temperature_avg":464,   "diameter_km":12104,
		  "spawn_rate":1.5,"obstacle_speed_mult":1.1,"max_obstacles":3,
		  "star_rating_time":[160,200,240], "color_hex":"#d4a060",
		  "fun_fact":"ดาวศุกร์ร้อนที่สุดในระบบสุริยะ 464°C เพราะบรรยากาศ CO₂ หนาทำให้เกิดเรือนกระจก",
		  "difficulty_label":"ปานกลาง ★★","difficulty_color":"#fbbf24" },

		{ "id":"earth",   "name_th":"โลก",          "name_en":"Earth",
		  "distance_km":0,            "difficulty":1, "time_limit":150,
		  "gravity":9.81,  "temperature_avg":15,    "diameter_km":12742,
		  "spawn_rate":1.8,"obstacle_speed_mult":0.9,"max_obstacles":3,
		  "star_rating_time":[100,125,150], "color_hex":"#3a7bd5",
		  "fun_fact":"โลกเป็นดาวเคราะห์เพียงดวงเดียวที่เรารู้ว่ามีสิ่งมีชีวิตอาศัยอยู่ และมีน้ำของเหลวปกคลุมผิวกว่า 70%",
		  "difficulty_label":"🏠 ฐานปฏิบัติการ","difficulty_color":"#60a5fa" },

		{ "id":"mars",    "name_th":"ดาวอังคาร",    "name_en":"Mars",
		  "distance_km":225000000,    "difficulty":2, "time_limit":300,
		  "gravity":3.72,  "temperature_avg":-60,   "diameter_km":6779,
		  "spawn_rate":1.4,"obstacle_speed_mult":1.2,"max_obstacles":4,
		  "star_rating_time":[200,250,300], "color_hex":"#c06840",
		  "fun_fact":"Olympus Mons สูง 21.9 กม. เป็นภูเขาไฟที่สูงที่สุดในระบบสุริยะ สูงกว่าเอเวอเรสต์ 3 เท่า!",
		  "difficulty_label":"ปานกลาง ★★","difficulty_color":"#fbbf24" },

		{ "id":"jupiter", "name_th":"ดาวพฤหัสบดี",  "name_en":"Jupiter",
		  "distance_km":778500000,    "difficulty":3, "time_limit":480,
		  "gravity":24.79, "temperature_avg":-110,  "diameter_km":139820,
		  "spawn_rate":1.0,"obstacle_speed_mult":1.5,"max_obstacles":5,
		  "star_rating_time":[320,400,480], "color_hex":"#c89060",
		  "fun_fact":"ดาวพฤหัสบดีใหญ่กว่าโลก 1,321 เท่า! พายุ Great Red Spot พัดมากว่า 350 ปีแล้ว",
		  "difficulty_label":"ยาก ★★★","difficulty_color":"#f87171" },

		{ "id":"saturn",  "name_th":"ดาวเสาร์",     "name_en":"Saturn",
		  "distance_km":1432000000,   "difficulty":3, "time_limit":660,
		  "gravity":10.44, "temperature_avg":-140,  "diameter_km":116460,
		  "spawn_rate":0.8,"obstacle_speed_mult":1.8,"max_obstacles":6,
		  "star_rating_time":[440,550,660], "color_hex":"#d0a860",
		  "fun_fact":"วงแหวนดาวเสาร์กว้าง 282,000 กม. แต่หนาเพียง 10–100 เมตร! ดาวเสาร์เบากว่าน้ำ",
		  "difficulty_label":"ยาก ★★★","difficulty_color":"#f87171" },

		{ "id":"uranus",  "name_th":"ดาวยูเรนัส",   "name_en":"Uranus",
		  "distance_km":2867000000,   "difficulty":4, "time_limit":780,
		  "gravity":8.69,  "temperature_avg":-195,  "diameter_km":50724,
		  "spawn_rate":0.7,"obstacle_speed_mult":2.0,"max_obstacles":6,
		  "star_rating_time":[520,650,780], "color_hex":"#60a0c0",
		  "fun_fact":"ดาวยูเรนัสเอียง 98° หมุนเหมือนกลิ้งไปรอบดวงอาทิตย์ และเย็นที่สุด -224°C!",
		  "difficulty_label":"ยากมาก ★★★★","difficulty_color":"#e040fb" },

		{ "id":"neptune", "name_th":"ดาวเนปจูน",    "name_en":"Neptune",
		  "distance_km":4515000000,   "difficulty":4, "time_limit":900,
		  "gravity":11.15, "temperature_avg":-200,  "diameter_km":49244,
		  "spawn_rate":0.6,"obstacle_speed_mult":2.2,"max_obstacles":7,
		  "star_rating_time":[600,750,900], "color_hex":"#2040c0",
		  "fun_fact":"ดาวเนปจูนมีพายุเร็วที่สุดในระบบสุริยะ 2,100 กม./ชั่วโมง! เร็วกว่าพายุโลก 10 เท่า",
		  "difficulty_label":"ยากมาก ★★★★","difficulty_color":"#e040fb" },

		{ "id":"pluto",   "name_th":"พลูโต",        "name_en":"Pluto",
		  "distance_km":5906000000,   "difficulty":5, "time_limit":1080,
		  "gravity":0.62,  "temperature_avg":-229,  "diameter_km":2377,
		  "spawn_rate":0.4,"obstacle_speed_mult":2.8,"max_obstacles":8,
		  "star_rating_time":[720,900,1080], "color_hex":"#8090a0",
		  "fun_fact":"ยาน New Horizons พบหัวใจสีขาวขนาดใหญ่บนพื้นผิวพลูโตในปี 2015! 1 ปีบนพลูโต = 248 ปีโลก",
		  "difficulty_label":"โหดสุด ★★★★★","difficulty_color":"#c060f0" },
	]
