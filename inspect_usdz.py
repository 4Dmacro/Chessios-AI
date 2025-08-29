#!/usr/bin/env python3
"""
USDZ File Inspector
Inspects USDZ files and shows the object hierarchy and names.
"""

import sys
import os
from pxr import Usd, UsdGeom, Sdf

def inspect_usdz_file(filepath):
    """Inspect a USDZ file and print its structure."""
    if not os.path.exists(filepath):
        print(f"❌ File not found: {filepath}")
        return
    
    print(f"🔍 Inspecting USDZ file: {filepath}")
    print("=" * 50)
    
    try:
        # Open the USDZ file
        stage = Usd.Stage.Open(filepath)
        if not stage:
            print("❌ Failed to open USDZ file")
            return
        
        # Get the root layer
        root_layer = stage.GetRootLayer()
        print(f"📄 Root layer: {root_layer.identifier}")
        print(f"📄 Layer display name: {root_layer.displayName}")
        
        # Get the default prim
        default_prim = stage.GetDefaultPrim()
        if default_prim:
            print(f"🏠 Default prim: {default_prim.GetPath()}")
        
        # Traverse all prims
        print("\n🌳 Object Hierarchy:")
        print("-" * 30)
        
        def print_prim(prim, indent=0):
            """Recursively print prim information."""
            indent_str = "  " * indent
            prim_path = str(prim.GetPath())
            prim_name = prim.GetName()
            prim_type = prim.GetTypeName()
            
            # Get additional info
            is_visible = prim.GetAttribute('visibility').Get() if prim.HasAttribute('visibility') else "unknown"
            has_geometry = prim.HasAPI(UsdGeom.Gprim) or prim.HasAPI(UsdGeom.Mesh)
            
            print(f"{indent_str}📦 {prim_name}")
            print(f"{indent_str}   Path: {prim_path}")
            print(f"{indent_str}   Type: {prim_type}")
            print(f"{indent_str}   Has Geometry: {has_geometry}")
            if is_visible != "unknown":
                print(f"{indent_str}   Visible: {is_visible}")
            
            # Print children
            for child in prim.GetChildren():
                print_prim(child, indent + 1)
        
        # Start from root
        root_prims = stage.GetPseudoRoot().GetChildren()
        for prim in root_prims:
            print_prim(prim)
        
        # Get all prims with geometry
        print("\n🔷 Prims with Geometry:")
        print("-" * 30)
        for prim in stage.Traverse():
            if prim.HasAPI(UsdGeom.Gprim) or prim.HasAPI(UsdGeom.Mesh):
                print(f"📐 {prim.GetPath()} ({prim.GetTypeName()})")
        
        # Get all material bindings
        print("\n🎨 Material Bindings:")
        print("-" * 30)
        for prim in stage.Traverse():
            if prim.HasAttribute('material:binding'):
                binding = prim.GetAttribute('material:binding').Get()
                if binding:
                    print(f"🎨 {prim.GetPath()} -> {binding}")
        
        # Get all transform information
        print("\n🔄 Transforms:")
        print("-" * 30)
        for prim in stage.Traverse():
            if prim.HasAttribute('xformOp:translate') or prim.HasAttribute('xformOp:rotate') or prim.HasAttribute('xformOp:scale'):
                print(f"🔄 {prim.GetPath()}:")
                if prim.HasAttribute('xformOp:translate'):
                    translate = prim.GetAttribute('xformOp:translate').Get()
                    print(f"   Translate: {translate}")
                if prim.HasAttribute('xformOp:rotate'):
                    rotate = prim.GetAttribute('xformOp:rotate').Get()
                    print(f"   Rotate: {rotate}")
                if prim.HasAttribute('xformOp:scale'):
                    scale = prim.GetAttribute('xformOp:scale').Get()
                    print(f"   Scale: {scale}")
        
        print("\n✅ USDZ inspection complete!")
        
    except Exception as e:
        print(f"❌ Error inspecting USDZ file: {e}")
        import traceback
        traceback.print_exc()

def main():
    """Main function to inspect USDZ files."""
    if len(sys.argv) < 2:
        print("Usage: python3 inspect_usdz.py <usdz_file_path>")
        print("\nAvailable USDZ files in chess2 directory:")
        
        chess2_dir = "chess2"
        if os.path.exists(chess2_dir):
            for file in os.listdir(chess2_dir):
                if file.endswith('.usdz'):
                    print(f"  - {chess2_dir}/{file}")
        
        return
    
    filepath = sys.argv[1]
    inspect_usdz_file(filepath)

if __name__ == "__main__":
    main() 