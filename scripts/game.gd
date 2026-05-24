extends Node2D

const SIZE := Vector2(960, 540)
const PLAYER_Y := 484.0
const PLAYER_SPEED := 420.0
const BULLET_SPEED := 650.0
const ENEMY_BULLET_SPEED := 250.0
const ENEMY_STEP_DOWN := 18.0
const ENEMY_COLS := 10
const ENEMY_ROWS := 4
const ENEMY_SPACING := Vector2(70, 44)
const ENEMY_SIZE := Vector2(34, 24)
const PLAYER_SIZE := Vector2(46, 28)
const SHOT_COOLDOWN := 0.22

var art: Texture2D = preload("res://assets/star_raid_sprite_sheet.png")
var player_x := SIZE.x * 0.5
var shot_timer := 0.0
var enemy_dir := 1.0
var enemy_speed := 42.0
var enemy_fire_timer := 1.0
var score := 0
var lives := 3
var wave := 1
var game_over := false
var won := false
var stars: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var enemy_shots: Array[Dictionary] = []
var blasts: Array[Dictionary] = []


func _ready() -> void:
	randomize()
	for i in 130:
		stars.append({
			"pos": Vector2(randf_range(0, SIZE.x), randf_range(0, SIZE.y)),
			"speed": randf_range(18.0, 100.0),
			"size": randf_range(1.0, 2.5),
			"color": Color(0.45 + randf() * 0.45, 0.75 + randf() * 0.25, 1.0, 0.35 + randf() * 0.55)
		})
	_spawn_wave()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept") and game_over:
		_restart()
	if game_over:
		_update_stars(delta)
		queue_redraw()
		return

	_update_stars(delta)
	_update_player(delta)
	_update_shots(delta)
	_update_enemies(delta)
	_update_enemy_fire(delta)
	_update_blasts(delta)
	_check_collisions()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		if game_over:
			_restart()
		else:
			player_x = clamp(event.position.x, 42.0, SIZE.x - 42.0)
			_fire()
	if event is InputEventScreenDrag:
		player_x = clamp(event.position.x, 42.0, SIZE.x - 42.0)


func _update_player(delta: float) -> void:
	var move := 0.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		move -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		move += 1.0
	player_x = clamp(player_x + move * PLAYER_SPEED * delta, 42.0, SIZE.x - 42.0)
	shot_timer = maxf(0.0, shot_timer - delta)
	if Input.is_action_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE):
		_fire()


func _fire() -> void:
	if shot_timer > 0.0:
		return
	shots.append({"pos": Vector2(player_x, PLAYER_Y - 25.0)})
	shot_timer = SHOT_COOLDOWN


func _update_stars(delta: float) -> void:
	for star in stars:
		star.pos.y += star.speed * delta
		if star.pos.y > SIZE.y:
			star.pos = Vector2(randf_range(0, SIZE.x), -8.0)


func _spawn_wave() -> void:
	enemies.clear()
	var start := Vector2(165, 82)
	for row in ENEMY_ROWS:
		for col in ENEMY_COLS:
			enemies.append({
				"pos": start + Vector2(col * ENEMY_SPACING.x, row * ENEMY_SPACING.y),
				"row": row,
				"phase": randf() * TAU,
				"alive": true
			})
	enemy_dir = 1.0
	enemy_speed = 42.0 + wave * 9.0
	enemy_fire_timer = 0.9


func _update_enemies(delta: float) -> void:
	var shift_down := false
	for enemy in enemies:
		enemy.pos.x += enemy_dir * enemy_speed * delta
		enemy.phase += delta * 5.0
		if enemy.pos.x < 42.0 or enemy.pos.x > SIZE.x - 42.0:
			shift_down = true
	if shift_down:
		enemy_dir *= -1.0
		for enemy in enemies:
			enemy.pos.y += ENEMY_STEP_DOWN
			if enemy.pos.y > PLAYER_Y - 45.0:
				_end_game(false)
	if enemies.is_empty():
		wave += 1
		score += 500
		_spawn_wave()


func _update_enemy_fire(delta: float) -> void:
	enemy_fire_timer -= delta
	if enemy_fire_timer > 0.0 or enemies.is_empty():
		return
	var shooter := enemies[randi() % enemies.size()]
	enemy_shots.append({"pos": shooter.pos + Vector2(0, 18)})
	enemy_fire_timer = randf_range(0.45, maxf(0.9, 1.7 - wave * 0.08))


func _update_shots(delta: float) -> void:
	for shot in shots:
		shot.pos.y -= BULLET_SPEED * delta
	for shot in enemy_shots:
		shot.pos.y += ENEMY_BULLET_SPEED * delta
	shots = shots.filter(func(shot): return shot.pos.y > -30.0)
	enemy_shots = enemy_shots.filter(func(shot): return shot.pos.y < SIZE.y + 30.0)


func _update_blasts(delta: float) -> void:
	for blast in blasts:
		blast.age += delta
	blasts = blasts.filter(func(blast): return blast.age < 0.35)


func _check_collisions() -> void:
	for shot in shots.duplicate():
		for enemy in enemies.duplicate():
			if Rect2(enemy.pos - ENEMY_SIZE * 0.5, ENEMY_SIZE).has_point(shot.pos):
				shots.erase(shot)
				enemies.erase(enemy)
				blasts.append({"pos": enemy.pos, "age": 0.0})
				score += 100 + enemy.row * 25
				break

	var player_rect := Rect2(Vector2(player_x, PLAYER_Y) - PLAYER_SIZE * 0.5, PLAYER_SIZE)
	for shot in enemy_shots.duplicate():
		if player_rect.has_point(shot.pos):
			enemy_shots.erase(shot)
			lives -= 1
			blasts.append({"pos": Vector2(player_x, PLAYER_Y), "age": 0.0})
			if lives <= 0:
				_end_game(false)


func _end_game(victory: bool) -> void:
	game_over = true
	won = victory


func _restart() -> void:
	score = 0
	lives = 3
	wave = 1
	game_over = false
	won = false
	shots.clear()
	enemy_shots.clear()
	blasts.clear()
	player_x = SIZE.x * 0.5
	_spawn_wave()


func _draw() -> void:
	_draw_backdrop()
	_draw_hud()
	for shot in shots:
		_draw_player_shot(shot.pos)
	for shot in enemy_shots:
		_draw_enemy_shot(shot.pos)
	for enemy in enemies:
		_draw_enemy(enemy)
	_draw_player()
	for blast in blasts:
		_draw_blast(blast)
	if game_over:
		_draw_overlay()


func _draw_backdrop() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color("#05070d"))
	draw_texture_rect(art, Rect2(Vector2(744, 24), Vector2(190, 190)), false, Color(1, 1, 1, 0.18))
	draw_texture_rect(art, Rect2(Vector2(28, 346), Vector2(180, 180)), false, Color(1, 1, 1, 0.11))
	for star in stars:
		draw_circle(star.pos, star.size, star.color)
	for y in range(56, 500, 36):
		draw_line(Vector2(0, y), Vector2(SIZE.x, y + sin(Time.get_ticks_msec() * 0.001 + y) * 8.0), Color(0.0, 0.85, 1.0, 0.055), 1.0)


func _draw_hud() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(24, 31), "SCORE %06d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#f6f7ff"))
	draw_string(ThemeDB.fallback_font, Vector2(402, 31), "WAVE %02d" % wave, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#ffe66d"))
	draw_string(ThemeDB.fallback_font, Vector2(805, 31), "LIVES %d" % lives, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#7cfbcb"))
	draw_line(Vector2(18, 42), Vector2(942, 42), Color("#1ee3ff", 0.35), 2.0)


func _draw_player() -> void:
	var p := Vector2(player_x, PLAYER_Y)
	draw_polygon(
		PackedVector2Array([p + Vector2(0, -24), p + Vector2(28, 18), p + Vector2(8, 12), p + Vector2(0, 22), p + Vector2(-8, 12), p + Vector2(-28, 18)]),
		PackedColorArray([Color("#39f5ff"), Color("#20c7f7"), Color("#f6f7ff"), Color("#8cff64"), Color("#f6f7ff"), Color("#20c7f7")])
	)
	draw_line(p + Vector2(-18, 18), p + Vector2(18, 18), Color("#ff5d8f"), 3.0)
	draw_circle(p + Vector2(0, 2), 5.0, Color("#fff47a"))


func _draw_enemy(enemy: Dictionary) -> void:
	var p: Vector2 = enemy.pos
	var bob := sin(enemy.phase) * 2.5
	var row: int = enemy.row
	var body_colors: Array[Color] = [Color("#8cff64"), Color("#ffe66d"), Color("#ff6b8a"), Color("#b986ff")]
	var body_color: Color = body_colors[row % 4]
	var eye_color := Color("#05070d")
	draw_rect(Rect2(p + Vector2(-17, -8 + bob), Vector2(34, 18)), body_color)
	draw_rect(Rect2(p + Vector2(-25, 4 + bob), Vector2(12, 8)), body_color.darkened(0.15))
	draw_rect(Rect2(p + Vector2(13, 4 + bob), Vector2(12, 8)), body_color.darkened(0.15))
	draw_rect(Rect2(p + Vector2(-9, -2 + bob), Vector2(5, 5)), eye_color)
	draw_rect(Rect2(p + Vector2(4, -2 + bob), Vector2(5, 5)), eye_color)
	draw_line(p + Vector2(-12, 14 + bob), p + Vector2(-18, 22 + bob), body_color, 2.0)
	draw_line(p + Vector2(12, 14 + bob), p + Vector2(18, 22 + bob), body_color, 2.0)


func _draw_player_shot(pos: Vector2) -> void:
	draw_line(pos + Vector2(0, 10), pos + Vector2(0, -12), Color("#f6f7ff"), 3.0)
	draw_circle(pos + Vector2(0, -13), 3.0, Color("#ffe66d"))


func _draw_enemy_shot(pos: Vector2) -> void:
	draw_line(pos + Vector2(0, -8), pos + Vector2(0, 10), Color("#ff5d8f"), 3.0)
	draw_circle(pos + Vector2(0, 11), 3.0, Color("#ffb3c8"))


func _draw_blast(blast: Dictionary) -> void:
	var t: float = blast.age / 0.35
	var radius := lerpf(8.0, 38.0, t)
	var alpha := 1.0 - t
	draw_circle(blast.pos, radius, Color(1.0, 0.28, 0.34, 0.22 * alpha))
	draw_arc(blast.pos, radius, 0.0, TAU, 18, Color("#ffe66d", alpha), 3.0)
	draw_arc(blast.pos, radius * 0.55, 0.0, TAU, 12, Color("#f6f7ff", alpha), 2.0)


func _draw_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.0, 0.0, 0.0, 0.56))
	var title := "SECTOR CLEARED" if won else "GAME OVER"
	var subtitle := "Press Space / Tap to restart"
	draw_string(ThemeDB.fallback_font, Vector2(0, 238), title, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 42, Color("#ffe66d"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 286), subtitle, HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 20, Color("#f6f7ff"))
