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
    
    for offset_x in [-20, -15, -10, -5, 0, 5, 10, 15, 20]:
        beetle.global_position = ball.global_position + Vector2(offset_x, -45)
        beetle.velocity = Vector2.ZERO
        for i in range(5):
            await physics_frame
        var has_ball_col = false
        var normal_y = 0.0
        for c in range(beetle.get_slide_collision_count()):
            var col = beetle.get_slide_collision(c)
            if col.get_collider() == ball:
                has_ball_col = true
                normal_y = col.get_normal().y
        print("offset x=", offset_x, " has_ball_col=", has_ball_col, " normal_y=", normal_y, " is_top=", beetle.is_on_top_of_ball(ball))

    quit()
