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
    
    var beetle = game_scene.get_node("Beetle")
    var ball = game_scene.get_node("DungBall")
    beetle.input_enabled = true
    
    # Place beetle above the ball with horizontal offset x+10, falling onto it
    beetle.global_position = ball.global_position + Vector2(10, -80)
    beetle.velocity = Vector2(0, 100)
    
    for i in range(10):
        await physics_frame
    
    paused = false
    beetle.input_enabled = true
    print("=== Landing on top of ball from above ===")
    for i in range(40):
        await physics_frame
        if i % 5 == 0:
            print("Frame ", i, " beetle pos: ", beetle.global_position, " vel: ", beetle.velocity, " ball pos: ", ball.global_position, " ball vel: ", ball.linear_velocity, " ang: ", ball.angular_velocity, " on_floor: ", beetle.is_on_floor(), " is_top: ", beetle.is_on_top_of_ball(ball))
    quit()
