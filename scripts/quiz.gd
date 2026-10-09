extends CanvasLayer
# ==============================================================
#  quiz.gd  —  attach กับ CanvasLayer "QuizPopup" ใน gameplay.tscn
#  หยุดเกมชั่วคราวและแสดงคำถาม
# ==============================================================

@onready var quiz_bg:         ColorRect     = $QuizBG
@onready var panel:           PanelContainer= $Panel
@onready var quiz_title:      Label         = $Panel/QuizVBox/QuizTitle
@onready var question_label:  Label         = $Panel/QuizVBox/QuestionLabel
@onready var answer_container:GridContainer = $Panel/QuizVBox/AnswerGrid
@onready var art_icon:        Label         = $Panel/QuizVBox/QuizArt/ArtIcon
@onready var feedback_panel:  PanelContainer= $Panel/QuizVBox/FeedbackPanel
@onready var feedback_label:  Label         = $Panel/QuizVBox/FeedbackPanel/FeedbackLabel
@onready var close_timer:     Timer         = $CloseTimer
@onready var bonus_label:     Label         = $Panel/QuizVBox/BonusLabel
@onready var quiz_art:        Control       = $Panel/QuizVBox/QuizArt

# กล่องผลคำตอบ: กว้างเท่าแถวปุ่มคำตอบ (2×270 + ช่องว่าง 16) ให้อยู่ในช่องมืดของกรอบ
const FEEDBACK_W := 556.0
var _panel_offsets: Array = []

const ANSWER_COUNT: int = 4
const ANSWER_TEXT_W := 236.0      # ความกว้างข้อความในปุ่ม (ปุ่ม 270 − ขอบใน)
const ANSWER_FONT_LONG := 21      # ขนาดตัวอักษรสำหรับคำตอบยาว
var _correct_index: int  = -1
var _answered:      bool = false

func _ready() -> void:
    layer = 10   # วางบนสุด
    process_mode = Node.PROCESS_MODE_ALWAYS
    hide()
    close_timer.one_shot = true
    close_timer.timeout.connect(_close_quiz)
    feedback_panel.hide()
    bonus_label.hide()
    _panel_offsets = [panel.offset_left, panel.offset_top, panel.offset_right, panel.offset_bottom]
    _apply_styles()
    _start_art_pulse()

func _apply_styles() -> void:
    _apply_frame_texture()
    quiz_title.add_theme_font_size_override("font_size", 34)
    quiz_title.add_theme_color_override("font_color", Color(1.0, 0.86, 1.0))
    quiz_title.add_theme_color_override("font_outline_color", Color(0.22, 0.08, 0.40))
    quiz_title.add_theme_constant_override("outline_size", 8)
    question_label.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
    question_label.add_theme_color_override("font_color", UITheme.C_TEXT_WHITE)
    answer_container.add_theme_constant_override("h_separation", 16)
    answer_container.add_theme_constant_override("v_separation", 16)
    _set_feedback_style(true)
    feedback_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    feedback_panel.size_flags_vertical   = Control.SIZE_SHRINK_BEGIN   # ชิดใต้ปุ่มคำตอบ ห่างจากมุมล่างของกรอบ
    feedback_panel.custom_minimum_size   = Vector2(FEEDBACK_W, 0)
    feedback_label.add_theme_font_size_override("font_size", 22)
    feedback_label.add_theme_color_override("font_color", UITheme.C_TEXT_WHITE)
    bonus_label.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
    art_icon.add_theme_font_size_override("font_size", 120)
    art_icon.modulate.a = 0.55

# ── ไอคอนตกแต่งกลางช่องว่างของกล่องคำถาม ลอยเบาๆ ให้ดูมีชีวิตชีวา ──
func _start_art_pulse() -> void:
    var tween := create_tween().set_loops()
    tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_property(art_icon, "scale", Vector2(1.08, 1.08), 1.6) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(art_icon, "scale", Vector2(1.0, 1.0), 1.6) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ──────────────────────────────────────────────────────────────
func show_quiz() -> void:
    var q: Dictionary = QuizManager.get_random_question()
    if q.is_empty():
        return

    # หยุดเกม (CockpitView จะหยุดเอง เพราะ _process ตรวจ is_game_running)
    get_tree().paused = true

    _answered       = false
    _correct_index  = q.get("correct", 0)

    question_label.text = q.get("question", "")
    feedback_panel.hide()
    bonus_label.hide()
    quiz_art.show()   # เครื่องหมาย ? แสดงระหว่างรอเลือกคำตอบ
    _set_compact(false)
    # คืนขนาดกรอบเดิมทุกครั้ง (กันกรอบค้างขนาดใหญ่จากคำถามก่อนหน้า)
    if _panel_offsets.size() == 4:
        panel.offset_left   = _panel_offsets[0]
        panel.offset_top    = _panel_offsets[1]
        panel.offset_right  = _panel_offsets[2]
        panel.offset_bottom = _panel_offsets[3]

    # ล้างปุ่มเก่า
    for child in answer_container.get_children():
        child.queue_free()

    # สร้างปุ่มคำตอบ
    var answers: Array = q.get("answers", [])
    for i in mini(ANSWER_COUNT, answers.size()):
        var btn := Button.new()
        btn.text                    = answers[i]
        btn.custom_minimum_size     = Vector2(270, 64)   # พอดีช่องมืดของกรอบ quiz_frame (กว้าง ~616px)
        # คำตอบยาว → ขึ้นบรรทัดใหม่แทนการขยายปุ่มจนล้นกรอบ
        btn.autowrap_mode           = TextServer.AUTOWRAP_WORD_SMART
        btn.size_flags_horizontal   = Control.SIZE_FILL
        btn.pressed.connect(_on_answer_pressed.bind(i, q))
        UITheme.style_button(btn, Color(0.14, 0.10, 0.28), UITheme.C_TEXT_WHITE, 14)
        # คำตอบยาวเกินหนึ่งบรรทัด → ลดขนาดตัวอักษร ให้ 2 บรรทัดยังพอดีความสูงปุ่ม (กล่องผลไม่ถูกดันทับกรอบ)
        var fnt: Font = btn.get_theme_font("font")
        var fsz: int = btn.get_theme_font_size("font_size")
        if fnt and fnt.get_string_size(answers[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x > ANSWER_TEXT_W:
            btn.add_theme_font_size_override("font_size", ANSWER_FONT_LONG)
        answer_container.add_child(btn)

    show()

# ──────────────────────────────────────────────────────────────
func _on_answer_pressed(idx: int, q: Dictionary) -> void:
    if _answered:
        return
    _answered = true

    # Lock ปุ่มทั้งหมด
    for child in answer_container.get_children():
        child.disabled = true

    var btns := answer_container.get_children()

    if idx == _correct_index:
        # ถูก → highlight เขียว + รับ bonus พลังชีวิต (หรือ coin ถ้าพลังเต็มแล้ว)
        if btns.size() > idx:
            btns[idx].modulate = Color(0.3, 1.0, 0.4)
        var hp_was_full: bool = GameManager.current_hp >= GameManager.MAX_HP
        var bonus: int = GameSettings.overflow_coin_bonus
        GameManager.heal_or_score(20.0, bonus)
        # รางวัลรวมไว้ในบรรทัดแรกของกล่องผล → ทุกอย่างอยู่ในช่องมืดของกรอบ
        var reward: String = ("+%d 🪙" % bonus) if hp_was_full else "+20 HP!"
        feedback_label.text = "✅ เยี่ยมมาก!  " + reward + "\n" + q.get("fun_fact", "")
        _set_feedback_style(true)
        SoundManager.play_sfx("quiz_correct")
    else:
        # ผิด → highlight แดง + เฉลย
        if btns.size() > idx:
            btns[idx].modulate = Color(1.0, 0.3, 0.3)
        if btns.size() > _correct_index:
            btns[_correct_index].modulate = Color(0.3, 1.0, 0.4)
        feedback_label.text = "❌ ยังไม่ใช่...\n" + q.get("fun_fact", "")
        _set_feedback_style(false)
        SoundManager.play_sfx("quiz_wrong")

    quiz_art.hide()   # เอาเครื่องหมาย ? ออก แล้วแสดงกล่องผลแทนที่
    _set_compact(true)
    feedback_panel.show()
    close_timer.wait_time = 5.0
    close_timer.start()

# ──────────────────────────────────────────────────────────────
func _close_quiz() -> void:
    hide()
    get_tree().paused = false
    # resume_from_quiz() ใน gameplay.gd จัดการ unpausing ให้แล้ว
    if get_parent().has_method("resume_from_quiz"):
        get_parent().resume_from_quiz()


# ==============================================================
#  กรอบกล่องคำถาม — ใช้รูป quiz_frame.png (กรอบม่วง-ชมพูเรืองแสง)
#  9-slice: มุมคงรูป ตรงกลางยืดได้ถ้าเนื้อหายาวกว่าปกติ
#  content margin: หัวข้อ "Science Quiz!" อยู่ในแถบด้านบน, คำถาม/คำตอบอยู่ในพื้นที่มืดตรงกลาง
# ==============================================================
const QUIZ_FRAME_TEX := "res://assets/ui/quiz_frame.png"

func _apply_frame_texture() -> void:
    var tex := load(QUIZ_FRAME_TEX) as Texture2D
    if tex == null:
        panel.add_theme_stylebox_override("panel",
            UITheme.make_panel_style(UITheme.C_BG_CARD, UITheme.C_BORDER_PURPLE, UITheme.PANEL_RADIUS, 3, 28))
        return
    var sb := StyleBoxTexture.new()
    sb.texture = tex
    # ขอบ 9-slice (พิกเซลของรูป 760×559) — ครอบมุมและของตกแต่งไว้ไม่ให้ยืด
    sb.texture_margin_left   = 150
    sb.texture_margin_right  = 150
    sb.texture_margin_top    = 150
    sb.texture_margin_bottom = 140
    # ระยะเนื้อหาด้านใน (ให้อยู่ในช่องมืดของกรอบ)
    sb.content_margin_left   = 75   # ซ้าย-ขวาเท่ากันจากขอบในของกรอบถึงปุ่มคำตอบ
    sb.content_margin_right  = 69
    sb.content_margin_top    = 64   # หัวข้อ Science Quiz! อยู่กึ่งกลางแถบด้านบน
    sb.content_margin_bottom = 66
    panel.add_theme_stylebox_override("panel", sb)
    _add_quiz_spacers()

# เว้นระยะ: ใต้หัวข้อ (ดันคำถามลงมาในช่องมืด) และ ระหว่างคำถามกับปุ่มคำตอบ
const GAP_TITLE_TO_QUESTION := 30
const GAP_QUESTION_TO_ANSWERS := 26
const GAP_ANSWERS_TO_FEEDBACK := 14

func _add_quiz_spacers() -> void:
    var vbox := quiz_title.get_parent()
    if vbox.has_node("SpacerTitle"):
        return
    var s1 := Control.new()
    s1.name = "SpacerTitle"
    s1.custom_minimum_size = Vector2(0, GAP_TITLE_TO_QUESTION)
    s1.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vbox.add_child(s1)
    vbox.move_child(s1, quiz_title.get_index() + 1)
    var s2 := Control.new()
    s2.name = "SpacerQuestion"
    s2.custom_minimum_size = Vector2(0, GAP_QUESTION_TO_ANSWERS)
    s2.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vbox.add_child(s2)
    vbox.move_child(s2, question_label.get_index() + 1)
    # ช่องว่างระหว่างปุ่มคำตอบกับกล่องผล (แสดงเฉพาะหลังเลือกคำตอบ)
    var s3 := Control.new()
    s3.name = "SpacerFeedback"
    s3.custom_minimum_size = Vector2(0, GAP_ANSWERS_TO_FEEDBACK)
    s3.mouse_filter = Control.MOUSE_FILTER_IGNORE
    s3.visible = false
    vbox.add_child(s3)
    vbox.move_child(s3, feedback_panel.get_index())

# สไตล์กล่องผลคำตอบ: เขียว = ถูก, แดง = ผิด (padding บางลงให้พอดีพื้นที่ในกรอบ)
func _set_feedback_style(correct: bool) -> void:
    var sb := UITheme.make_panel_style(
        Color(0.10, 0.30, 0.14, 0.88) if correct else Color(0.34, 0.08, 0.12, 0.88),
        UITheme.C_ACCENT_GREEN if correct else Color(1.0, 0.40, 0.45), 14, 2)
    sb.content_margin_left   = 16
    sb.content_margin_right  = 16
    sb.content_margin_top    = 6
    sb.content_margin_bottom = 6
    sb.shadow_size = 0
    feedback_panel.add_theme_stylebox_override("panel", sb)

# หลังเลือกคำตอบ: ลดช่องว่างระหว่างหัวข้อ/คำถาม/ปุ่ม ให้กล่องผลอยู่ในช่องมืดของกรอบ ไม่ทับมุมล่าง
func _set_compact(on: bool) -> void:
    var vbox := quiz_title.get_parent()
    if vbox.has_node("SpacerTitle"):
        (vbox.get_node("SpacerTitle") as Control).custom_minimum_size.y = 30.0 if on else float(GAP_TITLE_TO_QUESTION)
    if vbox.has_node("SpacerQuestion"):
        (vbox.get_node("SpacerQuestion") as Control).custom_minimum_size.y = 14.0 if on else float(GAP_QUESTION_TO_ANSWERS)
    if vbox.has_node("SpacerFeedback"):
        (vbox.get_node("SpacerFeedback") as Control).visible = on
    answer_container.add_theme_constant_override("v_separation", 10 if on else 16)
    for b in answer_container.get_children():
        (b as Control).custom_minimum_size.y = 54.0 if on else 64.0   # ปุ่มเตี้ยลงเล็กน้อย เผื่อที่ให้กล่องผล
