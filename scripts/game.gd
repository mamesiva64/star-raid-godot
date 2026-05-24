extends Node2D

const SIZE := Vector2(540, 960)
const PLAYER_Y := 850.0
const PLAYER_SPEED := 430.0
const BULLET_SPEED := 760.0
const ENEMY_BULLET_SPEED := 260.0
const ITEM_SPEED := 150.0
const ENEMY_COLS := 5
const ENEMY_ROWS := 4
const ENEMY_SPACING := Vector2(82, 58)
const ENEMY_SIZE := Vector2(58, 44)
const PLAYER_SIZE := Vector2(72, 58)
const BASE_SHOT_COOLDOWN := 0.34
const RAPID_SHOT_COOLDOWN := 0.13
const POWERUP_TIME := {
	"TRIPLE": 8.0,
	"LASER": 5.0,
	"RAPID": 7.0,
	"SHIELD": 8.0,
	"SPREAD": 7.0,
}

var art: Texture2D = preload("res://assets/star_raid_sprite_sheet.png")
var player_x := SIZE.x * 0.5
var shot_timer := 0.0
var enemy_dir := 1.0
var enemy_speed := 34.0
var enemy_fire_timer := 1.0
var laser_tick := 0.0
var score := 0
var lives := 3
var wave := 1
var active_power := ""
var power_timer := 0.0
var game_over := false
var stars: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var enemy_shots: Array[Dictionary] = []
var items: Array[Dictionary] = []
var blasts: Array[Dictionary] = []

var enemy_regions: Array[Rect2] = [
	Rect2(84, 58, 166, 120),
	Rect2(78, 210, 176, 126),
	Rect2(80, 366, 184, 118),
	Rect2(96, 520, 156, 118),
]
var enemy_tints: Array[Color] = [
	Color("#9ff7ff"),
	Color("#bcff58"),
	Color("#ff8068"),
	Color("#ffd64c"),
]
var power_colors := {
	"TRIPLE": Color("#61ecff"),
	"LASER": Color("#ff5a54"),
	"RAPID": Color("#ffe04d"),
	"SHIELD": Color("#8aff6f"),
	"SPREAD": Color("#b389ff"),
}
var power_labels := {
	"TRIPLE": "3WAY",
	"LASER": "LASER",
	"RAPID": "RAPID",
	"SHIELD": "GUARD",
	"SPREAD": "WIDE",
}


func _ready() -> void:
	randomize()
	for i in 140:
		stars.append({
			"pos": Vector2(randf_range(0, SIZE.x), randf_range(0, SIZE.y)),
			"speed": randf_range(24.0, 112.0),
			"size": randf_range(1.0, 2.6),
			"color": Color(0.42 + randf() * 0.46, 0.72 + randf() * 0.25, 1.0, 0.35 + randf() * 0.55)
		})
	_spawn_wave()


func _process(delta: float) -> void:
	if game_over:
		if Input.is_action_just_pressed("ui_accept"):
			_restart()
		_update_stars(delta)
		queue_redraw()
		return

	_update_stars(delta)
	_update_player(delta)
	_update_powerup(delta)
	_update_shots(delta)
	_update_enemies(delta)
	_update_enemy_fire(delta)
	_update_items(delta)
	_update_blasts(delta)
	_check_collisions()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and game_over:
		_restart()
	elif event is InputEventScreenDrag:
		player_x = clamp(player_x + event.relative.x, 46.0, SIZE.x - 46.0)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		player_x = clamp(player_x + event.relative.x, 46.0, SIZE.x - 46.0)
	elif event is InputEventMouseButton and event.pressed and game_over:
		_restart()


func _update_player(delta: float) -> void:
	var move := 0.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		move -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		move += 1.0
	player_x = clamp(player_x + move * PLAYER_SPEED * delta, 46.0, SIZE.x - 46.0)

	shot_timer = maxf(0.0, shot_timer - delta)
	if shot_timer <= 0.0:
		_auto_fire()


func _update_powerup(delta: float) -> void:
	if active_power.is_empty():
		return
	power_timer = maxf(0.0, power_timer - delta)
	if active_power == "LASER":
		laser_tick = maxf(0.0, laser_tick - delta)
		if laser_tick <= 0.0:
			_apply_laser_damage()
			laser_tick = 0.09
	if power_timer <= 0.0:
		active_power = ""


func _auto_fire() -> void:
	var cooldown := RAPID_SHOT_COOLDOWN if active_power == "RAPID" else BASE_SHOT_COOLDOWN
	if active_power == "SPREAD":
		for angle in [-0.34, -0.17, 0.0, 0.17, 0.34]:
			shots.append({"pos": Vector2(player_x, PLAYER_Y - 34.0), "vel": Vector2(sin(angle) * 230.0, -BULLET_SPEED), "kind": "cyan"})
	elif active_power == "TRIPLE":
		for angle in [-0.22, 0.0, 0.22]:
			shots.append({"pos": Vector2(player_x, PLAYER_Y - 34.0), "vel": Vector2(sin(angle) * 220.0, -BULLET_SPEED), "kind": "green"})
	else:
		shots.append({"pos": Vector2(player_x, PLAYER_Y - 34.0), "vel": Vector2(0.0, -BULLET_SPEED), "kind": "cyan"})
	shot_timer = cooldown


func _update_stars(delta: float) -> void:
	for star in stars:
		star.pos.y += star.speed * delta
		if star.pos.y > SIZE.y:
			star.pos = Vector2(randf_range(0, SIZE.x), -8.0)


func _spawn_wave() -> void:
	enemies.clear()
	items.clear()
	var start := Vector2(106, 128)
	var power_types := ["TRIPLE", "LASER", "RAPID", "SHIELD", "SPREAD"]
	var carrier_index := (wave * 2) % ENEMY_COLS
	for row in ENEMY_ROWS:
		for col in ENEMY_COLS:
			var is_carrier := col == (carrier_index + row) % ENEMY_COLS
			enemies.append({
				"pos": start + Vector2(col * ENEMY_SPACING.x, row * ENEMY_SPACING.y),
				"row": row,
				"phase": randf() * TAU,
				"carrier": is_carrier,
				"item": power_types[(wave + row + col) % power_types.size()] if is_carrier else "",
			})
	enemy_dir = 1.0
	enemy_speed = 34.0 + wave * 7.0
	enemy_fire_timer = 1.0


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
			enemy.pos.y += 24.0
			if enemy.pos.y > PLAYER_Y - 72.0:
				_end_game()
	if enemies.is_empty():
		wave += 1
		score += 500
		_spawn_wave()


func _update_enemy_fire(delta: float) -> void:
	enemy_fire_timer -= delta
	if enemy_fire_timer > 0.0 or enemies.is_empty():
		return
	var shooter := enemies[randi() % enemies.size()]
	enemy_shots.append({"pos": shooter.pos + Vector2(0, 24.0), "vel": Vector2(randf_range(-24.0, 24.0), ENEMY_BULLET_SPEED)})
	enemy_fire_timer = randf_range(0.5, maxf(0.88, 1.55 - wave * 0.06))


func _update_shots(delta: float) -> void:
	for shot in shots:
		shot.pos += shot.vel * delta
	for shot in enemy_shots:
		shot.pos += shot.vel * delta
	shots = shots.filter(func(shot): return shot.pos.y > -40.0 and shot.pos.x > -40.0 and shot.pos.x < SIZE.x + 40.0)
	enemy_shots = enemy_shots.filter(func(shot): return shot.pos.y < SIZE.y + 40.0)


func _update_items(delta: float) -> void:
	for item in items:
		item.pos.y += ITEM_SPEED * delta
		item.phase += delta * 4.5
	items = items.filter(func(item): return item.pos.y < SIZE.y + 40.0)


func _update_blasts(delta: float) -> void:
	for blast in blasts:
		blast.age += delta
	blasts = blasts.filter(func(blast): return blast.age < 0.42)


func _check_collisions() -> void:
	for shot in shots.duplicate():
		for enemy in enemies.duplicate():
			if Rect2(enemy.pos - ENEMY_SIZE * 0.5, ENEMY_SIZE).has_point(shot.pos):
				shots.erase(shot)
				_destroy_enemy(enemy)
				break

	var player_rect := Rect2(Vector2(player_x, PLAYER_Y) - PLAYER_SIZE * 0.5, PLAYER_SIZE)
	for shot in enemy_shots.duplicate():
		if player_rect.has_point(shot.pos):
			enemy_shots.erase(shot)
			blasts.append({"pos": Vector2(player_x, PLAYER_Y), "age": 0.0})
			if active_power == "SHIELD":
				score += 10
			else:
				lives -= 1
				if lives <= 0:
					_end_game()

	for item in items.duplicate():
		var item_rect := Rect2(item.pos - Vector2(18, 18), Vector2(36, 36))
		if player_rect.intersects(item_rect):
			items.erase(item)
			_apply_powerup(item.kind)


func _apply_laser_damage() -> void:
	for enemy in enemies.duplicate():
		if absf(enemy.pos.x - player_x) < 24.0 and enemy.pos.y < PLAYER_Y:
			_destroy_enemy(enemy)


func _destroy_enemy(enemy: Dictionary) -> void:
	if not enemies.has(enemy):
		return
	enemies.erase(enemy)
	blasts.append({"pos": enemy.pos, "age": 0.0})
	score += 100 + int(enemy.row) * 30
	if enemy.carrier:
		items.append({"pos": enemy.pos + Vector2(0, 12), "kind": enemy.item, "phase": 0.0})


func _apply_powerup(kind: String) -> void:
	active_power = kind
	power_timer = float(POWERUP_TIME.get(kind, 6.0))
	laser_tick = 0.0
	enemy_shots.clear()
	score += 150


func _end_game() -> void:
	game_over = true


func _restart() -> void:
	score = 0
	lives = 3
	wave = 1
	active_power = ""
	power_timer = 0.0
	game_over = false
	shots.clear()
	enemy_shots.clear()
	items.clear()
	blasts.clear()
	player_x = SIZE.x * 0.5
	_spawn_wave()


func _draw() -> void:
	_draw_backdrop()
	_draw_hud()
	if active_power == "LASER":
		_draw_laser()
	for item in items:
		_draw_item(item)
	for shot in shots:
		_draw_player_shot(shot)
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
	_draw_region(Rect2(60, 1000, 200, 205), Vector2(116, 755), Vector2(270, 277), Color(1, 1, 1, 0.24))
	_draw_region(Rect2(500, 1000, 222, 205), Vector2(422, 402), Vector2(274, 253), Color(1, 1, 1, 0.16))
	for star in stars:
		draw_circle(star.pos, star.size, star.color)
	for y in range(76, 880, 42):
		draw_line(Vector2(18, y), Vector2(SIZE.x - 18, y + sin(Time.get_ticks_msec() * 0.001 + y) * 7.0), Color(0.0, 0.85, 1.0, 0.045), 1.0)


func _draw_hud() -> void:
	_draw_region(Rect2(828, 795, 330, 158), Vector2(270, 54), Vector2(196, 94), Color(1, 1, 1, 0.9))
	draw_string(ThemeDB.fallback_font, Vector2(18, 114), "SCORE %06d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#f6f7ff"))
	draw_string(ThemeDB.fallback_font, Vector2(220, 114), "WAVE %02d" % wave, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#ffe66d"))
	draw_string(ThemeDB.fallback_font, Vector2(418, 114), "LIFE %d" % lives, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#7cfbcb"))
	if not active_power.is_empty():
		var label: String = power_labels.get(active_power, active_power)
		var color: Color = power_colors.get(active_power, Color.WHITE)
		draw_rect(Rect2(18, 128, 504 * (power_timer / float(POWERUP_TIME.get(active_power, 6.0))), 5), color)
		draw_string(ThemeDB.fallback_font, Vector2(18, 154), label + " %.1f" % power_timer, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)


func _draw_player() -> void:
	var tint := Color.WHITE
	if active_power == "SHIELD":
		var pulse := 0.45 + sin(Time.get_ticks_msec() * 0.012) * 0.18
		draw_arc(Vector2(player_x, PLAYER_Y), 48.0, 0.0, TAU, 40, Color("#8aff6f", pulse), 4.0)
	elif not active_power.is_empty():
		tint = power_colors.get(active_power, Color.WHITE).lerp(Color.WHITE, 0.5)
	_draw_region(Rect2(68, 740, 226, 230), Vector2(player_x, PLAYER_Y), Vector2(86, 88), tint)


func _draw_enemy(enemy: Dictionary) -> void:
	var p: Vector2 = enemy.pos + Vector2(0, sin(enemy.phase) * 2.5)
	var row: int = enemy.row
	_draw_region(enemy_regions[row % enemy_regions.size()], p, Vector2(68, 52), enemy_tints[row % enemy_tints.size()])
	if enemy.carrier:
		var color: Color = power_colors.get(enemy.item, Color.WHITE)
		draw_arc(p, 34.0 + sin(enemy.phase) * 2.0, 0.0, TAU, 28, color, 2.5)
		draw_circle(p + Vector2(0, -30), 4.0, color)


func _draw_player_shot(shot: Dictionary) -> void:
	var region := Rect2(98, 668, 42, 84)
	if shot.kind == "green":
		region = Rect2(356, 676, 44, 76)
	_draw_region(region, shot.pos, Vector2(16, 36), Color.WHITE)


func _draw_enemy_shot(pos: Vector2) -> void:
	_draw_region(Rect2(650, 668, 42, 86), pos, Vector2(16, 32), Color.WHITE)


func _draw_laser() -> void:
	var top := 128.0
	var alpha := 0.58 + sin(Time.get_ticks_msec() * 0.02) * 0.18
	draw_rect(Rect2(player_x - 9.0, top, 18.0, PLAYER_Y - top - 30.0), Color("#ff564f", alpha))
	draw_rect(Rect2(player_x - 3.0, top, 6.0, PLAYER_Y - top - 30.0), Color("#fff4c7", 0.92))
	_draw_region(Rect2(780, 658, 44, 96), Vector2(player_x, PLAYER_Y - 180), Vector2(28, 120), Color(1, 0.75, 0.65, 0.95))


func _draw_item(item: Dictionary) -> void:
	var color: Color = power_colors.get(item.kind, Color.WHITE)
	var p: Vector2 = item.pos + Vector2(0, sin(item.phase) * 4.0)
	draw_circle(p, 17.0, Color("#05070d", 0.88))
	draw_arc(p, 18.0, 0.0, TAU, 28, color, 3.0)
	draw_circle(p, 7.0, color)
	draw_string(ThemeDB.fallback_font, p + Vector2(-8, 5), String(item.kind)[0], HORIZONTAL_ALIGNMENT_CENTER, 16, 14, Color("#05070d"))


func _draw_blast(blast: Dictionary) -> void:
	var t: float = blast.age / 0.42
	var size := lerpf(42.0, 78.0, t)
	var region := Rect2(392, 785, 176, 160) if t < 0.5 else Rect2(602, 778, 188, 170)
	_draw_region(region, blast.pos, Vector2(size, size), Color(1, 1, 1, 1.0 - t * 0.65))


func _draw_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.0, 0.0, 0.0, 0.62))
	_draw_region(Rect2(828, 795, 330, 158), Vector2(270, 330), Vector2(292, 140), Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(0, 466), "GAME OVER", HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 42, Color("#ffe66d"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 512), "Tap / Space to restart", HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, 20, Color("#f6f7ff"))


func _draw_region(src: Rect2, center: Vector2, size: Vector2, modulate: Color = Color.WHITE) -> void:
	draw_texture_rect_region(art, Rect2(center - size * 0.5, size), src, modulate)
