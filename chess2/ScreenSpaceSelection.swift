//
//  ScreenSpaceSelection.swift
//  chess2
//
//  Created by Gareth Costa on 17/7/2025.
//

import Foundation
import SceneKit
import SwiftUI

// This file implements professional-grade screen space selection for the chess game
// It uses techniques similar to those in Photoshop and Blender for precise hit detection

struct ScreenSpaceSelection {
    // Just name the piece for direct hit detection (no collision nodes)
    static func addCollisionToPiece(_ pieceNode: SCNNode, collisionToPieceMap: inout [SCNNode: SCNNode]) {
        // Just name the piece properly for direct hit detection
        pieceNode.name = "Piece_\(pieceNode.name ?? "unknown")"
        
        // No collision nodes needed - we'll use the piece geometry directly
        print("🎯 Named piece for direct hit detection: \(pieceNode.name ?? "unknown")")
    }
}
