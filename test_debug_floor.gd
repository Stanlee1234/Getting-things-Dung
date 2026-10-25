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
    
    for i in range(25):
        await physics_frame
        
    beetle.global_position = ball.global_position + Vector2(0, -45)
    beetle.velocity = Vector2.ZERO
    
    for i in range(10):
        await physics_frame
        print("f", i, " pos=", beetle.global_position, " vel=", beetle.velocity, " on_floor=", beetle.is_on_floor(), " floor_layers=", beetle.platform_floor_layers)
        for c in range(beetle.get_slide_collision_count()):
            var col = beetle.get_slide_collision(c)
            print("   col ", c, ": collider=", col.get_collider().name, " norm=", col.get_normal())
    quit()
