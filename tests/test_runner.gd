extends SceneTree

const MainScene := preload("res://main.tscn")
const PlayerScript := preload("res://scripts/player.gd")
const TouristScript := preload("res://scripts/tourist.gd")

var failures := 0
var assertions := 0

var tourist_params := {
	"view_radius": 200.0,
	"fov_degrees": 100.0,
	"speed_min": 28.0,
	"speed_max": 52.0,
	"initial_wander_min": 1.0,
	"initial_wander_max": 3.2,
	"aim_duration": 1.25,
	"flash_duration": 0.16,
	"cooldown_min": 1.4,
	"cooldown_max": 2.5,
	"wander_min": 1.2,
	"wander_max": 3.5
}

var player_params := {
	"speed": 205.0,
	"acceleration": 1100.0,
	"deceleration": 1400.0,
	"controller_deadzone": 0.2,
	"invulnerability_duration": 1.0,
	"dash_speed": 560.0,
	"dash_duration": 0.18,
	"dash_cooldown": 1.0
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("Running Camera Dodging tests...")
	await _test_all_tourist_types()
	await _test_controls()
	await _test_artwork_viewing()
	await _test_entrance_and_exit()
	if failures == 0:
		print("PASS: %d assertions" % assertions)
		quit(0)
	else:
		printerr("FAIL: %d of %d assertions failed" % [failures, assertions])
		quit(1)

func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		print("  ✓ %s" % message)
	else:
		failures += 1
		printerr("  ✗ %s" % message)

func _make_player() -> CharacterBody2D:
	var player := CharacterBody2D.new()
	player.set_script(PlayerScript)
	player.configure(player_params)
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 17.0
	collision.shape = shape
	player.add_child(collision)
	get_root().add_child(player)
	player.set_physics_process(false)
	return player

func _make_tourist(player: CharacterBody2D, archetype: String, type_params: Dictionary, guide := false, guide_node: Node2D = null, slot := 0, previous_member: Node2D = null) -> CameraTourist:
	var tourist := TouristScript.new()
	tourist.position = Vector2(300 + slot * 36, 300)
	tourist.setup(player, PackedVector2Array([Vector2(500, 300)]), 12345, Rect2(0, 0, 1000, 1000), [], tourist_params, archetype, type_params, guide, guide_node, Vector2.ZERO, slot, 7, previous_member)
	get_root().add_child(tourist)
	tourist.set_physics_process(false)
	return tourist

func _test_all_tourist_types() -> void:
	print("Tourist archetypes")
	var player := _make_player()
	player.position = Vector2(300, 300)

	var regular := _make_tourist(player, "regular", {"speed_multiplier": 1.0})
	_expect(regular.tourist_type == "regular", "regular tourist initializes")
	_expect(regular.desired_velocity.length() >= tourist_params.speed_min, "regular tourist receives walking speed")

	var kid := _make_tourist(player, "kid", {
		"speed_multiplier": 3.2,
		"takes_photos": false,
		"collision_radius": 34.0,
		"knockback_speed": 560.0,
		"knockback_duration": 0.22,
		"knockback_cooldown": 1.0
	})
	kid.position = player.position
	kid._check_kid_collision()
	_expect(not bool(kid.type_params.takes_photos), "kid does not take photos")
	_expect(player.knockback_timer > 0.0, "kid collision knocks the player back")

	var influencer := _make_tourist(player, "influencer", {
		"speed_multiplier": 0.7,
		"takes_video": true,
		"video_hit_interval": 1.0,
		"view_radius": 260.0,
		"fov_degrees": 85.0
	})
	_expect(influencer.state == CameraTourist.CameraState.AIM, "influencer starts recording")
	_expect(is_equal_approx(influencer.view_radius, 260.0), "influencer uses extended video range")

	var elderly_config := {
		"speed_multiplier": 0.45,
		"group_size": 7,
		"aim_duration": 3.0,
		"initial_wander_min": 2.0,
		"initial_wander_max": 2.0,
		"wander_min": 2.0,
		"wander_max": 2.0,
		"cooldown_min": 3.0,
		"cooldown_max": 3.0,
		"view_radius": 180.0,
		"fov_degrees": 120.0,
		"synchronized": true
	}
	var guide := _make_tourist(player, "elderly", elderly_config, true)
	var follower := _make_tourist(player, "elderly", elderly_config, false, guide, 1, guide)
	_expect(guide.is_tour_guide, "elderly group has a guide")
	_expect(follower.group_guide == guide, "elderly member follows its guide")
	_expect(follower.line_barrier != null, "elderly line blocks passage between members")

	for node in [regular, kid, influencer, follower, guide, player]:
		node.queue_free()
	await process_frame

func _test_controls() -> void:
	print("Controls")
	var player := _make_player()
	var start := player.position
	Input.action_press("ui_right")
	player._physics_process(0.1)
	Input.action_release("ui_right")
	_expect(player.position.x > start.x, "directional input moves the player")

	if not InputMap.has_action("dash"):
		InputMap.add_action("dash")
	player.velocity = Vector2.ZERO
	player.last_move_direction = Vector2.RIGHT
	Input.action_press("dash")
	player._physics_process(0.016)
	Input.action_release("dash")
	player._physics_process(0.016)
	_expect(player.dash_timer > 0.0, "dash input starts a dash")
	_expect(player.velocity.length() >= player.dash_speed - 0.1, "dash reaches configured speed")
	player.queue_free()
	await process_frame

func _new_game() -> Node2D:
	var game := MainScene.instantiate()
	get_root().add_child(game)
	await process_frame
	game.set_process(false)
	game.player.set_physics_process(false)
	for tourist in game.crowd_nodes:
		tourist.set_physics_process(false)
	return game

func _test_artwork_viewing() -> void:
	print("Artwork viewing")
	var game := await _new_game()
	var artwork_index := -1
	for index in game.attractions.size():
		if game.attractions[index].floor == game.current_floor:
			artwork_index = index
			break
	_expect(artwork_index >= 0, "current floor contains artwork")
	if artwork_index >= 0:
		var artwork: MuseumArtwork = game.attractions[artwork_index].node
		game.player.global_position = artwork.global_position
		game._process(game.artwork_view_duration + 0.05)
		_expect(game.visited_attractions[artwork_index], "viewing for the required duration visits artwork")
		_expect(artwork.visited, "visited artwork updates its visual state")
	game.queue_free()
	await process_frame

func _test_entrance_and_exit() -> void:
	print("Entrance and exit")
	var game := await _new_game()
	_expect(game.player.position.is_equal_approx(game.start_position), "player enters at the entrance marker")
	game.player.position = game.exit_position
	game._process(0.016)
	_expect(game.game_over, "reaching the exit completes the visit")
	_expect(not game.player.is_physics_processing(), "controls stop after exiting")
	game.queue_free()
	await process_frame
