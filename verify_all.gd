extends SceneTree

func _init():
    var pcm_script = load("res://addons/phantom_camera/scripts/managers/phantom_camera_manager.gd")
    var pcm = Node.new()
    pcm.set_script(pcm_script)
    pcm.name = "PhantomCameraManager"
    root.add_child(pcm)
    
    var game_scene = load("res://Scenes/game.tscn").instantiate()
    root.add_child(game_scene)
    paused = false
    
    var ball = game_scene.get_node("DungBall")
    var beetle = game_scene.get_node("Beetle")
    beetle.input_enabled = true
    
    # 1. Let ball settle
    for i in range(25):
        await physics_frame
        
    var ball_initial_pos = ball.global_position
    print("=== TEST 1: Settle Ball pos: ", ball_initial_pos)
    
    # Place beetle on top of ball (x+5, y-45)
    beetle.global_position = ball.global_position + Vector2(5, -45)
    beetle.velocity = Vector2.ZERO
    
    for i in range(20):
        await physics_frame
        
    print("TEST 1 - Idle on top: is_top=", beetle.is_on_top_of_ball(ball), " ball_pos=", ball.global_position, " ball_vel=", ball.linear_velocity)
    assert(ball.global_position.distance_to(ball_initial_pos) < 0.5, "Ball moved while standing idle!")
    
    # 2. Walk right while on top of ball
    print("=== TEST 2: Walking across top of ball ===")
    Input.action_press("right", 1.0)
    for i in range(20):
        await physics_frame
        if i % 5 == 0:
            print("  Walk top f", i, " beetle pos=", beetle.global_position, " ball pos=", ball.global_position, " ball vel=", ball.linear_velocity)
    Input.action_release("right")
    
    assert(ball.global_position.distance_to(ball_initial_pos) < 0.5, "Ball moved while walking on top!")
    print("TEST 2 PASSED: Ball did not move while walking on top!")
    
    # 3. Charging and jumping off the top of the ball
    print("=== TEST 3: Charge jump and jump off top ===")
    Input.action_press("up")
    for i in range(15):
        await physics_frame
    print("  Charging jump: beetle is_handstand=", beetle.is_handstand, " ball pos=", ball.global_position)
    assert(!beetle.is_handstand, "Beetle should NOT be handstanding while on top of ball!")
    
    Input.action_release("up")
    await physics_frame
    print("  Jump release: beetle vel=", beetle.velocity, " ball pos=", ball.global_position)
    assert(beetle.velocity.y < -150.0, "Beetle should jump upward!")
    assert(ball.global_position.distance_to(ball_initial_pos) < 0.5, "Ball moved during jump off top!")
    print("TEST 3 PASSED: Jumped off top cleanly, ball stayed still!")
    
    # 4. Now test side pushing
    print("=== TEST 4: Pushing ball from the side ===")
    beetle.global_position = ball.global_position + Vector2(-42, 10)
    beetle.velocity = Vector2.ZERO
    for i in range(10):
        await physics_frame
        
    var pre_push_x = ball.global_position.x
    Input.action_press("right", 1.0)
    for i in range(30):
        await physics_frame
    Input.action_release("right")
    
    print("  Side push: initial x=", pre_push_x, " new ball x=", ball.global_position.x, " ball vel=", ball.linear_velocity)
    assert(ball.global_position.x > pre_push_x + 5.0, "Ball should have been pushed to the right!")
    print("TEST 4 PASSED: Side pushing works properly!")

    quit()
