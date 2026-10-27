extends Node
## Screenshots of the story missions (HUD, dialogue, markers, phone) for
## review. Needs a real renderer:
##   xvfb-run godot --rendering-driver opengl3 res://tests/mission_shots.tscn -- <out_dir>

const MainScene = preload("res://main.tscn")

var out_dir := "user://"
var game


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]
	_run.call_deferred()


func _run() -> void:
	game = MainScene.instantiate()
	game.save_enabled = false
	add_child(game)
	var mm = game.missions
	await _frames(100)
	await _shot("m1_intro.png")
	await _talk_until(func(): return mm.objective_text == "Catch the thief!", 900)
	await _frames(30)
	await _shot("m1_snatch.png")
	await _talk_until(func(): return mm.objective_text == "Get on the scooter", 900)
	var m = mm.active
	game.player.global_position = m.spare.global_position + Vector3(0, 0, -1.5)
	game.player.reset_physics_interpolation()
	await _frames(2)
	game.player.enter_vehicle(m.spare)
	Controls.override_vector = Controls.screen_from_world((m.getaway.global_position - game.player.global_position).normalized())
	for i in 150:
		Controls.override_vector = Controls.screen_from_world((m.getaway.global_position - m.spare.global_position).normalized())
		await _frames(1)
	await _shot("m1_chase.png")
	Controls.override_vector = null
	var end: Vector3 = m.getaway.path[m.getaway.path.size() - 1]
	game.city.stream_now(end)
	m.getaway.global_position = end + Vector3(-10, 0, 0)
	m.getaway.path_index = m.getaway.path.size() - 1
	m.spare.global_position = end + Vector3(-16, 0, 0)
	await _talk_until(func(): return mm.objective_text == "Beat the crew", 600)
	game.player.exit_vehicle()
	await _frames(70)
	Input.action_press("attack")
	await _frames(3)
	Input.action_release("attack")
	await _frames(5)
	await _shot("m1_fight.png")
	mm.abandon()

	mm.done = ["m01_homecoming"]
	mm.start("m02_empty_rooms", true)
	await _talk_until(func(): return mm.objective_text.begins_with("Check your phone"), 1200)
	await _shot("m2_phone_prompt.png")
	game.hud.phone.open()
	await _ui_frames(4)
	game.hud.phone._messages()
	await _ui_frames(4)
	await _shot("m2_phone_messages.png")
	game.hud.phone._missions()
	await _ui_frames(4)
	await _shot("m2_phone_missions.png")
	game.hud.phone.close()
	mm.abandon()

	mm.done = ["m01_homecoming", "m02_empty_rooms"]
	mm.start("m03_lantern_lights", true)
	await _frames(150)
	game.player.global_position = mm.active.front("blue_lantern") + Vector3(0.2, 0, 0)
	game.player.reset_physics_interpolation()
	await _frames(60)
	await _shot("m3_celeste.png")
	get_tree().quit()


func _talk_until(cond: Callable, limit: int) -> void:
	for i in limit:
		if cond.call():
			return
		if game.hud._dialogue.visible and i % 30 == 29:
			game.hud._advance_dialogue()
		await _frames(1)


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	print("saved ", file)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ui_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
