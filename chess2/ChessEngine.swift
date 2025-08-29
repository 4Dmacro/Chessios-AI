//
//  ChessEngine.swift
//  chess1
//
//  Created by Gareth Costa on 16/7/2025.
//
//
//  ChessEngine.swift
//  chess2
//
//  Created by Gareth Costa on 15/7/2025.
//

import Foundation
import SceneKit
import ObjectiveC

// MARK: - Chess Piece Types
enum PieceType: String, CaseIterable {
    case pawn = "pawn"
    case rook = "rook"
    case knight = "knight"
    case bishop = "bishop"
    case queen = "queen"
    case king = "king"
}

// MARK: - Chess Colors
enum PieceColor: String, CaseIterable {
    case white = "white"
    case black = "black"
    
    var opposite: PieceColor {
        return self == .white ? .black : .white
    }
}

// MARK: - Castling Side
enum CastlingSide {
    case kingside
    case queenside
}

// MARK: - Chess Position
struct ChessPosition: Equatable, Hashable {
    let file: Int // 0-7 (a-h)
    let rank: Int // 0-7 (1-8)
    
    init(file: Int, rank: Int) {
        self.file = max(0, min(7, file))
        self.rank = max(0, min(7, rank))
    }
    
    // Implement hash function for Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(file)
        hasher.combine(rank)
    }
    
    init?(fromString string: String) {
        guard string.count == 2 else { return nil }
        let chars = Array(string.lowercased())
        guard let fileChar = chars.first, let rankChar = chars.last else { return nil }
        
        let file = Int(fileChar.asciiValue! - Character("a").asciiValue!)
        let rank = Int(rankChar.asciiValue! - Character("1").asciiValue!)
        
        // Support standard board (files 0-7 for a-h)
        let maxFile = 7
        guard file >= 0 && file <= maxFile && rank >= 0 && rank <= 7 else { return nil }
        self.file = file
        self.rank = rank
    }
    
    var stringValue: String {
        let fileChar = Character(UnicodeScalar(Character("a").asciiValue! + UInt8(file)))
        let rankChar = Character(UnicodeScalar(Character("1").asciiValue! + UInt8(rank)))
        return String(fileChar) + String(rankChar)
    }
    
    func offset(file: Int, rank: Int) -> ChessPosition? {
        let newFile = self.file + file
        let newRank = self.rank + rank
        // Support standard board (files 0-7 for a-h)
        let maxFile = 7
        guard newFile >= 0 && newFile <= maxFile && newRank >= 0 && newRank <= 7 else { return nil }
        return ChessPosition(file: newFile, rank: newRank)
    }
}

// MARK: - Chess Piece
struct ChessPiece: Equatable {
    let type: PieceType
    let color: PieceColor
    let position: ChessPosition
    let hasMoved: Bool
    
    init(type: PieceType, color: PieceColor, position: ChessPosition, hasMoved: Bool = false) {
        self.type = type
        self.color = color
        self.position = position
        self.hasMoved = hasMoved
    }
    
    func moved(to newPosition: ChessPosition) -> ChessPiece {
        return ChessPiece(type: type, color: color, position: newPosition, hasMoved: true)
    }
}

// MARK: - Chess Move
struct ChessMove: Equatable {
    let piece: ChessPiece
    let from: ChessPosition
    let to: ChessPosition
    let capturedPiece: ChessPiece?
    let isEnPassant: Bool
    let isCastling: Bool
    let promotionType: PieceType?
    
    init(piece: ChessPiece, from: ChessPosition, to: ChessPosition, capturedPiece: ChessPiece? = nil, isEnPassant: Bool = false, isCastling: Bool = false, promotionType: PieceType? = nil) {
        self.piece = piece
        self.from = from
        self.to = to
        self.capturedPiece = capturedPiece
        self.isEnPassant = isEnPassant
        self.isCastling = isCastling
        self.promotionType = promotionType
    }
}

// MARK: - Chess Position 3D
struct ChessPosition3D: Equatable, Hashable {
    let file: Int // 0-15 (a-p for extended board)
    let rank: Int // 0-7 (1-8)
    let z: Int    // 0-7 (i-viii, bottom to top)
    
    init(file: Int, rank: Int, z: Int) {
        self.file = max(0, min(7, file)) // Files are always 0-7 (a-h)
        self.rank = max(0, min(7, rank))
        self.z = max(0, min(7, z))
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(file)
        hasher.combine(rank)
        hasher.combine(z)
    }
    
    var stringValue: String {
        // Files should always be a-h (0-7), regardless of extended board
        let actualFile = file % 8 // Map files 8-15 back to 0-7
        let fileChar = Character(UnicodeScalar(Character("a").asciiValue! + UInt8(actualFile)))
        let rankChar = Character(UnicodeScalar(Character("1").asciiValue! + UInt8(rank)))
        
        // Z-axis determines the prefix using Roman numerals starting with "i" for first board
        let prefixes = ["i", "ii", "iii", "iv", "v", "vi", "vii", "viii"]
        let prefix = z < prefixes.count ? prefixes[z] : "invalid"
        
        // Add space between prefix and position for clarity
        return "\(prefix) \(fileChar)\(rankChar)"
    }
    
    func offset(file: Int, rank: Int, z: Int) -> ChessPosition3D? {
        let newFile = self.file + file
        let newRank = self.rank + rank
        let newZ = self.z + z
        guard newFile >= 0 && newFile <= 7 && newRank >= 0 && newRank <= 7 && newZ >= 0 && newZ <= 7 else { return nil }
        return ChessPosition3D(file: newFile, rank: newRank, z: newZ)
    }
}

// MARK: - Chess Piece (3D)
struct ChessPiece3D: Equatable {
    let type: PieceType
    let color: PieceColor
    let position: ChessPosition3D
    let hasMoved: Bool
    
    init(type: PieceType, color: PieceColor, position: ChessPosition3D, hasMoved: Bool = false) {
        self.type = type
        self.color = color
        self.position = position
        self.hasMoved = hasMoved
    }
    
    func moved(to newPosition: ChessPosition3D) -> ChessPiece3D {
        return ChessPiece3D(type: type, color: color, position: newPosition, hasMoved: true)
    }
}

// MARK: - Chess Move (3D)
struct ChessMove3D: Equatable {
    let piece: ChessPiece3D
    let from: ChessPosition3D
    let to: ChessPosition3D
    let capturedPiece: ChessPiece3D?
    let isEnPassant: Bool
    let isCastling: Bool
    let promotionType: PieceType?
    
    init(piece: ChessPiece3D, from: ChessPosition3D, to: ChessPosition3D, capturedPiece: ChessPiece3D? = nil, isEnPassant: Bool = false, isCastling: Bool = false, promotionType: PieceType? = nil) {
        self.piece = piece
        self.from = from
        self.to = to
        self.capturedPiece = capturedPiece
        self.isEnPassant = isEnPassant
        self.isCastling = isCastling
        self.promotionType = promotionType
    }
}

// MARK: - Chess Board (3D)
class ChessBoard3D {
    var pieces: [ChessPosition3D: ChessPiece3D] = [:]
    private var moveHistory: [ChessMove3D] = []
    var currentTurn: PieceColor = .white
    var enPassantTarget: ChessPosition3D?
    
    init() {
        pieces = [:]
        moveHistory = []
        currentTurn = .white
        enPassantTarget = nil
    }
    
    // MARK: - Board Setup
    func setupInitialPosition() {
        pieces.removeAll()
        // print("🔍 setupInitialPosition: Starting with empty board")
        
        // Place pieces on z=0 (bottom board) as in standard chess
        for file in 0..<8 {
            let whitePawnPos = ChessPosition3D(file: file, rank: 1, z: 0)
            let blackPawnPos = ChessPosition3D(file: file, rank: 6, z: 0)
            safeSetPiece(ChessPiece3D(type: .pawn, color: .white, position: whitePawnPos), at: whitePawnPos)
            safeSetPiece(ChessPiece3D(type: .pawn, color: .black, position: blackPawnPos), at: blackPawnPos)
        }
        // print("🔍 setupInitialPosition: Added 16 standard pawns (8 white + 8 black) at z=0")
        
        let backRank: [PieceType] = [.rook, .knight, .bishop, .queen, .king, .bishop, .knight, .rook]
        for file in 0..<8 {
            let whitePos = ChessPosition3D(file: file, rank: 0, z: 0)
            let blackPos = ChessPosition3D(file: file, rank: 7, z: 0)
            safeSetPiece(ChessPiece3D(type: backRank[file], color: .white, position: whitePos), at: whitePos)
            safeSetPiece(ChessPiece3D(type: backRank[file], color: .black, position: blackPos), at: blackPos)
        }
        // print("🔍 setupInitialPosition: Added 16 standard pieces (8 white + 8 black) at z=0")
        // print("🔍 setupInitialPosition: Total pieces after standard board: \(pieces.count)")
        
        // Add extended pawns on z=1 (middle board)
        // WRpawn9-16 -> iia1 to iih1 (file 0-7, rank 0, z=1)
        // WRpawn17-24 -> iia2 to iih2 (file 0-7, rank 1, z=1)
        // BBpawn9-16 -> iia8 to iih8 (file 0-7, rank 7, z=1)
        // BBpawn17-24 -> iia7 to iih7 (file 0-7, rank 6, z=1)
        // print("🔍 Setting up extended pawns...")
        for file in 0..<8 {
            // White pawns on extended board
            let whitePawn1Pos = ChessPosition3D(file: file, rank: 0, z: 1) // WRpawn9-16
            let whitePawn2Pos = ChessPosition3D(file: file, rank: 1, z: 1) // WRpawn17-24
            safeSetPiece(ChessPiece3D(type: .pawn, color: .white, position: whitePawn1Pos), at: whitePawn1Pos)
            safeSetPiece(ChessPiece3D(type: .pawn, color: .white, position: whitePawn2Pos), at: whitePawn2Pos)
            
            // Black pawns on extended board
            let blackPawn1Pos = ChessPosition3D(file: file, rank: 7, z: 1) // BBpawn9-16
            let blackPawn2Pos = ChessPosition3D(file: file, rank: 6, z: 1) // BBpawn17-24
            safeSetPiece(ChessPiece3D(type: .pawn, color: .black, position: blackPawn1Pos), at: blackPawn1Pos)
            safeSetPiece(ChessPiece3D(type: .pawn, color: .black, position: blackPawn2Pos), at: blackPawn2Pos)
            
            // print("🔍 Created extended pawns at file \(file):")
            // print("  - White pawn 1: \(whitePawn1Pos.stringValue) (file=\(whitePawn1Pos.file), rank=\(whitePawn1Pos.rank), z=\(whitePawn1Pos.z))")
            // print("  - White pawn 2: \(whitePawn2Pos.stringValue) (file=\(whitePawn2Pos.file), rank=\(whitePawn2Pos.rank), z=\(whitePawn2Pos.z))")
            // print("  - Black pawn 1: \(blackPawn1Pos.stringValue) (file=\(blackPawn1Pos.file), rank=\(blackPawn1Pos.rank), z=\(blackPawn1Pos.z))")
            // print("  - Black pawn 2: \(blackPawn2Pos.stringValue) (file=\(blackPawn2Pos.file), rank=\(blackPawn2Pos.rank), z=\(blackPawn2Pos.z))")
        }
        // print("🔍 Total pieces after extended pawns: \(pieces.count)")
        
        // Debug: Count pieces by color and type
        let whitePieces = pieces.values.filter { $0.color == .white }
        let blackPieces = pieces.values.filter { $0.color == .black }
        let whitePawns = whitePieces.filter { $0.type == .pawn }
        let blackPawns = blackPieces.filter { $0.type == .pawn }
        let whiteOthers = whitePieces.filter { $0.type != .pawn }
        let blackOthers = blackPieces.filter { $0.type != .pawn }
        
        // print("🔍 setupInitialPosition: Final piece count breakdown:")
        // print("  - White pieces: \(whitePieces.count) total (\(whitePawns.count) pawns + \(whiteOthers.count) others)")
        // print("  - Black pieces: \(blackPieces.count) total (\(blackPawns.count) pawns + \(blackOthers.count) others)")
        // print("  - Total pieces: \(pieces.count)")
        
        // Verify we have the expected counts
        let expectedWhitePawns = 24 // 8 standard + 16 extended
        let expectedBlackPawns = 24 // 8 standard + 16 extended
        let expectedWhiteOthers = 8 // 2 rooks + 2 knights + 2 bishops + 1 queen + 1 king
        let expectedBlackOthers = 8 // 2 rooks + 2 knights + 2 bishops + 1 queen + 1 king
        
        if whitePawns.count != expectedWhitePawns {
            print("⚠️ WARNING: Expected \(expectedWhitePawns) white pawns, got \(whitePawns.count)")
        }
        if blackPawns.count != expectedBlackPawns {
            print("⚠️ WARNING: Expected \(expectedBlackPawns) black pawns, got \(blackPawns.count)")
        }
        if whiteOthers.count != expectedWhiteOthers {
            print("⚠️ WARNING: Expected \(expectedWhiteOthers) white other pieces, got \(whiteOthers.count)")
        }
        if blackOthers.count != expectedBlackOthers {
            print("⚠️ WARNING: Expected \(expectedBlackOthers) black other pieces, got \(blackOthers.count)")
        }
    }
    
    // MARK: - Board State
    
    func validateBoardState() -> Bool {
        // First check if pieces is actually a dictionary
        if Mirror(reflecting: pieces).displayStyle != .dictionary {
            print("❌ CRITICAL ERROR: pieces is not a dictionary in validateBoardState!")
            print("❌ CRITICAL ERROR: pieces type: \(type(of: pieces))")
            print("❌ CRITICAL ERROR: pieces value: \(pieces)")
            return false
        }
        
        // Check if we have a reasonable number of pieces
        let pieceCount = pieces.count
        if pieceCount < 0 || pieceCount > 100 {
            print("❌ CRITICAL ERROR: Invalid piece count: \(pieceCount)")
            return false
        }
        
        // Check if all pieces have valid positions
        for (position, _) in pieces {
            if position.file < 0 || position.file > 7 || position.rank < 0 || position.rank > 7 || position.z < 0 || position.z > 7 {
                print("❌ CRITICAL ERROR: Invalid position in pieces: \(position)")
                return false
            }
        }
        
        return true
    }
    
    func repairBoardState() {
        print("🔧 Attempting to repair board state...")
        pieces = [:]
        setupInitialPosition()
        print("🔧 Board state repaired")
    }
    
    private func validateDictionaryStructure() -> Bool {
        // Check if pieces is actually a dictionary
        if Mirror(reflecting: pieces).displayStyle != .dictionary {
            return false
        }
        
        // Check if count is reasonable
        let count = pieces.count
        if count < 0 || count > 100 {
            return false
        }
        
        // Test if the dictionary actually works by trying to access it safely
        // This will catch cases where pieces is a Date or other non-dictionary object
        let isEmpty = pieces.isEmpty
        if count > 0 && isEmpty {
            return false
        }
        
        // Test keys access
        let keys = pieces.keys
        if keys.count != count {
            return false
        }
        
        // Test values access
        let _ = pieces.values
        
        return true
    }
    
    func getPiece(at position: ChessPosition3D) -> ChessPiece3D? {
        // Use a safe wrapper to access the dictionary
        return safeDictionaryAccess {
            return pieces[position]
        }
    }
    
    // Safe dictionary access wrapper
    private func safeDictionaryAccess<T>(_ operation: () -> T?) -> T? {
        // First check if pieces is actually a dictionary
        if Mirror(reflecting: pieces).displayStyle != .dictionary {
            print("❌ CRITICAL ERROR: pieces is not a dictionary!")
            print("❌ CRITICAL ERROR: pieces type: \(type(of: pieces))")
            print("❌ CRITICAL ERROR: pieces value: \(pieces)")
            pieces = [:]
            return nil
        }
        
        // Check count bounds
        let pieceCount = pieces.count
        if pieceCount < 0 || pieceCount > 100 {
            print("❌ CRITICAL ERROR: Invalid pieces count: \(pieceCount)")
            pieces = [:]
            return nil
        }
        
        // Test dictionary integrity step by step
        // Test 1: Check if isEmpty works
        let isEmpty = pieces.isEmpty
        if pieceCount > 0 && isEmpty {
            print("❌ CRITICAL ERROR: pieces.count > 0 but isEmpty = true")
            pieces = [:]
            return nil
        }
        
        // Test 2: Try to access keys
        let keys = pieces.keys
        if keys.count != pieceCount {
            print("❌ CRITICAL ERROR: keys.count (\(keys.count)) != pieces.count (\(pieceCount))")
            pieces = [:]
            return nil
        }
        
        // Test 3: Try to access values
        let _ = pieces.values
        
        // If we get here, the dictionary seems valid, try the operation
        return operation()
    }
    
    // Safe set piece method
    private func safeSetPiece(_ piece: ChessPiece3D, at position: ChessPosition3D) {
        _ = safeDictionaryAccess {
            pieces[position] = piece
            return true
        }
    }
    
    // Update promoted piece type after user choice
    func updatePromotedPiece(at position: ChessPosition3D, to pieceType: PieceType) {
        _ = safeDictionaryAccess {
            if let currentPiece = pieces[position] {
                let updatedPiece = ChessPiece3D(type: pieceType, color: currentPiece.color, position: position, hasMoved: true)
                pieces[position] = updatedPiece
                print("♕ Chess engine: Updated promoted piece at \(position.stringValue) to \(pieceType.rawValue)")
                return true
            } else {
                print("❌ Chess engine: No piece found at \(position.stringValue) to update promotion")
                return false
            }
        }
    }
    
    // Safe get piece method (alternative to getPiece for internal use)
    private func safeGetPiece(at position: ChessPosition3D) -> ChessPiece3D? {
        return safeDictionaryAccess {
            return pieces[position]
        }
    }
    
    // Safe check if position is empty
    private func safeIsEmpty(at position: ChessPosition3D) -> Bool {
        return safeDictionaryAccess {
            return pieces[position] == nil
        } ?? true // Default to empty if dictionary is corrupted
    }
    
    // Safe check if position has piece
    private func safeHasPiece(at position: ChessPosition3D) -> Bool {
        return safeDictionaryAccess {
            return pieces[position] != nil
        } ?? false // Default to no piece if dictionary is corrupted
    }
    
    func getAllPieces() -> [ChessPiece3D] {
        return safeDictionaryAccess {
            return Array(pieces.values)
        } ?? []
    }
    
    func getPieces(of color: PieceColor) -> [ChessPiece3D] {
        return safeDictionaryAccess {
            return pieces.values.filter { $0.color == color }
        } ?? []
    }
    
    func getCurrentTurn() -> PieceColor {
        return currentTurn
    }
    
    // MARK: - Move Validation
    func isValidMove(from: ChessPosition3D, to: ChessPosition3D) -> Bool {
        guard let piece = getPiece(at: from) else { return false }
        guard piece.color == currentTurn else { return false }
        
        // Check if destination is empty or contains opponent piece
        if let targetPiece = getPiece(at: to) {
            if targetPiece.color == piece.color {
                return false // Can't capture own piece
            }
        }
        
        // Check if this move would leave the king in check
        if wouldMoveLeaveKingInCheck(from: from, to: to) {
            return false
        }
        
        // For pawns, add specific validation to prevent vertical captures
        if piece.type == .pawn {
            let fileDiff = abs(to.file - from.file)
            let rankDiff = abs(to.rank - from.rank)
            let zDiff = abs(to.z - from.z)
            
            // Prevent pure vertical captures (only Z changes) when there's a piece to capture
            if fileDiff == 0 && rankDiff == 0 && zDiff > 0 {
                if let targetPiece = getPiece(at: to) {
                    print("🔍 ChessEngine: Blocking pure vertical pawn capture")
                    return false
                }
                // Allow vertical moves to empty squares
                print("🔍 ChessEngine: Allowing pure vertical pawn move to empty square")
            }
        }
        
        // For detailed move validation, rely on the controller's isValidMoveForPiece function
        // This function only does basic validation - the controller handles piece-specific rules
        return true
    }
    
    // Check if a move would leave the king in check
    private func wouldMoveLeaveKingInCheck(from: ChessPosition3D, to: ChessPosition3D) -> Bool {
        guard let piece = getPiece(at: from) else { return false }
        
        // Temporarily make the move
        let originalPiece = safeGetPiece(at: to)
        let originalFromPiece = safeGetPiece(at: from)
        
        // Remove captured piece if any
        if safeGetPiece(at: to) != nil {
            _ = safeDictionaryAccess {
                pieces.removeValue(forKey: to)
                return true
            }
        }
        
        // Move the piece
        safeSetPiece(piece.moved(to: to), at: to)
        _ = safeDictionaryAccess {
            pieces.removeValue(forKey: from)
            return true
        }
        
        // Check if king is in check after the move (use suppressDebug to prevent infinite loop)
        let kingInCheck = isCheck(color: piece.color, suppressDebug: true)
        
        // Restore the board state - be more careful about cleanup
        _ = safeDictionaryAccess {
            pieces.removeValue(forKey: to) // Remove the moved piece
            return true
        }
        
        // Restore original pieces
        if let originalFrom = originalFromPiece {
            safeSetPiece(originalFrom, at: from)
        } else {
            // If there was no piece at from position, remove any piece that might be there
            _ = safeDictionaryAccess {
                pieces.removeValue(forKey: from)
                return true
            }
        }
        if let original = originalPiece {
            safeSetPiece(original, at: to)
        } else {
            // If there was no piece at to position, remove any piece that might be there
            _ = safeDictionaryAccess {
                pieces.removeValue(forKey: to)
                return true
            }
        }
        
        // Debug output for king moves
        if piece.type == .king {
            print("🔍 wouldMoveLeaveKingInCheck: King move from \(from.stringValue) to \(to.stringValue) would leave king in check: \(kingInCheck)")
        }
        
        return kingInCheck
    }
    
    func getValidMoves(for piece: ChessPiece3D) -> [ChessMove3D] {
        var validMoves: [ChessMove3D] = []
        
        switch piece.type {
        case .pawn:
            validMoves = generatePawnMoves(for: piece)
            print("🔍 Generated \(validMoves.count) moves for \(piece.color) pawn at \(piece.position.stringValue)")
            for move in validMoves {
                print("🔍 Move: \(move.from.stringValue) -> \(move.to.stringValue) (captured: \(move.capturedPiece?.type.rawValue ?? "none"))")
            }
        case .rook:
            validMoves = generateRookMoves(for: piece)
        case .knight:
            validMoves = generateKnightMoves(for: piece)
        case .bishop:
            validMoves = generateBishopMoves(for: piece)
        case .queen:
            validMoves = generateQueenMoves(for: piece)
        case .king:
            validMoves = generateKingMoves(for: piece)
        }
        
        // Filter out moves that would leave the king in check
        return validMoves.filter { !wouldMoveLeaveKingInCheck(from: $0.from, to: $0.to) }
    }
    
    // MARK: - Piece-Specific Move Generation
    
    private func generatePawnMoves(for piece: ChessPiece3D) -> [ChessMove3D] {
        var moves: [ChessMove3D] = []
        let direction = piece.color == .white ? 1 : -1
        let startRank = piece.color == .white ? 1 : 6
        // Only allow double Z move from z=0 for now
        // Forward move (rank) - only allow forward movement
        if let forwardPos = piece.position.offset(file: 0, rank: direction, z: 0), safeIsEmpty(at: forwardPos) {
            // Double-check that this is actually forward
            let rankDiff = forwardPos.rank - piece.position.rank
            if (piece.color == .white && rankDiff > 0) || (piece.color == .black && rankDiff < 0) {
                moves.append(ChessMove3D(piece: piece, from: piece.position, to: forwardPos, capturedPiece: nil))
                // Double move from starting position
                if piece.position.rank == startRank && piece.position.z == 0 {
                    if let doublePos = piece.position.offset(file: 0, rank: 2 * direction, z: 0), safeIsEmpty(at: doublePos) {
                        let doubleRankDiff = doublePos.rank - piece.position.rank
                        if (piece.color == .white && doubleRankDiff > 0) || (piece.color == .black && doubleRankDiff < 0) {
                            moves.append(ChessMove3D(piece: piece, from: piece.position, to: doublePos, capturedPiece: nil))
                        }
                    }
                }
            }
        }
        
        // Debug: Check if this is the problematic move
        if piece.position.stringValue.contains("b2") {
            print("🔍 Pawn move generation for \(piece.position.stringValue):")
            print("🔍 Direction: \(direction), startRank: \(startRank)")
            print("🔍 Generated moves:")
            for move in moves {
                print("  - \(move.from.stringValue) -> \(move.to.stringValue)")
            }
        }
        // Upward move (z) - only allow forward Z movement for pawns
        if let upPos = piece.position.offset(file: 0, rank: 0, z: 1), safeIsEmpty(at: upPos) {
            // Only allow forward Z movement (higher Z values for white, lower for black)
            let zDiff = upPos.z - piece.position.z
            if (piece.color == .white && zDiff > 0) || (piece.color == .black && zDiff < 0) {
                moves.append(ChessMove3D(piece: piece, from: piece.position, to: upPos, capturedPiece: nil))
                // Double upward move from starting position (allow from any z level)
                if piece.position.rank == startRank {
                    if let doubleUp = piece.position.offset(file: 0, rank: 0, z: 2), safeIsEmpty(at: doubleUp) {
                        let doubleZDiff = doubleUp.z - piece.position.z
                        if (piece.color == .white && doubleZDiff > 0) || (piece.color == .black && doubleZDiff < 0) {
                            moves.append(ChessMove3D(piece: piece, from: piece.position, to: doubleUp, capturedPiece: nil))
                        }
                    }
                }
            }
        }
        // 2D Diagonal captures (traditional chess) - only 1 square
        for fileOffset in [-1, 1] {
            let rankOffset = direction * 1
            if let diagPos = piece.position.offset(file: fileOffset, rank: rankOffset, z: 0), let target = safeGetPiece(at: diagPos), target.color != piece.color {
                moves.append(ChessMove3D(piece: piece, from: piece.position, to: diagPos, capturedPiece: target))
            }
        }
        
        // 3D Diagonal captures (orange controls) - must include forward movement and file changes
        for fileOffset in [-1, 1] {
            for rankOffset in [direction] { // Only forward direction
                for zOffset in [-1, 0, 1] {
                    if fileOffset == 0 { continue } // Must have file change
                    if rankOffset == 0 { continue } // Must have forward movement
                    if abs(fileOffset) + abs(rankOffset) + abs(zOffset) <= 2 { // Distance 1 or 2 moves
                        if let diagPos = piece.position.offset(file: fileOffset, rank: rankOffset, z: zOffset), let target = safeGetPiece(at: diagPos), target.color != piece.color {
                            moves.append(ChessMove3D(piece: piece, from: piece.position, to: diagPos, capturedPiece: target))
                        }
                    }
                }
            }
        }
        

        
        // En passant logic for horizontal moves only (2D chess rules)
        print("🔍 Current en passant target: \(enPassantTarget?.stringValue ?? "none")")
        if let enPassantTarget = enPassantTarget {
            print("🔍 En passant check: target at \(enPassantTarget.stringValue)")
            // Check if this pawn can capture en passant
            let fileDiff = abs(piece.position.file - enPassantTarget.file)
            let rankDiff = abs(piece.position.rank - enPassantTarget.rank)
            let zDiff = abs(piece.position.z - enPassantTarget.z)
            
            print("🔍 En passant check: pawn at \(piece.position.stringValue), fileDiff=\(fileDiff), rankDiff=\(rankDiff), zDiff=\(zDiff)")
            
            // En passant is only possible for horizontal moves (same rank, adjacent files, same z)
            if rankDiff == 0 && fileDiff == 1 && zDiff == 0 {
                // Calculate the capture position (same rank as the en passant target)
                let capturePos = ChessPosition3D(file: enPassantTarget.file, rank: enPassantTarget.rank, z: enPassantTarget.z)
                
                print("🔍 En passant check: capture position would be \(capturePos.stringValue)")
                
                // Check if the capture position is valid (support extended board)
                let maxFile = 15
                if capturePos.file >= 0 && capturePos.file <= maxFile && capturePos.rank >= 0 && capturePos.rank <= 7 {
                    // Check if there's an opponent pawn at the en passant target
                    if let targetPawn = safeGetPiece(at: enPassantTarget), targetPawn.type == .pawn && targetPawn.color != piece.color {
                        print("🔍 En passant: adding capture move to \(capturePos.stringValue)")
                        moves.append(ChessMove3D(piece: piece, from: piece.position, to: capturePos, capturedPiece: targetPawn))
                    } else {
                        print("🔍 En passant: no opponent pawn at target")
                    }
                } else {
                    print("🔍 En passant: capture position outside board")
                }
            } else {
                print("🔍 En passant: conditions not met (rankDiff=\(rankDiff), fileDiff=\(fileDiff), zDiff=\(zDiff))")
            }
        } else {
            print("🔍 En passant: no target set")
        }
        
        // Final safety check: filter out any backward moves that might have slipped through
        moves = moves.filter { move in
            let rankDiff = move.to.rank - move.from.rank
            let isForward = (piece.color == .white && rankDiff > 0) || (piece.color == .black && rankDiff < 0)
            if !isForward && rankDiff != 0 {
                print("🔍 Filtering out backward pawn move: \(move.from.stringValue) -> \(move.to.stringValue)")
            }
            return isForward || rankDiff == 0
        }
        
        return moves
    }
    
    // 3D Rook moves: straight lines in X, Y, or Z
    private func generateRookMoves(for piece: ChessPiece3D) -> [ChessMove3D] {
        var moves: [ChessMove3D] = []
        let directions = [
            (1, 0, 0), (-1, 0, 0), // X
            (0, 1, 0), (0, -1, 0), // Y
            (0, 0, 1), (0, 0, -1)  // Z
        ]
        for (df, dr, dz) in directions {
            var step = 1
            while true {
                guard let target = piece.position.offset(file: df * step, rank: dr * step, z: dz * step) else { break }
                if let targetPiece = getPiece(at: target) {
                    if targetPiece.color != piece.color {
                        moves.append(ChessMove3D(piece: piece, from: piece.position, to: target, capturedPiece: targetPiece))
                    }
                    break
                } else {
                    moves.append(ChessMove3D(piece: piece, from: piece.position, to: target, capturedPiece: nil))
                }
                step += 1
            }
        }
        return moves
    }

    // 3D Bishop moves: all diagonals (2D and 3D)
    private func generateBishopMoves(for piece: ChessPiece3D) -> [ChessMove3D] {
        print("🔍 generateBishopMoves called for \(piece.color) \(piece.type.rawValue) at \(piece.position.stringValue)")
        var moves: [ChessMove3D] = []
        
        // Generate moves in all diagonal directions
        let directions = [
            // 2D diagonals (file + rank)
            (1, 1, 0), (1, -1, 0), (-1, 1, 0), (-1, -1, 0),
            // 3D diagonals (file + z)
            (1, 0, 1), (1, 0, -1), (-1, 0, 1), (-1, 0, -1),
            // 3D diagonals (rank + z)
            (0, 1, 1), (0, 1, -1), (0, -1, 1), (0, -1, -1),
            // 3D diagonals (file + rank + z)
            (1, 1, 1), (1, 1, -1), (1, -1, 1), (1, -1, -1),
            (-1, 1, 1), (-1, 1, -1), (-1, -1, 1), (-1, -1, -1)
        ]
        
        for (df, dr, dz) in directions {
            var step = 1
            while true {
                guard let target = piece.position.offset(file: df * step, rank: dr * step, z: dz * step) else { break }
                
                if let targetPiece = getPiece(at: target) {
                    if targetPiece.color != piece.color {
                        moves.append(ChessMove3D(piece: piece, from: piece.position, to: target, capturedPiece: targetPiece))
                    }
                    break
                } else {
                    moves.append(ChessMove3D(piece: piece, from: piece.position, to: target, capturedPiece: nil))
                }
                step += 1
            }
        }
        
        print("🔍 Bishop moves generated: \(moves.count) moves")
        for move in moves {
            print("  - \(move.from.stringValue) -> \(move.to.stringValue)")
        }
        
        return moves
    }
    
    // 3D Queen moves: combine rook and bishop
    private func generateQueenMoves(for piece: ChessPiece3D) -> [ChessMove3D] {
        return generateRookMoves(for: piece) + generateBishopMoves(for: piece)
    }

    // 3D Knight moves: all permutations of (±2,±1,0)
    private func generateKnightMoves(for piece: ChessPiece3D) -> [ChessMove3D] {
        var moves: [ChessMove3D] = []
        let steps = [
            (2, 1, 0), (2, 0, 1), (1, 2, 0), (0, 2, 1), (1, 0, 2), (0, 1, 2)
        ]
        let signs = [-1, 1]
        for (a, b, c) in steps {
            for sa in signs {
                for sb in signs {
                    for sc in signs {
                        let df = a * sa
                        let dr = b * sb
                        let dz = c * sc
                        if let target = piece.position.offset(file: df, rank: dr, z: dz) {
                            if let targetPiece = getPiece(at: target) {
                                if targetPiece.color != piece.color {
                                    moves.append(ChessMove3D(piece: piece, from: piece.position, to: target, capturedPiece: targetPiece))
                                }
                            } else {
                                moves.append(ChessMove3D(piece: piece, from: piece.position, to: target, capturedPiece: nil))
                            }
                        }
                    }
                }
            }
        }
        return moves
    }
    
    private func generateKingMoves(for piece: ChessPiece3D) -> [ChessMove3D] {
        var moves: [ChessMove3D] = []
        
        // Regular king moves (one square in any direction)
        for fileOffset in -1...1 {
            for rankOffset in -1...1 {
                for zOffset in -1...1 { // King moves in 3D
                    if fileOffset == 0 && rankOffset == 0 && zOffset == 0 { continue }
                
                    if let targetPos = piece.position.offset(file: fileOffset, rank: rankOffset, z: zOffset) {
                    if let targetPiece = getPiece(at: targetPos) {
                        if targetPiece.color != piece.color {
                                moves.append(ChessMove3D(piece: piece, from: piece.position, to: targetPos, capturedPiece: targetPiece))
                        }
                    } else {
                            moves.append(ChessMove3D(piece: piece, from: piece.position, to: targetPos))
                        }
                    }
                }
            }
        }
        
        return moves
    }
    
    private func generateSlidingMoves(for piece: ChessPiece3D, directions: [(Int, Int)]) -> [ChessMove3D] {
        var moves: [ChessMove3D] = []
        
        for (fileOffset, rankOffset) in directions {
            var currentFile = piece.position.file + fileOffset
            var currentRank = piece.position.rank + rankOffset
            var currentZ = piece.position.z // Keep z constant for sliding
            
            // Support extended board (files 0-15 for extended pawns)
        let maxFile = 15
        while currentFile >= 0 && currentFile <= maxFile && currentRank >= 0 && currentRank <= 7 && currentZ >= 0 && currentZ <= 7 {
                let targetPos = ChessPosition3D(file: currentFile, rank: currentRank, z: currentZ)
                
                if let targetPiece = getPiece(at: targetPos) {
                    if targetPiece.color != piece.color {
                        moves.append(ChessMove3D(piece: piece, from: piece.position, to: targetPos, capturedPiece: targetPiece))
                    }
                    break // Stop sliding when we hit a piece
                } else {
                    moves.append(ChessMove3D(piece: piece, from: piece.position, to: targetPos))
                }
                
                currentFile += fileOffset
                currentRank += rankOffset
                currentZ += 0 // No change in z for sliding
            }
        }
        
        return moves
    }
    
    // MARK: - Move Execution
    func makeMove(_ move: ChessMove3D, changeTurn: Bool = true) -> Bool {
        print("🔍 makeMove called: \(move.piece.color) \(move.piece.type) from \(move.from.stringValue) to \(move.to.stringValue)")
        guard isValidMove(from: move.from, to: move.to) else { return false }
        
        // Remove captured piece
        if let capturedPiece = move.capturedPiece {
            print("🔍 Captured piece: \(capturedPiece.color) \(capturedPiece.type) at \(capturedPiece.position.stringValue)")
            pieces.removeValue(forKey: capturedPiece.position)
            
            // Handle en passant capture - remove the captured pawn from its original position
            if move.piece.type == .pawn && capturedPiece.type == .pawn {
                let rankDiff = abs(move.to.rank - move.from.rank)
                let fileDiff = abs(move.to.file - move.from.file)
                let zDiff = abs(move.to.z - move.from.z)
                
                print("🔍 En passant capture check: rankDiff=\(rankDiff), fileDiff=\(fileDiff), zDiff=\(zDiff)")
                print("🔍 En passant capture check: destination has piece: \(pieces[move.to] != nil)")
                
                // Check if this is an en passant capture (diagonal move)
                if rankDiff == 1 && fileDiff == 1 && zDiff == 0 {
                    // The captured pawn should be at the en passant target position
                    if let enPassantTarget = enPassantTarget {
                        print("🔍 En passant capture: target at \(enPassantTarget.stringValue)")
                        if let targetPawn = safeGetPiece(at: enPassantTarget), targetPawn.type == .pawn {
                            pieces.removeValue(forKey: enPassantTarget)
                            print("🎯 En passant capture: removed pawn at \(enPassantTarget.stringValue)")
                        } else {
                            print("🔍 En passant capture: no pawn at target position")
                        }
                    } else {
                        print("🔍 En passant capture: no en passant target set")
                    }
                }
            }
        }
        
        // Move piece
        var movedPiece = move.piece.moved(to: move.to)
                // Auto-promotion: if pawn reaches last rank on the SAME board (same Z-level) by moving forward, promote to queen
        // RESTRICTION: Only allow promotion on level i (z = 0)
        if movedPiece.type == .pawn && (movedPiece.position.rank == 0 || movedPiece.position.rank == 7) && move.to.z == move.from.z && move.to.z == 0 {
            // Only promote if the pawn moved forward (rank changed), not horizontally (file changed)
            let rankDiff = abs(move.to.rank - move.from.rank)
            let fileDiff = abs(move.to.file - move.from.file)

            if rankDiff > 0 && fileDiff == 0 {
                // Pawn moved forward to the last rank on level i - promote temporarily to queen
                // The 3D manager will update this with the actual chosen piece type
                print("♕ Pawn promotion at \(movedPiece.position.stringValue) on level i! Temporarily promoting to queen (will be updated by user choice).")
                movedPiece = ChessPiece3D(type: .queen, color: movedPiece.color, position: movedPiece.position, hasMoved: true)
            } else {
                print("🔍 Pawn at last rank but moved horizontally (fileDiff=\(fileDiff), rankDiff=\(rankDiff)) - no promotion")
            }
        } else if movedPiece.type == .pawn && (movedPiece.position.rank == 0 || movedPiece.position.rank == 7) && move.to.z == move.from.z && move.to.z != 0 {
            let levelName = move.to.z == 1 ? "ii" : move.to.z == 2 ? "iii" : move.to.z == 3 ? "iv" : move.to.z == 4 ? "v" : move.to.z == 5 ? "vi" : move.to.z == 6 ? "vii" : "viii"
            print("🚫 Pawn promotion blocked on level \(levelName) (z=\(move.to.z)) - promotion only allowed on level i")
        }
        safeSetPiece(movedPiece, at: move.to)
        _ = safeDictionaryAccess {
            pieces.removeValue(forKey: move.from)
            return true
        }
        
        // Handle en passant target tracking
        // Clear previous en passant target
        enPassantTarget = nil
        
        // Set new en passant target if a pawn made a two-square move
        if movedPiece.type == .pawn {
            let rankDiff = abs(move.to.rank - move.from.rank)
            let fileDiff = abs(move.to.file - move.from.file)
            let zDiff = abs(move.to.z - move.from.z)
            
            print("🔍 En passant check: pawn move from \(move.from.stringValue) to \(move.to.stringValue)")
            print("🔍 En passant check: rankDiff=\(rankDiff), fileDiff=\(fileDiff), zDiff=\(zDiff)")
            
            // Check if this was a two-square move (horizontal only for en passant)
            if rankDiff == 2 && fileDiff == 0 && zDiff == 0 {
                // Calculate the position that was "passed over" for en passant
                let passedRank = move.from.rank + (move.to.rank - move.from.rank) / 2
                let passedPos = ChessPosition3D(file: move.to.file, rank: passedRank, z: move.to.z)
                enPassantTarget = passedPos
                print("🎯 En passant target set at \(passedPos.stringValue)")
            } else {
                print("🔍 En passant target not set - not a two-square horizontal move")
            }
        }
        
        // Add to move history
        moveHistory.append(move)
        
        // Switch turns (only if changeTurn is true)
        if changeTurn {
        currentTurn = currentTurn.opposite
        }
        
        // Check for checkmate after the move
        if isCheckmate(color: currentTurn) {
            print("♔ CHECKMATE! \(currentTurn.opposite.rawValue.capitalized) wins!")
        } else if isCheck(color: currentTurn) {
            print("♔ \(currentTurn.rawValue.capitalized) is in check!")
        }
        
        return true
    }
    
    // MARK: - Move Undo
    func undoLastMove() -> Bool {
        guard let lastMove = moveHistory.last else {
            print("⚠️ No moves to undo")
            return false
        }
        
        print("🔄 Undoing move: \(lastMove.from.stringValue) -> \(lastMove.to.stringValue)")
        
        // Remove the moved piece from its current position
        _ = safeDictionaryAccess {
            pieces.removeValue(forKey: lastMove.to)
            return true
        }
        
        // Restore the piece to its original position
        let restoredPiece = ChessPiece3D(type: lastMove.piece.type, color: lastMove.piece.color, position: lastMove.from, hasMoved: lastMove.piece.hasMoved)
        safeSetPiece(restoredPiece, at: lastMove.from)
        
        // Restore captured piece if there was one
        if let capturedPiece = lastMove.capturedPiece {
            safeSetPiece(capturedPiece, at: capturedPiece.position)
            print("🔄 Restored captured piece: \(capturedPiece.color) \(capturedPiece.type)")
        }
        
        // Remove from move history
        moveHistory.removeLast()
        
        // Restore en passant target from previous move if available
        if moveHistory.count > 0 {
            let previousMove = moveHistory[moveHistory.count - 1]
            if previousMove.piece.type == .pawn {
                let rankDiff = abs(previousMove.to.rank - previousMove.from.rank)
                let fileDiff = abs(previousMove.to.file - previousMove.from.file)
                let zDiff = abs(previousMove.to.z - previousMove.from.z)
                
                // Check if the previous move was a two-square pawn move
                if rankDiff == 2 && fileDiff == 0 && zDiff == 0 {
                    let passedRank = previousMove.from.rank + (previousMove.to.rank - previousMove.from.rank) / 2
                    let passedPos = ChessPosition3D(file: previousMove.to.file, rank: passedRank, z: previousMove.to.z)
                    enPassantTarget = passedPos
                    print("🔄 Restored en passant target at \(passedPos.stringValue)")
                } else {
                    enPassantTarget = nil
                }
            } else {
                enPassantTarget = nil
            }
        } else {
            enPassantTarget = nil
        }
        
        // Switch turn back
        currentTurn = currentTurn.opposite
        
        print("✅ Move undone successfully")
        return true
    }
    
    // MARK: - Game State
    func getGameState() -> String {
        // Only return "Loading..." if we don't have both kings (actual loading issue)
        // Don't check piece count < 64 as pieces get captured during gameplay
        let whiteKing = pieces.values.first(where: { $0.type == .king && $0.color == .white })
        let blackKing = pieces.values.first(where: { $0.type == .king && $0.color == .black })
        if whiteKing == nil || blackKing == nil {
            return "Loading..."
        }
        
        // Check for checkmate first
        if isCheckmate(color: currentTurn) {
            let winner = currentTurn.opposite
            return "Checkmate! \(winner.rawValue.capitalized) wins!"
        }
        
        // Check for check
        if isCheck(color: currentTurn) {
            return "\(currentTurn.rawValue.capitalized) is in check!"
        }
        
        return "\(currentTurn.rawValue.capitalized)'s turn"
    }
    
    func resetGame() {
        setupInitialPosition()
        moveHistory.removeAll()
        currentTurn = .white
        enPassantTarget = nil
    }
    
    // MARK: - Game State Methods
    func isCheck(color: PieceColor, suppressDebug: Bool = false) -> Bool {
        // Find the king of the specified color
        guard let king = pieces.values.first(where: { $0.type == .king && $0.color == color }) else {
            return false
        }
        
        // Check if any opponent piece can attack the king
        let opponentColor = color.opposite
        let opponentPieces = pieces.values.filter { $0.color == opponentColor }
        
        if !suppressDebug {
            print("🔍 isCheck: Checking \(opponentPieces.count) opponent pieces for attacks on \(color.rawValue) king at \(king.position.stringValue)")
        }
        
        for opponentPiece in opponentPieces {
            if canPieceAttackPosition(piece: opponentPiece, targetPosition: king.position) {
                if !suppressDebug {
                    print("♔ \(color.rawValue) king at \(king.position.stringValue) is in check by \(opponentPiece.color) \(opponentPiece.type) at \(opponentPiece.position.stringValue)")
                }
                return true
            }
        }
        
        if !suppressDebug {
            print("🔍 isCheck: No attacking pieces found for \(color.rawValue) king at \(king.position.stringValue)")
        }
        
        return false
    }
    
    func isCheckmate(color: PieceColor) -> Bool {
        // During initial loading, suppress check detection to avoid interference
        if pieces.count < 64 {
            return false
        }
        
        // First check if the king is in check
        guard isCheck(color: color, suppressDebug: true) else { 
            print("♔ \(color.rawValue) king is NOT in check - not checkmate")
            return false 
        }
        
        print("♔ \(color.rawValue) king is in check - checking for checkmate")
        
        // Get all pieces of the given color
        let piecesOfColor = pieces.values.filter { $0.color == color }
        print("♔ Found \(piecesOfColor.count) pieces for \(color.rawValue) to check")
        
        // Check if any piece can make a move that gets the king out of check
        for piece in piecesOfColor {
            let validMoves = getValidMoves(for: piece)
            print("♔ \(piece.color) \(piece.type) at \(piece.position.stringValue) has \(validMoves.count) valid moves")
            
            for move in validMoves {
                // print("♔ Testing move: \(move.from.stringValue) -> \(move.to.stringValue)")
                
                // Try the move temporarily
                let originalPiece = pieces[move.to]
                let originalFromPiece = pieces[move.from]
                
                // Remove captured piece if any
                if let capturedPiece = move.capturedPiece {
                    pieces.removeValue(forKey: capturedPiece.position)
                }
                
                // Move the piece
                safeSetPiece(piece.moved(to: move.to), at: move.to)
                _ = safeDictionaryAccess {
                    pieces.removeValue(forKey: move.from)
                    return true
                }
                
                // Check if king is still in check
                let stillInCheck = isCheck(color: color, suppressDebug: true)
                
                // Restore the board state - be more careful about cleanup
                _ = safeDictionaryAccess {
                    pieces.removeValue(forKey: move.to) // Remove the moved piece
                    return true
                }
                
                // Restore original pieces
                if let originalFrom = originalFromPiece {
                    safeSetPiece(originalFrom, at: move.from)
                }
                if let original = originalPiece {
                    safeSetPiece(original, at: move.to)
                }
                if let capturedPiece = move.capturedPiece {
                    safeSetPiece(capturedPiece, at: capturedPiece.position)
                }
                
                // If any move gets the king out of check, it's not checkmate
                if !stillInCheck {
                    print("♔ Move \(move.from.stringValue) -> \(move.to.stringValue) saves the king - NOT checkmate")
                    return false
                }
                // else {
                //     print("♔ Move \(move.from.stringValue) -> \(move.to.stringValue) does NOT save the king")
                // }
            }
        }
        
        // If no move can get the king out of check, it's checkmate
        print("♔ No moves can save the king - CHECKMATE!")
        return true
    }
    
    func isStalemate(color: PieceColor) -> Bool {
        return false
    }
    
    // MARK: - Castling
    func canCastle(color: PieceColor, side: CastlingSide) -> Bool {
        // Find the king and rook
        guard let king = pieces.values.first(where: { $0.type == .king && $0.color == color }),
              let rook = findRookForCastling(color: color, side: side) else {
            return false
        }
        
        // Check if king and rook have moved
        if king.hasMoved || rook.hasMoved {
            return false
        }
        
        // Check if king is in check
        if isCheck(color: color) {
            return false
        }
        
        // Check if squares between king and rook are empty
        let kingFile = king.position.file
        let rookFile = rook.position.file
        let rank = king.position.rank
        
        let startFile = min(kingFile, rookFile) + 1
        let endFile = max(kingFile, rookFile)
        
        for file in startFile..<endFile {
            let position = ChessPosition3D(file: file, rank: rank, z: 0) // Assuming castling is in z=0
            if getPiece(at: position) != nil {
                return false
            }
        }
        
        // Check if king would pass through check
        let kingDirection = rookFile > kingFile ? 1 : -1
        for step in 1...2 {
            let checkFile = kingFile + (step * kingDirection)
            let checkPosition = ChessPosition3D(file: checkFile, rank: rank, z: 0) // Assuming check is in z=0
            if wouldPositionBeUnderAttack(position: checkPosition, by: color.opposite) {
                return false
            }
        }
        
        return true
    }
    
    func performCastling(color: PieceColor, side: CastlingSide) -> Bool {
        guard canCastle(color: color, side: side) else { return false }
        
        guard let king = pieces.values.first(where: { $0.type == .king && $0.color == color }),
              let rook = findRookForCastling(color: color, side: side) else {
            return false
        }
        
        let rank = king.position.rank
        let kingDirection = side == .kingside ? 2 : -2
        let rookDirection = side == .kingside ? -2 : 3
        
        // Calculate new positions
        let newKingFile = king.position.file + kingDirection
        let newRookFile = rook.position.file + rookDirection
        
        let newKingPosition = ChessPosition3D(file: newKingFile, rank: rank, z: 0) // Assuming castling is in z=0
        let newRookPosition = ChessPosition3D(file: newRookFile, rank: rank, z: 0) // Assuming castling is in z=0
        
        // Move the pieces
        let movedKing = king.moved(to: newKingPosition)
        let movedRook = rook.moved(to: newRookPosition)
        
        pieces[newKingPosition] = movedKing
        pieces[newRookPosition] = movedRook
        pieces.removeValue(forKey: king.position)
        pieces.removeValue(forKey: rook.position)
        
        // Create castling move
        let castlingMove = ChessMove3D(piece: king, from: king.position, to: newKingPosition, isCastling: true)
        moveHistory.append(castlingMove)
        
        // Switch turns
        currentTurn = currentTurn.opposite
        
        return true
    }
    
    private func findRookForCastling(color: PieceColor, side: CastlingSide) -> ChessPiece3D? {
        let rank = color == .white ? 0 : 7
        let rookFile = side == .kingside ? 7 : 0
        let rookPosition = ChessPosition3D(file: rookFile, rank: rank, z: 0) // Assuming castling is in z=0
        
        return pieces.values.first(where: { $0.type == .rook && $0.color == color && $0.position == rookPosition })
    }
    
    private func wouldPositionBeUnderAttack(position: ChessPosition3D, by color: PieceColor) -> Bool {
        let opponentPieces = pieces.values.filter { $0.color == color }
        
        for opponentPiece in opponentPieces {
            if canPieceAttackPosition(piece: opponentPiece, targetPosition: position) {
                return true
            }
        }
        
        return false
    }
    
    // Helper method to check if a piece can attack a specific position
    private func canPieceAttackPosition(piece: ChessPiece3D, targetPosition: ChessPosition3D) -> Bool {
        switch piece.type {
        case .pawn:
            // Pawns attack diagonally
            let direction = piece.color == .white ? 1 : -1
            let fileDiff = abs(targetPosition.file - piece.position.file)
            let rankDiff = targetPosition.rank - piece.position.rank
            
            return fileDiff == 1 && rankDiff == direction
            
        case .rook:
            // Rooks attack in straight lines
            return (targetPosition.file == piece.position.file || targetPosition.rank == piece.position.rank) &&
                   !isPathBlocked(from: piece.position, to: targetPosition)
            
        case .bishop:
            // Bishops attack diagonally (2D and 3D)
            let fileDiff = abs(targetPosition.file - piece.position.file)
            let rankDiff = abs(targetPosition.rank - piece.position.rank)
            let zDiff = abs(targetPosition.z - piece.position.z)
            
            // 2D diagonal (file + rank)
            let is2DDiagonal = fileDiff == rankDiff && zDiff == 0
            // 3D diagonal (file + Z, rank + Z, or file + rank + Z)
            let is3DDiagonal = (fileDiff == zDiff && rankDiff == 0) || 
                              (rankDiff == zDiff && fileDiff == 0) || 
                              (fileDiff == rankDiff && rankDiff == zDiff)
            
            let canAttack = (is2DDiagonal || is3DDiagonal) && !isPathBlocked(from: piece.position, to: targetPosition)
            
            // Debug output for bishop attacks
            if targetPosition.stringValue.contains("f1") || piece.position.stringValue.contains("g1") {
                print("🔍 Bishop attack check: \(piece.color) bishop at \(piece.position.stringValue) -> \(targetPosition.stringValue)")
                print("🔍 Bishop attack: fileDiff=\(fileDiff), rankDiff=\(rankDiff), zDiff=\(zDiff)")
                print("🔍 Bishop attack: is2DDiagonal=\(is2DDiagonal), is3DDiagonal=\(is3DDiagonal)")
                print("🔍 Bishop attack: pathBlocked=\(isPathBlocked(from: piece.position, to: targetPosition))")
                print("🔍 Bishop attack: canAttack=\(canAttack)")
            }
            
            return canAttack
            
        case .queen:
            // Queens attack in straight lines or diagonally
            let fileDiff = abs(targetPosition.file - piece.position.file)
            let rankDiff = abs(targetPosition.rank - piece.position.rank)
            
            return ((targetPosition.file == piece.position.file || targetPosition.rank == piece.position.rank) ||
                    (fileDiff == rankDiff)) && !isPathBlocked(from: piece.position, to: targetPosition)
            
        case .king:
            // Kings attack adjacent squares in 3D
            let fileDiff = abs(targetPosition.file - piece.position.file)
            let rankDiff = abs(targetPosition.rank - piece.position.rank)
            let zDiff = abs(targetPosition.z - piece.position.z)
            
            return fileDiff <= 1 && rankDiff <= 1 && zDiff <= 1 && (fileDiff > 0 || rankDiff > 0 || zDiff > 0)
            
        case .knight:
            // Knights attack in L-shape (2D or 3D)
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
    
    // Helper method to check if path is blocked
    private func isPathBlocked(from: ChessPosition3D, to: ChessPosition3D) -> Bool {
        let fileDiff = to.file - from.file
        let rankDiff = to.rank - from.rank
        let zDiff = to.z - from.z
        
        // Determine step direction
        let fileStep = fileDiff == 0 ? 0 : fileDiff > 0 ? 1 : -1
        let rankStep = rankDiff == 0 ? 0 : rankDiff > 0 ? 1 : -1
        let zStep = zDiff == 0 ? 0 : zDiff > 0 ? 1 : -1
        
        // Check each position along the path (excluding start and end)
        var currentFile = from.file + fileStep
        var currentRank = from.rank + rankStep
        var currentZ = from.z + zStep
        
        while currentFile != to.file || currentRank != to.rank || currentZ != to.z {
            let checkPosition = ChessPosition3D(file: currentFile, rank: currentRank, z: currentZ)
            if getPiece(at: checkPosition) != nil {
                return true
            }
            currentFile += fileStep
            currentRank += rankStep
            currentZ += zStep
        }
        
        return false
    }
    
    // MARK: - AI Support Methods
    
    func makeMove(_ move: ChessMove3D) {
        // Remove the piece from its original position
        _ = safeDictionaryAccess {
            pieces.removeValue(forKey: move.from)
            return true
        }
        
        // Place the piece at its new position
        let movedPiece = move.piece.moved(to: move.to)
        safeSetPiece(movedPiece, at: move.to)
        
        // Handle captures
        if let capturedPiece = move.capturedPiece {
            // Captured piece is already removed by the move
            print("🤖 AI: Captured \(capturedPiece.color) \(capturedPiece.type) at \(capturedPiece.position.stringValue)")
        }
        
        // Handle en passant
        if move.isEnPassant {
            // Remove the captured pawn from its original position
            if let enPassantTarget = enPassantTarget {
                _ = safeDictionaryAccess {
                    pieces.removeValue(forKey: enPassantTarget)
                    return true
                }
                print("🤖 AI: En passant capture at \(enPassantTarget.stringValue)")
            }
        }
        
        // Handle castling
        if move.isCastling {
            // Move the rook as well
            let rookFile = move.to.file > move.from.file ? 7 : 0
            let rookRank = move.from.rank
            let rookZ = move.from.z
            
            let rookFrom = ChessPosition3D(file: rookFile, rank: rookRank, z: rookZ)
            let rookTo = ChessPosition3D(file: move.to.file > move.from.file ? move.to.file - 1 : move.to.file + 1, 
                                       rank: rookRank, z: rookZ)
            
            if let rook = safeGetPiece(at: rookFrom) {
                _ = safeDictionaryAccess {
                    pieces.removeValue(forKey: rookFrom)
                    return true
                }
                safeSetPiece(rook.moved(to: rookTo), at: rookTo)
                print("🤖 AI: Castling rook moved from \(rookFrom.stringValue) to \(rookTo.stringValue)")
            }
        }
        
        // Handle pawn promotion
        if let promotionType = move.promotionType {
            let promotedPiece = ChessPiece3D(type: promotionType, color: movedPiece.color, position: move.to, hasMoved: true)
            safeSetPiece(promotedPiece, at: move.to)
            print("🤖 AI: Pawn promoted to \(promotionType.rawValue)")
        }
        
        // Update en passant target
        updateEnPassantTarget(for: move)
        
        // Switch turns
        currentTurn = currentTurn.opposite
        
        // Add to move history
        moveHistory.append(move)
        
        print("🤖 AI: Move completed: \(move.from.stringValue) -> \(move.to.stringValue)")
    }
    
    func undoMove(_ move: ChessMove3D, capturedPiece: ChessPiece3D?) {
        // Remove the piece from its current position
        _ = safeDictionaryAccess {
            pieces.removeValue(forKey: move.to)
            return true
        }
        
        // Restore the piece to its original position
        safeSetPiece(move.piece, at: move.from)
        
        // Restore captured piece if any
        if let capturedPiece = capturedPiece {
            safeSetPiece(capturedPiece, at: move.to)
        }
        
        // Handle en passant undo
        if move.isEnPassant {
            // Restore the captured pawn to its original position
            if let enPassantTarget = enPassantTarget {
                let capturedPawn = ChessPiece3D(type: .pawn, color: move.piece.color.opposite, position: enPassantTarget)
                safeSetPiece(capturedPawn, at: enPassantTarget)
            }
        }
        
        // Handle castling undo
        if move.isCastling {
            // Restore the rook to its original position
            let rookFile = move.to.file > move.from.file ? 7 : 0
            let rookRank = move.from.rank
            let rookZ = move.from.z
            
            let rookFrom = ChessPosition3D(file: move.to.file > move.from.file ? move.to.file - 1 : move.to.file + 1, 
                                         rank: rookRank, z: rookZ)
            let rookTo = ChessPosition3D(file: rookFile, rank: rookRank, z: rookZ)
            
            if let rook = safeGetPiece(at: rookFrom) {
                _ = safeDictionaryAccess {
                    pieces.removeValue(forKey: rookFrom)
                    return true
                }
                safeSetPiece(rook.moved(to: rookTo), at: rookTo)
            }
        }
        
        // Switch turns back
        currentTurn = currentTurn.opposite
        
        // Remove from move history
        if !moveHistory.isEmpty {
            moveHistory.removeLast()
        }
        
        // Restore en passant target from previous move if available
        if moveHistory.count >= 2 {
            let previousMove = moveHistory[moveHistory.count - 2]
            updateEnPassantTarget(for: previousMove)
        } else {
            enPassantTarget = nil
        }
        
        print("🤖 AI: Move undone: \(move.to.stringValue) -> \(move.from.stringValue)")
    }
    
    // getGameState method moved to ChessGameManager to avoid duplication
    
    // resetGame, isCheckmate, and isStalemate methods moved to ChessGameManager to avoid duplication
    
    // MARK: - En Passant Support
    
    private func updateEnPassantTarget(for move: ChessMove3D) {
        // Set en passant target for pawn double moves
        if move.piece.type == .pawn {
            let rankDiff = abs(move.to.rank - move.from.rank)
            let zDiff = abs(move.to.z - move.from.z)
            
            // Only set en passant target for 2D pawn moves (same z-level)
            if rankDiff == 2 && zDiff == 0 {
                let enPassantRank = move.from.rank + (move.piece.color == .white ? 1 : -1)
                enPassantTarget = ChessPosition3D(file: move.from.file, rank: enPassantRank, z: move.from.z)
                print("🤖 AI: Set en passant target to \(enPassantTarget?.stringValue ?? "none")")
            } else {
                enPassantTarget = nil
            }
        } else {
            enPassantTarget = nil
        }
    }
}


