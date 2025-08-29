import bpy
import bmesh
import math
from mathutils import Vector

def clear_scene():
    """Clear all objects from the scene"""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)

def create_pawn():
    """Create a pawn from basic shapes"""
    # Base
    bpy.ops.mesh.primitive_cylinder_add(radius=0.4, depth=0.2)
    base = bpy.context.active_object
    base.name = "Pawn_Base"
    
    # Body
    bpy.ops.mesh.primitive_cylinder_add(radius=0.25, depth=0.6)
    body = bpy.context.active_object
    body.name = "Pawn_Body"
    body.location.z = 0.4
    
    # Head
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.2)
    head = bpy.context.active_object
    head.name = "Pawn_Head"
    head.location.z = 0.8
    
    # Join all parts
    objects_to_join = [base, body, head]
    bpy.context.view_layer.objects.active = base
    for obj in objects_to_join:
        obj.select_set(True)
    bpy.ops.object.join()
    
    pawn = bpy.context.active_object
    pawn.name = "Pawn"
    return pawn

def create_rook():
    """Create a rook from basic shapes"""
    # Base
    bpy.ops.mesh.primitive_cylinder_add(radius=0.4, depth=0.2)
    base = bpy.context.active_object
    base.name = "Rook_Base"
    
    # Body
    bpy.ops.mesh.primitive_cube_add(size=0.5)
    body = bpy.context.active_object
    body.name = "Rook_Body"
    body.location.z = 0.35
    body.scale = (0.8, 0.8, 0.7)
    
    # Top
    bpy.ops.mesh.primitive_cube_add(size=0.6)
    top = bpy.context.active_object
    top.name = "Rook_Top"
    top.location.z = 0.7
    top.scale = (0.6, 0.6, 0.2)
    
    # Battlements (4 small cylinders)
    battlements = []
    positions = [(0.15, 0.15), (0.15, -0.15), (-0.15, 0.15), (-0.15, -0.15)]
    for i, pos in enumerate(positions):
        bpy.ops.mesh.primitive_cylinder_add(radius=0.05, depth=0.2)
        battlement = bpy.context.active_object
        battlement.name = f"Rook_Battlement_{i}"
        battlement.location = (pos[0], pos[1], 0.8)
        battlements.append(battlement)
    
    # Join all parts
    objects_to_join = [base, body, top] + battlements
    bpy.context.view_layer.objects.active = base
    for obj in objects_to_join:
        obj.select_set(True)
    bpy.ops.object.join()
    
    rook = bpy.context.active_object
    rook.name = "Rook"
    return rook

def create_knight():
    """Create a knight from basic shapes"""
    # Base
    bpy.ops.mesh.primitive_cylinder_add(radius=0.4, depth=0.2)
    base = bpy.context.active_object
    base.name = "Knight_Base"
    
    # Body
    bpy.ops.mesh.primitive_cylinder_add(radius=0.25, depth=0.5)
    body = bpy.context.active_object
    body.name = "Knight_Body"
    body.location.z = 0.35
    
    # Head (horse head shape approximated with sphere and cone)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.2)
    head = bpy.context.active_object
    head.name = "Knight_Head"
    head.location.z = 0.7
    head.scale = (1.2, 0.8, 0.8)
    
    # Snout
    bpy.ops.mesh.primitive_cone_add(radius1=0.1, radius2=0.05, depth=0.3)
    snout = bpy.context.active_object
    snout.name = "Knight_Snout"
    snout.location = (0.25, 0, 0.6)
    snout.rotation_euler = (0, math.radians(90), 0)
    
    # Join all parts
    objects_to_join = [base, body, head, snout]
    bpy.context.view_layer.objects.active = base
    for obj in objects_to_join:
        obj.select_set(True)
    bpy.ops.object.join()
    
    knight = bpy.context.active_object
    knight.name = "Knight"
    return knight

def create_bishop():
    """Create a bishop from basic shapes"""
    # Base
    bpy.ops.mesh.primitive_cylinder_add(radius=0.4, depth=0.2)
    base = bpy.context.active_object
    base.name = "Bishop_Base"
    
    # Body
    bpy.ops.mesh.primitive_cylinder_add(radius=0.25, depth=0.5)
    body = bpy.context.active_object
    body.name = "Bishop_Body"
    body.location.z = 0.35
    
    # Top (cone shape)
    bpy.ops.mesh.primitive_cone_add(radius1=0.2, radius2=0.05, depth=0.4)
    top = bpy.context.active_object
    top.name = "Bishop_Top"
    top.location.z = 0.75
    
    # Slit in top
    bpy.ops.mesh.primitive_cube_add(size=0.1)
    slit = bpy.context.active_object
    slit.name = "Bishop_Slit"
    slit.location = (0, 0, 0.75)
    slit.scale = (0.1, 0.3, 0.2)
    
    # Join all parts
    objects_to_join = [base, body, top, slit]
    bpy.context.view_layer.objects.active = base
    for obj in objects_to_join:
        obj.select_set(True)
    bpy.ops.object.join()
    
    bishop = bpy.context.active_object
    bishop.name = "Bishop"
    return bishop

def create_queen():
    """Create a queen from basic shapes"""
    # Base
    bpy.ops.mesh.primitive_cylinder_add(radius=0.4, depth=0.2)
    base = bpy.context.active_object
    base.name = "Queen_Base"
    
    # Body
    bpy.ops.mesh.primitive_cylinder_add(radius=0.25, depth=0.6)
    body = bpy.context.active_object
    body.name = "Queen_Body"
    body.location.z = 0.4
    
    # Crown base
    bpy.ops.mesh.primitive_cylinder_add(radius=0.2, depth=0.2)
    crown_base = bpy.context.active_object
    crown_base.name = "Queen_Crown_Base"
    crown_base.location.z = 0.7
    
    # Crown points (8 small cones)
    crown_points = []
    for i in range(8):
        angle = (i * 45) * math.pi / 180
        x = 0.15 * math.cos(angle)
        y = 0.15 * math.sin(angle)
        
        bpy.ops.mesh.primitive_cone_add(radius1=0.03, radius2=0.01, depth=0.15)
        point = bpy.context.active_object
        point.name = f"Queen_Crown_Point_{i}"
        point.location = (x, y, 0.85)
        crown_points.append(point)
    
    # Join all parts
    objects_to_join = [base, body, crown_base] + crown_points
    bpy.context.view_layer.objects.active = base
    for obj in objects_to_join:
        obj.select_set(True)
    bpy.ops.object.join()
    
    queen = bpy.context.active_object
    queen.name = "Queen"
    return queen

def create_king():
    """Create a king from basic shapes"""
    # Base
    bpy.ops.mesh.primitive_cylinder_add(radius=0.4, depth=0.2)
    base = bpy.context.active_object
    base.name = "King_Base"
    
    # Body
    bpy.ops.mesh.primitive_cylinder_add(radius=0.25, depth=0.6)
    body = bpy.context.active_object
    body.name = "King_Body"
    body.location.z = 0.4
    
    # Crown base
    bpy.ops.mesh.primitive_cylinder_add(radius=0.2, depth=0.2)
    crown_base = bpy.context.active_object
    crown_base.name = "King_Crown_Base"
    crown_base.location.z = 0.7
    
    # Cross on top
    bpy.ops.mesh.primitive_cube_add(size=0.1)
    cross_vertical = bpy.context.active_object
    cross_vertical.name = "King_Cross_Vertical"
    cross_vertical.location = (0, 0, 0.85)
    cross_vertical.scale = (0.05, 0.05, 0.2)
    
    bpy.ops.mesh.primitive_cube_add(size=0.1)
    cross_horizontal = bpy.context.active_object
    cross_horizontal.name = "King_Cross_Horizontal"
    cross_horizontal.location = (0, 0, 0.85)
    cross_horizontal.scale = (0.15, 0.05, 0.05)
    
    # Join all parts
    objects_to_join = [base, body, crown_base, cross_vertical, cross_horizontal]
    bpy.context.view_layer.objects.active = base
    for obj in objects_to_join:
        obj.select_set(True)
    bpy.ops.object.join()
    
    king = bpy.context.active_object
    king.name = "King"
    return king

def create_chess_set():
    """Create a complete chess set"""
    # Clear the scene
    clear_scene()
    
    # Create all pieces
    pieces = {}
    
    # White pieces
    pieces['white_pawn'] = create_pawn()
    pieces['white_pawn'].location = (0, 0, 0)
    
    pieces['white_rook'] = create_rook()
    pieces['white_rook'].location = (2, 0, 0)
    
    pieces['white_knight'] = create_knight()
    pieces['white_knight'].location = (4, 0, 0)
    
    pieces['white_bishop'] = create_bishop()
    pieces['white_bishop'].location = (6, 0, 0)
    
    pieces['white_queen'] = create_queen()
    pieces['white_queen'].location = (8, 0, 0)
    
    pieces['white_king'] = create_king()
    pieces['white_king'].location = (10, 0, 0)
    
    # Black pieces (same shapes, different materials later)
    pieces['black_pawn'] = create_pawn()
    pieces['black_pawn'].location = (0, 2, 0)
    
    pieces['black_rook'] = create_rook()
    pieces['black_rook'].location = (2, 2, 0)
    
    pieces['black_knight'] = create_knight()
    pieces['black_knight'].location = (4, 2, 0)
    
    pieces['black_bishop'] = create_bishop()
    pieces['black_bishop'].location = (6, 2, 0)
    
    pieces['black_queen'] = create_queen()
    pieces['black_queen'].location = (8, 2, 0)
    
    pieces['black_king'] = create_king()
    pieces['black_king'].location = (10, 2, 0)
    
    print("Chess pieces created successfully!")
    print("You can now:")
    print("1. Select individual pieces to modify")
    print("2. Add materials (white/black)")
    print("3. Adjust proportions as needed")
    print("4. Export as USDZ for your iOS app")
    
    return pieces

# Run the script
if __name__ == "__main__":
    create_chess_set() 