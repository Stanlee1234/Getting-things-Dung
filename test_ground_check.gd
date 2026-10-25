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
    
    for i in range(20):
        await physics_frame
        
    var space_state = ball.get_world_2d().direct_space_state
    var b_pos = ball.global_position
    var b_radius = 29.0
    
    var ray_down = PhysicsRayQueryParameters2D.create(b_pos, b_pos + Vector2(0, b_radius + 8.0), 1)
    var hit_down = not space_state.intersect_ray(ray_down).is_empty()
    
    print("Ball at: ", b_pos, " hit_down: ", hit_down)
    quit()
