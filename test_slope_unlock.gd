extends SceneTree

func _init():
    var ball = RigidBody2D.new()
    var ball_col = CollisionShape2D.new()
    var ball_circle = CircleShape2D.new()
    ball_circle.radius = 29.0
    ball_col.shape = ball_circle
    ball.add_child(ball_col)
    ball.position = Vector2(0, 0)
    
    var script = GDScript.new()
    script.source_code = """extends RigidBody2D
var lock_ball = false
var lock_pos = Vector2.ZERO
func _integrate_forces(state: PhysicsDirectBodyState2D):
    if lock_ball:
        if lock_pos == Vector2.ZERO:
            lock_pos = state.transform.origin
        state.transform = Transform2D(state.transform.get_rotation(), lock_pos)
        state.linear_velocity = Vector2.ZERO
        state.angular_velocity = 0.0
    else:
        lock_pos = Vector2.ZERO
"""
    script.reload()
    ball.set_script(script)
    root.add_child(ball)
    
    var slope = StaticBody2D.new()
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
    
    print("Ball before locking: pos=", ball.position, " vel=", ball.linear_velocity)
    ball.lock_ball = true
    
    for i in range(40):
        await physics_frame
        
    print("Ball while locked: pos=", ball.position, " vel=", ball.linear_velocity)
    ball.lock_ball = false
    
    for i in range(40):
        await physics_frame
        if i % 10 == 0:
            print("Frame ", i, " after unlocking: pos=", ball.position, " vel=", ball.linear_velocity)
            
    quit()
