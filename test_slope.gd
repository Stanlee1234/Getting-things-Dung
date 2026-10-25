extends SceneTree

func _init():
    # Ball on a 25-degree slope
    var ball = RigidBody2D.new()
    var ball_col = CollisionShape2D.new()
    var ball_circle = CircleShape2D.new()
    ball_circle.radius = 29.0
    ball_col.shape = ball_circle
    ball.add_child(ball_col)
    ball.position = Vector2(0, 0)
    root.add_child(ball)
    
    # Static slope (25 deg)
    var slope = StaticBody2D.new()
    var slope_col = CollisionShape2D.new()
    var slope_poly = CollisionPolygon2D.new()
    # A triangle slope
    slope_poly.polygon = PackedVector2Array([
        Vector2(-200, 200),
        Vector2(200, 100),
        Vector2(200, 300),
        Vector2(-200, 300)
    ])
    slope.add_child(slope_poly)
    root.add_child(slope)
    
    # Let ball drop and settle on slope for 60 frames
    for i in range(60):
        await physics_frame
    
    print("Ball rolling on slope: pos=", ball.position, " vel=", ball.linear_velocity)
    quit()
