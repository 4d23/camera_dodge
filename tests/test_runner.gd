extends SceneTree

const MainScene := preload("res://main.tscn")
const TouristScript := preload("res://scripts/tourist.gd")
const PlayerScript := preload("res://scripts/player.gd")

var failures := 0
var assertions := 0
var game_params: Dictionary

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game_params = JSON.parse_string(FileAccess.get_file_as_string("res://config/game_params.json"))
	await _test_tourist_archetypes()
	await _test_travel_and_photo_cycle()
	await _test_separation()
	await _test_elderly_follow_guide()
	await _test_seeded_crowd_is_reproducible()
	await _test_density_controls_crowd_size()
	await _test_astar_travel_paths()
	await _test_player_starts_outside_camera_frames()
	await _test_elderly_group_size_distribution()
	await _test_crowd_reaches_photo_state()
	await _test_structures_block_camera_view()
	await _test_controls()
	await _test_artwork_and_entry_exit()
	await _test_failure_page()
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

func _spawn_config(player: CharacterBody2D, archetype: String, type_params: Dictionary, agents: Array, seed_value := 7) -> Dictionary:
	return {
		"player": player,
		"attractions": PackedVector2Array([Vector2(300, 100), Vector2(600, 300), Vector2(200, 600)]),
		"seed": seed_value,
		"bounds": Rect2(0, 0, 900, 900),
		"walls": [],
		"params": game_params.tourist,
		"archetype": archetype,
		"type_params": type_params,
		"crowd": agents
	}

func _add_tourist(config: Dictionary, position: Vector2) -> CameraTourist:
	var tourist := TouristScript.new()
	tourist.position = position
	tourist.setup(config)
	get_root().add_child(tourist)
	tourist.set_physics_process(false)
	return tourist

func _test_tourist_archetypes() -> void:
	print("Tourist archetypes")
	var player := _make_player()
	var agents: Array = []
	var kid := TouristScript.new()
	var influencer := TouristScript.new()
	agents.assign([kid, influencer])
	kid.position = Vector2(100, 100)
	influencer.position = Vector2(200, 100)
	kid.setup(_spawn_config(player, "kid", game_params.tourist_types.kid, agents, 30))
	influencer.setup(_spawn_config(player, "influencer", game_params.tourist_types.influencer, agents, 31))
	get_root().add_child(kid)
	get_root().add_child(influencer)
	kid.set_physics_process(false)
	influencer.set_physics_process(false)
	_expect(not bool(kid.type_params.takes_photos), "kid travels without taking photos")
	_expect(kid.walking_speed > float(game_params.tourist.speed_max), "kid receives its fast speed multiplier")
	kid.velocity = Vector2.RIGHT * kid.walking_speed
	player.position = kid.position + Vector2(120, 0)
	kid._try_start_kid_dash()
	_expect(kid.kid_dash_timer > 0.0, "kid dashes when the player is close and inside its view cone")
	_expect(kid.kid_dash_direction.is_equal_approx(Vector2.RIGHT), "kid locks its dash toward the detected player")
	var first_cooldown := kid.kid_dash_cooldown_timer
	kid.kid_dash_timer = 0.0
	kid._try_start_kid_dash()
	_expect(is_equal_approx(kid.kid_dash_cooldown_timer, first_cooldown), "kid cannot dash again during cooldown")
	player.position = kid.position + Vector2(20, 0)
	kid.collision_cooldown = 0.0
	kid._check_kid_collision()
	_expect(player.knockback_timer > 0.0, "kid knocks the player over on contact")
	_expect(bool(influencer.type_params.takes_video), "influencer records continuous video")
	_expect(influencer.state == CameraTourist.CameraState.AIM, "influencer starts in its camera state")
	_expect(is_equal_approx(influencer.view_radius, 260.0), "influencer uses its extended view radius")
	var artwork_angle := influencer.global_position.angle_to_point(influencer.destination)
	var aim_difference := absf(angle_difference(artwork_angle, influencer.aim_target_angle))
	_expect(aim_difference > 0.001, "camera direction is not locked exactly onto artwork")
	_expect(aim_difference < deg_to_rad(70.0), "camera direction remains biased toward artwork")
	kid.queue_free()
	influencer.queue_free()
	player.queue_free()
	await process_frame

func _test_travel_and_photo_cycle() -> void:
	print("Travel and photo cycle")
	var player := CharacterBody2D.new()
	get_root().add_child(player)
	var agents: Array = []
	var tourist := TouristScript.new()
	agents.append(tourist)
	tourist.position = Vector2(100, 100)
	tourist.setup(_spawn_config(player, "regular", game_params.tourist_types.regular, agents, 55))
	get_root().add_child(tourist)
	tourist.set_physics_process(false)
	_expect(tourist.state == CameraTourist.CameraState.TRAVEL, "regular tourist starts by travelling toward art")
	var first_destination := tourist.destination_index
	tourist.travel_photo_timer = 0.0
	tourist._physics_process(0.016)
	_expect(tourist.state == CameraTourist.CameraState.AIM and not tourist.photo_at_destination, "tourist can stop for a picture along the route")
	tourist.state = CameraTourist.CameraState.COOLDOWN
	tourist.timer = 0.0
	tourist._physics_process(0.016)
	_expect(tourist.state == CameraTourist.CameraState.TRAVEL and tourist.destination_index == first_destination, "tourist resumes the same trip after a route photo")
	tourist.global_position = tourist.destination
	tourist._physics_process(0.016)
	_expect(tourist.state == CameraTourist.CameraState.AIM and tourist.photo_at_destination, "tourist takes a picture after reaching artwork")
	tourist.state = CameraTourist.CameraState.COOLDOWN
	tourist.timer = 0.0
	tourist._physics_process(0.016)
	_expect(tourist.state == CameraTourist.CameraState.TRAVEL and tourist.destination_index != first_destination, "tourist chooses another artwork after the destination photo")
	tourist.queue_free()
	player.queue_free()
	await process_frame

func _test_separation() -> void:
	print("Crowd separation")
	var player := CharacterBody2D.new()
	get_root().add_child(player)
	var agents: Array = []
	var first := TouristScript.new()
	var second := TouristScript.new()
	agents.assign([first, second])
	first.position = Vector2(100, 100)
	second.position = Vector2(115, 100)
	first.setup(_spawn_config(player, "regular", game_params.tourist_types.regular, agents, 10))
	second.setup(_spawn_config(player, "regular", game_params.tourist_types.regular, agents, 11))
	get_root().add_child(first)
	get_root().add_child(second)
	first.set_physics_process(false)
	second.set_physics_process(false)
	_expect(first._separation_force().x < 0.0, "nearby tourist pushes the first tourist away")
	_expect(second._separation_force().x > 0.0, "separation force is reciprocal")
	first.queue_free()
	second.queue_free()
	player.queue_free()
	await process_frame

func _test_elderly_follow_guide() -> void:
	print("Elderly guide following")
	var player := CharacterBody2D.new()
	get_root().add_child(player)
	var agents: Array = []
	var guide := TouristScript.new()
	var follower := TouristScript.new()
	agents.assign([guide, follower])
	var guide_config := _spawn_config(player, "elderly", game_params.tourist_types.elderly, agents, 20)
	guide_config.is_tour_guide = true
	guide.position = Vector2(100, 100)
	guide.setup(guide_config)
	var follower_config := _spawn_config(player, "elderly", game_params.tourist_types.elderly, agents, 21)
	follower_config.group_guide = guide
	follower_config.previous_group_member = guide
	follower.position = Vector2(64, 100)
	follower.setup(follower_config)
	get_root().add_child(guide)
	get_root().add_child(follower)
	guide.set_physics_process(false)
	follower.set_physics_process(false)
	_expect(follower.group_guide == guide, "elderly follower is linked to its guide")
	_expect(follower.line_barrier != null, "elderly line remains player-blocking")
	guide.path_history.assign([Vector2(0, 0), Vector2(40, 0), Vector2(40, 40)])
	var curved_target := follower._path_target_behind(guide, 36.0)
	_expect(curved_target.is_equal_approx(Vector2(40, 4)), "follower targets the guide's curved path instead of a fixed straight offset")
	guide.queue_free()
	follower.queue_free()
	player.queue_free()
	await process_frame

func _test_seeded_crowd_is_reproducible() -> void:
	print("Seeded crowd spawning")
	var game := MainScene.instantiate()
	get_root().add_child(game)
	await process_frame
	game.set_process(false)
	game.game_params.crowd.seed = 424242
	var first_layout := await _respawn_and_capture(game)
	var second_layout := await _respawn_and_capture(game)
	_expect(first_layout == second_layout, "same master seed reproduces tourist types and positions")
	_expect(first_layout.size() == game.crowd_count, "seeded spawn still creates the configured crowd size")
	var regular_count := 0
	for tourist_data in first_layout:
		if tourist_data[0] == "regular":
			regular_count += 1
	_expect(regular_count >= int(game.game_params.crowd.minimum_regular_photographers), "crowd always includes regular photographers")
	game.queue_free()
	await process_frame

func _test_density_controls_crowd_size() -> void:
	print("Area-based crowd density")
	var game := MainScene.instantiate()
	get_root().add_child(game)
	await process_frame
	game.set_process(false)
	var base_count: int = game._crowd_count_for_current_floor()
	var base_density := float(game.game_params.crowd.tourists_per_100k_pixels)
	game.game_params.crowd.tourists_per_100k_pixels = base_density * 2.0
	var doubled_count: int = game._crowd_count_for_current_floor()
	_expect(base_count > 0, "configured density creates tourists from usable floor area")
	_expect(abs(doubled_count - base_count * 2) <= 1, "doubling density approximately doubles tourist count")
	_expect(not game.game_params.crowd.has("count"), "crowd size no longer uses a fixed count")
	game.queue_free()
	await process_frame

func _test_astar_travel_paths() -> void:
	print("A* tourist navigation")
	var game := MainScene.instantiate()
	get_root().add_child(game)
	await process_frame
	game.set_process(false)
	var routed_tourist: CameraTourist
	for tourist in game.crowd_nodes:
		tourist.set_physics_process(false)
		if tourist.travel_path.size() > 2:
			routed_tourist = tourist
			break
	_expect(game.tourist_navigation != null, "floor builds one shared A* navigation grid")
	_expect(routed_tourist != null, "tourists receive waypoint paths to artwork")
	if routed_tourist != null:
		var all_waypoints_walkable := true
		for waypoint in routed_tourist.travel_path:
			var cell: Vector2i = routed_tourist._navigation_cell_for(waypoint)
			if game.tourist_navigation.is_point_solid(cell):
				all_waypoints_walkable = false
				break
		_expect(all_waypoints_walkable, "A* path avoids wall and cover clearance cells")
		var desk: MuseumWall = game.get_node("Level0/Walls/RegistrationDesk")
		var desk_rect := desk.world_rect()
		routed_tourist.global_position = Vector2(desk_rect.position.x - 45.0, desk.global_position.y)
		var recovery_target := Vector2(desk_rect.end.x + 45.0, desk.global_position.y)
		_expect(routed_tourist._segment_crosses_wall(routed_tourist.global_position, recovery_target), "follower detects a wall cutting across its trail target")
		routed_tourist._plan_follower_recovery(recovery_target)
		_expect(routed_tourist.follower_recovery_path.size() > 2, "stuck follower receives an A* recovery route around the wall")
	game.queue_free()
	await process_frame

func _test_player_starts_outside_camera_frames() -> void:
	print("Safe entrance spawning")
	var game := MainScene.instantiate()
	get_root().add_child(game)
	await process_frame
	game.set_process(false)
	var all_cameras_safe := true
	var all_tourists_outside_safe_radius := true
	for tourist in game.crowd_nodes:
		tourist.set_physics_process(false)
		if tourist.global_position.distance_to(game.player.global_position) < game.start_exclusion_radius:
			all_tourists_outside_safe_radius = false
		if tourist.state == CameraTourist.CameraState.AIM and tourist._player_is_in_frame():
			all_cameras_safe = false
	_expect(all_tourists_outside_safe_radius, "tourists spawn outside the entrance safe radius")
	_expect(all_cameras_safe, "player starts outside every active camera frame")
	game.queue_free()
	await process_frame

func _test_elderly_group_size_distribution() -> void:
	print("Elderly group size distribution")
	var game := MainScene.instantiate()
	get_root().add_child(game)
	await process_frame
	game.set_process(false)
	var sample_rng := RandomNumberGenerator.new()
	sample_rng.seed = 9001
	var sample_total := 0.0
	var observed_sizes: Dictionary = {}
	for index in 2000:
		var sample: int = game._sample_elderly_group_size(sample_rng, game.game_params.tourist_types.elderly, 20)
		sample_total += sample
		observed_sizes[sample] = true
	var sample_mean := sample_total / 2000.0
	_expect(absf(sample_mean - float(game.game_params.tourist_types.elderly.group_size)) < 0.25, "random group length is centered on configured group_size")
	_expect(observed_sizes.size() > 3, "elderly groups spawn with varied lengths")
	_expect(not observed_sizes.has(int(game.game_params.tourist_types.elderly.group_size_min) - 1), "group length respects configured minimum")
	_expect(not observed_sizes.has(int(game.game_params.tourist_types.elderly.group_size_max) + 1), "group length respects configured maximum")
	game.queue_free()
	await process_frame

func _test_crowd_reaches_photo_state() -> void:
	print("Live crowd photo cycle")
	var game := MainScene.instantiate()
	get_root().add_child(game)
	await process_frame
	game.set_process(false)
	var saw_camera_state := false
	var saw_photo_flash := false
	var first_camera_time := 0.0
	for step in 900:
		for tourist in game.crowd_nodes:
			tourist.set_physics_process(false)
			tourist._physics_process(0.1)
			if tourist.state == CameraTourist.CameraState.AIM or tourist.state == CameraTourist.CameraState.FLASH:
				saw_camera_state = true
				first_camera_time = step * 0.1
			if tourist.state == CameraTourist.CameraState.FLASH:
				saw_photo_flash = true
		if saw_camera_state and saw_photo_flash:
			break
	_expect(saw_camera_state, "a live crowd reaches a camera state within 90 seconds")
	if saw_camera_state:
		print("    first camera state: %.1fs" % first_camera_time)
	_expect(saw_photo_flash, "a regular photographer reaches the flash state")
	game.queue_free()
	await process_frame

func _test_structures_block_camera_view() -> void:
	print("Camera cover structures")
	var game := MainScene.instantiate()
	get_root().add_child(game)
	await process_frame
	game.set_process(false)
	var cover_count := 0
	for structure in game.get_node("Level0/Walls").get_children():
		if structure.structure_type != "wall":
			cover_count += 1
	_expect(cover_count >= 4, "museum floor contains desks, kiosks, and columns")
	var desk: MuseumWall = game.get_node("Level0/Walls/RegistrationDesk")
	var desk_rect := desk.world_rect()
	var player := CharacterBody2D.new()
	player.position = Vector2(desk_rect.end.x + 25.0, desk.global_position.y)
	get_root().add_child(player)
	var tourist := TouristScript.new()
	tourist.position = Vector2(desk_rect.position.x - 25.0, desk.global_position.y)
	var agents: Array = [tourist]
	var cover_config := _spawn_config(player, "influencer", game_params.tourist_types.influencer, agents, 80)
	cover_config.walls = game.get_node("Level0").wall_rects()
	tourist.setup(cover_config)
	get_root().add_child(tourist)
	tourist.set_physics_process(false)
	tourist.aim_angle = tourist.global_position.angle_to_point(player.global_position)
	_expect(not tourist._player_is_in_frame(), "registration desk hides the player from the camera")
	var clipped_endpoint := tourist._camera_ray_endpoint(0.0)
	_expect(clipped_endpoint.length() < tourist.view_radius, "rendered camera cone stops at the registration desk")
	tourist.walls = []
	_expect(tourist._player_is_in_frame(), "same camera sees the player when cover is removed")
	_expect(is_equal_approx(tourist._camera_ray_endpoint(0.0).length(), tourist.view_radius), "camera cone reaches full range without cover")
	tourist.queue_free()
	player.queue_free()
	game.queue_free()
	await process_frame

func _make_player() -> CharacterBody2D:
	var player := CharacterBody2D.new()
	player.set_script(PlayerScript)
	player.configure(game_params.player)
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 17.0
	collision.shape = shape
	player.add_child(collision)
	get_root().add_child(player)
	player.set_physics_process(false)
	return player

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

func _test_artwork_and_entry_exit() -> void:
	print("Artwork, entrance, and exit")
	var game := MainScene.instantiate()
	get_root().add_child(game)
	await process_frame
	game.set_process(false)
	game.player.set_physics_process(false)
	for tourist in game.crowd_nodes:
		tourist.set_physics_process(false)
	_expect(game.player.position.is_equal_approx(game.start_position), "player enters at the entrance marker")
	var artwork_index := -1
	for index in game.attractions.size():
		if game.attractions[index].floor == game.current_floor:
			artwork_index = index
			break
	_expect(artwork_index >= 0, "current floor contains artwork")
	if artwork_index >= 0:
		var artwork: MuseumArtwork = game.attractions[artwork_index].node
		game.player.global_position = artwork.global_position
		game._process(0.05)
		_expect(not game.visited_attractions[artwork_index], "standing at the artwork does not count as viewing")
		game.player.global_position = artwork.viewing_position()
		_expect(artwork.contains_world_point(game.player.global_position), "standing on the carpet counts as viewing")
		game._process(game.artwork_view_duration + 0.05)
		_expect(game.visited_attractions[artwork_index], "viewing for the required duration visits artwork")
		_expect(artwork.visited, "visited artwork updates its visual state")
	game.player.position = game.exit_position
	game._process(0.016)
	_expect(game.game_over, "reaching the exit completes the visit")
	_expect(not game.player.is_physics_processing(), "controls stop after exiting")
	game.queue_free()
	await process_frame

func _test_failure_page() -> void:
	print("Failure page")
	var game := MainScene.instantiate()
	get_root().add_child(game)
	await process_frame
	for tourist in game.crowd_nodes:
		tourist.set_physics_process(false)
	for exposure in 3:
		game.player.invulnerable = false
		game._on_photographed()
	_expect(game.game_over, "three exposures fail the run")
	var failure_page: Node = game.ui_layer.get_node_or_null("FailurePage")
	_expect(failure_page != null, "failure opens the full-screen failed page")
	_expect(failure_page != null and failure_page.get_node("FailureHeading").text == "YOU FAILED", "failed page shows the failure heading")
	_expect(not game.player.is_physics_processing(), "failure stops player controls")
	game.queue_free()
	await process_frame

func _respawn_and_capture(game: Node2D) -> Array:
	for tourist in game.crowd_nodes:
		if is_instance_valid(tourist):
			tourist.queue_free()
	game.crowd_nodes.clear()
	await process_frame
	game._spawn_crowd()
	var layout: Array = []
	for tourist in game.crowd_nodes:
		tourist.set_physics_process(false)
		layout.append([tourist.tourist_type, tourist.position])
	return layout
