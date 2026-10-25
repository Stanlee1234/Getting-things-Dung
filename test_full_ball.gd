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
    
    # Let ball drop and settle
    for i in range(25):
        await physics_frame
        
    print("--- SCENARIO 1: Settle Ball pos: ", ball.global_position)
    
    # Place beetle on top of ball
    beetle.global_position = ball.global_position + Vector2(5, -45)
    beetle.velocity = Vector2.ZERO
    for i in range(10):
        await physics_frame
        
    print("Scenario 1 (Beetle on top): is_top=", beetle.is_on_top_of_ball(ball), " ball_vel=", ball.linear_velocity)

    quit()
