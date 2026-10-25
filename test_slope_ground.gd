extends SceneTree

func _init():
    var ball = RigidBody2D.new()
    var ball_col = CollisionShape2D.new()
    var ball_circle = CircleShape2D.new()
    ball_circle.radius = 29.0
    ball_col.shape = ball_circle
    ball.add_child(ball_col)
    ball.position = Vector2(0, 0)
    ball.collision_layer = 2
    ball.collision_mask = 1
    root.add_child(ball)
    
    var slope = StaticBody2D.new()
    slope.collision_layer = 1
    slope.collision_mask = 3
    var slope_poly = CollisionPolygon2D.new()
    slope_poly.polygon = PackedVector2Array([
        Vector2(-200, 200),
        Vector2(200, 100),
        Vector2(200, 300),
        Vector2(-200, 300)
    ])
    slope.add_child(slope_poly)
    root.add_child(slope)
    
    for i in range(40):
        await physics_frame
        
    var space_state = ball.get_world_2d().direct_space_state
    var b_pos = ball.global_position
    var b_radius = 29.0
    
    var ray_down = PhysicsRayQueryParameters2D.create(b_pos, b_pos + Vector2(0, b_radius + 8.0), 1)
    var ray_dl = PhysicsRayQueryParameters2D.create(b_pos, b_pos + Vector2(-b_radius * 0.7, b_radius * 0.7 + 6.0), 1)
    var ray_dr = PhysicsRayQueryParameters2D.create(b_pos, b_pos + Vector2(b_radius * 0.7, b_radius * 0.7 + 6.0), 1)
    
    var hit = not space_state.intersect_ray(ray_down).is_empty() or not space_state.intersect_ray(ray_dl).is_empty() or not space_state.intersect_ray(ray_dr).is_empty()
    
    print("Slope test: pos=", b_pos, " hit=", hit)
    quit()
