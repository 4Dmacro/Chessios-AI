#!/usr/bin/env swift

import Foundation
import SceneKit

// MARK: - USDZ Inspector
class USDZInspector {
    
    static func inspectUSDZFile(at path: String) {
        print("🔍 Inspecting USDZ file: \(path)")
        print(String(repeating: "=", count: 50))
        
        // Convert string path to URL
        let url = URL(fileURLWithPath: path)
        
        do {
            let scene = try SCNScene(url: url, options: nil)
            print("✅ Successfully loaded USDZ file")
            print("📄 Scene name: \(scene.rootNode.name ?? "unnamed")")
            
            // Inspect root node
            inspectNode(scene.rootNode, indent: 0)
            
            // Find all geometry nodes
            print("\n🔷 Geometry Nodes:")
            print(String(repeating: "-", count: 30))
            findGeometryNodes(scene.rootNode)
            
            // Find all material nodes
            print("\n🎨 Material Nodes:")
            print(String(repeating: "-", count: 30))
            findMaterialNodes(scene.rootNode)
            
            print("\n✅ USDZ inspection complete!")
            
        } catch {
            print("❌ Failed to load USDZ file: \(error)")
        }
    }
    
    private static func inspectNode(_ node: SCNNode, indent: Int) {
        let indentStr = String(repeating: "  ", count: indent)
        let nodeName = node.name ?? "unnamed"
        let nodeType = type(of: node)
        
        print("\(indentStr)📦 \(nodeName)")
        print("\(indentStr)   Type: \(nodeType)")
        
        if let geometry = node.geometry {
            print("\(indentStr)   Geometry: \(type(of: geometry))")
            if let geometryName = geometry.name {
                print("\(indentStr)   Geometry Name: \(geometryName)")
            }
        }
        
        if let material = node.geometry?.firstMaterial {
            print("\(indentStr)   Material: \(material.name ?? "unnamed")")
        }
        
        if node.childNodes.count > 0 {
            print("\(indentStr)   Children: \(node.childNodes.count)")
        }
        
        // Inspect children
        for child in node.childNodes {
            inspectNode(child, indent: indent + 1)
        }
    }
    
    private static func findGeometryNodes(_ node: SCNNode) {
        if let geometry = node.geometry {
            let nodeName = node.name ?? "unnamed"
            let geometryType = type(of: geometry)
            print("📐 \(nodeName) -> \(geometryType)")
            
            if let geometryName = geometry.name {
                print("   Geometry Name: \(geometryName)")
            }
        }
        
        for child in node.childNodes {
            findGeometryNodes(child)
        }
    }
    
    private static func findMaterialNodes(_ node: SCNNode) {
        if let material = node.geometry?.firstMaterial {
            let nodeName = node.name ?? "unnamed"
            let materialName = material.name ?? "unnamed"
            print("🎨 \(nodeName) -> \(materialName)")
        }
        
        for child in node.childNodes {
            findMaterialNodes(child)
        }
    }
}

// MARK: - Main
func main() {
    let args = CommandLine.arguments
    
    if args.count < 2 {
        print("Usage: swift inspect_usdz.swift <usdz_file_path>")
        print("\nAvailable USDZ files in chess2 directory:")
        
        let chess2Dir = "chess2"
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: chess2Dir) {
            for file in contents {
                if file.hasSuffix(".usdz") {
                    print("  - \(chess2Dir)/\(file)")
                }
            }
        }
        return
    }
    
    let filepath = args[1]
    USDZInspector.inspectUSDZFile(at: filepath)
}

main() 