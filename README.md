# Cosmos Explorer — Educational Space Game
## Godot 4.4.1 | Touch Screen 16:9 | Windows

### วิธีติดตั้ง
1. เปิด Godot 4.4.1 → Import → เลือก project.godot
2. รอ import เสร็จ → กด Play (F5)

### โครงสร้างไฟล์
```
cosmos_explorer/
├── project.godot          ← ตั้งค่าโปรเจกต์
├── data/
│   ├── planets.json       ← ข้อมูลดาว 9 ดวง (ครบระบบสุริยะ)
│   └── quiz_questions.json← คำถาม + Science Tips
├── scenes/
│   ├── attract.tscn       ← หน้า Idle/Attract
│   ├── login.tscn         ← Login + Avatar
│   ├── how_to_play.tscn   ← วิธีเล่น
│   ├── planet_select.tscn ← Galaxy Map เลือกดาว
│   ├── gameplay.tscn      ← เกมหลัก
│   ├── win.tscn           ← ชนะ
│   ├── game_over.tscn     ← แพ้
│   ├── leaderboard.tscn   ← อันดับ
│   ├── obstacles/         ← asteroid, comet, meteor, debris, stardust
│   ├── powerups/          ← shield, quiz, energy, score
│   └── ui/
│       └── planet_node.tscn← ดาวแต่ละดวงบน map
├── scripts/               ← GDScript ทั้งหมด (แยกไฟล์)
└── assets/
    ├── sprites/           ← ใส่ภาพ PNG ตามโฟลเดอร์
    │   ├── ships/         ← ship_rocket.png, ship_ufo.png, ship_star.png
    │   ├── planets/       ← moon.png, mercury.png, venus.png ... pluto.png
    │   ├── obstacles/     ← asteroid.png, comet.png, meteor.png, debris.png
    │   ├── powerups/      ← shield.png, quiz.png, energy.png, score.png
    │   └── ui/            ← bg_stars.png, sun.png
    ├── audio/
    │   ├── bgm/           ← bgm_attract.ogg, bgm_menu.ogg, bgm_gameplay.ogg
    │   │                     bgm_intense.ogg, bgm_win.ogg, bgm_gameover.ogg
    │   └── sfx/           ← sfx_boost.ogg, sfx_hit.ogg, sfx_explosion.ogg
    │                         sfx_powerup.ogg, sfx_correct.ogg, sfx_wrong.ogg
    │                         sfx_click.ogg, sfx_shield.ogg, sfx_countdown.ogg
    │                         sfx_landing.ogg
    └── fonts/             ← (optional) NotoSansThai-Regular.ttf

### Autoload ลำดับ (Project → Autoload)
1. UITheme        → scripts/ui_theme.gd
2. GameManager    → scripts/game_manager.gd
3. TouchInput     → scripts/touch_input.gd
4. PlanetData     → scripts/planet_data.gd
5. QuizManager    → scripts/quiz_manager.gd
6. LeaderboardManager → scripts/leaderboard_manager.gd
7. SoundManager   → scripts/sound_manager.gd

### ดาวทั้งหมด 9 ดวง + ความยาก
| ดาว          | ความยาก    | เวลา   |
|-------------|-----------|-------|
| ดวงจันทร์   | ง่าย ★     | 2 นาที |
| ดาวพุธ      | ปานกลาง ★★ | 3.5 นาที |
| ดาวศุกร์    | ปานกลาง ★★ | 4 นาที |
| ดาวอังคาร   | ปานกลาง ★★ | 5 นาที |
| ดาวพฤหัสบดี | ยาก ★★★   | 8 นาที |
| ดาวเสาร์    | ยากมาก ★★★★| 11 นาที|
| ดาวยูเรนัส  | ยากมาก ★★★★| 13 นาที|
| ดาวเนปจูน   | ยากมาก ★★★★| 15 นาที|
| พลูโต       | โหดสุด ★★★★★| 18 นาที|

### Assets ที่ต้องเตรียมเอง
- ภาพดาวเคราะห์ (PNG ขนาด 128x128 ขึ้นไป)
- ภาพยานอวกาศ 3 แบบ
- ภาพ obstacle 5 แบบ
- เสียง BGM และ SFX (OGG format)
- แนะนำ: ใช้ Kenney.nl (free assets) หรือ OpenGameArt.org

### Touch Screen Setup
- แบ่งจอ 3 โซน: ซ้าย (เลี้ยวซ้าย) | กลาง (Boost) | ขวา (เลี้ยวขวา)
- ระบบจัดการโดย TouchInput.gd autoload (แนวทาง B)
- ทดสอบบน PC: A/D = เลี้ยว, Space = Boost
