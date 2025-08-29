//
//  ChessPieceController.swift
//  chess2
//
//  Created by Kiro on 17/07/2025.
//

import Foundation
import SwiftUI
import SceneKit
import Combine

// Move direction enum
enum MoveDirection {
    case up, down, left, right, forward, backward
    case upLeft, upRight, downLeft, downRight
    case upZ, downZ
    case upZLeft, upZRight, downZLeft, downZRight
    case upZBackLeft, upZBackRight, downZForwardLeft, downZForwardRight
}

class ChessPieceController: ObservableObject {
    // Helper function to remap directions for player perspective
    private func playerPerspectiveDirection(_ direction: MoveDirection, for color: PieceColor) -> MoveDirection {
        switch direction {
        case .upLeft:
            return color == .black ? .upRight : .upLeft
        case .upRight:
            return color == .black ? .upLeft : .upRight
        case .downLeft:
            return color == .black ? .downRight : .downLeft
        case .downRight:
            return color == .black ? .downLeft : .downRight
        case .upZLeft:
            return color == .black ? .upZRight : .upZLeft
        case .upZRight:
            return color == .black ? .upZLeft : .upZRight
        case .downZLeft:
            return color == .black ? .downZRight : .downZLeft
        case .downZRight:
            return color == .black ? .downZLeft : .downZRight
        case .upZBackLeft:
            return (color == .black && isBoardRotatedForBlack) ? .upZBackRight : .upZBackLeft
        case .upZBackRight:
            return (color == .black && isBoardRotatedForBlack) ? .upZBackLeft : .upZBackRight
        case .downZForwardLeft:
            return (color == .black && isBoardRotatedForBlack) ? .downZForwardRight : .downZForwardLeft
        case .downZForwardRight:
            return (color == .black && isBoardRotatedForBlack) ? .downZForwardLeft : .downZForwardRight
        case .forward, .backward, .left, .right, .up, .down, .upZ, .downZ:
            return direction
        }
    }
    
    // Selected piece and position
    @Published var selectedPiece: SCNNode?
    @Published var selectedPiecePosition: ChessPosition3D?
    @Published var selectedPieceName: String = "No piece selected"
    
    // Movement distance control
    @Published var moveDistance: Int = 1
    
    // Knight movement mode
    @Published var knightMode: Bool = false
    @Published var knightFirstMove: MoveDirection?
    @Published var isKnightMoving: Bool = false
    @Published var isMoveButtonClicked: Bool = false
    
    // Timer state for move confirmation
    @Published var isMovePending: Bool = false
    @Published var moveConfirmationTimeRemaining: Double = 5.0
    @Published var pendingMoveFrom: ChessPosition3D?
    @Published var pendingMoveTo: ChessPosition3D?
    @Published var pendingPieceNode: SCNNode?
    
    var chessGame: ChessGameManager?
    
    private var moveConfirmationTimer: Timer?
    
    // Movement controls
    @Published var moveForward: Bool = false {
        didSet { 
            if moveForward && !oldValue && !knightMode { 
                moveSelectedPiece(direction: .forward, distance: moveDistance) 
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.moveForward = false
                }
            }
        }
    }
    @Published var moveBackward: Bool = false {
        didSet { 
            if moveBackward && !oldValue && !knightMode { 
                moveSelectedPiece(direction: .backward, distance: moveDistance) 
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.moveBackward = false
                }
            }
        }
    }
    @Published var moveLeft: Bool = false {
        didSet { 
            if moveLeft && !oldValue && !knightMode { 
                moveSelectedPiece(direction: .left, distance: moveDistance) 
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.moveLeft = false
                }
            }
        }
    }
    @Published var moveRight: Bool = false {
        didSet { 
            if moveRight && !oldValue && !knightMode { 
                moveSelectedPiece(direction: .right, distance: moveDistance) 
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.moveRight = false
                }
            }
        }
    }
    
    @Published var moveUp: Bool = false {
        didSet { 
            if moveUp && !oldValue && !knightMode { 
                moveSelectedPiece(direction: .up, distance: moveDistance) 
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.moveUp = false
                }
            }
        }
    }
    
    @Published var moveDown: Bool = false {
        didSet { 
            if moveDown && !oldValue && !knightMode { 
                moveSelectedPiece(direction: .down, distance: moveDistance) 
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.moveDown = false
                }
            }
        }
    }
    
    // Diagonal movement controls
    @Published var moveUpLeft: Bool = false {
        didSet { 
            if moveUpLeft && !oldValue && !knightMode { 
                moveSelectedPieceWithPlayerPerspective(direction: .upLeft, distance: moveDistance) 
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.moveUpLeft = false
                }
            }
        }
    }
    @Published var moveUpRight: Bool = false {
        didSet { 
            if moveUpRight && !oldValue && !knightMode { 
                moveSelectedPieceWithPlayerPerspective(direction: .upRight, distance: moveDistance) 
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.moveUpRight = false
                }
            }
        }
    }
    @Published var moveDownLeft: Bool = false {
        didSet { 
            if moveDownLeft && !oldValue && !knightMode { 
                moveSelectedPieceWithPlayerPerspective(direction: .downLeft, distance: moveDistance) 
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.moveDownLeft = false
                }
            }
        }
    }
    @Published var moveDownRight: Bool = false {
        didSet { 
            if moveDownRight && !oldValue && !knightMode { 
                moveSelectedPieceWithPlayerPerspective(direction: .downRight, distance: moveDistance) 
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.moveDownRight = false
                }
            }
        }
    }
    
    // Z movement controls
    @Published var moveUpZ: Bool = false {
        didSet {
            if moveUpZ && !oldValue && !knightMode {
                moveSelectedPieceZ(direction: .up, distance: moveDistance)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.moveUpZ = false
                }
            }
        }
    }
    @Published var moveDownZ: Bool = false {
        didSet {
            if moveDownZ && !oldValue && !knightMode {
                moveSelectedPieceZ(direction: .down, distance: moveDistance)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.moveDownZ = false
                }
            }
        }
    }
    
    // 3D diagonal movement controls
    @Published var moveUpZLeft: Bool = false {
        didSet { 
            if moveUpZLeft && !oldValue && !knightMode { 
                moveSelectedPieceWithPlayerPerspective(direction: .upZLeft, distance: moveDistance) 
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.moveUpZLeft = false
                }
            }
        }
    }
    @Published var moveUpZRight: Bool = false {
        didSet { 
            if moveUpZRight && !oldValue && !knightMode { 
                moveSelectedPieceWithPlayerPerspective(direction: .upZRight, distance: moveDistance) 
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.moveUpZRight = false
                }
            }
        }
    }
    @Published var moveDownZLeft: Bool = false {
        didSet { 
            if moveDownZLeft && !oldValue && !knightMode { 
                moveSelectedPieceWithPlayerPerspective(direction: .downZLeft, distance: moveDistance) 
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.moveDownZLeft = false
                }
            }
        }
    }
    @Published var moveDownZRight: Bool = false {
        didSet { 
            if moveDownZRight && !oldValue && !knightMode { 
                moveSelectedPieceWithPlayerPerspective(direction: .downZRight, distance: moveDistance) 
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.moveDownZRight = false
                }
            }
        }
    }
    @Published var moveUpZBackLeft: Bool = false {
        didSet { 
            if moveUpZBackLeft && !oldValue && !knightMode { 
                moveSelectedPieceWithPlayerPerspective(direction: .upZBackLeft, distance: moveDistance) 
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.moveUpZBackLeft = false
                }
            }
        }
    }
    @Published var moveUpZBackRight: Bool = false {
        didSet { 
            if moveUpZBackRight && !oldValue && !knightMode { 
                moveSelectedPieceWithPlayerPerspective(direction: .upZBackRight, distance: moveDistance) 
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.moveUpZBackRight = false
                }
            }
        }
    }
    @Published var moveDownZForwardLeft: Bool = false {
        didSet { 
            if moveDownZForwardLeft && !oldValue && !knightMode { 
                moveSelectedPieceWithPlayerPerspective(direction: .downZForwardLeft, distance: moveDistance) 
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.moveDownZForwardLeft = false
                }
            }
        }
    }
    @Published var moveDownZForwardRight: Bool = false {
        didSet { 
            if moveDownZForwardRight && !oldValue && !knightMode { 
                moveSelectedPieceWithPlayerPerspective(direction: .downZForwardRight, distance: moveDistance) 
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.moveDownZForwardRight = false
                }
            }
        }
    }
    
    // 3D diagonal movement state
    @Published var is3DDiagonalMode: Bool = false
    @Published var diagonalZDirection: MoveDirection?
    @Published var diagonalInstruction: String = ""
    
    // Move history
    @Published var moveHistory: [String] = []
    @Published var showMoveHistory: Bool = false
    
    // Reference to the chess game manager
    // private var chessGame: ChessGameManager? // This line is removed
    
    // Movement direction enum
    enum MoveDirection {
        case forward
        case backward
        case left
        case right
        case upLeft
        case upRight
        case downLeft
        case downRight
        case up
        case down
        case upZ
        case downZ
        case upZLeft
        case upZRight
        case downZLeft
        case downZRight
        case upZBackLeft
        case upZBackRight
        case downZForwardLeft
        case downZForwardRight
    }
    
    // Piece lists for white and black
    @Published var whitePieces: [ChessPiece3D] = []
    @Published var blackPieces: [ChessPiece3D] = []
    
    // Initialize with chess game manager
    init(chessGame: ChessGameManager? = nil) {
        self.chessGame = chessGame
        updatePieceLists()
    }
    
    // Set the chess game manager
    func setChessGame(_ chessGame: ChessGameManager) {
        self.chessGame = chessGame
        updatePieceLists()
    }
    
    // Get the current turn
    func getCurrentTurn() -> PieceColor {
        guard let chessGame = chessGame else { return .white }
        return chessGame.getCurrentTurn()
    }
    
    // Get the current game mode
    func getGameMode() -> GameMode {
        guard let chessGame = chessGame else { return .play }
        return chessGame.gameMode
    }
    
    // Check if the current player's king is in check
    func isKingInCheck() -> Bool {
        // print("🔍 isKingInCheck() called")
        guard let chessGame = chessGame else { 
            print("🔍 isKingInCheck: No chessGame")
            return false 
        }
        let result = chessGame.isKingInCheck()
        // print("🔍 isKingInCheck: Result = \(result)")
        return result
    }
    
    // Check if castling is available
    func canCastle(side: CastlingSide) -> Bool {
        guard let chessGame = chessGame else { return false }
        return chessGame.canCastle(side: side)
    }
    
    // Perform castling
    func performCastling(side: CastlingSide) {
        guard let chessGame = chessGame else { return }
        
        let success = chessGame.performCastling(side: side)
        if success {
            print("♔ Castling successful: \(side)")
            // Update piece lists
            updatePieceLists()
            
            // Force UI refresh to update turn indicator and piece selector
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
            
            // Rotate board for the new turn after a 2-second delay (same as normal moves)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                chessGame.rotateBoardForTurn()
            }
        } else {
            print("❌ Castling failed: \(side)")
        }
    }
    
    // Check if the selected piece is a king
    func isSelectedPieceKing() -> Bool {
        // print("🔍 isSelectedPieceKing() called")
        
        guard let chessGame = chessGame else {
            print("🔍 isSelectedPieceKing: No chessGame")
            return false
        }
        
        guard let selectedPosition = selectedPiecePosition else {
            print("🔍 isSelectedPieceKing: No selectedPosition")
            return false
        }
        
        guard let piece = chessGame.getPieceAtPosition(selectedPosition) else {
            print("🔍 isSelectedPieceKing: No piece at position \(selectedPosition.stringValue)")
            return false
        }
        
        print("🔍 isSelectedPieceKing: Found piece \(piece.color) \(piece.type)")
        return piece.type == .king
    }
    
    // Clear the selected piece and remove highlight
    func clearSelectedPiece() {
        print("🎯 ChessPieceController: Clearing selected piece")
        
        // Remove highlight from current selected piece
        if let selectedPiece = selectedPiece {
            selectedPiece.enumerateChildNodes { (childNode, _) in
                if childNode.name == "PieceHighlight" {
                    print("🎯 Removing highlight node: \(childNode.name ?? "unknown")")
                    childNode.removeFromParentNode()
                }
            }
        }
        
        // Clear selected piece state
        selectedPiece = nil
        selectedPiecePosition = nil
        selectedPieceName = "No piece selected"
        
        print("🎯 ChessPieceController: Selected piece cleared")
    }
    
    // Update the selected piece position after a move
    func updateSelectedPiecePosition(to newPosition: ChessPosition3D) {
        print("🎯 ChessPieceController: Updating selected piece position to \(newPosition.stringValue)")
        selectedPiecePosition = newPosition
    }
    
    // Update the piece lists for the side panels
    func updatePieceLists() {
        guard let chessGame = chessGame else { return }
        
        whitePieces = chessGame.chessBoard.getPieces(of: .white)
        blackPieces = chessGame.chessBoard.getPieces(of: .black)
        
        // Get captured pieces
        let capturedWhitePieces = chessGame.getCapturedPieces().filter { $0.color == .white }
        let capturedBlackPieces = chessGame.getCapturedPieces().filter { $0.color == .black }
        
        let totalPiecesOnBoard = chessGame.chessBoard.pieces.count
        let totalCapturedPieces = capturedWhitePieces.count + capturedBlackPieces.count
        let totalPieces = totalPiecesOnBoard + totalCapturedPieces
        
        print("🔍 updatePieceLists: Chess board has \(totalPiecesOnBoard) pieces on board + \(totalCapturedPieces) captured = \(totalPieces) total pieces")
        print("🔍 updatePieceLists: Found \(whitePieces.count) white pieces and \(blackPieces.count) black pieces")
            
            // Only print detailed debug info if not in knight mode to reduce interference
            if !knightMode {
        print("📋 Updated piece lists:")
        print("  White pieces (\(whitePieces.count)):")
        for piece in whitePieces {
            print("    - \(piece.color) \(piece.type) at \(piece.position.stringValue)")
        }
        print("  Black pieces (\(blackPieces.count)):")
        for piece in blackPieces {
            print("    - \(piece.color) \(piece.type) at \(piece.position.stringValue)")
                }
        }
        
        // Debug: Check if we have the expected number of pieces (accounting for captures)
        let capturedWhitePiecesCount = chessGame.getCapturedPiecesCount(for: .white)
        let capturedBlackPiecesCount = chessGame.getCapturedPiecesCount(for: .black)
        
        let expectedWhitePieces = 32 - capturedWhitePiecesCount // 24 pawns (8 original + 16 extended) + 2 rooks + 2 knights + 2 bishops + 1 queen + 1 king
        let expectedBlackPieces = 32 - capturedBlackPiecesCount
        
        // Only show piece count warnings if not in knight mode to reduce interference
        if !knightMode {
        if whitePieces.count != expectedWhitePieces {
                print("⚠️ WARNING: Expected \(expectedWhitePieces) white pieces (32 - \(capturedWhitePiecesCount) captured), but got \(whitePieces.count)")
        }
        if blackPieces.count != expectedBlackPieces {
                print("⚠️ WARNING: Expected \(expectedBlackPieces) black pieces (32 - \(capturedBlackPiecesCount) captured), but got \(blackPieces.count)")
            }
        }
        
        // Debug: Check for specific missing pieces (accounting for captures)
        let whitePieceTypes = whitePieces.map { $0.type }
        let blackPieceTypes = blackPieces.map { $0.type }
        
        // Get captured pieces by type
        let capturedWhitePiecesByType = chessGame.getCapturedPieces().filter { $0.color == .white }.map { $0.type }
        let capturedBlackPiecesByType = chessGame.getCapturedPieces().filter { $0.color == .black }.map { $0.type }
        
        let expectedWhiteTypes: [PieceType] = Array(repeating: .pawn, count: 24) + [.rook, .knight, .bishop, .queen, .king, .bishop, .knight, .rook]
        let expectedBlackTypes: [PieceType] = Array(repeating: .pawn, count: 24) + [.rook, .knight, .bishop, .queen, .king, .bishop, .knight, .rook]
        
        for pieceType in expectedWhiteTypes {
            let count = whitePieceTypes.filter { $0 == pieceType }.count
            let captured = capturedWhitePiecesByType.filter { $0 == pieceType }.count
            let expected = expectedWhiteTypes.filter { $0 == pieceType }.count - captured
            if count != expected {
                print("⚠️ WARNING: White \(pieceType) - expected \(expected) (original \(expectedWhiteTypes.filter { $0 == pieceType }.count) - \(captured) captured), got \(count)")
            }
        }
        
        for pieceType in expectedBlackTypes {
            let count = blackPieceTypes.filter { $0 == pieceType }.count
            let captured = capturedBlackPiecesByType.filter { $0 == pieceType }.count
            let expected = expectedBlackTypes.filter { $0 == pieceType }.count - captured
            if count != expected {
                print("⚠️ WARNING: Black \(pieceType) - expected \(expected) (original \(expectedBlackTypes.filter { $0 == pieceType }.count) - \(captured) captured), got \(count)")
            }
        }
    }
    
    // Select a piece from the list
    func selectPieceFromList(_ piece: ChessPiece3D) {
        print("🎯 ChessPieceController: selectPieceFromList called for \(piece.color) \(piece.type) at \(piece.position.stringValue)")
        print("🎯 isMoveButtonClicked: \(isMoveButtonClicked)")
        
        // Debug: Check if this piece matches what we expect
        guard let chessGame = chessGame else { 
            print("⚠️ ChessPieceController: No chess game available")
            return 
        }
        
        // Check if this piece is actually at the position it claims to be
        if let actualPiece = chessGame.getPieceAtPosition(piece.position) {
            if actualPiece.type == piece.type && actualPiece.color == piece.color {
                print("✅ Piece in list matches chess board state")
            } else {
                print("❌ Piece in list doesn't match chess board state!")
                print("   List piece: \(piece.color) \(piece.type) at \(piece.position.stringValue)")
                print("   Board piece: \(actualPiece.color) \(actualPiece.type) at \(piece.position.stringValue)")
            }
        } else {
            print("❌ No piece found at position \(piece.position.stringValue) in chess board!")
        }
        
        // Prevent piece selection if a move button was just clicked
        if isMoveButtonClicked {
            print("🎯 Piece list selection ignored - move button was just clicked")
            return
        }
        
        // Find the SCNNode for this piece
        print("🎯 ChessPieceController: Looking for piece node at \(piece.position.stringValue)")
        if let pieceNode = chessGame.getPieceNode(at: piece.position) {
            print("🎯 ChessPieceController: Found piece node: \(pieceNode.name ?? "unknown") at world position: \(pieceNode.position)")
            print("🎯 ChessPieceController: Piece node world position: \(pieceNode.worldPosition)")
            print("🎯 ChessPieceController: Piece node transform: \(pieceNode.transform)")
            
            // Debug: Check if this is the right piece by comparing with chess board state
            if let boardPiece = chessGame.getPieceAtPosition(piece.position) {
                print("🎯 ChessPieceController: Board expects: \(boardPiece.color) \(boardPiece.type) at \(piece.position.stringValue)")
                print("🎯 ChessPieceController: Selected piece: \(piece.color) \(piece.type) at \(piece.position.stringValue)")
                if boardPiece.type == piece.type && boardPiece.color == piece.color {
                    print("✅ Piece types match!")
                } else {
                    print("❌ Piece types don't match!")
                }
            }
            
            selectedPiece = pieceNode
            selectedPiecePosition = piece.position
            selectedPieceName = "\(piece.color.rawValue.capitalized) \(piece.type.rawValue.capitalized)"
            
            // Enable knight mode if this is a knight
            knightMode = (piece.type == .knight)
            knightFirstMove = nil
            
            // Highlight the selected piece
            highlightSelectedPiece()
            print("✅ Successfully selected \(piece.color) \(piece.type) at \(piece.position.stringValue)")
        } else {
            print("⚠️ ChessPieceController: No piece node found for \(piece.color) \(piece.type) at \(piece.position.stringValue)")
        }
    }
    
    // Select a piece from a board position
    func selectPieceAtPosition(_ position: ChessPosition3D) {
        print("🎯 ChessPieceController: selectPieceAtPosition called for \(position.stringValue)")
        
        guard let chessGame = chessGame else { 
            print("⚠️ ChessPieceController: No chess game available")
            return 
        }
        
        print("🎯 ChessPieceController: Looking for piece at position \(position.stringValue)")
        
        if let piece = chessGame.getPieceAtPosition(position) {
            print("🎯 ChessPieceController: Found piece: \(piece.color) \(piece.type)")
            
            if let pieceNode = chessGame.getPieceNode(at: position) {
                print("🎯 ChessPieceController: Found piece node: \(pieceNode.name ?? "unknown")")
                
            selectedPiece = pieceNode
            selectedPiecePosition = position
            selectedPieceName = "\(piece.color.rawValue.capitalized) \(piece.type.rawValue.capitalized)"
            
            // Enable knight mode if this is a knight, disable otherwise
            knightMode = (piece.type == .knight)
            knightFirstMove = nil
            
            // Clear AI move display when a piece is selected
            chessGame.clearAIMoveDisplay()
            
                print("🎯 ChessPieceController: About to call highlightSelectedPiece()")
            // Highlight the selected piece
            highlightSelectedPiece()
            
                print("🎯 ChessPieceController: About to call showValidMoves()")
            // Show valid moves for this piece
            showValidMoves(for: piece)
            
                print("🎯 ChessPieceController: About to call updatePieceLists()")
            // Update the piece lists to reflect current board state
            updatePieceLists()
                
                print("🎯 ChessPieceController: Piece selection completed successfully")
            } else {
                print("⚠️ ChessPieceController: No piece node found for \(piece.color) \(piece.type) at \(position.stringValue)")
            }
        } else {
            print("⚠️ ChessPieceController: No piece found at position \(position.stringValue)")
        }
    }
    
    // Show valid moves for the selected piece
    private func showValidMoves(for piece: ChessPiece3D) {
        print("🎯 showValidMoves() called for \(piece.color) \(piece.type) at \(piece.position.stringValue)")
        
        guard let chessGame = chessGame else { 
            print("⚠️ showValidMoves: No chessGame")
            return 
        }
        
        print("🎯 showValidMoves: About to call clearMoveIndicators()")
        // Clear any existing move indicators
        clearMoveIndicators()
        
        print("🎯 showValidMoves: About to call chessGame.chessBoard.getValidMoves()")
        // Get valid moves from the chess game (for debugging/logging purposes)
        let validMoves = chessGame.chessBoard.getValidMoves(for: piece)
        print("🎯 Valid moves for \(piece.type) at \(piece.position.stringValue): \(validMoves.map { $0.to.stringValue })")
    }
    
    // Clear all move indicators (kept for compatibility, but no longer needed)
    private func clearMoveIndicators() {
        // No longer creating move indicators, so nothing to clear
    }
    
    // Highlight the selected piece
    private func highlightSelectedPiece() {
        guard let selectedPiece = selectedPiece else { 
            print("⚠️ ChessPieceController: Cannot highlight piece: no piece selected")
            return 
        }
        
        print("🎯 ChessPieceController: Highlighting piece at world position: \(selectedPiece.worldPosition)")
        print("🎯 ChessPieceController: Piece name: \(selectedPiece.name ?? "unknown")")
        print("🎯 ChessPieceController: Piece transform: \(selectedPiece.transform)")
        print("🎯 ChessPieceController: Piece has \(selectedPiece.childNodes.count) child nodes")
        
        // Remove highlight from all pieces first
        removeAllHighlights()
        
        // Add highlight to selected piece
        let highlightMaterial = SCNMaterial()
        highlightMaterial.diffuse.contents = NSColor.yellow
        highlightMaterial.emission.contents = NSColor.yellow
        highlightMaterial.transparency = 0.3
        
        // Determine highlight size based on piece type
        var highlightRadius: CGFloat = 0.5  // Default size for pawns
        
        if let currentPosition = selectedPiecePosition,
           let piece = chessGame?.getPieceAtPosition(currentPosition) {
            // Use larger highlight for non-pawn pieces
            if piece.type != .pawn {
                highlightRadius = 0.4  // Double size for major pieces
            }
        }
        
        let highlightGeometry = SCNSphere(radius: highlightRadius)
        highlightGeometry.materials = [highlightMaterial]
        
        let highlightNode = SCNNode(geometry: highlightGeometry)
        highlightNode.position = SCNVector3(0, 0, 0.3)  // Local offset above the piece
        highlightNode.name = "PieceHighlight"
        
        print("🎯 ChessPieceController: Created highlight node with radius: \(highlightRadius)")
        print("🎯 ChessPieceController: About to add highlight as child of: \(selectedPiece.name ?? "unknown")")
        
        // Add as child of the selected piece so it moves with the piece and board
        selectedPiece.addChildNode(highlightNode)
        
        print("🎯 ChessPieceController: Highlight node local position: \(highlightNode.position)")
        print("🎯 ChessPieceController: Piece now has \(selectedPiece.childNodes.count) child nodes")
        print("🎯 ChessPieceController: Added highlight successfully!")
    }
    
    // Remove all highlights
    private func removeAllHighlights() {
        guard let chessGame = chessGame, let scene = chessGame.getScene() else { return }
        
        // Remove highlights from all nodes in the scene, not just root children
        scene.rootNode.enumerateChildNodes { (node, _) in
            // Check if this node itself is a highlight
            if node.name == "PieceHighlight" {
                node.removeFromParentNode()
            }
            
            // Also check all children of this node for highlights
            node.enumerateChildNodes { (childNode, _) in
                if childNode.name == "PieceHighlight" {
                    print("🎯 Removing highlight node: \(childNode.name ?? "unknown") from \(node.name ?? "unknown")")
                    childNode.removeFromParentNode()
                }
            }
        }
    }
    
    // Move the selected piece in the specified direction
    func moveSelectedPiece(direction: MoveDirection, distance: Int = 1) {
        // Handle knight movement differently
        if knightMode {
            moveKnight(direction: direction)
            return
        }
        print("🎯 ChessPieceController: moveSelectedPiece called with direction: \(direction), distance: \(distance)")
        
        guard let currentPiece = selectedPiece,
              let currentPosition = selectedPiecePosition,
              let chessGame = chessGame else { 
            print("⚠️ ChessPieceController: Cannot move piece - missing required data")
            return 
        }
        
        print("🎯 ChessPieceController: Moving piece from \(currentPosition.stringValue)")
        print("🎯 ChessPieceController: Current piece node: \(currentPiece.name ?? "unknown")")
        
        // Calculate new position based on direction and distance
        var newFile = currentPosition.file
        var newRank = currentPosition.rank
        var newZ = currentPosition.z
        
        print("🎯 ChessPieceController: Starting position - file: \(newFile), rank: \(newRank), z: \(newZ) (\(fileToLetter(newFile))\(newRank + 1)z\(newZ))")
        
        // Get the piece to determine color for direction handling
        let piece = chessGame.getPieceAtPosition(currentPosition)
        let isBlack = piece?.color == .black
        
        // Get effective distance using the centralized function
        let effectiveDistance = getEffectiveDistance(for: currentPosition)
        
        print("🎯 ChessPieceController: Piece color: \(piece?.color.rawValue ?? "unknown"), isBlack: \(isBlack)")
        print("🎯 ChessPieceController: Direction: \(direction), effectiveDistance: \(effectiveDistance)")
        print("🎯 ChessPieceController: Board rotated for black: \(isBoardRotatedForBlack)")
        
        // Apply board rotation perspective mapping for 2D directions
        var mappedDirection = direction
        if isBoardRotatedForBlack {
            switch direction {
            case .left:
                mappedDirection = .right
            case .right:
                mappedDirection = .left
            case .up:
                mappedDirection = .down
            case .down:
                mappedDirection = .up
            case .upLeft:
                mappedDirection = .downRight
            case .upRight:
                mappedDirection = .downLeft
            case .downLeft:
                mappedDirection = .upRight
            case .downRight:
                mappedDirection = .upLeft
            default:
                // Keep other directions unchanged (forward, backward, 3D movements)
                mappedDirection = direction
            }
            print("🔄 Board rotation mapping: \(direction) -> \(mappedDirection)")
        }
        
        switch mappedDirection {
        case .forward:
            // For black pieces, forward means decreasing rank (towards white's side)
            newRank += isBlack ? -effectiveDistance : effectiveDistance
        case .backward:
            // For black pieces, backward means increasing rank (towards black's side)
            newRank += isBlack ? effectiveDistance : -effectiveDistance
        case .left:
            newFile -= effectiveDistance
        case .right:
            newFile += effectiveDistance
        case .upLeft:
            newFile -= effectiveDistance
            newRank += effectiveDistance
        case .upRight:
            newFile += effectiveDistance
            newRank += effectiveDistance
        case .downLeft:
            newFile -= effectiveDistance
            newRank -= effectiveDistance
        case .downRight:
            newFile += effectiveDistance
            newRank -= effectiveDistance
        case .up:
            newRank += effectiveDistance
        case .down:
            newRank -= effectiveDistance
        case .upZ:
            newZ += effectiveDistance
        case .downZ:
            newZ -= effectiveDistance
        case .upZLeft:
            newFile -= effectiveDistance
            newRank += isBlack ? -effectiveDistance : effectiveDistance
            newZ += effectiveDistance
        case .upZRight:
            newFile += effectiveDistance
            newRank += isBlack ? -effectiveDistance : effectiveDistance
            newZ += effectiveDistance
        case .downZLeft:
            newFile -= effectiveDistance
            newRank -= isBlack ? -effectiveDistance : effectiveDistance
            newZ -= effectiveDistance
        case .downZRight:
            newFile += effectiveDistance
            newRank -= isBlack ? -effectiveDistance : effectiveDistance
            newZ -= effectiveDistance
        case .upZBackLeft:
            newFile -= effectiveDistance
            newRank -= isBlack ? -effectiveDistance : effectiveDistance
            newZ += effectiveDistance
        case .upZBackRight:
            newFile += effectiveDistance
            newRank -= isBlack ? -effectiveDistance : effectiveDistance
            newZ += effectiveDistance
        case .downZForwardLeft:
            newFile -= effectiveDistance
            newRank += isBlack ? -effectiveDistance : effectiveDistance
            newZ -= effectiveDistance
        case .downZForwardRight:
            newFile += effectiveDistance
            newRank += isBlack ? -effectiveDistance : effectiveDistance
            newZ -= effectiveDistance
        }
        
        print("🎯 ChessPieceController: Calculated new position - file: \(newFile), rank: \(newRank), z: \(newZ) (\(fileToLetter(newFile))\(newRank + 1)z\(newZ))")
        
        // Check if the new position is valid (on the board)
        // For 3D chess, files are 0-7 (a-h), ranks 0-7, z 0-7 (i, ii, iii, iv, v, vi, vii, viii)
        let maxFile = 7 // Standard chess files a-h (0-7)
        let maxZ = 7 // Maximum Z coordinate for 8-board setup (i=0, ii=1, iii=2, iv=3, v=4, vi=5, vii=6, viii=7)
        guard newFile >= 0 && newFile <= maxFile && newRank >= 0 && newRank <= 7 && newZ >= 0 && newZ <= maxZ else { 
            let romanNames = ["i", "ii", "iii", "iv", "v", "vi", "vii", "viii"]
            let zRoman = newZ >= 0 && newZ < romanNames.count ? romanNames[newZ] : "invalid"
            let maxZRoman = maxZ >= 0 && maxZ < romanNames.count ? romanNames[maxZ] : "invalid"
            print("⚠️ ChessPieceController: New position (\(newFile), \(newRank), \(newZ) (Roman: \(zRoman))) is outside board bounds (maxZ=\(maxZ) (Roman: \(maxZRoman)))")
            chessGame.showInvalidMoveMessage("Invalid Move")
            return 
        }
        
        // Use proper piece-specific validation for all moves
        if let piece = chessGame.getPieceAtPosition(currentPosition) {
            let newPosition = ChessPosition3D(file: newFile, rank: newRank, z: newZ)
            
            // Use the detailed isValidMoveForPiece validation
            if !isValidMoveForPiece(piece, from: currentPosition, to: newPosition, distance: effectiveDistance) {
                print("⚠️ ChessPieceController: Move validation failed for \(piece.type)")
                chessGame.showInvalidMoveMessage("Invalid Move")
                
                // Check for checkmate if the king is in check and no valid moves are available
                if chessGame.chessBoard.isCheck(color: piece.color) {
                    print("🔍 King is in check and move was rejected - checking for checkmate...")
                    if chessGame.chessBoard.isCheckmate(color: piece.color) {
                        print("🎯 CHECKMATE DETECTED! \(piece.color.opposite.rawValue.capitalized) wins!")
                        // You could add UI notification here
                    }
                }
                return
            }
        }
        
        let newPosition = ChessPosition3D(file: newFile, rank: newRank, z: newZ)
        print("🎯 ChessPieceController: Attempting to move to \(newPosition.stringValue)")
        
        // Check if the new position is empty or has an opponent's piece
        if let targetPiece = chessGame.getPieceAtPosition(newPosition) {
            print("🎯 ChessPieceController: Target position has piece: \(targetPiece.color) \(targetPiece.type)")
            // If it's our own piece, don't move
            if let piece = chessGame.getPieceAtPosition(currentPosition), 
               targetPiece.color == piece.color {
                print("⚠️ ChessPieceController: Cannot move to position occupied by own piece")
                chessGame.showInvalidMoveMessage("Invalid Move")
                return
            }
        } else {
            print("🎯 ChessPieceController: Target position is empty")
        }
        
        // Move the piece in the chess engine
        if let piece = chessGame.getPieceAtPosition(currentPosition) {
            print("🎯 ChessPieceController: Found piece to move: \(piece.color) \(piece.type)")
            print("🎯 ChessPieceController: Current turn: \(chessGame.getCurrentTurn().rawValue)")
            
            // Check if king is in check and validate the move resolves it
            if chessGame.isKingInCheck() {
                // MANUAL MODE FIX: Removed AI-like check resolution validation
                // In manual mode, we don't need to validate that moves resolve check
                // The player should be able to make any legal move, even if it doesn't resolve check
                // The system will detect checkmate if no legal moves are available
                // TODO: If AI mode needs check resolution validation, add: if chessGame.aiModeActive { ... }
                print("🔍 King is in check - allowing any legal move in manual mode")
            }
            
            // IMPORTANT: Capture the turn BEFORE tryMove (which changes the turn)
            let currentTurnBeforeMove = chessGame.getCurrentTurn()
            print("🔍 Timer Debug: Captured turn before tryMove: \(currentTurnBeforeMove)")
            
            // Try to move the piece using the chess engine
            print("🔍 Timer Debug: About to call tryMove from \(currentPosition) to \(newPosition)")
            let moveSuccess = chessGame.tryMove(from: currentPosition, to: newPosition)
            print("🎯 ChessPieceController: Move attempted, success: \(moveSuccess)")
            
            // Check if the piece moved successfully by checking if it's now at the new position
            print("🔍 Timer Debug: moveSuccess=\(moveSuccess)")
            print("🔍 Timer Debug: piece at newPosition=\(chessGame.getPieceAtPosition(newPosition) != nil)")
            print("🔍 Timer Debug: piece at currentPosition=\(chessGame.getPieceAtPosition(currentPosition) == nil)")
            
            let allConditionsMet = moveSuccess && chessGame.getPieceAtPosition(newPosition) != nil && chessGame.getPieceAtPosition(currentPosition) == nil
            print("🔍 Timer Debug: All conditions met: \(allConditionsMet)")
            
            if allConditionsMet {
                print("✅ ChessPieceController: Move successful!")
                print("🔍 Timer Logic: About to check timer conditions")
                
                // Check if we should use confirmation timer based on game mode
                // Use the turn we captured BEFORE tryMove
                let shouldUseTimer = chessGame.gameMode == .play && 
                                   piece.color == currentTurnBeforeMove
                
                print("🔍 Timer Debug: gameMode=\(chessGame.gameMode), isAITurn=\(chessGame.isAITurn()), piece.color=\(piece.color), currentTurn=\(currentTurnBeforeMove), shouldUseTimer=\(shouldUseTimer)")
                print("🔍 Timer Debug: piece.color=\(piece.color.rawValue), currentTurn=\(currentTurnBeforeMove.rawValue), colors match: \(piece.color == currentTurnBeforeMove)")
                print("🔍 Timer Debug: gameMode enum value=\(chessGame.gameMode)")
                
                if shouldUseTimer {
                    // Use confirmation timer for human moves in play mode
                    print("⏰ Using confirmation timer for human move")
                    // Execute visual move only, then start confirmation timer
                    executeMoveVisualOnly(from: currentPosition, to: newPosition, pieceNode: currentPiece)
                    startMoveConfirmation(from: currentPosition, to: newPosition, pieceNode: currentPiece)
                } else {
                    // Execute move immediately for AI moves or learn mode
                    print("⚡ Executing move immediately (AI or learn mode)")
                    executeMove(from: currentPosition, to: newPosition, pieceNode: currentPiece)
                    
                    // Update our selected piece position
                    selectedPiecePosition = newPosition
                    
                    // Find the new node for the piece (it might have been recreated)
                    if let newNode = chessGame.getPieceNode(at: newPosition) {
                        selectedPiece = newNode
                        highlightSelectedPiece()
                    }
                    
                    // Add move to history
                    addMoveToHistory(piece: piece, from: currentPosition, to: newPosition)
                    
                    // Clear move indicators
                    clearMoveIndicators()
                    
                    // Update piece lists
                    updatePieceLists()
                }
            } else {
                print("🔍 Timer Debug: Conditions not met - timer logic skipped")
                print("❌ ChessPieceController: Move failed - piece not found at new position or still at old position")
                print("🎯 ChessPieceController: Piece at old position: \(chessGame.getPieceAtPosition(currentPosition)?.type.rawValue ?? "none")")
                print("🎯 ChessPieceController: Piece at new position: \(chessGame.getPieceAtPosition(newPosition)?.type.rawValue ?? "none")")
                
                // If the chess engine rejected the move, try to understand why
                if !moveSuccess {
                    print("⚠️ ChessPieceController: Chess engine rejected the move")
                    chessGame.showInvalidMoveMessage("Invalid Move")
                    if piece.color != chessGame.getCurrentTurn() {
                        print("⚠️ ChessPieceController: Wrong turn - it's \(chessGame.getCurrentTurn().rawValue)'s turn, but trying to move \(piece.color.rawValue) piece")
                    }
                }
            }
        } else {
            print("❌ ChessPieceController: No piece found at current position \(currentPosition.stringValue)")
        }
    }
    
    // Add a move to the history
    private func addMoveToHistory(piece: ChessPiece3D, from: ChessPosition3D, to: ChessPosition3D) {
        let pieceSymbol = getPieceSymbol(piece)
        let moveText = "\(pieceSymbol) \(from.stringValue) → \(to.stringValue)"
        moveHistory.append(moveText)
        
        // Keep only the last 10 moves
        if moveHistory.count > 10 {
            moveHistory.removeFirst()
        }
    }
    
    // Get symbol for a piece
    private func getPieceSymbol(_ piece: ChessPiece3D) -> String {
        let whiteSymbols: [PieceType: String] = [
            .king: "♔", .queen: "♕", .rook: "♖", 
            .bishop: "♗", .knight: "♘", .pawn: "♙"
        ]
        
        let blackSymbols: [PieceType: String] = [
            .king: "♚", .queen: "♛", .rook: "♜", 
            .bishop: "♝", .knight: "♞", .pawn: "♟"
        ]
        
        return piece.color == .white ? 
            whiteSymbols[piece.type] ?? "?" : 
            blackSymbols[piece.type] ?? "?"
    }
    
    // Get piece name for display
    func getPieceName(_ piece: ChessPiece3D) -> String {
        return "\(piece.color.rawValue.capitalized) \(piece.type.rawValue.capitalized)"
    }
    
    // Calculate custom move position based on direction and distance
    func calculateCustomMove(direction: MoveDirection, distance: Int) -> ChessPosition3D? {
        guard let currentPosition = selectedPiecePosition,
              let chessGame = chessGame,
              let piece = chessGame.getPieceAtPosition(currentPosition) else { return nil }
        
        // Get effective distance (1 for kings, original distance for other pieces)
        let effectiveDistance = getEffectiveDistance(for: currentPosition)
        
        var newFile = currentPosition.file
        var newRank = currentPosition.rank
        var newZ = currentPosition.z
        
        // Apply player perspective for rank changes
        let rankDirection = piece.color == .white ? 1 : -1
        
        switch direction {
        case .upZLeft:
            newFile -= effectiveDistance
            newRank += effectiveDistance * rankDirection
            newZ += effectiveDistance
        case .upZRight:
            newFile += effectiveDistance
            newRank += effectiveDistance * rankDirection
            newZ += effectiveDistance
        case .downZLeft:
            newFile -= effectiveDistance
            newRank -= effectiveDistance * rankDirection
            newZ -= effectiveDistance
        case .downZRight:
            newFile += effectiveDistance
            newRank -= effectiveDistance * rankDirection
            newZ -= effectiveDistance
        case .upZBackLeft:
            newFile -= effectiveDistance
            newRank -= effectiveDistance * rankDirection
            newZ += effectiveDistance
        case .upZBackRight:
            newFile += effectiveDistance
            newRank -= effectiveDistance * rankDirection
            newZ += effectiveDistance
        case .downZForwardLeft:
            newFile -= effectiveDistance
            newRank += effectiveDistance * rankDirection
            newZ -= effectiveDistance
        case .downZForwardRight:
            newFile += effectiveDistance
            newRank += effectiveDistance * rankDirection
            newZ -= effectiveDistance
        default:
            return nil
        }
        
        // Check bounds
        let maxFile = 7 // Standard chess files a-h (0-7)
        let maxZ = 7 // Maximum Z coordinate for 8-board setup (i=0, ii=1, iii=2, iv=3, v=4, vi=5, vii=6, viii=7)
        guard newFile >= 0 && newFile <= maxFile && newRank >= 0 && newRank <= 7 && newZ >= 0 && newZ <= maxZ else {
            let romanNames = ["i", "ii", "iii", "iv", "v", "vi", "vii", "viii"]
            let zRoman = newZ >= 0 && newZ < romanNames.count ? romanNames[newZ] : "invalid"
            let maxZRoman = maxZ >= 0 && maxZ < romanNames.count ? romanNames[maxZ] : "invalid"
            print("⚠️ calculateCustomMove: Position (\(newFile), \(newRank), \(newZ) (Roman: \(zRoman))) is outside board bounds (maxZ=\(maxZ) (Roman: \(maxZRoman)))")
            return nil
        }
        
        return ChessPosition3D(file: newFile, rank: newRank, z: newZ)
    }
    
    // Helper function to convert file number to letter
    private func fileToLetter(_ file: Int) -> String {
        let letters = ["a", "b", "c", "d", "e", "f", "g", "h"]
        return file >= 0 && file < letters.count ? letters[file] : "?"
    }
    
    // Validate if a move is valid for a specific piece type
    func isValidMoveForPiece(_ piece: ChessPiece3D, from: ChessPosition3D, to: ChessPosition3D, distance: Int) -> Bool {
        print("🚨🚨🚨 isValidMoveForPiece CALLED for \(piece.color) \(piece.type) from \(from.stringValue) to \(to.stringValue) 🚨🚨🚨")
        
        let fileDiff = abs(to.file - from.file)
        let rankDiff = abs(to.rank - from.rank)
        
        // print("🔍 Validating move for \(piece.color) \(piece.type) from \(from.stringValue) to \(to.stringValue) with distance \(distance)")
        // print("🔍 File diff: \(fileDiff), Rank diff: \(rankDiff)")
        
        // First check if the move is valid according to piece movement rules
        var isValidMove = false
        
        switch piece.type {
        case .pawn:
            // Pawns move forward only (rank increases for white, decreases for black)
            let direction = piece.color == .white ? 1 : -1
            let zDiff = abs(to.z - from.z)
            
            // Check if pawn has moved before (not at starting position)
            // Starting positions: 
            // z=i (z=0): White pawns at rank 0-1, Black pawns at rank 6-7
            // z=ii (z=1): White pawns at rank 0-1, Black pawns at rank 6-7
            // If pawn is at z >= 2 OR at wrong ranks for z=0/1, it has moved
            let isStartingPosition = (from.z == 0 && ((piece.color == .white && from.rank <= 1) || (piece.color == .black && from.rank >= 6))) ||
                                   (from.z == 1 && ((piece.color == .white && from.rank <= 1) || (piece.color == .black && from.rank >= 6)))
            
            // If pawn has moved before, force distance to 1 regardless of selector
            let effectiveDistance = isStartingPosition ? distance : 1
            
            print("🔍 Pawn validation - direction: \(direction), from rank: \(from.rank), from z: \(from.z), isStartingPosition: \(isStartingPosition), effectiveDistance: \(effectiveDistance)")
            
            // Explicitly reject backward moves for pawns
            let rankDirection = to.rank - from.rank
            if (piece.color == .white && rankDirection < 0) || (piece.color == .black && rankDirection > 0) {
                print("🔍 Pawn backward move - INVALID (pawns cannot move backward)")
                return false
            }
            
            // Pawns cannot move horizontally (file changes without rank or Z changes)
            if fileDiff > 0 && rankDiff == 0 && zDiff == 0 {
                print("🔍 Pawn horizontal move - INVALID (pawns cannot move sideways)")
                return false
            }
            
            // Forward move (no file change) - ONLY for non-captures
            if fileDiff == 0 && (to.rank - from.rank) == (direction * effectiveDistance) && zDiff == 0 {
                // Check if this is a capture attempt (destination has opponent piece)
                guard let chessGame = chessGame else { return false }
                if let targetPiece = chessGame.getPieceAtPosition(to) {
                    if targetPiece.color != piece.color {
                        print("🔍 Pawn forward capture - INVALID (pawns cannot capture straight forward)")
                        return false
                    }
                }
                // Allow 2 squares for first move, 1 square otherwise
                isValidMove = effectiveDistance == 1 || (effectiveDistance == 2 && isStartingPosition)
                print("🔍 Pawn forward move - isStartingPosition: \(isStartingPosition), isValid: \(isValidMove)")
            }
            // Vertical Z move (no file/rank change) - ONLY for non-captures
            if fileDiff == 0 && rankDiff == 0 && zDiff == effectiveDistance {
                print("🔍 DEBUG: Vertical Z move validation triggered")
                // Check if this is a capture attempt (destination has opponent piece)
                guard let chessGame = chessGame else { return false }
                if let targetPiece = chessGame.getPieceAtPosition(to) {
                    if targetPiece.color != piece.color {
                        print("🔍 Pawn vertical capture - INVALID (pawns cannot capture straight up/down)")
                        return false
                    }
                }
                isValidMove = effectiveDistance == 1 || (effectiveDistance == 2 && isStartingPosition)
                print("🔍 Pawn vertical Z move - isStartingPosition: \(isStartingPosition), isValid: \(isValidMove)")
            }
            // En passant capture (check FIRST before other diagonal validations)
            if fileDiff == 1 && rankDiff == 1 && (to.rank - from.rank) == direction && zDiff == 0 {
                // Check if this is an en passant capture (no piece at destination)
                guard let chessGame = chessGame else { return false }
                if chessGame.getPieceAtPosition(to) == nil {
                    // Check if there's an en passant target
                    if let enPassantTarget = chessGame.chessBoard.enPassantTarget {
                        print("🔍 En passant validation: target at \(enPassantTarget.stringValue)")
                        print("🔍 En passant validation: trying to move to \(to.stringValue)")
                        
                        // Check if the destination is the en passant capture position (same rank as en passant target)
                        let expectedCapturePos = ChessPosition3D(file: enPassantTarget.file, rank: enPassantTarget.rank, z: enPassantTarget.z)
                        
                        if to == expectedCapturePos {
                            print("🔍 Pawn en passant capture - valid")
                            isValidMove = effectiveDistance == 1
                            return true // Exit early to prevent other diagonal validations from running
                        } else {
                            print("🔍 En passant validation: destination \(to.stringValue) != expected capture position \(expectedCapturePos.stringValue)")
                        }
                    } else {
                        print("🔍 En passant validation: no target set")
                    }
                } else {
                    print("🔍 En passant validation: destination not empty")
                }
            }
            
            // 2D Diagonal capture (only if there's an opponent piece)
            // Only allow 1 square diagonal captures
            if fileDiff == rankDiff && fileDiff == 1 && (to.rank - from.rank) == (direction * fileDiff) && zDiff == 0 {
                // Check if there's an opponent piece to capture
                guard let chessGame = chessGame else { return false }
                if let targetPiece = chessGame.getPieceAtPosition(to) {
                    if targetPiece.color != piece.color {
                        print("🔍 Pawn 2D diagonal capture - valid (capturing \(targetPiece.color) \(targetPiece.type) at distance \(fileDiff))")
                        isValidMove = true
                    } else {
                        print("🔍 Pawn 2D diagonal move - INVALID (no opponent piece to capture)")
                        return false
                    }
                } else {
                    print("🔍 Pawn 2D diagonal move - INVALID (no piece to capture)")
                    return false
                }
            }
            
            // 3D Diagonal capture (orange controls) - must have at least 2 components changing, but NOT pure vertical
            // AND must include forward movement (rank change in correct direction)
            if fileDiff <= effectiveDistance && rankDiff <= effectiveDistance && zDiff <= effectiveDistance && 
               effectiveDistance == 1 && ((fileDiff > 0 && rankDiff > 0) || (fileDiff > 0 && rankDiff > 0 && zDiff > 0)) {
                print("🔍 DEBUG: 3D diagonal validation triggered")
                // Check that the rank movement is forward (not backward)
                let rankDirection = to.rank - from.rank
                if (piece.color == .white && rankDirection > 0) || (piece.color == .black && rankDirection < 0) {
                    // Check if there's an opponent piece to capture
                    guard let chessGame = chessGame else { return false }
                    if let targetPiece = chessGame.getPieceAtPosition(to) {
                        if targetPiece.color != piece.color {
                            print("🔍 Pawn 3D diagonal capture - valid (capturing \(targetPiece.color) \(targetPiece.type))")
                            isValidMove = true
                        } else {
                            print("🔍 Pawn 3D diagonal move - INVALID (no opponent piece to capture)")
                            return false
                        }
                    } else {
                        print("🔍 Pawn 3D diagonal move - INVALID (no piece to capture)")
                        return false
                    }
                } else {
                    print("🔍 Pawn 3D diagonal capture - INVALID (not forward)")
                    return false
                }
            }
            

            
            if !isValidMove {
                print("🔍 Pawn move - invalid")
                return false
            }
            
            // Check if path is blocked (for forward moves and vertical Z moves)
            if (fileDiff == 0 && zDiff == 0) || (fileDiff == 0 && rankDiff == 0) {
                if isPathBlocked(from: from, to: to) {
                    print("🔍 Pawn move blocked by piece in path")
                    return false
                }
            }
            
        case .rook:
            // Rooks move in straight lines along file, rank, or z
            let zDiff = abs(to.z - from.z)
            let isStraight =
                (fileDiff == distance && rankDiff == 0 && zDiff == 0) ||
                (fileDiff == 0 && rankDiff == distance && zDiff == 0) ||
                (fileDiff == 0 && rankDiff == 0 && zDiff == distance)
            isValidMove = isStraight && !isPathBlocked(from: from, to: to)
            if !isValidMove { return false }
            
        case .bishop:
            // Bishops move diagonally only (not in straight lines)
            let zDiff = abs(to.z - from.z)
            
            print("🔍 BISHOP VALIDATION CALLED: \(from.stringValue) -> \(to.stringValue)")
            
            // Simple 2D diagonal validation (most common case)
            let is2DDiagonal = (fileDiff == rankDiff && fileDiff == distance && zDiff == 0)
            
            // 3D diagonal validation
            let is3DDiagonal = (fileDiff == zDiff && fileDiff == distance && rankDiff == 0) ||
                              (rankDiff == zDiff && rankDiff == distance && fileDiff == 0) ||
                              (fileDiff == rankDiff && rankDiff == zDiff && fileDiff == distance)
            
            isValidMove = is2DDiagonal || is3DDiagonal
            print("🔍 Bishop validation - fileDiff: \(fileDiff), rankDiff: \(rankDiff), zDiff: \(zDiff), distance: \(distance)")
            print("🔍 Bishop validation - is2DDiagonal: \(is2DDiagonal), is3DDiagonal: \(is3DDiagonal), isValid: \(isValidMove)")
            
            // Debug: Check if this is the problematic move
            if from.stringValue.contains("g1") && to.stringValue.contains("g1") {
                print("🔍 PROBLEMATIC BISHOP MOVE: \(from.stringValue) -> \(to.stringValue)")
                print("🔍 This should be a pure vertical move and should be INVALID")
            }
            
            // Additional safety check: explicitly reject pure vertical/horizontal moves
            let isPureVertical = fileDiff == 0 && rankDiff == 0 && zDiff > 0
            let isPureHorizontal = (fileDiff > 0 && rankDiff == 0 && zDiff == 0) || (fileDiff == 0 && rankDiff > 0 && zDiff == 0)
            
            if isPureVertical || isPureHorizontal {
                print("🔍 Bishop pure vertical/horizontal move - INVALID")
                return false
            }
            
            if isValidMove {
                // Check if there are any pieces blocking the path
                isValidMove = !isPathBlocked(from: from, to: to)
            }
            if !isValidMove {
                return false
            }
            
        case .queen:
            // Queens move in straight lines or diagonally in 3D
            let zDiff = abs(to.z - from.z)
            
            // Queens can move in any direction - no backward restrictions
            let isStraight = (fileDiff == 0 && rankDiff == distance && zDiff == 0) ||
                           (fileDiff == distance && rankDiff == 0 && zDiff == 0) ||
                           (fileDiff == 0 && rankDiff == 0 && zDiff == distance)
            let isDiagonal = (fileDiff == rankDiff && fileDiff == distance && zDiff == 0) ||
                           (fileDiff == zDiff && fileDiff == distance && rankDiff == 0) ||
                           (rankDiff == zDiff && rankDiff == distance && fileDiff == 0) ||
                           (fileDiff == rankDiff && rankDiff == zDiff && fileDiff == distance)
            isValidMove = isStraight || isDiagonal
            if isValidMove {
                // Check if there are any pieces blocking the path
                isValidMove = !isPathBlocked(from: from, to: to)
            }
            if !isValidMove {
                return false
            }
            
        case .king:
            // Kings move one square in any direction in 3D (including all diagonal combinations)
            let zDiff = abs(to.z - from.z)
            
            // Allow any combination of X, Y, Z movements with distance 1
            // This includes: straight moves (1,0,0), (0,1,0), (0,0,1)
            // And diagonal moves: (1,1,0), (1,0,1), (0,1,1), (1,1,1)
            isValidMove = distance == 1 && fileDiff <= 1 && rankDiff <= 1 && zDiff <= 1 && (fileDiff > 0 || rankDiff > 0 || zDiff > 0)
            
            if !isValidMove {
                return false
            }
            
        case .knight:
            // Knights move in L-shape in 3D: 2 squares in one direction, 1 square in another
            let zDiff = abs(to.z - from.z)
            
            // Simple 2D L-shape validation (most common case)
            let is2DLShape = (fileDiff == 2 && rankDiff == 1 && zDiff == 0) ||
                            (fileDiff == 1 && rankDiff == 2 && zDiff == 0)
            
            // 3D L-shape validation
            let is3DLShape = (fileDiff == 2 && rankDiff == 0 && zDiff == 1) ||
                            (fileDiff == 0 && rankDiff == 2 && zDiff == 1) ||
                            (fileDiff == 1 && rankDiff == 0 && zDiff == 2) ||
                            (fileDiff == 0 && rankDiff == 1 && zDiff == 2) ||
                            // Additional 3D L-move patterns
                            (fileDiff == 2 && rankDiff == 0 && zDiff == 2) ||
                            (fileDiff == 0 && rankDiff == 2 && zDiff == 2) ||
                            (fileDiff == 2 && rankDiff == 2 && zDiff == 0)
            
            isValidMove = is2DLShape || is3DLShape
            print("🔍 Knight validation - fileDiff: \(fileDiff), rankDiff: \(rankDiff), zDiff: \(zDiff)")
            print("🔍 Knight validation - is2DLShape: \(is2DLShape), is3DLShape: \(is3DLShape), isValid: \(isValidMove)")
            
            // For knights, don't check path blocking since they can jump over pieces
            if isValidMove {
                print("🔍 Knight move is valid")
                return true
            } else {
                print("🔍 Knight move is invalid")
                return false
            }
        }
        
        // Now check if this move would put the player's own king in check
        print("🔍 Checking if move would put own king in check...")
        let wouldPutInCheck = wouldMovePutOwnKingInCheck(piece: piece, from: from, to: to)
        print("🔍 Result of check validation: \(wouldPutInCheck)")
        
        if wouldPutInCheck {
            print("❌ Move would put own king in check - invalid")
            return false
        }
        
        // MANUAL MODE FIX: Removed AI-like check resolution validation
        // In manual mode, we don't validate that moves resolve check
        // The player should be able to make any legal move, even if it doesn't resolve check
        // The system will detect checkmate if no legal moves are available
        // TODO: If AI mode needs check resolution validation, add: if chessGame.aiModeActive { ... }
        guard let chessGame = chessGame else { return false }
        if chessGame.chessBoard.isCheck(color: piece.color, suppressDebug: true) {
            print("🔍 King is in check - allowing any legal move in manual mode")
        }
        
        print("✅ Move is valid")
        return true
    }
    
    // Check if there are any pieces blocking the path between two positions
    private func isPathBlocked(from: ChessPosition3D, to: ChessPosition3D, excluding piece: ChessPiece3D? = nil) -> Bool {
        guard let chessGame = chessGame else { return false }
        
        let fileDiff = to.file - from.file
        let rankDiff = to.rank - from.rank
        let zDiff = to.z - from.z
        
        // Determine the step direction for each coordinate
        let fileStep = fileDiff == 0 ? 0 : fileDiff > 0 ? 1 : -1
        let rankStep = rankDiff == 0 ? 0 : rankDiff > 0 ? 1 : -1
        let zStep = zDiff == 0 ? 0 : zDiff > 0 ? 1 : -1
        
        // Check each position along the path (excluding start and end positions)
        var currentFile = from.file + fileStep
        var currentRank = from.rank + rankStep
        var currentZ = from.z + zStep
        
        while currentFile != to.file || currentRank != to.rank || currentZ != to.z {
            let checkPosition = ChessPosition3D(file: currentFile, rank: currentRank, z: currentZ)
            
            // If there's any piece at this position, the path is blocked
            if let blockingPiece = chessGame.getPieceAtPosition(checkPosition) {
                // Don't count the piece being moved as a blocker
                if let excludedPiece = piece, blockingPiece.position == excludedPiece.position {
                    print("🔍 Ignoring moving piece at \(checkPosition.stringValue)")
                } else {
                    print("🔍 Path blocked at \(checkPosition.stringValue) by \(blockingPiece.color) \(blockingPiece.type)")
                    return true
                }
            }
            
            currentFile += fileStep
            currentRank += rankStep
            currentZ += zStep
        }
        
        return false
    }
    
    // Check if a move would resolve a check situation
    private func doesMoveResolveCheck(from: ChessPosition3D, to: ChessPosition3D) -> Bool {
        print("🔍 doesMoveResolveCheck called: from \(from.stringValue) to \(to.stringValue)")
        guard let chessGame = chessGame else { return false }
        
        // Get the piece being moved
        guard let piece = chessGame.getPieceAtPosition(from) else { return false }
        print("🔍 doesMoveResolveCheck: Moving \(piece.color) \(piece.type) from \(from.stringValue)")
        
        // Find the king
        guard let king = chessGame.chessBoard.getAllPieces().first(where: { $0.type == .king && $0.color == piece.color }) else {
            return false
        }
        print("🔍 doesMoveResolveCheck: King at \(king.position.stringValue)")
        
        // If the piece being moved is the king, check if the new position is safe
        if piece.type == .king {
            print("🔍 doesMoveResolveCheck: King move - checking if new position is safe")
            
            // First, find what's attacking the king
            let attackingPieces = findPiecesAttackingKing(king: king)
            print("🔍 doesMoveResolveCheck: Found \(attackingPieces.count) attacking pieces for king")
            
            // If there's only one attacker, check if we're capturing it
            if attackingPieces.count == 1 {
                let attacker = attackingPieces[0]
                print("🔍 doesMoveResolveCheck: Single attacker at \(attacker.position.stringValue)")
                print("🔍 doesMoveResolveCheck: King moving to \(to.stringValue)")
                
                // Check if we're capturing the attacking piece
                if to == attacker.position {
                    print("🔍 doesMoveResolveCheck: King captures the attacking piece")
                    return true
                }
            }
            
            // Otherwise, check if the new position is safe
            let isSafe = !wouldPositionBeUnderAttack(position: to, by: piece.color.opposite)
            print("🔍 doesMoveResolveCheck: King new position safe: \(isSafe)")
            return isSafe
        }
        
        // For other pieces, we need to simulate the move and check if it resolves the check
        // First, let's find what's attacking the king
        let attackingPieces = findPiecesAttackingKing(king: king)
        print("🔍 doesMoveResolveCheck: Found \(attackingPieces.count) attacking pieces")
        
        if attackingPieces.isEmpty {
            print("🔍 doesMoveResolveCheck: No attacking pieces found")
            return true // No pieces attacking the king
        }
        
        // If there's only one attacking piece, we can capture it or block it
        if attackingPieces.count == 1 {
            let attacker = attackingPieces[0]
            
            print("🔍 Check resolution: Single attacker at \(attacker.position.stringValue)")
            print("🔍 Check resolution: Move target is \(to.stringValue)")
            
            // Check if we're capturing the attacking piece
            if to == attacker.position {
                print("🔍 Check resolution: Move captures the attacking piece")
                return true
            }
            
            // Check if we're blocking the attack path
            if isBlockingAttack(from: attacker.position, to: king.position, blockingPosition: to) {
                print("🔍 Check resolution: Move blocks the attack path")
                return true
            }
            
            print("🔍 Check resolution: Move neither captures nor blocks")
        }
        
        // If there are multiple attackers, only capturing one of them won't help
        // We need to block all attacks or move the king
        return false
    }
    
    // Find all pieces that are attacking the king
        private func findPiecesAttackingKing(king: ChessPiece3D) -> [ChessPiece3D] {
        guard let chessGame = chessGame else { return [] }
        
        let opponentPieces = chessGame.chessBoard.getAllPieces().filter { $0.color == king.color.opposite }
            var attackers: [ChessPiece3D] = []
        
        for opponentPiece in opponentPieces {
            if canPieceAttackPosition(piece: opponentPiece, targetPosition: king.position, excluding: nil) {
                    print("🔍 Found attacker: \(opponentPiece.color) \(opponentPiece.type) at \(opponentPiece.position.stringValue)")
                attackers.append(opponentPiece)
            }
        }
        
        return attackers
    }
    
    // Check if a position blocks the attack path between attacker and target (3D)
    private func isBlockingAttack(from attackerPosition: ChessPosition3D, to targetPosition: ChessPosition3D, blockingPosition: ChessPosition3D) -> Bool {
        let fileDiff = targetPosition.file - attackerPosition.file
        let rankDiff = targetPosition.rank - attackerPosition.rank
        let zDiff = targetPosition.z - attackerPosition.z
        
        // Determine the step direction for all axes
        let fileStep = fileDiff == 0 ? 0 : fileDiff > 0 ? 1 : -1
        let rankStep = rankDiff == 0 ? 0 : rankDiff > 0 ? 1 : -1
        let zStep = zDiff == 0 ? 0 : zDiff > 0 ? 1 : -1
        
        // Check if the blocking position is on the attack path
        var currentFile = attackerPosition.file + fileStep
        var currentRank = attackerPosition.rank + rankStep
        var currentZ = attackerPosition.z + zStep
        
        while currentFile != targetPosition.file || currentRank != targetPosition.rank || currentZ != targetPosition.z {
            if currentFile == blockingPosition.file && currentRank == blockingPosition.rank && currentZ == blockingPosition.z {
                return true
            }
            currentFile += fileStep
            currentRank += rankStep
            currentZ += zStep
        }
        
        return false
    }
    
    // Check if a move would put the player's own king in check
    private func wouldMovePutOwnKingInCheck(piece: ChessPiece3D, from: ChessPosition3D, to: ChessPosition3D) -> Bool {
        guard let chessGame = chessGame else { 
            print("❌ No chess game available for check validation")
            return false 
        }
        
        // Find the king of the same color as the moving piece
        guard let king = chessGame.chessBoard.getAllPieces().first(where: { $0.type == .king && $0.color == piece.color }) else {
            print("❌ Could not find \(piece.color) king for check validation")
            return false
        }
        
        print("🔍 Checking if moving \(piece.color) \(piece.type) from \(from.stringValue) to \(to.stringValue) would put king at \(king.position.stringValue) in check")
        
        // If the piece being moved is the king, check if the new position is safe
        if piece.type == .king {
            // Find if there is a piece being captured at the destination
            let capturedPiece = chessGame.getPieceAtPosition(to)
            let wouldBeUnderAttack = wouldPositionBeUnderAttack(position: to, by: piece.color.opposite, excluding: piece, capturing: capturedPiece)
            print("🔍 King move to \(to.stringValue) would be under attack: \(wouldBeUnderAttack)")
            return wouldBeUnderAttack
        }
        
        // For other pieces, we need to simulate the move and check if the king would be in check
        // The key insight is: if moving this piece would expose the king to attack, the move is invalid
        
        // Check if any opponent piece can attack the king's position after this move
        let opponentPieces = chessGame.chessBoard.getAllPieces().filter { $0.color == piece.color.opposite }
        print("🔍 Checking \(opponentPieces.count) opponent pieces for potential attacks on king")
        
        for opponentPiece in opponentPieces {
            // Skip the piece we're about to capture (if any)
            if opponentPiece.position == to {
                print("🔍 Skipping opponent piece at destination \(to.stringValue)")
                continue
            }
            
            // Check if this opponent piece can attack the king
            if canPieceAttackPosition(piece: opponentPiece, targetPosition: king.position, excluding: piece) {
                print("🔍 \(opponentPiece.color) \(opponentPiece.type) at \(opponentPiece.position.stringValue) can attack king")
                
                // Check if the moving piece was blocking this attack
                if isPieceBlockingAttack(from: opponentPiece.position, to: king.position, blockingPiece: piece) {
                    print("❌ Moving \(piece.type) would expose king to attack from \(opponentPiece.type)")
                    return true
                } else {
                    print("🔍 Moving \(piece.type) would NOT expose king to attack from \(opponentPiece.type)")
                }
            }
        }
        
        print("✅ Move would NOT put king in check")
        return false
    }
    
    // Check if a piece is blocking an attack path
    private func isPieceBlockingAttack(from attackerPosition: ChessPosition3D, to targetPosition: ChessPosition3D, blockingPiece: ChessPiece3D) -> Bool {
        let fileDiff = targetPosition.file - attackerPosition.file
        let rankDiff = targetPosition.rank - attackerPosition.rank
        
        // Determine the step direction
        let fileStep = fileDiff == 0 ? 0 : fileDiff > 0 ? 1 : -1
        let rankStep = rankDiff == 0 ? 0 : rankDiff > 0 ? 1 : -1
        
        // Check if the blocking piece is on the attack path
        var currentFile = attackerPosition.file + fileStep
        var currentRank = attackerPosition.rank + rankStep
        
        while currentFile != targetPosition.file || currentRank != targetPosition.rank {
            if currentFile == blockingPiece.position.file && currentRank == blockingPiece.position.rank {
                return true
            }
            currentFile += fileStep
            currentRank += rankStep
        }
        
        return false
    }
    
    // Check if a position would be under attack by a specific color
    private func wouldPositionBeUnderAttack(position: ChessPosition3D, by color: PieceColor, excluding piece: ChessPiece3D? = nil, capturing: ChessPiece3D? = nil) -> Bool {
        guard let chessGame = chessGame else { return false }
        
        let opponentPieces = chessGame.chessBoard.getAllPieces().filter { $0.color == color }
        
        for opponentPiece in opponentPieces {
            // Skip the excluded piece
            if let excludedPiece = piece, opponentPiece.position == excludedPiece.position {
                continue
            }
            // Skip the piece being captured (for king captures)
            if let capturingPiece = capturing, opponentPiece.position == capturingPiece.position {
                continue
            }
            
            if canPieceAttackPosition(piece: opponentPiece, targetPosition: position, excluding: nil) {
                return true
            }
        }
        
        return false
    }
    
    // Check if a piece can attack a specific position (same logic as in ChessBoard)
    private func canPieceAttackPosition(piece: ChessPiece3D, targetPosition: ChessPosition3D, excluding movingPiece: ChessPiece3D? = nil) -> Bool {
        switch piece.type {
        case .pawn:
            let direction = piece.color == .white ? 1 : -1
            let fileDiff = abs(targetPosition.file - piece.position.file)
            let rankDiff = targetPosition.rank - piece.position.rank
            return fileDiff == 1 && rankDiff == direction
            
        case .rook:
            return (targetPosition.file == piece.position.file || targetPosition.rank == piece.position.rank) &&
                   !isPathBlocked(from: piece.position, to: targetPosition, excluding: movingPiece)
            
        case .bishop:
            let fileDiff = abs(targetPosition.file - piece.position.file)
            let rankDiff = abs(targetPosition.rank - piece.position.rank)
            return fileDiff == rankDiff && !isPathBlocked(from: piece.position, to: targetPosition, excluding: movingPiece)
            
        case .queen:
            let fileDiff = abs(targetPosition.file - piece.position.file)
            let rankDiff = abs(targetPosition.rank - piece.position.rank)
            return ((targetPosition.file == piece.position.file || targetPosition.rank == piece.position.rank) ||
                    (fileDiff == rankDiff)) && !isPathBlocked(from: piece.position, to: targetPosition, excluding: movingPiece)
            
        case .king:
            let fileDiff = abs(targetPosition.file - piece.position.file)
            let rankDiff = abs(targetPosition.rank - piece.position.rank)
            return fileDiff <= 1 && rankDiff <= 1 && (fileDiff > 0 || rankDiff > 0)
            
        case .knight:
            let fileDiff = abs(targetPosition.file - piece.position.file)
            let rankDiff = abs(targetPosition.rank - piece.position.rank)
            let zDiff = abs(targetPosition.z - piece.position.z)
            
            // 2D L-shape (same Z-level) - exactly 2 squares in one direction, 1 in another
            let is2DLShape = (fileDiff == 2 && rankDiff == 1 && zDiff == 0) ||
                            (fileDiff == 1 && rankDiff == 2 && zDiff == 0)
            
            // 3D L-shape (different Z-levels) - exactly 2 squares total displacement
            // Only allow true L-shapes: 2 in one direction, 1 in another, 0 in the third
            let is3DLShape = (fileDiff == 2 && rankDiff == 1 && zDiff == 0) ||
                            (fileDiff == 2 && rankDiff == 0 && zDiff == 1) ||
                            (fileDiff == 1 && rankDiff == 2 && zDiff == 0) ||
                            (fileDiff == 0 && rankDiff == 2 && zDiff == 1) ||
                            (fileDiff == 1 && rankDiff == 0 && zDiff == 2) ||
                            (fileDiff == 0 && rankDiff == 1 && zDiff == 2)
            
            return is2DLShape || is3DLShape
        }
    }
    
    // Special movement function for knights
    func moveKnight(direction: MoveDirection) {
        // For 2D movement, show "forward" instead of "up" to avoid confusion with Z-axis
        let displayDirection = (direction == .up) ? "forward" : "\(direction)"
        print("🐎 Knight movement: \(displayDirection)")
        
        // Prevent interference from other operations during knight movement
        guard !isMovePending else {
            print("⚠️ Knight movement blocked - move already pending")
            return
        }
        
        print("🐎 Knight movement allowed - isMovePending: \(isMovePending)")
        
        // Prevent multiple knight operations from interfering with each other
        guard !isKnightMoving else {
            print("⚠️ Knight movement blocked - knight already moving")
            return
        }
        
        print("🐎 Knight movement allowed - isKnightMoving: \(isKnightMoving)")
        
        isKnightMoving = true
        defer { isKnightMoving = false }
        
        guard let _ = selectedPiece,
              let originalPosition = selectedPiecePosition, // Always use the original position
              let chessGame = chessGame else { 
            print("⚠️ ChessPieceController: Cannot move knight - missing required data")
            return 
        }
        
        // If this is the first move, store it and wait for the second
        if knightFirstMove == nil {
            knightFirstMove = direction
            print("🐎 First knight move: \(displayDirection)")
            print("💡 Now click a perpendicular direction for the second part of the L-shape")
            // Do NOT move the piece or update selectedPiecePosition
            return
        }
        
        // This is the second move - calculate the final position from the original position
        let firstMove = knightFirstMove!
        let firstMoveDisplay = (firstMove == .up) ? "forward" : "\(firstMove)"
        print("🐎 Second knight move: \(displayDirection), first was: \(firstMoveDisplay)")
        print("🐎 Calculating final position from original: \(originalPosition.stringValue)")
        
        // Calculate the final position based on the two moves
        var newFile = originalPosition.file
        var newRank = originalPosition.rank
        var newZ = originalPosition.z
        
        // Get the piece to determine color and board rotation for direction handling
        let piece = chessGame.getPieceAtPosition(originalPosition)
        let isBlack = piece?.color == .black
        
        // Apply first move (2 squares in any axis)
        switch firstMove {
        case .up: 
            // UP means visually forward from player's perspective
            if isBoardRotatedForBlack {
                newRank -= 2  // When board rotated for black view, UP moves toward white's side (lower ranks)
            } else {
                newRank += 2  // Normal view: UP moves toward black's side (higher ranks)
            }
        case .down: 
            // DOWN means visually backward from player's perspective
            if isBoardRotatedForBlack {
                newRank += 2  // When board rotated for black view, DOWN moves toward black's side (higher ranks)
            } else {
                newRank -= 2  // Normal view: DOWN moves toward white's side (lower ranks)
            }
        case .forward: 
            // Forward means toward the opponent's side (2 squares)
            if isBoardRotatedForBlack {
                newRank -= 2  // When board rotated for black view, forward moves toward white's side (lower ranks)
            } else {
                newRank += 2  // Normal view: forward moves toward black's side (higher ranks)
            }
        case .backward: 
            // Backward means toward your own side (2 squares)
            if isBoardRotatedForBlack {
                newRank += 2  // When board rotated for black view, backward moves toward black's side (higher ranks)
            } else {
                newRank -= 2  // Normal view: backward moves toward white's side (lower ranks)
            }
        case .left: 
            // Apply board rotation perspective for X-axis
            if isBoardRotatedForBlack {
                newFile += 2  // Flipped for board rotation
            } else {
                newFile -= 2  // Normal direction
            }
        case .right: 
            // Apply board rotation perspective for X-axis
            if isBoardRotatedForBlack {
                newFile -= 2  // Flipped for board rotation
            } else {
                newFile += 2  // Normal direction
            }
        case .upZ: newZ += 2
        case .downZ: newZ -= 2
        default:
            print("⚠️ Invalid first knight move direction: \(firstMove)")
            knightFirstMove = nil
            return
        }
        
        // Apply second move (1 square in a perpendicular axis)
        switch direction {
        case .up: 
            // UP means visually forward from player's perspective
            if isBoardRotatedForBlack {
                newRank -= 1  // When board rotated for black view, UP moves toward white's side (lower ranks)
            } else {
                newRank += 1  // Normal view: UP moves toward black's side (higher ranks)
            }
        case .down: 
            // DOWN means visually backward from player's perspective
            if isBoardRotatedForBlack {
                newRank += 1  // When board rotated for black view, DOWN moves toward black's side (higher ranks)
            } else {
                newRank -= 1  // Normal view: DOWN moves toward white's side (lower ranks)
            }
        case .forward: 
            // Forward means toward the opponent's side
            if isBoardRotatedForBlack {
                newRank -= 1  // When board rotated for black view, forward button moves toward white's side (lower ranks)
            } else {
                newRank += 1  // Normal view: forward moves toward black's side (higher ranks)
            }
        case .backward: 
            // Backward means toward your own side
            if isBoardRotatedForBlack {
                newRank += 1  // When board rotated for black view, backward button moves toward black's side (higher ranks)
            } else {
                newRank -= 1  // Normal view: backward moves toward white's side (lower ranks)
            }
        case .left: 
            // Apply board rotation perspective for X-axis
            if isBoardRotatedForBlack {
                newFile += 1  // Flipped for board rotation
            } else {
                newFile -= 1  // Normal direction
            }
        case .right: 
            // Apply board rotation perspective for X-axis
            if isBoardRotatedForBlack {
                newFile -= 1  // Flipped for board rotation
            } else {
                newFile += 1  // Normal direction
            }
        case .upZ: newZ += 1
        case .downZ: newZ -= 1
        default:
            print("⚠️ Invalid second knight move direction: \(direction)")
            knightFirstMove = nil
            return
        }
        
        // Check if the moves are perpendicular (not the same axis)
        // Allow same direction twice for special cases (like UP+UP = 2 squares up, then 1 square perpendicular)
        let isSameDirection = firstMove == direction
        
        // More flexible perpendicular check that allows up/down combinations
        let isPerpendicular = (firstMove == .up || firstMove == .down) && (direction == .left || direction == .right || direction == .forward || direction == .backward) ||
                              (firstMove == .left || firstMove == .right) && (direction == .up || direction == .down || direction == .forward || direction == .backward) ||
                              (firstMove == .upZ || firstMove == .downZ) && (direction == .up || direction == .down || direction == .left || direction == .right || direction == .forward || direction == .backward) ||
                              (firstMove == .up || firstMove == .down) && (direction == .upZ || direction == .downZ) ||
                              (firstMove == .left || firstMove == .right) && (direction == .upZ || direction == .downZ) ||
                              // Allow up+down and down+up combinations for knight moves
                              (firstMove == .up && direction == .down) ||
                              (firstMove == .down && direction == .up)
        
        // Debug print to see what's happening
        print("🐎 Debug: firstMove=\(firstMove), direction=\(direction), isSameDirection=\(isSameDirection), isPerpendicular=\(isPerpendicular)")
        
        if !isPerpendicular && !isSameDirection {
            print("⚠️ Knight moves must be perpendicular or same direction: first=\(firstMove), second=\(direction)")
            knightFirstMove = nil
            return
        }
        
        // If same direction, treat as a 3-square move in that direction (not valid for knight)
        if isSameDirection {
            print("⚠️ Knight cannot move 3 squares in the same direction")
            print("💡 Knight moves require: 2 squares in one direction, then 1 square perpendicular")
            print("💡 Try: UP then LEFT/RIGHT, or LEFT/RIGHT then UP/DOWN")
            print("💡 For your first move (UP), now press LEFT or RIGHT for the second part")
            knightFirstMove = nil
            return
        }
        
        // Check bounds
        // Support extended board (files 0-15 for extended pawns)
        let maxFile = 15
        guard newFile >= 0 && newFile <= maxFile && newRank >= 0 && newRank <= 7 && newZ >= 0 && newZ <= 7 else { 
            print("⚠️ Knight move would go outside board bounds")
            knightFirstMove = nil
            return 
        }
        
        // Validate and execute the move
        let newPosition = ChessPosition3D(file: newFile, rank: newRank, z: newZ)
        print("🐎 Knight attempting to move from \(originalPosition.stringValue) to \(newPosition.stringValue)")
        
        // For knights, skip the complex validation since we've already validated the L-shape
        // Just check if the destination is occupied by own piece
        if let targetPiece = chessGame.getPieceAtPosition(newPosition) {
            if let piece = chessGame.getPieceAtPosition(originalPosition), 
               targetPiece.color == piece.color {
                print("⚠️ Cannot move to position occupied by own piece")
                knightFirstMove = nil
                return
            }
        }
        
        // Check if the new position is empty or has an opponent's piece
        if let targetPiece = chessGame.getPieceAtPosition(newPosition) {
            if let piece = chessGame.getPieceAtPosition(originalPosition), 
               targetPiece.color == piece.color {
                print("⚠️ Cannot move to position occupied by own piece")
                knightFirstMove = nil
                return
            }
        }
        
        // Move the piece in the chess engine
        if let piece = chessGame.getPieceAtPosition(originalPosition) {
            print("🎯 ChessPieceController: Found piece to move: \(piece.color) \(piece.type)")
            print("🎯 ChessPieceController: Current turn: \(chessGame.getCurrentTurn().rawValue)")
            
            // Check if king is in check and validate the move resolves it
            if chessGame.isKingInCheck() {
                // MANUAL MODE FIX: Removed AI-like check resolution validation
                // In manual mode, we don't need to validate that moves resolve check
                // The player should be able to make any legal move, even if it doesn't resolve check
                // The system will detect checkmate if no legal moves are available
                // TODO: If AI mode needs check resolution validation, add: if chessGame.aiModeActive { ... }
                print("🔍 King is in check - allowing any legal move in manual mode")
            }
            
            // IMPORTANT: Capture the turn and piece BEFORE tryMove (which changes the turn and moves the piece)
            let currentTurnBeforeMove = chessGame.getCurrentTurn()
            let pieceBeforeMove = chessGame.getPieceAtPosition(originalPosition)
            print("🔍 Timer Debug: Captured turn before knight tryMove: \(currentTurnBeforeMove)")
            print("🔍 Timer Debug: Captured piece before knight tryMove: \(pieceBeforeMove?.type.rawValue ?? "none")")
            
            // Try to move the piece using the chess engine
            let moveSuccess = chessGame.tryMove(from: originalPosition, to: newPosition)
            print("🎯 ChessPieceController: Knight move attempted, success: \(moveSuccess)")
            
            // Check if the piece moved successfully by checking if it's now at the new position
            print("🔍 Timer Debug: knight moveSuccess=\(moveSuccess)")
            print("🔍 Timer Debug: piece at newPosition=\(chessGame.getPieceAtPosition(newPosition) != nil)")
            print("🔍 Timer Debug: piece at originalPosition=\(chessGame.getPieceAtPosition(originalPosition) == nil)")
            
            let allConditionsMet = moveSuccess && chessGame.getPieceAtPosition(newPosition) != nil && 
               chessGame.getPieceAtPosition(originalPosition) == nil
            print("🔍 Timer Debug: All knight conditions met: \(allConditionsMet)")
            
            if allConditionsMet {
                print("✅ ChessPieceController: Knight move successful!")
                print("🔍 Timer Logic: About to check timer conditions for knight")
                
                // Use the piece we captured BEFORE the move
                guard let piece = pieceBeforeMove else {
                    print("❌ ChessPieceController: No piece found at original position for knight timer logic")
                    knightFirstMove = nil
                    return
                }
                
                // Check if we should use confirmation timer based on game mode
                // Use the turn we captured BEFORE tryMove
                let shouldUseTimer = chessGame.gameMode == .play && 
                                   piece.color == currentTurnBeforeMove
                
                print("🔍 Timer Debug: gameMode=\(chessGame.gameMode), isAITurn=\(chessGame.isAITurn()), piece.color=\(piece.color), currentTurn=\(currentTurnBeforeMove), shouldUseTimer=\(shouldUseTimer)")
                print("🔍 Timer Debug: piece.color=\(piece.color.rawValue), currentTurn=\(currentTurnBeforeMove.rawValue), colors match: \(piece.color == currentTurnBeforeMove)")
                print("🔍 Timer Debug: gameMode enum value=\(chessGame.gameMode)")
                
                if shouldUseTimer {
                    // Use confirmation timer for human moves in play mode
                    print("⏰ Using confirmation timer for human knight move")
                    if let pieceNode = selectedPiece {
                        startMoveConfirmation(from: originalPosition, to: newPosition, pieceNode: pieceNode)
                    }
                } else {
                    // Execute move immediately for AI moves or learn mode
                    print("⚡ Executing knight move immediately (AI or learn mode)")
                    if let pieceNode = selectedPiece {
                        executeMove(from: originalPosition, to: newPosition, pieceNode: pieceNode)
                    }
                }
            } else {
                print("🔍 Timer Debug: Knight move conditions not met - timer logic skipped")
                print("❌ ChessPieceController: Knight move failed")
                if !moveSuccess {
                    print("⚠️ ChessPieceController: Chess engine rejected the knight move")
                    if piece.color != chessGame.getCurrentTurn() {
                        print("⚠️ ChessPieceController: Wrong turn - it's \(chessGame.getCurrentTurn().rawValue)'s turn, but trying to move \(piece.color.rawValue) piece")
                    }
                }
            }
        } else {
            print("❌ ChessPieceController: No piece found at current position \(originalPosition.stringValue)")
        }
        
        // Reset knight move state
        knightFirstMove = nil
    }
    
    // Move the selected piece up or down in Z
    func moveSelectedPieceZ(direction: MoveDirection, distance: Int = 1) {
        guard let _ = selectedPiece,
              let currentPosition = selectedPiecePosition,
              let chessGame = chessGame else {
            print("⚠️ ChessPieceController: Cannot move piece in Z - missing required data")
            return
        }
        var newZ = currentPosition.z
        switch direction {
        case .up:
            newZ += distance
        case .down:
            newZ -= distance
        default:
            return
        }
        guard newZ >= 0 && newZ <= 7 else {
            print("⚠️ ChessPieceController: Z move out of bounds (newZ: \(newZ))")
            return
        }
        let newPosition = ChessPosition3D(file: currentPosition.file, rank: currentPosition.rank, z: newZ)
        print("🎯 ChessPieceController: Attempting to move in Z to \(newPosition.stringValue)")
        
        // For Z-moves, do basic validation instead of the complex isValidMoveForPiece
        if let piece = chessGame.getPieceAtPosition(currentPosition) {
            // Check if destination is occupied by own piece
            if let targetPiece = chessGame.getPieceAtPosition(newPosition) {
                if targetPiece.color == piece.color {
                    print("⚠️ ChessPieceController: Z move blocked by own piece at \(newPosition.stringValue)")
                    return
                }
            }
            
                    // For pawns and kings, check if it's a valid Z-move
        if piece.type == .pawn || piece.type == .king {
                // For pawns: use starting position logic
                // For kings: always force distance to 1
                let isStartingPosition = (currentPosition.z == 0 && ((piece.color == .white && currentPosition.rank <= 1) || (piece.color == .black && currentPosition.rank >= 6))) ||
                                       (currentPosition.z == 1 && ((piece.color == .white && currentPosition.rank <= 1) || (piece.color == .black && currentPosition.rank >= 6)))
                let effectiveDistance = piece.type == .king ? 1 : (isStartingPosition ? distance : 1)
                let isValidZMove = effectiveDistance == 1 || (effectiveDistance == 2 && isStartingPosition && piece.type == .pawn)
                
                // If the move distance is greater than allowed, try with distance 1
                let actualMoveDistance = abs(newZ - currentPosition.z)
                if actualMoveDistance > effectiveDistance {
                    print("⚠️ ChessPieceController: Z move distance \(actualMoveDistance) exceeds allowed distance \(effectiveDistance), trying with distance 1")
                    
                    // Recalculate with distance 1
                    var adjustedZ = currentPosition.z
                    switch direction {
                    case .up:
                        adjustedZ = currentPosition.z + 1
                    case .down:
                        adjustedZ = currentPosition.z - 1
                    default:
                        return
                    }
                    
                    // Check bounds
                    guard adjustedZ >= 0 && adjustedZ <= 7 else {
                        print("⚠️ ChessPieceController: Adjusted Z move out of bounds (adjustedZ: \(adjustedZ))")
                        return
                    }
                    
                    let adjustedPosition = ChessPosition3D(file: currentPosition.file, rank: currentPosition.rank, z: adjustedZ)
                    print("🎯 ChessPieceController: Attempting adjusted Z move to \(adjustedPosition.stringValue)")
                    
                    // Check if destination is occupied by own piece
                    if let targetPiece = chessGame.getPieceAtPosition(adjustedPosition) {
                        if targetPiece.color == piece.color {
                            print("⚠️ ChessPieceController: Adjusted Z move blocked by own piece at \(adjustedPosition.stringValue)")
                            return
                        }
                    }
                    
                    // IMPORTANT: Capture the turn and piece BEFORE tryMove (which changes the turn and moves the piece)
                    let currentTurnBeforeMove = chessGame.getCurrentTurn()
                    let pieceBeforeMove = chessGame.getPieceAtPosition(currentPosition)
                    print("🔍 Timer Debug: Captured turn before adjusted tryMove: \(currentTurnBeforeMove)")
                    print("🔍 Timer Debug: Captured piece before adjusted tryMove: \(pieceBeforeMove?.type.rawValue ?? "none")")
                    
                    // Try the adjusted move
                    print("🔍 Timer Debug: About to call tryMove from \(currentPosition) to \(adjustedPosition)")
                    let moveSuccess = chessGame.tryMove(from: currentPosition, to: adjustedPosition)
                    print("🎯 ChessPieceController: Adjusted Z Move attempted, success: \(moveSuccess)")
                    
                    // Check if the piece moved successfully by checking if it's now at the new position
                    print("🔍 Timer Debug: adjusted moveSuccess=\(moveSuccess)")
                    print("🔍 Timer Debug: piece at adjustedPosition=\(chessGame.getPieceAtPosition(adjustedPosition) != nil)")
                    print("🔍 Timer Debug: piece at currentPosition=\(chessGame.getPieceAtPosition(currentPosition) == nil)")
                    
                    let allConditionsMet = moveSuccess && chessGame.getPieceAtPosition(adjustedPosition) != nil && chessGame.getPieceAtPosition(currentPosition) == nil
                    print("🔍 Timer Debug: All adjusted conditions met: \(allConditionsMet)")
                    
                    if allConditionsMet {
                        print("✅ ChessPieceController: Adjusted Z Move successful!")
                        print("🔍 Timer Logic: About to check timer conditions for adjusted move")
                        
                        // Use the piece we captured BEFORE the move
                        guard let piece = pieceBeforeMove else {
                            print("❌ ChessPieceController: No piece found at current position for adjusted timer logic")
                            return
                        }
                        
                        // Check if we should use confirmation timer based on game mode
                        // Use the turn we captured BEFORE tryMove
                        let shouldUseTimer = chessGame.gameMode == .play && 
                                           piece.color == currentTurnBeforeMove
                        
                        print("🔍 Timer Debug: gameMode=\(chessGame.gameMode), isAITurn=\(chessGame.isAITurn()), piece.color=\(piece.color), currentTurn=\(currentTurnBeforeMove), shouldUseTimer=\(shouldUseTimer)")
                        print("🔍 Timer Debug: piece.color=\(piece.color.rawValue), currentTurn=\(currentTurnBeforeMove.rawValue), colors match: \(piece.color == currentTurnBeforeMove)")
                        print("🔍 Timer Debug: gameMode enum value=\(chessGame.gameMode)")
                        
                        if shouldUseTimer {
                            // Use confirmation timer for human moves in play mode
                            print("⏰ Using confirmation timer for human adjusted Z move")
                            if let pieceNode = selectedPiece {
                                startMoveConfirmation(from: currentPosition, to: adjustedPosition, pieceNode: pieceNode)
                            }
                        } else {
                            // Execute move immediately for AI moves or learn mode
                            print("⚡ Executing adjusted Z move immediately (AI or learn mode)")
                            if let pieceNode = selectedPiece {
                                executeMove(from: currentPosition, to: adjustedPosition, pieceNode: pieceNode)
                            }
                            
                            // Update our selected piece position
                            selectedPiecePosition = adjustedPosition
                            
                            // Find the new node for the piece (it might have been recreated)
                            if let newNode = chessGame.getPieceNode(at: adjustedPosition) {
                                selectedPiece = newNode
                                highlightSelectedPiece()
                            }
                            
                            // Add move to history
                            addMoveToHistory(piece: piece, from: currentPosition, to: adjustedPosition)
                            
                            // Clear move indicators
                            clearMoveIndicators()
                            
                            // Update piece lists
                            updatePieceLists()
                        }
                    } else {
                        print("🔍 Timer Debug: Adjusted Z move conditions not met - timer logic skipped")
                        print("❌ ChessPieceController: Adjusted Z Move failed - piece not found at new position or still at old position")
                        print("🎯 ChessPieceController: Piece at old position: \(chessGame.getPieceAtPosition(currentPosition)?.type.rawValue ?? "none")")
                        print("🎯 ChessPieceController: Piece at new position: \(chessGame.getPieceAtPosition(adjustedPosition)?.type.rawValue ?? "none")")
                        
                        // If the chess engine rejected the move, try to understand why
                        if !moveSuccess {
                            print("⚠️ ChessPieceController: Chess engine rejected the adjusted Z move")
                            chessGame.showInvalidMoveMessage("Invalid Move")
                            if piece.color != chessGame.getCurrentTurn() {
                                print("⚠️ ChessPieceController: Wrong turn - it's \(chessGame.getCurrentTurn().rawValue)'s turn, but trying to move \(piece.color.rawValue) piece")
                            }
                        }
                    }
                    return
                }
                
                if !isValidZMove {
                    print("⚠️ ChessPieceController: Invalid Z move for pawn - distance: \(distance), effectiveDistance: \(effectiveDistance), isStartingPosition: \(isStartingPosition)")
                    return
                }
            }
            
            // For bishops, validate that the move is diagonal (not pure vertical)
            if piece.type == .bishop {
                let fileDiff = abs(newPosition.file - currentPosition.file)
                let rankDiff = abs(newPosition.rank - currentPosition.rank)
                let zDiff = abs(newPosition.z - currentPosition.z)
                
                // Check if this is a pure vertical move (only Z changes)
                let isPureVertical = fileDiff == 0 && rankDiff == 0 && zDiff > 0
                if isPureVertical {
                    print("🔍 Bishop pure vertical Z move - INVALID")
                    return
                }
                
                // Check if this is a pure horizontal move (only file or rank changes)
                let isPureHorizontal = (fileDiff > 0 && rankDiff == 0 && zDiff == 0) || (fileDiff == 0 && rankDiff > 0 && zDiff == 0)
                if isPureHorizontal {
                    print("🔍 Bishop pure horizontal Z move - INVALID")
                    return
                }
            }
        }
        
        // IMPORTANT: Capture the turn and piece BEFORE tryMove (which changes the turn and moves the piece)
        let currentTurnBeforeMove = chessGame.getCurrentTurn()
        let pieceBeforeMove = chessGame.getPieceAtPosition(currentPosition)
        print("🔍 Timer Debug: Captured turn before tryMove: \(currentTurnBeforeMove)")
        print("🔍 Timer Debug: Captured piece before tryMove: \(pieceBeforeMove?.type.rawValue ?? "none")")
        
        // Try to move the piece using the chess engine
        print("🔍 Timer Debug: About to call tryMove from \(currentPosition) to \(newPosition)")
        let moveSuccess = chessGame.tryMove(from: currentPosition, to: newPosition)
        print("🎯 ChessPieceController: Z Move attempted, success: \(moveSuccess)")
        
        // Check if the piece moved successfully by checking if it's now at the new position
        print("🔍 Timer Debug: moveSuccess=\(moveSuccess)")
        print("🔍 Timer Debug: piece at newPosition=\(chessGame.getPieceAtPosition(newPosition) != nil)")
        print("🔍 Timer Debug: piece at currentPosition=\(chessGame.getPieceAtPosition(currentPosition) == nil)")
        
        let allConditionsMet = moveSuccess && chessGame.getPieceAtPosition(newPosition) != nil && chessGame.getPieceAtPosition(currentPosition) == nil
        print("🔍 Timer Debug: All conditions met: \(allConditionsMet)")
        
        if allConditionsMet {
            print("✅ ChessPieceController: Z Move successful!")
            print("🔍 Timer Logic: About to check timer conditions")
            
            // Use the piece we captured BEFORE the move
            guard let piece = pieceBeforeMove else {
                print("❌ ChessPieceController: No piece found at current position for timer logic")
                return
            }
            
            // Check if we should use confirmation timer based on game mode
            // Use the turn we captured BEFORE tryMove
            let shouldUseTimer = chessGame.gameMode == .play && 
                               piece.color == currentTurnBeforeMove
            
            print("🔍 Timer Debug: gameMode=\(chessGame.gameMode), isAITurn=\(chessGame.isAITurn()), piece.color=\(piece.color), currentTurn=\(currentTurnBeforeMove), shouldUseTimer=\(shouldUseTimer)")
            print("🔍 Timer Debug: piece.color=\(piece.color.rawValue), currentTurn=\(currentTurnBeforeMove.rawValue), colors match: \(piece.color == currentTurnBeforeMove)")
            print("🔍 Timer Debug: gameMode enum value=\(chessGame.gameMode)")
            
            if shouldUseTimer {
                // Use confirmation timer for human moves in play mode
                print("⏰ Using confirmation timer for human Z move")
                if let pieceNode = selectedPiece {
                    startMoveConfirmation(from: currentPosition, to: newPosition, pieceNode: pieceNode)
                }
            } else {
                // Execute move immediately for AI moves or learn mode
                print("⚡ Executing Z move immediately (AI or learn mode)")
                if let pieceNode = selectedPiece {
                    executeMove(from: currentPosition, to: newPosition, pieceNode: pieceNode)
                }
                
                // Update our selected piece position
                selectedPiecePosition = newPosition
                
                // Find the new node for the piece (it might have been recreated)
                if let newNode = chessGame.getPieceNode(at: newPosition) {
                    selectedPiece = newNode
                    highlightSelectedPiece()
                }
                
                // Add move to history
                addMoveToHistory(piece: piece, from: currentPosition, to: newPosition)
                
                // Clear move indicators
                clearMoveIndicators()
                
                // Update piece lists
                updatePieceLists()
            }
        } else {
            print("🔍 Timer Debug: Z move conditions not met - timer logic skipped")
            print("❌ ChessPieceController: Z Move failed - piece not found at new position or still at old position")
            print("🎯 ChessPieceController: Piece at old position: \(chessGame.getPieceAtPosition(currentPosition)?.type.rawValue ?? "none")")
            print("🎯 ChessPieceController: Piece at new position: \(chessGame.getPieceAtPosition(newPosition)?.type.rawValue ?? "none")")
            
            // If the chess engine rejected the move, try to understand why
            if !moveSuccess {
                print("⚠️ ChessPieceController: Chess engine rejected the Z move")
                chessGame.showInvalidMoveMessage("Invalid Move")
                if let piece = chessGame.getPieceAtPosition(currentPosition),
                   piece.color != chessGame.getCurrentTurn() {
                    print("⚠️ ChessPieceController: Wrong turn - it's \(chessGame.getCurrentTurn().rawValue)'s turn, but trying to move \(piece.color.rawValue) piece")
                }
            }
        }
    }
    

    
    // MARK: - Move Execution
    
    func executeMove(from: ChessPosition3D, to: ChessPosition3D, pieceNode: SCNNode) {
        print("✅ Executing move immediately: \(from.stringValue) -> \(to.stringValue)")
        
        // Execute the move in the chess engine FIRST
        if let chessGame = chessGame {
            let moveSuccess = chessGame.tryMove(from: from, to: to)
            if moveSuccess {
                // Only move the piece visually if engine move succeeded
                let newWorldPos = chessGame.boardToWorldPosition(file: to.file, rank: to.rank, z: to.z)
                let moveAction = SCNAction.move(to: newWorldPos, duration: 0.3)
                pieceNode.runAction(moveAction)
                
                // Update tracking dictionaries after successful engine move
                chessGame.updatePiecePosition(pieceNode, from: from, to: to)
            } else {
                print("❌ Chess engine move failed - no visual move")
            }
        }
    }
    
    func executeMoveVisualOnly(from: ChessPosition3D, to: ChessPosition3D, pieceNode: SCNNode) {
        print("🎭 Executing visual move only: \(from.stringValue) -> \(to.stringValue)")
        
        // Move the piece visually ONLY (no chess engine update)
        if let chessGame = chessGame {
            let newWorldPos = chessGame.boardToWorldPosition(file: to.file, rank: to.rank, z: to.z)
            let moveAction = SCNAction.move(to: newWorldPos, duration: 0.3)
            pieceNode.runAction(moveAction)
            
            // Update tracking dictionaries for visual purposes only
            chessGame.updatePiecePosition(pieceNode, from: from, to: to)
        }
    }
    
    // MARK: - Helper Functions
    
    func getEffectiveDistance(for position: ChessPosition3D) -> Int {
        guard let chessGame = chessGame,
              let piece = chessGame.getPieceAtPosition(position) else {
            return moveDistance
        }
        
        if piece.type == .king {
            return 1
        } else if piece.type == .pawn {
            // Starting positions:
            // z=0 (i): White pawns at rank 1, Black pawns at rank 6
            // z=1 (ii): Extended pawns at their original positions (ranks 0-1 for white, 6-7 for black)
            let isStartingPosition = (piece.color == .white && ((position.z == 0 && position.rank == 1) || (position.z == 1 && (position.rank == 0 || position.rank == 1)))) || 
                                   (piece.color == .black && ((position.z == 0 && position.rank == 6) || (position.z == 1 && (position.rank == 6 || position.rank == 7))))
            
            if isStartingPosition {
                return moveDistance
            } else {
                print("🎯 ChessPieceController: Pawn has moved from starting position, forcing distance to 1")
                return 1
            }
        }
        
        return moveDistance
    }
    
    // MARK: - Board Rotation
    private var isBoardRotatedForBlack = false
    private var originalRotation: SCNVector4?
    
    // Helper function to apply board rotation perspective to rank and file offsets
    func applyBoardRotationPerspective(rankOffset: Int, fileOffset: Int) -> (rank: Int, file: Int) {
        if isBoardRotatedForBlack {
            // When board is rotated 180°, flip the rank and file directions for visual perspective
            return (rank: -rankOffset, file: -fileOffset)
        } else {
            return (rank: rankOffset, file: fileOffset)
        }
    }
    
    func rotateBoardForTurn(currentTurn: PieceColor) {
        print("🔄 ChessPieceController: Rotating board for \(currentTurn.rawValue)'s turn")
        
        // Get the modelNode from the ContentView through the chess game
        if let chessGame = chessGame,
           let modelNode = chessGame.getModelNode() {
            
            // Apply turn-based rotation directly to the target position
            if currentTurn == .black {
                // For black's turn: rotate to black's position (180° Y-axis + -30° X-axis from default)
                let blackRotation = SCNVector3(-Float.pi * 5/12 - Float.pi/6, Float.pi, 0) // Default + -30° X-axis + 180° Y-axis
                let blackAction = SCNAction.rotateTo(x: CGFloat(blackRotation.x), 
                                                   y: CGFloat(blackRotation.y), 
                                                   z: CGFloat(blackRotation.z), 
                                                   duration: 0.8)
                modelNode.runAction(blackAction)
                self.isBoardRotatedForBlack = true
                print("🔄 Rotated to black's position: 180° Y-axis + -30° X-axis from default")
            } else if currentTurn == .white {
                // For white's turn: rotate to white's default position
                let whiteRotation = SCNVector3(-Float.pi * 5/12, 0, 0) // Default white position
                let whiteAction = SCNAction.rotateTo(x: CGFloat(whiteRotation.x), 
                                                   y: CGFloat(whiteRotation.y), 
                                                   z: CGFloat(whiteRotation.z), 
                                                   duration: 0.8)
                modelNode.runAction(whiteAction)
                self.isBoardRotatedForBlack = false
                print("🔄 Rotated to white's default position")
            }
        } else {
            print("⚠️ Cannot rotate board - modelNode not available")
        }
    }
    
    // MARK: - Move Confirmation Timer
    
    func startMoveConfirmation(from: ChessPosition3D, to: ChessPosition3D, pieceNode: SCNNode) {
        print("⏰ Starting move confirmation timer: \(from.stringValue) -> \(to.stringValue)")
        
        // Safety check: Ensure we have a chess game reference
        guard let chessGame = chessGame else {
            print("⚠️ Cannot start move confirmation timer - no chess game")
            return
        }
        
        print("🔍 Timer UI Debug: Setting isMovePending=true, moveConfirmationTimeRemaining=5.0")
        
        // Store pending move details
        pendingMoveFrom = from
        pendingMoveTo = to
        pendingPieceNode = pieceNode
        isMovePending = true
        moveConfirmationTimeRemaining = 2.0
        
        print("🔍 Timer UI Debug: isMovePending set to \(isMovePending), timeRemaining=\(moveConfirmationTimeRemaining)")
        
        // Start countdown timer
        moveConfirmationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateMoveConfirmationTimer()
        }
    }
    
    private func updateMoveConfirmationTimer() {
        moveConfirmationTimeRemaining -= 0.1
        
        // Safety check: Stop timer if it's no longer the player's turn
        if let chessGame = chessGame,
           let piece = chessGame.getPieceAtPosition(pendingMoveFrom ?? ChessPosition3D(file: 0, rank: 0, z: 0)),
           piece.color != chessGame.getCurrentTurn() {
            print("⚠️ Timer stopped - no longer player's turn")
            cancelMove()
            return
        }
        
        if moveConfirmationTimeRemaining <= 0 {
            confirmMove()
        }
    }
    
    func confirmMove() {
        print("✅ Move confirmed: \(pendingMoveFrom?.stringValue ?? "unknown") -> \(pendingMoveTo?.stringValue ?? "unknown")")
        
        // Stop timer
        moveConfirmationTimer?.invalidate()
        moveConfirmationTimer = nil
        
        // Execute the pending move
        if let from = pendingMoveFrom,
           let to = pendingMoveTo,
           let pieceNode = pendingPieceNode,
           let chessGame = chessGame {
            
            // Check if the piece is already at the destination in the chess engine
            // This can happen if the chess engine move was already executed during the countdown
            if chessGame.getPieceAtPosition(to) != nil {
                print("✅ Piece already at destination in chess engine - no need to move")
                // The piece is already at the destination, so we just need to update tracking
                selectedPiecePosition = to
                
                // Find the new node for the piece (it might have been recreated)
                if let newNode = chessGame.getPieceNode(at: to) {
                    selectedPiece = newNode
                    highlightSelectedPiece()
                }
                
                // Add move to history
                if let piece = chessGame.getPieceAtPosition(to) {
                    addMoveToHistory(piece: piece, from: from, to: to)
                }
                
                // Clear move indicators
                clearMoveIndicators()
                
                // Update piece lists
                updatePieceLists()
            } else {
                // The piece was already moved visually during the countdown
                // Now we just need to execute the chess engine move WITHOUT moving the visual piece again
                // We'll call a special function that only updates the chess engine state
                let moveSuccess = chessGame.executeChessEngineMoveOnly(from: from, to: to)
                if !moveSuccess {
                    print("❌ Chess engine move failed - reverting visual move")
                    // Revert the visual move if chess engine rejected it
                    let originalWorldPos = chessGame.boardToWorldPosition(file: from.file, rank: from.rank, z: from.z)
                    let revertAction = SCNAction.move(to: originalWorldPos, duration: 0.3)
                    pieceNode.runAction(revertAction)
                    chessGame.resetPiecePosition(pieceNode, to: from)
                    chessGame.removePieceFromPosition(to)
                                } else {
                    // Move was successful - update our tracking
                    selectedPiecePosition = to
                    
                    // Find the new node for the piece (it might have been recreated)
                    if let newNode = chessGame.getPieceNode(at: to) {
                        selectedPiece = newNode
                        highlightSelectedPiece()
                    }
                    
                    // Add move to history
                    if let piece = chessGame.getPieceAtPosition(to) {
                        addMoveToHistory(piece: piece, from: from, to: to)
                    }
                    
                    // Clear move indicators
                    clearMoveIndicators()
                    
                    // Update piece lists
                    updatePieceLists()
                }
            }
        }
        
        // Clear pending state
        isMovePending = false
        moveConfirmationTimeRemaining = 5.0
        pendingMoveFrom = nil
        pendingMoveTo = nil
        pendingPieceNode = nil
        
        // Check if promotion choice UI should be shown, otherwise execute any pending promotion
        if let chessGame = chessGame {
            // Only auto-execute promotion if choice UI is not being shown
            if !chessGame.showPromotionChoice {
                chessGame.executePendingPromotion()
            } else {
                print("♕ Promotion choice UI is showing - waiting for user selection")
            }
        }
        
        // Human move confirmed - AI can now take its turn immediately
        print("⏰ Human move confirmed - AI can now take its turn")
        
        // Rotate board for the new turn after a 2-second delay
        if let chessGame = chessGame {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                chessGame.rotateBoardForTurn()
            }
        }
    }
    
    func cancelMove() {
        print("❌ Move cancelled: \(pendingMoveFrom?.stringValue ?? "unknown") -> \(pendingMoveTo?.stringValue ?? "unknown")")
        print("🔍 Cancel debug: pendingPieceNode=\(pendingPieceNode != nil), pendingMoveFrom=\(pendingMoveFrom?.stringValue ?? "nil"), pendingMoveTo=\(pendingMoveTo?.stringValue ?? "nil"), chessGame=\(chessGame != nil)")
        
        // Stop timer
        moveConfirmationTimer?.invalidate()
        moveConfirmationTimer = nil
        
        // Reset piece to original position
        if let pieceNode = pendingPieceNode,
           let fromPosition = pendingMoveFrom,
           let toPosition = pendingMoveTo,
           let chessGame = chessGame {
            
            let originalWorldPos = chessGame.boardToWorldPosition(file: fromPosition.file, rank: fromPosition.rank, z: fromPosition.z)
            let moveAction = SCNAction.move(to: originalWorldPos, duration: 0.3)
            pieceNode.runAction(moveAction)
            
            // Update tracking dictionaries using public methods
            chessGame.resetPiecePosition(pieceNode, to: fromPosition)
            
            // Remove from destination position
            chessGame.removePieceFromPosition(toPosition)
            
            // Check if the chess engine move was executed and undo it
            if chessGame.getPieceAtPosition(toPosition) != nil {
                print("🔄 Chess engine move detected - undoing move in chess engine")
                // The piece is at the destination, so the chess engine move was executed
                // We need to undo it
                _ = chessGame.chessBoard.undoLastMove()
            } else {
                print("🔄 No chess engine move detected - visual move only")
            }
            
            print("🔄 Piece reset to original position: \(fromPosition.stringValue)")
        }
        
        // Clear pending state
        isMovePending = false
        moveConfirmationTimeRemaining = 5.0
        pendingMoveFrom = nil
        pendingMoveTo = nil
        pendingPieceNode = nil
    }

    // Two-step 3D move state
    @Published var pending3DMovePieceType: PieceType? = nil
    @Published var pending3DMoveStart: ChessPosition3D? = nil
    @Published var pending3DMoveZ: Int? = nil
    @Published var pending3DMoveDistance: Int? = nil
    @Published var pending3DMoveFirstDirection: MoveDirection? = nil
    @Published var awaitingSecondDirection: Bool = false

    // Call this when a Z move is initiated for bishop/queen/knight
    func start3DMoveZ(direction: MoveDirection, distance: Int) {
        guard let pos = selectedPiecePosition, let chessGame = chessGame, let piece = chessGame.getPieceAtPosition(pos) else { return }
        print("[DEBUG] start3DMoveZ called for \(piece.color) \(piece.type) at \(pos.stringValue), direction: \(direction), distance: \(distance), current z: \(pos.z)")
        let newZ = (direction == .up) ? pos.z + distance : pos.z - distance
        print("[DEBUG] Intended new z after Z move: \(newZ)")
        pending3DMovePieceType = piece.type
        pending3DMoveStart = pos
        pending3DMoveZ = newZ
        pending3DMoveDistance = distance
        pending3DMoveFirstDirection = direction
        awaitingSecondDirection = true
        diagonalInstruction = "Now select X/Y direction for diagonal move"
    }

    // Call this when an X/Y direction is chosen after Z for bishop/queen/knight
    func complete3DMoveXY(direction: MoveDirection) {
        guard awaitingSecondDirection,
              let start = pending3DMoveStart,
              let z = pending3DMoveZ,
              let distance = pending3DMoveDistance,
              let pieceType = pending3DMovePieceType else { return }
        var newFile = start.file
        var newRank = start.rank
        print("[DEBUG] complete3DMoveXY for \(pieceType) from \(start.stringValue) to z=\(z), direction: \(direction), distance: \(distance)")
        
        // For knights, the second step should always be 1, regardless of the distance setting
        let secondStepDistance = (pieceType == .knight) ? 1 : distance
        
        // Get the piece to determine color for direction handling
        let piece = chessGame?.getPieceAtPosition(start)
        let isBlack = piece?.color == .black
        
        // Only allow valid bishop/queen/knight 3D diagonals
        switch direction {
        case .left: newFile -= secondStepDistance
        case .right: newFile += secondStepDistance
        case .forward: 
            // For black pieces, forward means decreasing rank (towards white's side)
            newRank += isBlack ? -secondStepDistance : secondStepDistance
        case .backward: 
            // For black pieces, backward means increasing rank (towards black's side)
            newRank += isBlack ? secondStepDistance : -secondStepDistance
        case .upLeft: 
            newFile -= secondStepDistance
            newRank += isBlack ? -secondStepDistance : secondStepDistance
        case .upRight: 
            newFile += secondStepDistance
            newRank += isBlack ? -secondStepDistance : secondStepDistance
        case .downLeft: 
            newFile -= secondStepDistance
            newRank += isBlack ? secondStepDistance : -secondStepDistance
        case .downRight: 
            newFile += secondStepDistance
            newRank += isBlack ? secondStepDistance : -secondStepDistance
        default: break
        }
        let newPos = ChessPosition3D(file: newFile, rank: newRank, z: z)
        print("[DEBUG] Final intended position: \(newPos.stringValue) (file: \(newFile), rank: \(newRank), z: \(z))")
        // Validate and execute the move
        if let chessGame = chessGame, let piece = chessGame.getPieceAtPosition(start) {
            if isValidMoveForPiece(piece, from: start, to: newPos, distance: distance) {
                // Actually move the piece
                _ = chessGame.tryMove(from: start, to: newPos)
                selectedPiecePosition = newPos
                updatePieceLists()
            }
        }
        // Reset state
        pending3DMovePieceType = nil
        pending3DMoveStart = nil
        pending3DMoveZ = nil
        pending3DMoveDistance = nil
        pending3DMoveFirstDirection = nil
        awaitingSecondDirection = false
        diagonalInstruction = ""
    }
    
    // Move the selected piece in the specified direction with player perspective
    func moveSelectedPieceWithPlayerPerspective(direction: MoveDirection, distance: Int = 1) {
        guard let currentPosition = selectedPiecePosition,
              let chessGame = chessGame,
              let piece = chessGame.getPieceAtPosition(currentPosition) else { 
            print("⚠️ ChessPieceController: Cannot move piece - missing required data")
            return 
        }
        
        // Apply player perspective remapping
        let mappedDirection = playerPerspectiveDirection(direction, for: piece.color)
        moveSelectedPiece(direction: mappedDirection, distance: distance)
    }

    // ... existing code ...
    func is3DPlanePathBlocked(from: ChessPosition3D, to: ChessPosition3D) -> Bool {
        // Only for moves where exactly two axes change and the third is constant
        let fileDiff = to.file - from.file
        let rankDiff = to.rank - from.rank
        let zDiff = to.z - from.z
        let steps = max(abs(fileDiff), abs(rankDiff), abs(zDiff))
        let dx = fileDiff == 0 ? 0 : fileDiff / abs(fileDiff)
        let dy = rankDiff == 0 ? 0 : rankDiff / abs(rankDiff)
        let dz = zDiff == 0 ? 0 : zDiff / abs(zDiff)
        // Only apply for plane-diagonal (XZ or YZ) moves
        let numNonZero = [fileDiff, rankDiff, zDiff].filter { $0 != 0 }.count
        let isPlaneDiagonal = numNonZero == 2 && !(abs(fileDiff) == abs(rankDiff) && abs(rankDiff) == abs(zDiff))
        print("🔍 is3DPlanePathBlocked: fileDiff=\(fileDiff), rankDiff=\(rankDiff), zDiff=\(zDiff), numNonZero=\(numNonZero), isPlaneDiagonal=\(isPlaneDiagonal)")
        if !isPlaneDiagonal { 
            print("🔍 is3DPlanePathBlocked: Not a plane-diagonal move, returning false")
            return false 
        } // Not a plane-diagonal, don't block
        for step in 1..<steps {
            let pos = ChessPosition3D(file: from.file + dx * step, rank: from.rank + dy * step, z: from.z + dz * step)
            if let chessGame = chessGame, chessGame.getPieceAtPosition(pos) != nil {
                print("🔍 is3DPlanePathBlocked: Blocked at \(pos.stringValue)")
                return true
            }
        }
        return false
    }

    // Update tryCustomMove to use is3DPlanePathBlocked for plane-diagonal moves
    func tryCustomMove(to toPosition: ChessPosition3D) {
        guard let from = selectedPiecePosition, let piece = chessGame?.getPieceAtPosition(from), let chessGame = chessGame else { return }
        print("🔍 tryCustomMove called: \(piece.color) \(piece.type) from \(from.stringValue) to \(toPosition.stringValue)")
        // Check bounds - allow 3D moves beyond traditional board boundaries
        // Support extended board (files 0-15 for extended pawns)
        let maxFile = 15
        guard toPosition.file >= 0 && toPosition.file <= maxFile && toPosition.z >= 0 && toPosition.z <= 7 else {
            print("⚠️ tryCustomMove: New position (\(toPosition.file), \(toPosition.rank), \(toPosition.z)) is outside board bounds")
            chessGame.showInvalidMoveMessage("Invalid Move")
            return
        }
        // Allow rank to go beyond 0-7 for 3D moves (pieces can "fly" over the board)
        if toPosition.rank < 0 || toPosition.rank > 7 {
            print("🔍 3D move: Piece moving beyond traditional board boundaries (rank: \(toPosition.rank))")
        }
        let fileDiff = abs(toPosition.file - from.file)
        let rankDiff = abs(toPosition.rank - from.rank)
        let zDiff = abs(toPosition.z - from.z)
        let distance = max(fileDiff, rankDiff, zDiff)
        if !isValidMoveForPiece(piece, from: from, to: toPosition, distance: distance) {
            print("⚠️ tryCustomMove: Invalid move for \(piece.type) from \(from.stringValue) to (\(toPosition.file), \(toPosition.rank), \(toPosition.z)) with distance \(distance)")
            chessGame.showInvalidMoveMessage("Invalid Move")
            return
        }
        // Use special path-blocking for plane-diagonal moves
        print("🔍 Checking if 3D plane path is blocked...")
        if is3DPlanePathBlocked(from: from, to: toPosition) {
            print("⚠️ tryCustomMove: Path blocked for plane-diagonal move from \(from.stringValue) to \(toPosition.stringValue)")
            chessGame.showInvalidMoveMessage("Invalid Move")
            return
        } else {
            print("✅ 3D plane path is clear")
        }
        // Check for blocking pieces at the destination
        if let targetPiece = chessGame.getPieceAtPosition(toPosition) {
            if targetPiece.color == piece.color {
                print("⚠️ tryCustomMove: Cannot move to position occupied by own piece")
                chessGame.showInvalidMoveMessage("Invalid Move")
                return
            }
        }
        // Try to move the piece using the chess engine
        print("🔍 About to call chessGame.tryMove from \(from.stringValue) to \(toPosition.stringValue)")
        let moveSuccess = chessGame.tryMove(from: from, to: toPosition)
        print("🎯 tryCustomMove: Move attempted, success: \(moveSuccess)")
        if !moveSuccess {
            print("❌ tryCustomMove: Chess engine rejected the move")
            chessGame.showInvalidMoveMessage("Invalid Move")
            
            // Check for checkmate if the king is in check and no valid moves are available
            if chessGame.chessBoard.isCheck(color: piece.color) {
                print("🔍 King is in check and move was rejected - checking for checkmate...")
                if chessGame.chessBoard.isCheckmate(color: piece.color) {
                    print("🎯 CHECKMATE DETECTED! \(piece.color.opposite.rawValue.capitalized) wins!")
                    // You could add UI notification here
                }
            }
        }
        if moveSuccess {
            selectedPiecePosition = toPosition
            if let newNode = chessGame.getPieceNode(at: toPosition) {
                selectedPiece = newNode
                highlightSelectedPiece()
            }
            addMoveToHistory(piece: piece, from: from, to: toPosition)
            clearMoveIndicators()
            updatePieceLists()
            
            // Force UI refresh to update turn indicator and piece selector
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
            
            // Rotate board for the new turn after a 2-second delay (same as normal moves)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                chessGame.rotateBoardForTurn()
            }
        }
    }
}

// ChessPieceController class ends here

// SwiftUI View for the piece controller
struct ChessPieceControllerView: View {
    @ObservedObject var controller: ChessPieceController
    @State private var showWhitePieces = true
    
    // Computed property to automatically show current player's pieces
    private var currentPlayerPieces: Bool {
        return controller.getCurrentTurn() == .white
    }
    @State private var moveUp = false
    @State private var moveDown = false
    @State private var moveLeft = false
    @State private var moveRight = false
    @State private var moveUpLeft = false
    @State private var moveUpRight = false
    @State private var moveDownLeft = false
    @State private var moveDownRight = false
    
    var body: some View {
        VStack {
            selectedPieceInfo
            movementControls
            pieceSelection
        }
        .padding()
        .frame(width: 290)
        .frame(maxHeight: .infinity)
        .background(.regularMaterial.opacity(0.2))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.02), lineWidth: 1)
        )
        .cornerRadius(12)
        .modifier(MoveUpModifier(controller: controller, moveUp: $moveUp))
        .modifier(MoveDownModifier(controller: controller, moveDown: $moveDown))
        .modifier(MoveLeftModifier(controller: controller, moveLeft: $moveLeft))
        .modifier(MoveRightModifier(controller: controller, moveRight: $moveRight))
        .modifier(MoveUpLeftModifier(controller: controller, moveUpLeft: $moveUpLeft))
        .modifier(MoveUpRightModifier(controller: controller, moveUpRight: $moveUpRight))
        .modifier(MoveDownLeftModifier(controller: controller, moveDownLeft: $moveDownLeft))
        .modifier(MoveDownRightModifier(controller: controller, moveDownRight: $moveDownRight))
        .modifier(MoveUpZModifier(controller: controller))
        .modifier(MoveDownZModifier(controller: controller))
        .modifier(MoveUpZLeftModifier(controller: controller))
        .modifier(MoveUpZRightModifier(controller: controller))
        .modifier(MoveDownZLeftModifier(controller: controller))
        .modifier(MoveDownZRightModifier(controller: controller))
        .modifier(MoveUpZBackLeftModifier(controller: controller))
        .modifier(MoveUpZBackRightModifier(controller: controller))
        .modifier(MoveDownZForwardLeftModifier(controller: controller))
        .modifier(MoveDownZForwardRightModifier(controller: controller))
    }
    
    private var selectedPieceInfo: some View {
        VStack(spacing: 8) {
            // Game mode selector

            
            // Current player indicator at the top
            // Text("Current Player: \(currentPlayerPieces ? "White" : "Black")")
            //     .font(.headline)
            //     .fontWeight(.bold)
            //     .padding()
            //     .frame(maxWidth: .infinity)
            //     .background(currentPlayerPieces ? Color.white.opacity(0.8) : Color.black.opacity(0.8))
            //     .foregroundColor(currentPlayerPieces ? .black : .white)
            //     .cornerRadius(8)
            
            // Selected piece box
           // Text(controller.selectedPieceName)
            //    .font(.subheadline)
           //     .fontWeight(.semibold)
           //     .foregroundColor(.primary)
           //     .padding(.horizontal)
           //     .padding(.vertical, 4)
          //      .background(controller.selectedPiecePosition != nil ? //Color.yellow.opacity(0.8) : Color.gray.opacity(0.3))
          //      .cornerRadius(6)
            
            // AI move display
            if let chessGame = controller.chessGame, chessGame.showAIMoveHighlight && !chessGame.lastAIMove.isEmpty {
                HStack {
                    Image(systemName: "robot")
                        .foregroundColor(.white)
                    Text(chessGame.lastAIMove)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(Color.black)
                .cornerRadius(6)
            }
            
            // Check warning (only show when a piece is selected)
            if controller.selectedPiecePosition != nil && controller.isKingInCheck() {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("CHECK! Your king is under attack!")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.2))
                .cornerRadius(6)
            }
            
            if controller.knightMode {
                HStack {
                    Image(systemName: "horse")
                        .foregroundColor(.orange)
                    Text("Knight Mode: Click two arrows for L-shape move")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.2))
                .cornerRadius(6)
            }
        }
    }
    
    private var movementControls: some View {
        VStack(spacing: 5) {
            Text(controller.knightMode ? "Knight Movement (2-step)" : "Movement Controls")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            // Castling buttons (only show when king is selected and not in check)
            if controller.isSelectedPieceKing() && !controller.isKingInCheck() {
                
                VStack(spacing: 4) {
                    Text("Castling")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Button(action: {
                            controller.performCastling(side: .kingside)
                        }) {
                            VStack(spacing: 2) {
                                HStack {
                                    Image(systemName: "arrow.right")
                                    Text("O-O")
                                }
                                .font(.caption)
                                Text("Kingside")
                                    .font(.caption2)
                            }
                            .foregroundColor(controller.canCastle(side: .kingside) ? .orange : .gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(!controller.canCastle(side: .kingside))
                        
                        Button(action: {
                            controller.performCastling(side: .queenside)
                        }) {
                            VStack(spacing: 2) {
                                HStack {
                                    Image(systemName: "arrow.left")
                                    Text("O-O-O")
                                }
                                .font(.caption)
                                Text("Queenside")
                                    .font(.caption2)
                            }
                            .foregroundColor(controller.canCastle(side: .queenside) ? .orange : .gray)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(!controller.canCastle(side: .queenside))
                    }
                }
                .padding(.horizontal, 8)
            }
            
            // Movement controls with distance selector on the left
            HStack(spacing: 16) {
                // Distance selector (vertical stack on the left)
                VStack(spacing: 2) {
                    Text("Distance:")
                        .font(.caption2)
                        .foregroundColor(.white)
                    
                    VStack(spacing: 2) {
                        ForEach((1...8).reversed(), id: \.self) { distance in
                            Button(action: {
                                controller.moveDistance = distance
                            }) {
                                Text("\(distance)")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .frame(width: 20, height: 20)
                                    .background(controller.moveDistance == distance ? Color.white : Color.clear)
                                    .foregroundColor(controller.moveDistance == distance ? .black : .white)
                                    .cornerRadius(4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 8)
                
                // Movement controls on the right
                VStack(spacing: 8) {
                    // 3D Diagonal movement controls with instructions
            VStack(spacing: 8) {
                // Instructions for 3D diagonal moves
                if let chessGame = controller.chessGame,
                   let selectedPos = controller.selectedPiecePosition,
                   let selectedPiece = chessGame.getPieceAtPosition(selectedPos),
                   (selectedPiece.type == .bishop || selectedPiece.type == .queen || selectedPiece.type == .knight) {
                    Text("3D Diagonal: Direct moves with Z component")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                }
                
                // 3D Diagonal buttons - reorganized to save vertical space
                HStack(spacing: 16) {
                    // Left column: Top two rows
                    VStack(spacing: 8) {
                        // Top row: up/forward + left/right
                        VStack(spacing: 4) {
            HStack(spacing: 8) {
                                Button(action: { controller.moveUpZLeft = true }) {
                                    Image(systemName: "arrow.up.left.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(controller.moveUpZLeft ? .green : .orange)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: { controller.moveUpZRight = true }) {
                                    Image(systemName: "arrow.up.right.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(controller.moveUpZRight ? .green : .orange)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        // Second row: down/back + left/right
                        VStack(spacing: 4) {
                            Text("3D Up")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            HStack(spacing: 8) {
                                Button(action: { controller.moveUpZBackLeft = true }) {
                                    Image(systemName: "arrow.down.left.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(controller.moveUpZBackLeft ? .green : .orange)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: { controller.moveUpZBackRight = true }) {
                    Image(systemName: "arrow.down.right.circle.fill")
                        .font(.title3)
                                        .foregroundColor(controller.moveUpZBackRight ? .green : .orange)
                }
                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    // Right column: Bottom two rows
                    VStack(spacing: 8) {
                        // Third row: up/forward + back (left/right) - grey fill
                        VStack(spacing: 4) {
                            HStack(spacing: 8) {
                                Button(action: { controller.moveDownZForwardLeft = true }) {
                                    Image(systemName: "arrow.up.left.circle")
                                        .font(.title3)
                                        .foregroundColor(controller.moveDownZForwardLeft ? .green : .orange)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: { controller.moveDownZForwardRight = true }) {
                                    Image(systemName: "arrow.up.right.circle")
                                        .font(.title3)
                                        .foregroundColor(controller.moveDownZForwardRight ? .green : .orange)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        // Fourth row: down/back + forward (left/right) - grey fill
                        VStack(spacing: 4) {
                            Text("3D Down")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            HStack(spacing: 8) {
                                Button(action: { controller.moveDownZLeft = true }) {
                                    Image(systemName: "arrow.down.left.circle")
                                        .font(.title3)
                                        .foregroundColor(controller.moveDownZLeft ? .green : .orange)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: { controller.moveDownZRight = true }) {
                                    Image(systemName: "arrow.down.right.circle")
                                        .font(.title3)
                                        .foregroundColor(controller.moveDownZRight ? .green : .orange)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                
                // Straight line movement controls for queens and bishops - moved below orange buttons
                if let chessGame = controller.chessGame,
                   let selectedPos = controller.selectedPiecePosition,
                   let selectedPiece = chessGame.getPieceAtPosition(selectedPos),
                   (selectedPiece.type == .bishop || selectedPiece.type == .queen || selectedPiece.type == .king) {
                    Text("Plane Diagonals: Forward/Back Up/Down and Left/Right Up/Down")
                        .font(.caption)
                        .foregroundColor(.purple)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.2))
                        .cornerRadius(4)
                    
                    // Plane diagonal movement buttons
                    VStack(spacing: 8) {
                        // YZ plane (up/down) - first row with "Up" label
                        VStack(spacing: 4) {
                           // Text("Up")
                            //    .font(.caption2)
                            //    .foregroundColor(.purple)
                            HStack(spacing: 8) {
                                Button(action: {
                                    // Up: YZ plane (ΔY = +distance, ΔZ = +distance, ΔX = 0)
                                    if let pos = controller.selectedPiecePosition {
                                        // Get effective distance (1 for kings, original distance for other pieces)
                                        let effectiveDistance = controller.getEffectiveDistance(for: pos)
                                        // Apply player perspective for black pieces (no board rotation perspective needed for Y-component)
                                        let rankOffset = controller.getCurrentTurn() == .black ? -effectiveDistance : effectiveDistance
                                        let newZ = pos.z + effectiveDistance
                                        
                                        // Check bounds before creating the position
                                        guard newZ >= 0 && newZ <= 7 else {
                                            print("🔍 Purple UP (filled) button: Move would be off board (z: \(newZ))")
                                            controller.chessGame?.showInvalidMoveMessage("Invalid Move")
                                            return
                                        }
                                        
                                        let to = ChessPosition3D(file: pos.file, rank: pos.rank + rankOffset, z: newZ)
                                        print("🔍 Purple UP button: Moving from \(pos.stringValue) to \(to.stringValue) (file: \(pos.file), rank: \(pos.rank + rankOffset), z: \(pos.z + effectiveDistance))")
                                        
                                        // Validate the move before attempting it
                                        if let piece = controller.chessGame?.getPieceAtPosition(pos) {
                                            if !controller.isValidMoveForPiece(piece, from: pos, to: to, distance: effectiveDistance) {
                                                print("🔍 Purple UP button: Invalid move for \(piece.type)")
                                                controller.chessGame?.showInvalidMoveMessage("Invalid Move")
                                                return
                                            }
                                        }
                                        
                                        controller.tryCustomMove(to: to)
                                    }
                                }) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.purple)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: {
                                    // Down: YZ plane (ΔY = -distance, ΔZ = +distance, ΔX = 0)
                                    if let pos = controller.selectedPiecePosition {
                                        // Get effective distance (1 for kings, original distance for other pieces)
                                        let effectiveDistance = controller.getEffectiveDistance(for: pos)
                                        // Apply player perspective for black pieces (no board rotation perspective needed for Y-component)
                                        let rankOffset = controller.getCurrentTurn() == .black ? effectiveDistance : -effectiveDistance
                                        let newZ = pos.z + effectiveDistance
                                        
                                        // Check bounds before creating the position
                                        guard newZ >= 0 && newZ <= 7 else {
                                            print("🔍 Purple DOWN (filled) button: Move would be off board (z: \(newZ))")
                                            controller.chessGame?.showInvalidMoveMessage("Invalid Move")
                                            return
                                        }
                                        
                                        let to = ChessPosition3D(file: pos.file, rank: pos.rank + rankOffset, z: newZ)
                                        
                                        // Validate the move before attempting it
                                        if let piece = controller.chessGame?.getPieceAtPosition(pos) {
                                            if !controller.isValidMoveForPiece(piece, from: pos, to: to, distance: effectiveDistance) {
                                                print("🔍 Purple DOWN (filled) button: Invalid move for \(piece.type)")
                                                controller.chessGame?.showInvalidMoveMessage("Invalid Move")
                                                return
                                            }
                                        }
                                        
                                        controller.tryCustomMove(to: to)
                                    }
                                }) {
                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.purple)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: {
                                    // Up/Forward: YZ plane (ΔY = +distance, ΔZ = -distance, ΔX = 0)
                                    if let pos = controller.selectedPiecePosition {
                                        // Get effective distance (1 for kings, original distance for other pieces)
                                        let effectiveDistance = controller.getEffectiveDistance(for: pos)
                                        // Apply player perspective for black pieces (no board rotation perspective needed for Y-component)
                                        let rankOffset = controller.getCurrentTurn() == .black ? -effectiveDistance : effectiveDistance
                                        let newZ = pos.z - effectiveDistance
                                        
                                        // Check bounds before creating the position
                                        guard newZ >= 0 && newZ <= 7 else {
                                            print("🔍 Purple UP (empty) button: Move would be off board (z: \(newZ))")
                                            controller.chessGame?.showInvalidMoveMessage("Invalid Move")
                                            return
                                        }
                                        
                                        let to = ChessPosition3D(file: pos.file, rank: pos.rank + rankOffset, z: newZ)
                                        
                                        // Validate the move before attempting it
                                        if let piece = controller.chessGame?.getPieceAtPosition(pos) {
                                            if !controller.isValidMoveForPiece(piece, from: pos, to: to, distance: effectiveDistance) {
                                                print("🔍 Purple UP (empty) button: Invalid move for \(piece.type)")
                                                controller.chessGame?.showInvalidMoveMessage("Invalid Move")
                                                return
                                            }
                                        }
                                        
                                        controller.tryCustomMove(to: to)
                                    }
                                }) {
                                    Image(systemName: "arrow.up.circle")
                                        .font(.title3)
                                        .foregroundColor(.purple)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: {
                                    // Down/Back: YZ plane (ΔY = -distance, ΔZ = -distance, ΔX = 0)
                                    if let pos = controller.selectedPiecePosition {
                                        // Get effective distance (1 for kings, original distance for other pieces)
                                        let effectiveDistance = controller.getEffectiveDistance(for: pos)
                                        // Apply player perspective for black pieces (no board rotation perspective needed for Y-component)
                                        let rankOffset = controller.getCurrentTurn() == .black ? effectiveDistance : -effectiveDistance
                                        let newZ = pos.z - effectiveDistance
                                        
                                        // Check bounds before creating the position
                                        guard newZ >= 0 && newZ <= 7 else {
                                            print("🔍 Purple Down/Back button: Move would be off board (z: \(newZ))")
                                            controller.chessGame?.showInvalidMoveMessage("Invalid Move")
                                            return
                                        }
                                        
                                        let to = ChessPosition3D(file: pos.file, rank: pos.rank + rankOffset, z: newZ)
                                        
                                        // Validate the move before attempting it
                                        if let piece = controller.chessGame?.getPieceAtPosition(pos) {
                                            if !controller.isValidMoveForPiece(piece, from: pos, to: to, distance: effectiveDistance) {
                                                print("🔍 Purple Down/Back button: Invalid move for \(piece.type)")
                                                controller.chessGame?.showInvalidMoveMessage("Invalid Move")
                                                return
                                            }
                                        }
                                        
                                        controller.tryCustomMove(to: to)
                                    }
                                }) {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.title3)
                                        .foregroundColor(.purple)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            // XZ plane (left/right) - second row with "Down" label
                            VStack(spacing: 4) {
                                Text("Up         Down")
                                    .font(.caption2)
                                    .foregroundColor(.purple)
                                HStack(spacing: 8) {
                                    Button(action: {
                                        // Left: XZ plane (ΔX = -distance, ΔZ = +distance, ΔY = 0)
                                        if let pos = controller.selectedPiecePosition {
                                            let effectiveDistance = controller.getEffectiveDistance(for: pos)
                                            let baseFileOffset = -effectiveDistance
                                            // Apply board rotation perspective
                                            let perspective = controller.applyBoardRotationPerspective(rankOffset: 0, fileOffset: baseFileOffset)
                                            let newFile = pos.file + perspective.file
                                            let newZ = pos.z + effectiveDistance
                                            
                                            // Check bounds before creating the position
                                            guard newFile >= 0 && newFile <= 7 && newZ >= 0 && newZ <= 7 else {
                                                print("🔍 Purple LEFT (filled) button: Move would be off board (file: \(newFile), z: \(newZ))")
                                                controller.chessGame?.showInvalidMoveMessage("Invalid Move")
                                                return
                                            }
                                            
                                            let to = ChessPosition3D(file: newFile, rank: pos.rank, z: newZ)
                                            
                                            // Validate the move before attempting it
                                            if let piece = controller.chessGame?.getPieceAtPosition(pos) {
                                                if !controller.isValidMoveForPiece(piece, from: pos, to: to, distance: effectiveDistance) {
                                                    print("🔍 Purple LEFT (filled) button: Invalid move for \(piece.type)")
                                                    controller.chessGame?.showInvalidMoveMessage("Invalid Move")
                                                    return
                                                }
                                            }
                                            
                                            controller.tryCustomMove(to: to)
                                        }
                                    }) {
                                        
                                        
                                        Image(systemName: "arrow.left.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.purple)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    Button(action: {
                                        // Right: XZ plane (ΔX = +distance, ΔZ = +distance, ΔY = 0)
                                        if let pos = controller.selectedPiecePosition {
                                            let effectiveDistance = controller.getEffectiveDistance(for: pos)
                                            let baseFileOffset = effectiveDistance
                                            // Apply board rotation perspective
                                            let perspective = controller.applyBoardRotationPerspective(rankOffset: 0, fileOffset: baseFileOffset)
                                            let newFile = pos.file + perspective.file
                                            let newZ = pos.z + effectiveDistance
                                            
                                            // Check bounds before creating the position
                                            guard newFile >= 0 && newFile <= 7 && newZ >= 0 && newZ <= 7 else {
                                                print("🔍 Purple RIGHT (filled) button: Move would be off board (file: \(newFile), z: \(newZ))")
                                                controller.chessGame?.showInvalidMoveMessage("Invalid Move")
                                                return
                                            }
                                            
                                            let to = ChessPosition3D(file: newFile, rank: pos.rank, z: newZ)
                                            
                                            // Validate the move before attempting it
                                            if let piece = controller.chessGame?.getPieceAtPosition(pos) {
                                                if !controller.isValidMoveForPiece(piece, from: pos, to: to, distance: effectiveDistance) {
                                                    print("🔍 Purple RIGHT (filled) button: Invalid move for \(piece.type)")
                                                    controller.chessGame?.showInvalidMoveMessage("Invalid Move")
                                                    return
                                                }
                                            }
                                            
                                            controller.tryCustomMove(to: to)
                                        }
                                    }) {
                                        Image(systemName: "arrow.right.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.purple)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    Button(action: {
                                        // Down/Left: XZ plane (ΔX = -distance, ΔZ = -distance, ΔY = 0)
                                        if let pos = controller.selectedPiecePosition {
                                            let effectiveDistance = controller.getEffectiveDistance(for: pos)
                                            let baseFileOffset = -effectiveDistance
                                            // Apply board rotation perspective
                                            let perspective = controller.applyBoardRotationPerspective(rankOffset: 0, fileOffset: baseFileOffset)
                                            let newFile = pos.file + perspective.file
                                            let newZ = pos.z - effectiveDistance
                                            
                                            // Check bounds before creating the position
                                            guard newFile >= 0 && newFile <= 7 && newZ >= 0 && newZ <= 7 else {
                                                print("🔍 Purple LEFT (empty) button: Move would be off board (file: \(newFile), z: \(newZ))")
                                                controller.chessGame?.showInvalidMoveMessage("Invalid Move")
                                                return
                                            }
                                            
                                            let to = ChessPosition3D(file: newFile, rank: pos.rank, z: newZ)
                                            
                                            // Validate the move before attempting it
                                            if let piece = controller.chessGame?.getPieceAtPosition(pos) {
                                                if !controller.isValidMoveForPiece(piece, from: pos, to: to, distance: effectiveDistance) {
                                                    print("🔍 Purple LEFT (empty) button: Invalid move for \(piece.type)")
                                                    controller.chessGame?.showInvalidMoveMessage("Invalid Move")
                                                    return
                                                }
                                            }
                                            
                                            controller.tryCustomMove(to: to)
                                        }
                                    }) {
                                        Image(systemName: "arrow.left.circle")
                                            .font(.title3)
                                            .foregroundColor(.purple)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    Button(action: {
                                        // Down/Right: XZ plane (ΔX = +distance, ΔZ = -distance, ΔY = 0)
                                        if let pos = controller.selectedPiecePosition {
                                            let effectiveDistance = controller.getEffectiveDistance(for: pos)
                                            let baseFileOffset = effectiveDistance
                                            // Apply board rotation perspective
                                            let perspective = controller.applyBoardRotationPerspective(rankOffset: 0, fileOffset: baseFileOffset)
                                            let newFile = pos.file + perspective.file
                                            let newZ = pos.z - effectiveDistance
                                            
                                            // Check bounds before creating the position
                                            guard newFile >= 0 && newFile <= 7 && newZ >= 0 && newZ <= 7 else {
                                                print("🔍 Purple RIGHT (empty) button: Move would be off board (file: \(newFile), z: \(newZ))")
                                                controller.chessGame?.showInvalidMoveMessage("Invalid Move")
                                                return
                                            }
                                            
                                            let to = ChessPosition3D(file: newFile, rank: pos.rank, z: newZ)
                                            
                                            // Validate the move before attempting it
                                            if let piece = controller.chessGame?.getPieceAtPosition(pos) {
                                                if !controller.isValidMoveForPiece(piece, from: pos, to: to, distance: effectiveDistance) {
                                                    print("🔍 Purple RIGHT (empty) button: Invalid move for \(piece.type)")
                                                    controller.chessGame?.showInvalidMoveMessage("Invalid Move")
                                                    return
                                                }
                                            }
                                            
                                            controller.tryCustomMove(to: to)
                                        }
                                    }) {
                                        Image(systemName: "arrow.right.circle")
                                            .font(.title3)
                                            .foregroundColor(.purple)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
     //
                // Z movement controls (below diagonals)
                HStack(spacing: 8) {
                    Button(action: {
                        if controller.knightMode {
                            print("🔘 Z UP button clicked, knightMode: \(controller.knightMode)")
                            print("🔘 Calling moveKnight with direction: .upZ")
                            controller.moveKnight(direction: .upZ)
                        } else {
                            controller.moveUpZ = true
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                            .foregroundColor(controller.moveUpZ ? .green : .blue)
                }
                .buttonStyle(PlainButtonStyle())
                
                    Button(action: {
                        if controller.knightMode {
                            print("🔘 Z DOWN button clicked, knightMode: \(controller.knightMode)")
                            print("🔘 Calling moveKnight with direction: .downZ")
                            controller.moveKnight(direction: .downZ)
                        } else {
                            controller.moveDownZ = true
                        }
                    }) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.title2)
                            .foregroundColor(controller.moveDownZ ? .green : .blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 8)
                
                // 2D Movement Controls (color-coded) - Use knight logic when in knight mode
                VStack(spacing: 4) {
                    // Top row with diagonal buttons (pointing down) - YELLOW
                    HStack(spacing: 8) {
                        Button(action: {
                            if controller.knightMode {
                                controller.moveKnight(direction: .downRight)
                            } else {
                                moveDownRight.toggle()
                            }
                        }) {
                            Image(systemName: "arrow.down.right.circle.fill")
                                .font(.title3)
                                .foregroundColor(moveDownRight ? .green : .yellow)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            if controller.knightMode {
                                controller.moveKnight(direction: .down)
                            } else {
                                moveDown.toggle()
                            }
                        }) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.title2)
                                .foregroundColor(moveDown ? .green : .green)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            if controller.knightMode {
                                controller.moveKnight(direction: .downLeft)
                            } else {
                                moveDownLeft.toggle()
                            }
                        }) {
                    Image(systemName: "arrow.down.left.circle.fill")
                        .font(.title3)
                                .foregroundColor(moveDownLeft ? .green : .yellow)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
                    // Middle row with left, center, right - RED for left/right, GREEN for center
            HStack(spacing: 8) {
                        Button(action: {
                            if controller.knightMode {
                                controller.moveKnight(direction: .right)
                            } else {
                                moveRight.toggle()
                            }
                        }) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                                .foregroundColor(moveRight ? .green : .red)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Center space
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 20, height: 15)
                
                        Button(action: {
                            print("🔘 LEFT button clicked, knightMode: \(controller.knightMode)")
                            if controller.knightMode {
                                print("🔘 Calling moveKnight with direction: .left")
                                controller.moveKnight(direction: .left)
                            } else {
                                print("🔘 Calling moveLeft.toggle()")
                                moveLeft.toggle()
                            }
                        }) {
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.title2)
                                .foregroundColor(moveLeft ? .green : .red)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
                    // Bottom row with diagonal buttons (pointing up) - YELLOW
            HStack(spacing: 8) {
                        Button(action: {
                            if controller.knightMode {
                                controller.moveKnight(direction: .upRight)
                            } else {
                                moveUpRight.toggle()
                            }
                        }) {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.title3)
                                .foregroundColor(moveUpRight ? .green : .yellow)
                }
                .buttonStyle(PlainButtonStyle())
                
                        Button(action: {
                            print("🔘 UP button clicked, knightMode: \(controller.knightMode)")
                            controller.isMoveButtonClicked = true
                            print("🔘 Set isMoveButtonClicked = true")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                controller.isMoveButtonClicked = false
                                print("🔘 Reset isMoveButtonClicked = false")
                            }
                            if controller.knightMode {
                                print("🔘 Calling moveKnight with direction: .up")
                                controller.moveKnight(direction: .up)
                            } else {
                                print("🔘 Calling moveUp.toggle()")
                                moveUp.toggle()
                            }
                        }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                                .foregroundColor(moveUp ? .green : .green)
                }
                .buttonStyle(PlainButtonStyle())
                
                        Button(action: {
                            if controller.knightMode {
                                controller.moveKnight(direction: .upLeft)
                            } else {
                                moveUpLeft.toggle()
                            }
                        }) {
                    Image(systemName: "arrow.up.left.circle.fill")
                        .font(.title3)
                                .foregroundColor(moveUpLeft ? .green : .yellow)
                }
                .buttonStyle(PlainButtonStyle())
            }
                }
                .padding(.horizontal, 8)
                }
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
        }
    }
    
    var pieceSelection: some View {
        VStack {
            // Selected piece info below the movement arrows, above the piece list
            if let pos = controller.selectedPiecePosition,
               let chessGame = controller.chessGame,
               let piece = chessGame.getPieceAtPosition(pos) {
                Text("\(piece.color.rawValue.capitalized) \(piece.type.rawValue.capitalized) \(pos.stringValue)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.7))
                    .cornerRadius(6)
            }
            // Piece list
            ScrollView {
            HStack(alignment: .top, spacing: 5) {
                // Pawns column
                VStack(alignment: .leading, spacing: 3) {
                    Text("Pawns")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    ForEach(getPawns(for: currentPlayerPieces), id: \.position.stringValue) { piece in
                        CompactPieceRowView(piece: piece, controller: controller)
                    }
                }
                // Other pieces column
                VStack(alignment: .leading, spacing: 3) {
                    Text("Pieces")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    ForEach(getOtherPieces(for: currentPlayerPieces), id: \.position.stringValue) { piece in
                        CompactPieceRowView(piece: piece, controller: controller)
                    }
                }
            }
            .padding(.horizontal, 1)
            .padding(.vertical, 4)
            }
            .cornerRadius(8)
        }
    }
    
    func getPawns(for whitePieces: Bool) -> [ChessPiece3D] {
        let pieces = whitePieces ? controller.whitePieces : controller.blackPieces
        return pieces.filter { $0.type == .pawn }.sorted { $0.position.file < $1.position.file }
    }
    
    func getOtherPieces(for whitePieces: Bool) -> [ChessPiece3D] {
        let pieces = whitePieces ? controller.whitePieces : controller.blackPieces
        let otherPieces = pieces.filter { $0.type != .pawn }
        
        // Sort in board order: Rook, Knight, Bishop, Queen, King, Bishop, Knight, Rook
        return otherPieces.sorted { piece1, piece2 in
            let order1 = getPieceOrder(piece1)
            let order2 = getPieceOrder(piece2)
            return order1 < order2
        }
    }
    
    func getPieceOrder(_ piece: ChessPiece3D) -> Int {
        switch piece.type {
        case .rook: return piece.position.file == 0 ? 0 : 7
        case .knight: return piece.position.file == 1 ? 1 : 6
        case .bishop: return piece.position.file == 2 ? 2 : 5
        case .queen: return 3
        case .king: return 4
        case .pawn: return piece.position.file + 8
        }
    }
    
    // MARK: - Move Modifiers
    
    struct MoveUpModifier: ViewModifier {
        let controller: ChessPieceController
        @Binding var moveUp: Bool
        
        func body(content: Content) -> some View {
            content
                .onChange(of: moveUp) { _, _ in
                    if moveUp {
                        controller.moveSelectedPiece(direction: .up, distance: controller.moveDistance)
                        moveUp = false
                    }
                }
        }
    }
    
    struct MoveDownModifier: ViewModifier {
        let controller: ChessPieceController
        @Binding var moveDown: Bool
        
        func body(content: Content) -> some View {
            content
                .onChange(of: moveDown) { _, _ in
                    if moveDown {
                        controller.moveSelectedPiece(direction: .down, distance: controller.moveDistance)
                        moveDown = false
                    }
                }
        }
    }
    
    struct MoveLeftModifier: ViewModifier {
        let controller: ChessPieceController
        @Binding var moveLeft: Bool
        
        func body(content: Content) -> some View {
            content
                .onChange(of: moveLeft) { _, _ in
                    if moveLeft {
                        controller.moveSelectedPiece(direction: .left, distance: controller.moveDistance)
                        moveLeft = false
                    }
                }
        }
    }
    
    struct MoveRightModifier: ViewModifier {
        let controller: ChessPieceController
        @Binding var moveRight: Bool
        
        func body(content: Content) -> some View {
            content
                .onChange(of: moveRight) { _, _ in
                    if moveRight {
                        controller.moveSelectedPiece(direction: .right, distance: controller.moveDistance)
                        moveRight = false
                    }
                }
        }
    }
    
    struct MoveUpLeftModifier: ViewModifier {
        let controller: ChessPieceController
        @Binding var moveUpLeft: Bool
        
        func body(content: Content) -> some View {
            content
                .onChange(of: moveUpLeft) { _, _ in
                    if moveUpLeft {
                        controller.moveSelectedPiece(direction: .upLeft, distance: controller.moveDistance)
                        moveUpLeft = false
                    }
                }
        }
    }
    
    struct MoveUpRightModifier: ViewModifier {
        let controller: ChessPieceController
        @Binding var moveUpRight: Bool
        
        func body(content: Content) -> some View {
            content
                .onChange(of: moveUpRight) { _, _ in
                    if moveUpRight {
                        controller.moveSelectedPiece(direction: .upRight, distance: controller.moveDistance)
                        moveUpRight = false
                    }
                }
        }
    }
    
    struct MoveDownLeftModifier: ViewModifier {
        let controller: ChessPieceController
        @Binding var moveDownLeft: Bool
        
        func body(content: Content) -> some View {
            content
                .onChange(of: moveDownLeft) { _, _ in
                    if moveDownLeft {
                        controller.moveSelectedPiece(direction: .downLeft, distance: controller.moveDistance)
                        moveDownLeft = false
                    }
                }
        }
    }
    
    struct MoveDownRightModifier: ViewModifier {
        let controller: ChessPieceController
        @Binding var moveDownRight: Bool
        
        func body(content: Content) -> some View {
            content
                .onChange(of: moveDownRight) { _, _ in
                    if moveDownRight {
                        controller.moveSelectedPiece(direction: .downRight, distance: controller.moveDistance)
                        moveDownRight = false
                    }
                }
        }
    }
    
    struct MoveUpZModifier: ViewModifier {
        let controller: ChessPieceController
        
        func body(content: Content) -> some View {
            content
                .onChange(of: controller.moveUpZ) { _, _ in
                    if controller.moveUpZ {
                        controller.moveSelectedPieceZ(direction: .up, distance: controller.moveDistance)
                        controller.moveUpZ = false
                    }
                }
        }
    }
    
    struct MoveDownZModifier: ViewModifier {
        let controller: ChessPieceController
        
        func body(content: Content) -> some View {
            content
                .onChange(of: controller.moveDownZ) { _, _ in
                    if controller.moveDownZ {
                        controller.moveSelectedPieceZ(direction: .down, distance: controller.moveDistance)
                        controller.moveDownZ = false
                    }
                }
        }
    }
    
    struct MoveUpZLeftModifier: ViewModifier {
        let controller: ChessPieceController
        
        func body(content: Content) -> some View {
            content
                .onChange(of: controller.moveUpZLeft) { _, _ in
                    if controller.moveUpZLeft {
                        let targetPosition = controller.calculateCustomMove(direction: .upZLeft, distance: controller.moveDistance)
                        if let position = targetPosition {
                            controller.tryCustomMove(to: position)
                        }
                        controller.moveUpZLeft = false
                    }
                }
        }
    }
    
    struct MoveUpZRightModifier: ViewModifier {
        let controller: ChessPieceController
        
        func body(content: Content) -> some View {
            content
                .onChange(of: controller.moveUpZRight) { _, _ in
                    if controller.moveUpZRight {
                        let targetPosition = controller.calculateCustomMove(direction: .upZRight, distance: controller.moveDistance)
                        if let position = targetPosition {
                            controller.tryCustomMove(to: position)
                        }
                        controller.moveUpZRight = false
                    }
                }
        }
    }
    
    struct MoveDownZLeftModifier: ViewModifier {
        let controller: ChessPieceController
        
        func body(content: Content) -> some View {
            content
                .onChange(of: controller.moveDownZLeft) { _, _ in
                    if controller.moveDownZLeft {
                        let targetPosition = controller.calculateCustomMove(direction: .downZLeft, distance: controller.moveDistance)
                        if let position = targetPosition {
                            controller.tryCustomMove(to: position)
                        }
                        controller.moveDownZLeft = false
                    }
                }
        }
    }
    
    struct MoveDownZRightModifier: ViewModifier {
        let controller: ChessPieceController
        
        func body(content: Content) -> some View {
            content
                .onChange(of: controller.moveDownZRight) { _, _ in
                    if controller.moveDownZRight {
                        let targetPosition = controller.calculateCustomMove(direction: .downZRight, distance: controller.moveDistance)
                        if let position = targetPosition {
                            controller.tryCustomMove(to: position)
                        }
                        controller.moveDownZRight = false
                    }
                }
        }
    }
    
    struct MoveUpZBackLeftModifier: ViewModifier {
        let controller: ChessPieceController
        
        func body(content: Content) -> some View {
            content
                .onChange(of: controller.moveUpZBackLeft) { _, _ in
                    if controller.moveUpZBackLeft {
                        let targetPosition = controller.calculateCustomMove(direction: .upZBackLeft, distance: controller.moveDistance)
                        if let position = targetPosition {
                            controller.tryCustomMove(to: position)
                        }
                        controller.moveUpZBackLeft = false
                    }
                }
        }
    }
    
    struct MoveUpZBackRightModifier: ViewModifier {
        let controller: ChessPieceController
        
        func body(content: Content) -> some View {
            content
                .onChange(of: controller.moveUpZBackRight) { _, _ in
                    if controller.moveUpZBackRight {
                        let targetPosition = controller.calculateCustomMove(direction: .upZBackRight, distance: controller.moveDistance)
                        if let position = targetPosition {
                            controller.tryCustomMove(to: position)
                        }
                        controller.moveUpZBackRight = false
                    }
                }
        }
    }
    
    struct MoveDownZForwardLeftModifier: ViewModifier {
        let controller: ChessPieceController
        
        func body(content: Content) -> some View {
            content
                .onChange(of: controller.moveDownZForwardLeft) { _, _ in
                    if controller.moveDownZForwardLeft {
                        let targetPosition = controller.calculateCustomMove(direction: .downZForwardLeft, distance: controller.moveDistance)
                        if let position = targetPosition {
                            controller.tryCustomMove(to: position)
                        }
                        controller.moveDownZForwardLeft = false
                    }
                }
        }
    }
    
    struct MoveDownZForwardRightModifier: ViewModifier {
        let controller: ChessPieceController
        
        func body(content: Content) -> some View {
            content
                .onChange(of: controller.moveDownZForwardRight) { _, _ in
                    if controller.moveDownZForwardRight {
                        let targetPosition = controller.calculateCustomMove(direction: .downZForwardRight, distance: controller.moveDistance)
                        if let position = targetPosition {
                            controller.tryCustomMove(to: position)
                        }
                        controller.moveDownZForwardRight = false
                    }
                }
        }
    }
    
// Helper view for displaying a chess piece row
struct PieceRowView: View {
        let piece: ChessPiece3D
    let controller: ChessPieceController
    
    var body: some View {
        Button(action: {
            controller.selectPieceFromList(piece)
        }) {
            HStack {
                Text(pieceSymbol)
                    .font(.title2)
                    .frame(width: 40)
                
                Text(controller.getPieceName(piece))
                
                Spacer()
                
                Text(piece.position.stringValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Computed property for piece symbol
        var pieceSymbol: String {
        let whiteSymbols: [PieceType: String] = [
            .king: "♔", .queen: "♕", .rook: "♖", 
            .bishop: "♗", .knight: "♘", .pawn: "♙"
        ]
        
        let blackSymbols: [PieceType: String] = [
            .king: "♚", .queen: "♛", .rook: "♜", 
            .bishop: "♝", .knight: "♞", .pawn: "♟"
        ]
        
        return piece.color == .white ? 
            whiteSymbols[piece.type] ?? "?" : 
            blackSymbols[piece.type] ?? "?"
    }
}

// Compact piece row view for the new layout
struct CompactPieceRowView: View {
        let piece: ChessPiece3D
    let controller: ChessPieceController
    
    var body: some View {
        Button(action: {
            controller.selectPieceFromList(piece)
        }) {
            HStack(spacing: 6) {
                Text(pieceSymbol)
                    .font(.title3)
                    .frame(width: 12)
                    .foregroundColor(.white)
            
               
                Text(controller.getPieceName(piece))
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(piece.position.stringValue)
                    .font(.caption2)
                    .foregroundColor(.white)
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(controller.selectedPiecePosition == piece.position ? Color.yellow.opacity(0.4) : (piece.color == .white ? Color.red.opacity(0.2) : Color.blue.opacity(0.2)))
            .cornerRadius(4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Computed property for piece symbol
        var pieceSymbol: String {
        let whiteSymbols: [PieceType: String] = [
            .king: "♔", .queen: "♕", .rook: "♖", 
            .bishop: "♗", .knight: "♘", .pawn: "♙"
        ]
        
        let blackSymbols: [PieceType: String] = [
            .king: "♚", .queen: "♛", .rook: "♜", 
            .bishop: "♝", .knight: "♞", .pawn: "♟"
        ]
        
        return piece.color == .white ? 
            whiteSymbols[piece.type] ?? "?" : 
            blackSymbols[piece.type] ?? "?"
    }
    }
}

// ChessPieceController class ends here
