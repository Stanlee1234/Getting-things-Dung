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
    
    # 1. Place beetle on top of ball
    beetle.global_position = ball.global_position + Vector2(0, -45)
    for i in range(10):
        await physics_frame
        
    print("=== ON TOP OF BALL ===")
    for c in range(beetle.get_slide_collision_count()):
        var col = beetle.get_slide_collision(c)
        print("col ", c, ": collider=", col.get_collider().name, " norm=", col.get_normal(), " pos=", col.get_position())
        
    # 2. Place beetle to side of ball on ground
    beetle.global_position = ball.global_position + Vector2(-38, 10)
    for i in range(10):
        await physics_frame
        
    print("=== BESIDE BALL ===")
    for c in range(beetle.get_slide_collision_count()):
        var col = beetle.get_slide_collision(c)
        print("col ", c, ": collider=", col.get_collider().name, " norm=", col.get_normal(), " pos=", col.get_position())

    quit()
