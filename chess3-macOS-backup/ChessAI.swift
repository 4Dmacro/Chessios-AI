//
//  ChessAI.swift
//  chess3
//
//  Created by Gareth Costa on 15/7/2025.
//

import Foundation
import ObjectiveC
import SceneKit

// MARK: - Game Outcomes
enum GameOutcome {
    case win
    case loss
    case draw
    case ongoing
}

// MARK: - AI Difficulty Levels
enum AIDifficulty {
    case easy
    case medium
    case hard
    
    var searchDepth: Int {
        switch self {
        case .easy: return 1
        case .medium: return 2
        case .hard: return 3
        }
    }
}

// MARK: - AI Player
class ChessAI {
    private let difficulty: AIDifficulty
    private weak var board: ChessBoard3D?
    let aiColor: PieceColor
    
    // MARK: - Strategic Approaches
    enum StrategicApproach {
        case aggressive      // Focus on attacking and piece development
        case defensive      // Focus on king safety and solid pawn structure
        case positional     // Focus on center control and piece coordination
        case tactical       // Focus on immediate tactics and captures
        case endgame       // Focus on pawn advancement and king activation
    }
    
    private var currentStrategy: StrategicApproach
    private var gamePhase: GamePhase = .opening
    
    enum GamePhase {
        case opening    // First 10-15 moves
        case middlegame // Moves 15-40
        case endgame    // After most pieces are traded
    }
    
    // MARK: - Learning System
    private var moveHistory: [ChessMove3D] = []
    private var gameOutcomes: [GameOutcome] = []
    
    // MARK: - Strategic Rules Tracking
    private var pieceMoveCounts: [String: Int] = [:] // Track consecutive moves per piece
    private var lastMovedPiece: String? = nil
    private var movesSinceZAxisMove: Int = 0
    private var totalMovesPlayed: Int = 0
    
    // MARK: - New Move Tracking for Rules 9-11
    private var lastKnightMoveNumber: Int = -1
    private var lastBishopMoveNumber: Int = -1
    private var completedPawnMoves: Set<String> = []
    private var aiMoveHistory: [ChessMove3D] = []
    private var strategyWeights: [String: Double] = [
        "advancement": 1.0,
        "center_control": 1.0,
        "pawn_structure": 1.0,
        "passed_pawn": 1.0,
        "safety": 1.0,
        "pawn_chain": 1.0,
        "king_protection": 1.0,
        "opponent_attack": 1.0,
        "isolation_avoidance": 1.0,
        "position_opening": 1.0,
        "piece_development": 1.0,
        "tactical_opportunity": 1.0,
        "king_activity": 1.0,
        "material_advantage": 1.0
    ]
    
    // MARK: - Data Persistence
    private let userDefaults = UserDefaults.standard
    private let strategyWeightsKey = "AIStrategyWeights"
    private let gameOutcomesKey = "AIGameOutcomes"
    private let totalGamesKey = "AITotalGames"
    private let winsKey = "AIWins"
    private let lossesKey = "AILosses"
    private let drawsKey = "AIDraws"
    
    // Piece values for evaluation
    private let pieceValues: [PieceType: Int] = [
        .pawn: 100,
        .knight: 320,
        .bishop: 330,
        .rook: 500,
        .queen: 900,
        .king: 20000
    ]
    
    // Position bonuses for 3D chess
    private let centerBonus = 10
    private let heightBonus = 5
    private let mobilityBonus = 2
    
    // Track logged strategic moves to prevent duplicate debug output
    private var loggedStrategicMoves: Set<String> = []
    
    init(board: ChessBoard3D, aiColor: PieceColor, difficulty: AIDifficulty = .medium) {
        self.board = board
        self.aiColor = aiColor
        self.difficulty = difficulty
        
        // Randomly choose a strategic approach
        let strategies: [StrategicApproach] = [.aggressive, .defensive, .positional, .tactical, .endgame]
        self.currentStrategy = strategies.randomElement() ?? .positional
        
        // Load saved learning data
        loadLearningData()
        
        print("🤖 AI initialized with \(aiColor.rawValue) color, \(difficulty) difficulty, \(currentStrategy) strategy")
        print("🤖 AI loaded learning data - Total games: \(getTotalGames()), Win rate: \(getWinRate())%")
    }
    
    private func getBoard() -> ChessBoard3D? {
        return board
    }
    
    // MARK: - Main AI Decision Making
    
    func getBestMove() -> ChessMove3D? {
        print("🤖 AI (\(aiColor.rawValue)) calculating best move with difficulty: \(difficulty)")
        
        // Add aggressive timeout protection
        let startTime = Date()
        let maxCalculationTime: TimeInterval = 2.0 // Further reduced to 2 seconds for 3D chess
        
        // Safety check for board corruption
        guard let board = getBoard() else {
            print("❌ AI error: Board not available")
            return nil
        }
        
        // Check if board is in a valid state
        let allPieces = board.getAllPieces()
        if allPieces.isEmpty {
            print("❌ AI error: Board has no pieces - board may be corrupted")
            return nil
        }
        
        // Additional safety check - if we have too many pieces, something is wrong
        if allPieces.count > 100 {
            print("❌ AI error: Board has too many pieces (\(allPieces.count)) - board may be corrupted")
            return nil
        }
        
        // Additional safety check - validate board state before proceeding
        if !board.validateBoardState() {
            print("❌ AI error: Board state validation failed - board may be corrupted")
            return nil
        }
        
        // Check timeout
        let elapsedTime = Date().timeIntervalSince(startTime)
        if elapsedTime > maxCalculationTime {
            print("⚠️ AI timeout reached (\(elapsedTime)s) - choosing first available move")
            let allMoves = getAllValidMoves(for: aiColor)
            return allMoves.first
        }
        
        // CRITICAL: Add timeout check before any heavy evaluation
        if Date().timeIntervalSince(startTime) > maxCalculationTime * 0.5 {
            print("⚠️ AI early timeout - skipping complex evaluation")
            let allMoves = getAllValidMoves(for: aiColor)
            return allMoves.first
        }
        
        // Check if king is in check - if so, we need to allow king moves
        let isKingInCheck = board.isCheck(color: aiColor)
        if isKingInCheck {
            print("🤖 AI: King is in check - using emergency move selection")
            let allMoves = getAllValidMoves(for: aiColor)
            if allMoves.isEmpty {
                print("🤖 AI: No valid moves available - checkmate!")
                return nil
            }
            
            // CRITICAL: When king is in check, force immediate decision to prevent freezing
            // Don't do any complex evaluation - just pick the best available move type
            
            // CRITICAL: When in check, prioritize moves by type for speed
            // Don't evaluate every move - just pick the best type available
            let captureMoves = allMoves.filter { $0.capturedPiece != nil }
            let kingMoves = allMoves.filter { move in
                if let piece = board.getPiece(at: move.from) {
                    return piece.type == .king
                }
                return false
            }
            
            // Force immediate decision - no complex evaluation when in check
            if !captureMoves.isEmpty {
                print("🤖 AI: Choosing capture move to escape check")
                return captureMoves.first
            } else if !kingMoves.isEmpty {
                print("🤖 AI: Choosing king move to escape check")
                return kingMoves.first
            } else {
                print("🤖 AI: Choosing other move to escape check")
                return allMoves.first
            }
            

        }
        
        // Update game phase based on move count
        updateGamePhase()
        
        // Get all valid moves (not just pawns)
        let allMoves = getAllValidMoves(for: aiColor)
        
        guard !allMoves.isEmpty else {
            print("🤖 AI has no valid moves available")
            return nil
        }
        
        print("🤖 AI found \(allMoves.count) valid moves")
        
        // CRITICAL: Filter out king moves unless king is in check
        let kingInCheck = self.isKingInCheck()
        let filteredMoves: [ChessMove3D]
        
        if kingInCheck {
            // If king is in check, allow all moves (including king moves)
            filteredMoves = allMoves
            print("🤖 AI: King is in check - allowing all moves including king moves")
        } else {
            // If king is not in check, exclude king moves unless they're captures
            // Also exclude moves that are clearly bad to reduce evaluation load
            filteredMoves = allMoves.filter { move in
                if let piece = board.getPiece(at: move.from) {
                    // Allow all king moves to be evaluated (no filtering)
                    if piece.type == .king {
                        return true // Allow all king moves to be evaluated
                    }
                    
                    // Exclude queen moves unless they're captures or defensive
                    if piece.type == .queen {
                        if move.capturedPiece != nil {
                            return true // Captures are always good
                        }
                        // Only allow defensive queen moves
                        if let board = getBoard(), isDefensiveMove(move, piece: piece, board: board) {
                            return true
                        }
                        return false // Exclude non-capture, non-defensive queen moves
                    }
                    
                    // CRITICAL: Exclude moves that would allow valuable pieces to be captured by less valuable pieces
                    let movingPieceValue = pieceValues[piece.type] ?? 0
                    if movingPieceValue >= 3 { // Queen, rook, bishop, knight
                        // Check if this move would allow our piece to be captured by a less valuable enemy piece
                        let enemyColor = aiColor.opposite
                        let enemyPieces = board.getPieces(of: enemyColor)
                        
                        for enemyPiece in enemyPieces {
                            let enemyValue = pieceValues[enemyPiece.type] ?? 0
                            if enemyValue < movingPieceValue { // Enemy piece is less valuable
                                // Check if enemy can capture our piece after this move
                                let enemyMoves = board.getValidMoves(for: enemyPiece, checkEnPassant: false)
                                if enemyMoves.contains(where: { $0.to == move.to }) {
                                    // CRITICAL: This move would allow our valuable piece to be captured by a less valuable piece
                                    print("🤖 AI CRITICAL FILTER: Excluding move that would allow \(piece.type.rawValue) to be captured by \(enemyPiece.type.rawValue)")
                                    return false // Exclude this move completely
                                }
                            }
                        }
                    }
                    
                    // Exclude moves that put pieces in obvious danger
                    if move.capturedPiece == nil {
                        // For non-capture moves, check if they put the piece in danger
                        if movingPieceValue >= 3 { // Queen, rook, bishop
                            // Check if this move puts a valuable piece in danger
                            if wouldMovePutPieceInDanger(move: move) {
                                return false // Exclude dangerous moves for valuable pieces
                            }
                        }
                    }
                }
                return true
            }
            print("🤖 AI: King not in check - filtered out \(allMoves.count - filteredMoves.count) moves (including non-capture king moves and dangerous moves)")
        }
        
        guard !filteredMoves.isEmpty else {
            print("🤖 AI has no valid moves after filtering")
            return nil
        }
        
        // CRITICAL: Prioritize captures over strategic rules, but be smart about it
        let captureMoves = filteredMoves.filter { $0.capturedPiece != nil }
        let movesToEvaluate: [ChessMove3D]
        
        if !captureMoves.isEmpty {
            // Check if any captures are advantageous
            let advantageousCaptures = captureMoves.filter { move in
                if let piece = board.getPiece(at: move.from),
                   let capturedPiece = move.capturedPiece {
                    let captureValue = pieceValues[capturedPiece.type] ?? 0
                    let movingPieceValue = pieceValues[piece.type] ?? 0
                    return captureValue >= movingPieceValue
                }
                return false
            }
            
            if !advantageousCaptures.isEmpty {
                print("🤖 AI: Found \(advantageousCaptures.count) advantageous capture moves - bypassing strategic rules")
                // CRITICAL: For advantageous captures, make immediate decision to prevent freezing
                print("🤖 AI: Making immediate decision for advantageous capture")
                return advantageousCaptures.first
            } else {
                print("🤖 AI: Found \(captureMoves.count) capture moves but none are advantageous - evaluating all moves")
                movesToEvaluate = allMoves
            }
        } else {
            // Filter moves using strategic rules only if no captures available
            let strategicMoves = filteredMoves.filter { isValidStrategicMove($0) }
            movesToEvaluate = strategicMoves.isEmpty ? filteredMoves : strategicMoves
            
            if strategicMoves.isEmpty {
                print("🤖 AI Warning: No moves pass strategic rules, evaluating all \(filteredMoves.count) moves")
            } else {
                print("🤖 AI: Filtered to \(strategicMoves.count) strategic moves from \(filteredMoves.count) total moves")
            }
        }
        
        // CRITICAL: If too many moves, force immediate decision to prevent freezing
        if movesToEvaluate.count > 50 {
            print("⚠️ AI: Too many moves (\(movesToEvaluate.count)) - forcing immediate decision")
            let captureMoves = movesToEvaluate.filter { $0.capturedPiece != nil }
            if !captureMoves.isEmpty {
                print("🤖 AI forced decision: Choosing capture move")
                return captureMoves.first
            } else {
                // Prioritize pawns, knights, bishops over king/queen when not under attack
                let prioritizedMove = getPrioritizedMove(from: movesToEvaluate)
                print("🤖 AI forced decision: Choosing prioritized move")
                return prioritizedMove
            }
        }
        
        // Debug: Print moves being considered
        print("🤖 AI: Evaluating \(movesToEvaluate.count) moves:")
        for (index, move) in movesToEvaluate.enumerated() {
            let captureInfo = move.capturedPiece != nil ? " (captures \(move.capturedPiece!.type.rawValue))" : ""
            print("🤖 AI debug: Move \(index): \(move.from.stringValue) -> \(move.to.stringValue)\(captureInfo)")
        }
        
        // Clear logged strategic moves for this evaluation cycle
        loggedStrategicMoves.removeAll()
        
        // Evaluate moves based on current strategy and game phase
        var evaluatedMoves: [(ChessMove3D, Int)] = []
        
        // CRITICAL: Limit the number of moves to evaluate to prevent timeout
        // In 3D chess, there are many more moves, so we need to be more aggressive
        // BUT: If king moves are present, evaluate ALL king moves
        let kingMoves = movesToEvaluate.filter { move in
            if let piece = board.getPiece(at: move.from) {
                return piece.type == .king
            }
            return false
        }
        
        let maxMovesToEvaluate = min(movesToEvaluate.count, 4) // Further reduced from 6 to 4
        let movesToEvaluateLimited: [ChessMove3D]
        
        if !kingMoves.isEmpty {
            // If king moves are present, evaluate ALL king moves plus some others
            let nonKingMoves = movesToEvaluate.filter { move in
                if let piece = board.getPiece(at: move.from) {
                    return piece.type != .king
                }
                return true
            }
            let limitedNonKingMoves = Array(nonKingMoves.prefix(2)) // Limit non-king moves to 2
            movesToEvaluateLimited = kingMoves + limitedNonKingMoves
            print("🤖 AI: Evaluating ALL \(kingMoves.count) king moves + \(limitedNonKingMoves.count) other moves")
        } else {
            movesToEvaluateLimited = Array(movesToEvaluate.prefix(maxMovesToEvaluate))
        }
        
        print("🤖 AI: Evaluating \(movesToEvaluateLimited.count) moves out of \(movesToEvaluate.count) total")
        
        // CRITICAL: Add early timeout check before starting evaluation
        let earlyElapsedTime = Date().timeIntervalSince(startTime)
        if earlyElapsedTime > maxCalculationTime * 0.5 { // More aggressive - 50% instead of 70%
            print("⚠️ AI early timeout before evaluation - forcing decision")
            // Force immediate decision with captures first
            let captureMoves = movesToEvaluate.filter { $0.capturedPiece != nil }
            if !captureMoves.isEmpty {
                print("🤖 AI forced decision: Choosing capture move")
                return captureMoves.first
            } else {
                // Prioritize pawns, knights, bishops over king/queen when not under attack
                let prioritizedMove = getPrioritizedMove(from: movesToEvaluate)
                print("🤖 AI forced decision: Choosing prioritized move")
                return prioritizedMove
            }
        }
        
        for (index, move) in movesToEvaluateLimited.enumerated() {
            // Check timeout during evaluation
            let elapsedTime = Date().timeIntervalSince(startTime)
            if elapsedTime > maxCalculationTime {
                print("⚠️ AI timeout during move evaluation - stopping at move \(index)")
                break
            }
            
            // Special timeout check for king moves - force decision after evaluating king moves
            if let piece = board.getPiece(at: move.from), piece.type == .king {
                if elapsedTime > maxCalculationTime * 0.8 {
                    print("⚠️ AI king move timeout - forcing decision after evaluating \(index) king moves")
                    break
                }
            }
            
            let score = evaluateMove(move)
            evaluatedMoves.append((move, score))
        }
        
        // Sort by score descending
        evaluatedMoves.sort { $0.1 > $1.1 }
        
        let bestMove: ChessMove3D?
        if let bestEvaluatedMove = evaluatedMoves.first {
            print("🤖 AI chose move with score \(bestEvaluatedMove.1): \(bestEvaluatedMove.0.from.stringValue) -> \(bestEvaluatedMove.0.to.stringValue)")
            bestMove = bestEvaluatedMove.0
        } else {
            // Fallback: Choose a move quickly
            print("🤖 AI: No evaluated moves - choosing fallback move")
            
            // CRITICAL: Final timeout check before fallback
            let elapsedTime = Date().timeIntervalSince(startTime)
            if elapsedTime > maxCalculationTime {
                print("⚠️ AI final timeout - forcing decision")
                // Force immediate decision with captures first
                let captureMoves = filteredMoves.filter { $0.capturedPiece != nil }
                if !captureMoves.isEmpty {
                    print("🤖 AI final forced decision: Choosing capture move")
                    return captureMoves.first
                } else {
                    // Prioritize pawns, knights, bishops over king/queen when not under attack
                    let prioritizedMove = getPrioritizedMove(from: filteredMoves)
                    print("🤖 AI final forced decision: Choosing prioritized move")
                    return prioritizedMove
                }
            }
            
            // Prioritize captures first
            let captureMoves = filteredMoves.filter { $0.capturedPiece != nil }
            if !captureMoves.isEmpty {
                bestMove = captureMoves.first
                print("🤖 AI fallback: Choosing capture move")
            } else {
                // Prioritize pawns, knights, bishops over king/queen when not under attack
                let prioritizedMove = getPrioritizedMove(from: filteredMoves)
                bestMove = prioritizedMove
                print("🤖 AI fallback: Choosing prioritized move")
            }
        }
        
        // Final timeout check - force decision if taking too long
        let timeElapsed = Date().timeIntervalSince(startTime)
        if timeElapsed > maxCalculationTime {
            print("⚠️ AI final timeout - forcing decision")
            if let move = allMoves.first {
                print("🤖 AI forced decision: \(move.from.stringValue) -> \(move.to.stringValue)")
                recordMove(move)
                return move
            }
        }
        
        // Record the move for learning
        if let move = bestMove {
            recordMove(move)
        }
        
        print("🤖 AI chose move: \(bestMove?.from.stringValue ?? "none") -> \(bestMove?.to.stringValue ?? "none")")
        print("🤖 AI calculation time: \(String(format: "%.3f", timeElapsed))s")
        
        return bestMove
    }
    
    // MARK: - Minimax Algorithm with Alpha-Beta Pruning
    
    private var searchStartTime: Date?
    private let maxSearchTime: TimeInterval = 3.0 // 3 second timeout
    
    private func minimax(depth: Int, alpha: Int, beta: Int, maximizing: Bool) -> Int {
        guard let board = getBoard() else { return 0 }
        
        // Check for timeout
        if let startTime = searchStartTime {
            let elapsedTime = Date().timeIntervalSince(startTime)
            if elapsedTime > maxSearchTime {
                print("⚠️ AI warning: Search timeout reached (\(elapsedTime)s) - returning current evaluation")
                return evaluatePosition()
            }
        }
        
        if depth == 0 {
            return evaluatePosition()
        }
        
        let currentColor = maximizing ? PieceColor.white : PieceColor.black
        let moves = getAllValidMoves(for: currentColor)
        
        if moves.isEmpty {
            // Checkmate or stalemate
            if isCheck(color: currentColor) {
                return maximizing ? Int.min : Int.max // Checkmate
            } else {
                return 0 // Stalemate
            }
        }
        
        var alpha = alpha
        var beta = beta
        
        if maximizing {
            var maxScore = Int.min
            for move in moves {
                let capturedPiece = board.getPiece(at: move.to)
                board.makeMove(move)
                
                let score = minimax(depth: depth - 1, alpha: alpha, beta: beta, maximizing: false)
                
                board.undoMove(move, capturedPiece: capturedPiece)
                
                maxScore = max(maxScore, score)
                alpha = max(alpha, score)
                
                if beta <= alpha {
                    break // Beta cutoff
                }
            }
            return maxScore
        } else {
            var minScore = Int.max
            for move in moves {
                let capturedPiece = board.getPiece(at: move.to)
                board.makeMove(move)
                
                let score = minimax(depth: depth - 1, alpha: alpha, beta: beta, maximizing: true)
                
                board.undoMove(move, capturedPiece: capturedPiece)
                
                minScore = min(minScore, score)
                beta = min(beta, score)
                
                if beta <= alpha {
                    break // Alpha cutoff
                }
            }
            return minScore
        }
    }
    
    // MARK: - Move Generation for AI
    
    private func getAllValidMoves(for color: PieceColor) -> [ChessMove3D] {
        guard let board = getBoard() else {
            print("❌ AI error: Board not available")
            return []
        }
        
        // Safety check for board corruption before accessing pieces
        if !board.validateBoardState() {
            print("❌ AI error: Board validation failed in getAllValidMoves")
            return []
        }
        
        // Safety check for board corruption
        let pieces = board.getPieces(of: color)
        if pieces.isEmpty && color == .black {
            print("⚠️ AI warning: No pieces found for \(color.rawValue), this might indicate board corruption")
            return []
        }
        
        var allMoves: [ChessMove3D] = []
        
        print("🤖 AI debug: Found \(pieces.count) pieces for \(color.rawValue)")
        
        for piece in pieces {
            print("🤖 AI debug: Checking moves for \(piece.type.rawValue) at \(piece.position.stringValue)")
            
            // Add safety check for piece position
            guard piece.position.file >= 0 && piece.position.file <= 7 &&
                    piece.position.rank >= 0 && piece.position.rank <= 7 &&
                    piece.position.z >= 0 && piece.position.z <= 7 else {
                print("⚠️ AI warning: Invalid piece position: \(piece.position.stringValue)")
                continue
            }
            
            let moves = board.getValidMoves(for: piece, checkEnPassant: false)
            print("🤖 AI debug: Generated \(moves.count) moves for \(piece.type.rawValue) at \(piece.position.stringValue)")
            allMoves.append(contentsOf: moves)
        }
        
        return allMoves
    }
    
    private func getPawnMovesOnly(for color: PieceColor) -> [ChessMove3D] {
        guard let board = getBoard() else {
            print("❌ AI error: Board not available")
            return []
        }
        
        // Safety check for board corruption before accessing pieces
        if !board.validateBoardState() {
            print("❌ AI error: Board validation failed in getPawnMovesOnly")
            return []
        }
        
        let pieces = board.getPieces(of: color)
        var pawnMoves: [ChessMove3D] = []
        
        print("🤖 AI debug: Found \(pieces.count) pieces for \(color.rawValue), looking for pawns only")
        
        for piece in pieces {
            // Only consider pawns
            if piece.type != .pawn {
                continue
            }
            
            print("🤖 AI debug: Checking moves for pawn at \(piece.position.stringValue)")
            
            // Add safety check for piece position
            guard piece.position.file >= 0 && piece.position.file <= 7 &&
                    piece.position.rank >= 0 && piece.position.rank <= 7 &&
                    piece.position.z >= 0 && piece.position.z <= 7 else {
                print("⚠️ AI warning: Invalid pawn position: \(piece.position.stringValue)")
                continue
            }
            
            let moves = board.getValidMoves(for: piece, checkEnPassant: false)
            print("🤖 AI debug: Generated \(moves.count) moves for pawn at \(piece.position.stringValue)")
            
            // Filter to only include valid pawn moves (forward or diagonal captures)
            let validPawnMoves = moves.filter { move in
                let fileDiff = abs(move.to.file - move.from.file)
                let rankDiff = move.to.rank - move.from.rank
                let zDiff = abs(move.to.z - move.from.z)
                
                // Valid pawn moves:
                // 1. Forward move (no file change, positive rank change for white, negative for black)
                // 2. Diagonal capture (file change of 1, rank change of 1, and there's a captured piece)
                // 3. No z-axis movement for pawns
                
                if zDiff > 0 {
                    print("🤖 AI debug: Rejecting move \(move.from.stringValue) -> \(move.to.stringValue) - invalid z-axis movement")
                    return false
                }
                
                if aiColor == .white {
                    // White pawns move up (increasing rank)
                    if rankDiff <= 0 {
                        print("🤖 AI debug: Rejecting move \(move.from.stringValue) -> \(move.to.stringValue) - white pawn moving backward")
                        return false
                    }
                    
                    if fileDiff == 0 {
                        // Forward move - must be empty
                        if move.capturedPiece != nil {
                            print("🤖 AI debug: Rejecting move \(move.from.stringValue) -> \(move.to.stringValue) - forward move with capture")
                            return false
                        }
                    } else if fileDiff == 1 {
                        // Diagonal move - must have capture
                        if move.capturedPiece == nil {
                            print("🤖 AI debug: Rejecting move \(move.from.stringValue) -> \(move.to.stringValue) - diagonal move without capture")
                            return false
                        }
                    } else {
                        print("🤖 AI debug: Rejecting move \(move.from.stringValue) -> \(move.to.stringValue) - invalid file difference")
                        return false
                    }
                } else {
                    // Black pawns move down (decreasing rank)
                    if rankDiff >= 0 {
                        print("🤖 AI debug: Rejecting move \(move.from.stringValue) -> \(move.to.stringValue) - black pawn moving backward")
                        return false
                    }
                    
                    if fileDiff == 0 {
                        // Forward move - must be empty
                        if move.capturedPiece != nil {
                            print("🤖 AI debug: Rejecting move \(move.from.stringValue) -> \(move.to.stringValue) - forward move with capture")
                            return false
                        }
                    } else if fileDiff == 1 {
                        // Diagonal move - must have capture
                        if move.capturedPiece == nil {
                            print("🤖 AI debug: Rejecting move \(move.from.stringValue) -> \(move.to.stringValue) - diagonal move without capture")
                            return false
                        }
                    } else {
                        print("🤖 AI debug: Rejecting move \(move.from.stringValue) -> \(move.to.stringValue) - invalid file difference")
                        return false
                    }
                }
                
                print("🤖 AI debug: Accepting valid pawn move \(move.from.stringValue) -> \(move.to.stringValue)")
                return true
            }
            
            pawnMoves.append(contentsOf: validPawnMoves)
        }
        
        return pawnMoves
    }
    
    private func evaluateMove(_ move: ChessMove3D) -> Int {
        guard let board = getBoard() else { return 0 }
        
        var score = 0
        
        // Get the piece being moved
        guard let piece = board.getPiece(at: move.from) else { return 0 }
        
        // SIMPLIFIED EVALUATION TO PREVENT LOOPS
        
        // 1. CRITICAL: Piece preservation check - avoid moves that leave valuable pieces vulnerable
        let movingPieceValue = pieceValues[piece.type] ?? 0
        if movingPieceValue >= 3 { // Queen, rook, bishop, knight
            // Check if this move would leave the piece vulnerable to capture by a less valuable piece
            if let board = getBoard() {
                let enemyColor = aiColor.opposite
                let enemyPieces = board.getPieces(of: enemyColor)
                
                for enemyPiece in enemyPieces {
                    let enemyValue = pieceValues[enemyPiece.type] ?? 0
                    if enemyValue < movingPieceValue { // Enemy piece is less valuable
                        // Check if enemy can capture our piece after this move
                        let enemyMoves = board.getValidMoves(for: enemyPiece, checkEnPassant: false)
                        if enemyMoves.contains(where: { $0.to == move.to }) {
                            // CRITICAL: This move would allow our valuable piece to be captured by a less valuable piece
                            let valueLoss = movingPieceValue - enemyValue
                            score -= valueLoss * 50 // Massive penalty for allowing valuable piece to be captured cheaply
                            print("🤖 AI CRITICAL ERROR: Move would allow \(piece.type.rawValue) to be captured by \(enemyPiece.type.rawValue) - penalty \(valueLoss * 50)")
                        }
                    }
                }
            }
        }
        
        // 2. Material evaluation - captures are the most important
        if let capturedPiece = move.capturedPiece {
            let captureValue = pieceValues[capturedPiece.type] ?? 0
            
            // If we're capturing a more valuable piece, this is excellent
            if captureValue > movingPieceValue {
                score += captureValue * 10 // Much higher bonus for winning material
            } else if captureValue == movingPieceValue {
                score += captureValue * 2 // Good bonus for equal trades
            } else {
                // For losing trades, apply a penalty based on the value difference
                let valueLoss = movingPieceValue - captureValue
                score -= valueLoss * 2 // Penalty for losing material
                print("🤖 AI MATERIAL LOSS: Penalty of \(valueLoss * 2) for losing \(valueLoss) material")
            }
            
            // Additional bonus for any capture, but reduced for losing trades
            if captureValue >= movingPieceValue {
                score += 500 // Base bonus for advantageous captures
            } else {
                score += 50 // Small bonus for losing trades
            }
        }
        
        // 2. Basic check evaluation (simplified to prevent loops)
        if isKingInCheck() {
            // If we're in check, prioritize moves that might escape
            if piece.type == .king {
                score += 300 // King moves when in check
            } else if move.capturedPiece != nil {
                score += 200 // Captures when in check
            }
        }
        
        // 3. STRONG king safety - avoid moving king unless absolutely necessary
        if piece.type == .king {
            if isKingInCheck() {
                // Only move king when in check
                score += 200 // Bonus for king moves when in check
            } else {
                // CRITICAL: Massive penalty for unnecessary king moves
                score -= 1000 // Extremely strong penalty for king moves when not in check
                
                // Additional penalty for moving king away from back rank
                if aiColor == .white && move.to.rank > 1 {
                    score -= 500 // Extra penalty for white king moving away from back rank
                } else if aiColor == .black && move.to.rank < 6 {
                    score -= 500 // Extra penalty for black king moving away from back rank
                }
                
                // Penalty for moving king to center files
                if move.to.file >= 2 && move.to.file <= 5 {
                    score -= 300 // Extra penalty for moving king to center
                }
            }
        }
        
        // 4. QUEEN SAFETY - CRITICAL: Avoid any move that puts queen in danger
        if piece.type == .queen {
            if move.capturedPiece != nil {
                // Queen captures are good, but check if it's safe
                score += 100 // Bonus for queen captures
                
                // Check if queen would be vulnerable after capture
                if let board = getBoard() {
                    let enemyColor = aiColor.opposite
                    let enemyPieces = board.getPieces(of: enemyColor)
                    
                    for enemyPiece in enemyPieces {
                        let enemyValue = pieceValues[enemyPiece.type] ?? 0
                        if enemyValue < 9 { // Queen value is 9, so any piece less valuable
                            let enemyMoves = board.getValidMoves(for: enemyPiece, checkEnPassant: false)
                            if enemyMoves.contains(where: { $0.to == move.to }) {
                                // CRITICAL: Queen would be vulnerable after capture
                                score -= 2000 // Massive penalty for putting queen in danger
                                print("🤖 AI QUEEN DANGER: Queen would be vulnerable after capture - penalty -2000")
                            }
                        }
                    }
                }
            } else if let board = getBoard(), isDefensiveMove(move, piece: piece, board: board) {
                // Defensive queen moves are acceptable
                score += 50 // Small bonus for defensive queen moves
            } else {
                // CRITICAL: Strong penalty for non-capture, non-defensive queen moves
                score -= 800 // Strong penalty for reckless queen moves
                print("🤖 AI QUEEN SAFETY: Penalty -800 for non-capture, non-defensive queen move")
            }
        }
        
        // 5. ROOK SAFETY - prevent pointless rook movements
        if piece.type == .rook {
            if move.capturedPiece != nil {
                // Rook captures are good
                score += 80 // Bonus for rook captures
            } else if let board = getBoard(), isDefensiveMove(move, piece: piece, board: board) {
                // Defensive rook moves are acceptable
                score += 40 // Small bonus for defensive rook moves
            } else {
                // Check if this is a pointless back-and-forth move
                if isRepetitiveMove(move) {
                    score -= 600 // Strong penalty for repetitive rook moves
                    print("🤖 AI ROOK SAFETY: Penalty -600 for repetitive rook move")
                } else {
                    score -= 300 // Moderate penalty for non-capture, non-defensive rook moves
                    print("🤖 AI ROOK SAFETY: Penalty -300 for non-capture, non-defensive rook move")
                }
            }
        }
        
        // 6. PAWN ADVANCEMENT RISK ASSESSMENT - evaluate capture risks for advanced pawns
        if piece.type == .pawn {
            // Check if pawn is reaching advanced ranks where it might be captured
            let advancedRank = aiColor == .white ? 5 : 2 // Rank 5 for white, rank 2 for black
            if (aiColor == .white && move.to.rank >= advancedRank) || (aiColor == .black && move.to.rank <= advancedRank) {
                // Evaluate capture risks for advanced pawns
                let captureRisk = evaluatePawnCaptureRisk(move, piece: piece, board: board)
                score += captureRisk
                print("🤖 AI PAWN RISK: Advanced pawn at \(move.to.stringValue) - capture risk score: \(captureRisk)")
            }
            
            // Basic positional scoring
            if aiColor == .white {
                score += move.to.rank * 10
            } else {
                score += (7 - move.to.rank) * 10
            }
        }
        
        // 7. 3D Space Usage Bonus - encourage Z-component moves
        let zDiff = abs(move.to.z - move.from.z)
        let fileDiff = abs(move.to.file - move.from.file)
        let rankDiff = abs(move.to.rank - move.from.rank)
        
        if zDiff > 0 {
            // Bonus for using the Z-axis (3D space)
            score += zDiff * 15 // +15 points per Z-level moved
            print("🤖 AI 3D Bonus: \(piece.type.rawValue) moved \(zDiff) Z-levels (+\(zDiff * 10))")
            
            // Extra bonus for true 3D diagonal moves (all 3 components change)
            if fileDiff > 0 && rankDiff > 0 && zDiff > 0 {
                score += 25 // +25 extra for true 3D diagonal
                print("🤖 AI 3D Diagonal Bonus: True 3D diagonal move (+25)")
            }
        }
        
        // 8. Avoid repetitive moves
        if isRepetitiveMove(move) {
            score -= 50
        }
        
        // 9. King safety - avoid moving king to squares that could be attacked
        if piece.type == .king {
            // Check if the destination square could be attacked by enemy pieces
            if wouldKingBeInDangerAtPosition(move.to) {
                score -= 500 // Massive penalty for moving king to dangerous square
            }
        }
        
        // 8. Add some randomness to break ties and prevent loops
        score += Int.random(in: -10...10)
        
        // CRITICAL: Check if this move is defensive (saves a piece from capture)
        if isDefensiveMove(move, piece: piece, board: board) {
            score += 100 // High priority for defensive moves
        }
        
        // ENHANCED: High-value piece protection (queen, rooks, bishops, knights)
        if isHighValuePiece(piece.type) {
            let defensiveScore = evaluateHighValuePieceDefense(move, piece: piece, board: board)
            score += defensiveScore
            print("🤖 AI HIGH-VALUE DEFENSE: \(piece.type.rawValue) defensive score: \(defensiveScore)")
        }
        
        // CRITICAL: Prevent allowing easy captures of valuable pieces
        if let board = getBoard() {
            let captureRisk = evaluateCaptureRiskForMove(move, piece: piece, board: board)
            score += captureRisk
            if captureRisk < 0 {
                print("🤖 AI CAPTURE RISK: Move \(move.from.stringValue) -> \(move.to.stringValue) has capture risk: \(captureRisk)")
            }
        }
        
        // Debug output for captures
        if move.capturedPiece != nil {
            let captureValue = pieceValues[move.capturedPiece!.type] ?? 0
            let movingPieceValue = pieceValues[piece.type] ?? 0
            print("🤖 AI Capture Analysis: \(piece.type.rawValue) captures \(move.capturedPiece!.type.rawValue) - Score: \(score) (capture value: \(captureValue), moving piece: \(movingPieceValue))")
        } else {
            print("🤖 AI Non-capture move: \(piece.type.rawValue) \(move.from.stringValue) -> \(move.to.stringValue) - Score: \(score)")
        }
        
        // CRITICAL: Force captures to be the highest priority, but only if they're advantageous
        if move.capturedPiece != nil {
            let captureValue = pieceValues[move.capturedPiece!.type] ?? 0
            let movingPieceValue = pieceValues[piece.type] ?? 0
            
            // Only give massive bonus if we're gaining material or making an equal trade
            if captureValue >= movingPieceValue {
                score += 10000 // Massive bonus for advantageous captures
                print("🤖 AI FORCE CAPTURE: Adding 10000 bonus for advantageous capture (\(piece.type.rawValue) captures \(move.capturedPiece!.type.rawValue))")
            } else {
                // For losing trades, still give a bonus but not as much
                score += 1000 // Moderate bonus for losing trades
                print("🤖 AI MODERATE CAPTURE: Adding 1000 bonus for losing trade (\(piece.type.rawValue) captures \(move.capturedPiece!.type.rawValue))")
            }
        }
        
        return score
    }
    
    // MARK: - Strategy-Specific Evaluations
    
    // MARK: - Pawn Risk Assessment
    
    private func evaluatePawnCaptureRisk(_ move: ChessMove3D, piece: ChessPiece3D, board: ChessBoard3D) -> Int {
        var riskScore = 0
        
        // Check if the pawn can be captured by enemy pieces
        let enemyColor = piece.color == .white ? PieceColor.black : PieceColor.white
        let enemyPieces = board.getPieces(of: enemyColor)
        
        // Limit evaluation to prevent timeout
        let maxEnemyChecks = 10
        var enemyChecks = 0
        
        for enemyPiece in enemyPieces {
            if enemyChecks >= maxEnemyChecks { break }
            enemyChecks += 1
            
            // Check if enemy piece can attack the pawn's destination
            if canPieceAttackPosition(piece: enemyPiece, targetPosition: move.to) {
                let enemyValue = pieceValues[enemyPiece.type] ?? 0
                
                // Higher penalty for being attacked by more valuable pieces
                if enemyValue >= 3 { // Queen, rook, bishop
                    riskScore -= 200 // High risk for being attacked by valuable pieces
                    print("🤖 AI PAWN RISK: Pawn at \(move.to.stringValue) can be captured by \(enemyPiece.type.rawValue) (value: \(enemyValue))")
                } else if enemyValue == 1 { // Pawn
                    riskScore -= 50 // Lower risk for pawn attacks
                } else { // Knight
                    riskScore -= 100 // Medium risk for knight attacks
                }
            }
        }
        
        // Bonus if pawn is protected by friendly pieces (limited check)
        let friendlyColor = piece.color
        let friendlyPieces = board.getPieces(of: friendlyColor)
        
        let maxFriendlyChecks = 5
        var friendlyChecks = 0
        
        for friendlyPiece in friendlyPieces {
            if friendlyChecks >= maxFriendlyChecks { break }
            friendlyChecks += 1
            
            if friendlyPiece.type != .pawn && canPieceAttackPosition(piece: friendlyPiece, targetPosition: move.to) {
                let friendlyValue = pieceValues[friendlyPiece.type] ?? 0
                riskScore += friendlyValue * 10 // Bonus for protection by valuable pieces
                print("🤖 AI PAWN PROTECTION: Pawn at \(move.to.stringValue) protected by \(friendlyPiece.type.rawValue)")
            }
        }
        
        return riskScore
    }
    
    private func evaluateCaptureRiskForMove(_ move: ChessMove3D, piece: ChessPiece3D, board: ChessBoard3D) -> Int {
        var riskScore = 0
        let pieceValue = pieceValues[piece.type] ?? 0
        
        // Only evaluate capture risk for valuable pieces (knight and above)
        if pieceValue >= 3 {
            let enemyColor = piece.color == .white ? PieceColor.black : PieceColor.white
            let enemyPieces = board.getPieces(of: enemyColor)
            
            // Limit evaluation to prevent timeout
            let maxEnemyChecks = 8
            var enemyChecks = 0
            
            for enemyPiece in enemyPieces {
                if enemyChecks >= maxEnemyChecks { break }
                enemyChecks += 1
                
                // Check if enemy piece can attack the destination square
                if canPieceAttackPosition(piece: enemyPiece, targetPosition: move.to) {
                    let enemyValue = pieceValues[enemyPiece.type] ?? 0
                    
                    // If enemy piece is less valuable, this is a bad trade
                    if enemyValue < pieceValue {
                        riskScore -= (pieceValue - enemyValue) * 50 // Heavy penalty for losing material
                        print("🤖 AI CAPTURE RISK: \(piece.type.rawValue) (value: \(pieceValue)) can be captured by \(enemyPiece.type.rawValue) (value: \(enemyValue))")
                    }
                }
            }
        }
        
        return riskScore
    }
    
    // MARK: - Strategy-Specific Evaluations
    
    private func evaluateAggressiveMove(_ move: ChessMove3D, piece: ChessPiece3D, board: ChessBoard3D) -> Int {
        var score = 0
        
        // Aggressive strategy focuses on attacking and piece development
        if piece.type == .pawn {
            // Pawn advancement toward opponent
            if aiColor == .white {
                score += move.to.rank * 20
            } else {
                score += (7 - move.to.rank) * 20
            }
        } else {
            // Piece development and attacking
            score += evaluatePieceDevelopment(move, piece: piece, board: board)
            score += evaluateAttackOpportunity(move, piece: piece, board: board)
        }
        
        return score
    }
    
    private func evaluateDefensiveMove(_ move: ChessMove3D, piece: ChessPiece3D, board: ChessBoard3D) -> Int {
        var score = 0
        
        // Defensive strategy focuses on king safety and solid structure
        if piece.type == .pawn {
            // Solid pawn structure
            score += evaluatePawnStructure(move, board: board)
            score += evaluateKingProtection(move, board: board)
        } else {
            // Defensive piece placement
            score += evaluateDefensivePlacement(move, piece: piece, board: board)
        }
        
        // CRITICAL: King safety is paramount
        if piece.type == .king {
            score += evaluateKingSafety(move, board: board)
        }
        
        return score
    }
    
    private func evaluatePositionalMove(_ move: ChessMove3D, piece: ChessPiece3D, board: ChessBoard3D) -> Int {
        var score = 0
        
        // Positional strategy focuses on center control and coordination
        score += evaluateCenterControl(move, board: board)
        score += evaluatePieceCoordination(move, piece: piece, board: board)
        score += evaluatePositionalAdvantage(move, piece: piece, board: board)
        
        return score
    }
    
    private func evaluateTacticalMove(_ move: ChessMove3D, piece: ChessPiece3D, board: ChessBoard3D) -> Int {
        var score = 0
        
        // Tactical strategy focuses on immediate opportunities
        if move.capturedPiece != nil {
            // CRITICAL: Evaluate if the capture is advantageous
            if let capturedPiece = move.capturedPiece {
                let captureValue = pieceValues[capturedPiece.type] ?? 0
                let ourPieceValue = pieceValues[piece.type] ?? 0
                
                if captureValue >= ourPieceValue {
                    score += 100 // Good capture
                } else {
                    score += 20 // Risky capture
                }
            }
        }
        
        // CRITICAL: Check if this move creates a threat
        if createsThreat(move, piece: piece, board: board) {
            score += 40
        }
        
        score += evaluateTacticalOpportunity(move, piece: piece, board: board)
        score += evaluateForkOpportunity(move, piece: piece, board: board)
        score += evaluatePinOpportunity(move, piece: piece, board: board)
        
        return score
    }
    
    private func evaluateEndgameMove(_ move: ChessMove3D, piece: ChessPiece3D, board: ChessBoard3D) -> Int {
        var score = 0
        
        // Endgame strategy focuses on pawn advancement and king activity
        if piece.type == .pawn {
            score += evaluatePawnAdvancement(move, board: board)
            score += evaluatePassedPawn(move, board: board)
        } else if piece.type == .king {
            score += evaluateKingActivity(move, board: board)
        }
        
        return score
    }
    
    // MARK: - Helper Evaluation Functions
    
    private func evaluatePieceDevelopment(_ move: ChessMove3D, piece: ChessPiece3D, board: ChessBoard3D) -> Int {
        var score = 0
        
        // Bonus for developing pieces from back rank
        if (aiColor == .white && move.from.rank == 0) || (aiColor == .black && move.from.rank == 7) {
            score += 15
        }
        
        // Bonus for controlling center squares
        if move.to.file >= 2 && move.to.file <= 5 && move.to.rank >= 2 && move.to.rank <= 5 {
            score += 10
        }
        
        return score
    }
    
    private func evaluateAttackOpportunity(_ move: ChessMove3D, piece: ChessPiece3D, board: ChessBoard3D) -> Int {
        var score = 0
        
        // Check if this move attacks opponent pieces
        let opponentColor: PieceColor = aiColor == .white ? .black : .white
        let opponentPieces = board.getPieces(of: opponentColor)
        
        for opponentPiece in opponentPieces {
            let distance = abs(move.to.file - opponentPiece.position.file) + abs(move.to.rank - opponentPiece.position.rank)
            if distance <= 2 {
                score += 5 // Bonus for being near opponent pieces
            }
        }
        
        return score
    }
    
    private func evaluatePawnStructure(_ move: ChessMove3D, board: ChessBoard3D) -> Int {
        var score = 0
        
        // Check for pawn chains
        if formsPawnChain(move, board: board) {
            score += 15
        }
        
        // Avoid isolated pawns
        if createsIsolatedPawn(move, board: board) {
            score -= 20
        }
        
        return score
    }
    
    private func evaluateKingProtection(_ move: ChessMove3D, board: ChessBoard3D) -> Int {
        var score = 0
        
        if protectsKing(move, board: board) {
            score += 20
        }
        
        return score
    }
    
    private func evaluateDefensivePlacement(_ move: ChessMove3D, piece: ChessPiece3D, board: ChessBoard3D) -> Int {
        var score = 0
        
        // Prefer defensive positions
        if piece.type == .bishop || piece.type == .rook {
            // Keep pieces near king for protection
            let kingPosition = findKingPosition(board: board)
            if let kingPos = kingPosition {
                let distanceToKing = abs(move.to.file - kingPos.file) + abs(move.to.rank - kingPos.rank)
                if distanceToKing <= 3 {
                    score += 10
                }
            }
        }
        
        return score
    }
    
    private func evaluateCenterControl(_ move: ChessMove3D, board: ChessBoard3D) -> Int {
        var score = 0
        
        // Bonus for controlling center in 3D
        // 2D center control
        if move.to.file >= 2 && move.to.file <= 5 && move.to.rank >= 2 && move.to.rank <= 5 {
            score += 15
        }
        
        // 3D center control - prefer middle Z levels
        if move.to.z >= 1 && move.to.z <= 2 {
            score += 10
        }
        
        // Bonus for controlling multiple Z levels
        if move.to.z == 1 {
            score += 5 // Middle level is valuable
        }
        
        return score
    }
    
    private func evaluatePieceCoordination(_ move: ChessMove3D, piece: ChessPiece3D, board: ChessBoard3D) -> Int {
        var score = 0
        
        // Check if this move coordinates with other pieces
        let friendlyPieces = board.getPieces(of: aiColor)
        
        for friendlyPiece in friendlyPieces {
            if friendlyPiece.position != move.from {
                let distance = abs(move.to.file - friendlyPiece.position.file) + abs(move.to.rank - friendlyPiece.position.rank)
                if distance <= 3 {
                    score += 5 // Bonus for piece coordination
                }
            }
        }
        
        return score
    }
    
    private func evaluatePositionalAdvantage(_ move: ChessMove3D, piece: ChessPiece3D, board: ChessBoard3D) -> Int {
        var score = 0
        
        // Evaluate positional factors based on piece type
        switch piece.type {
        case .knight, .bishop:
            // Prefer good squares for minor pieces
            score += evaluateMinorPieceSquare(move, piece: piece)
        case .rook:
            // Prefer open files and ranks
            score += evaluateRookPlacement(move, board: board)
        case .queen:
            // Prefer safe but active positions
            score += evaluateQueenPlacement(move, board: board)
        default:
            break
        }
        
        return score
    }
    
    private func evaluateTacticalOpportunity(_ move: ChessMove3D, piece: ChessPiece3D, board: ChessBoard3D) -> Int {
        var score = 0
        
        // Check for tactical opportunities
        if move.capturedPiece != nil {
            score += 30 // Capture bonus
        }
        
        // Check for discovered attacks
        if createsDiscoveredAttack(move, board: board) {
            score += 20
        }
        
        return score
    }
    
    private func evaluateForkOpportunity(_ move: ChessMove3D, piece: ChessPiece3D, board: ChessBoard3D) -> Int {
        var score = 0
        
        // Check if this move creates a fork
        if createsFork(move, piece: piece, board: board) {
            score += 25
        }
        
        return score
    }
    
    private func evaluatePinOpportunity(_ move: ChessMove3D, piece: ChessPiece3D, board: ChessBoard3D) -> Int {
        var score = 0
        
        // Check if this move creates a pin
        if createsPin(move, piece: piece, board: board) {
            score += 20
        }
        
        return score
    }
    
    private func evaluatePawnAdvancement(_ move: ChessMove3D, board: ChessBoard3D) -> Int {
        var score = 0
        
        // Strong bonus for pawn advancement in endgame
        if aiColor == .white {
            score += move.to.rank * 25
        } else {
            score += (7 - move.to.rank) * 25
        }
        
        return score
    }
    
    private func evaluatePassedPawn(_ move: ChessMove3D, board: ChessBoard3D) -> Int {
        var score = 0
        
        if isPassedPawn(move, board: board) {
            score += 40 // Strong bonus for passed pawns in endgame
        }
        
        return score
    }
    
    private func evaluateKingActivity(_ move: ChessMove3D, board: ChessBoard3D) -> Int {
        var score = 0
        
        // Encourage king activity in endgame
        if gamePhase == .endgame {
            score += 15
        }
        
        return score
    }
    
    private func evaluateGamePhaseAdjustments(_ move: ChessMove3D, piece: ChessPiece3D, board: ChessBoard3D) -> Int {
        var score = 0
        
        switch gamePhase {
        case .opening:
            // Focus on development and center control
            score += evaluatePieceDevelopment(move, piece: piece, board: board)
        case .middlegame:
            // Focus on tactical opportunities and piece coordination
            score += evaluateTacticalOpportunity(move, piece: piece, board: board)
            score += evaluatePieceCoordination(move, piece: piece, board: board)
        case .endgame:
            // Focus on pawn advancement and king activity
            if piece.type == .pawn {
                score += evaluatePawnAdvancement(move, board: board)
            } else if piece.type == .king {
                score += evaluateKingActivity(move, board: board)
            }
        }
        
        return score
    }
    
    // MARK: - Additional Helper Functions
    
    private func evaluateMinorPieceSquare(_ move: ChessMove3D, piece: ChessPiece3D) -> Int {
        var score = 0
        
        // Knights prefer center squares
        if piece.type == .knight {
            if move.to.file >= 2 && move.to.file <= 5 && move.to.rank >= 2 && move.to.rank <= 5 {
                score += 10
            }
        }
        
        // Bishops prefer long diagonals
        if piece.type == .bishop {
            let diagonalLength = min(move.to.file, move.to.rank) + min(7 - move.to.file, 7 - move.to.rank)
            score += diagonalLength * 2
        }
        
        return score
    }
    
    private func evaluateRookPlacement(_ move: ChessMove3D, board: ChessBoard3D) -> Int {
        var score = 0
        
        // Rooks prefer open files and ranks
        let filePieces = countPiecesInFile(move.to.file, board: board)
        let rankPieces = countPiecesInRank(move.to.rank, board: board)
        
        if filePieces <= 2 {
            score += 10 // Open file bonus
        }
        
        if rankPieces <= 2 {
            score += 10 // Open rank bonus
        }
        
        return score
    }
    
    private func evaluateQueenPlacement(_ move: ChessMove3D, board: ChessBoard3D) -> Int {
        var score = 0
        
        // Queens prefer safe but active positions
        if !isEasilyCapturable(move, board: board) {
            score += 15
        }
        
        // Bonus for attacking opportunities
        score += evaluateAttackOpportunity(move, piece: ChessPiece3D(type: .queen, color: aiColor, position: move.to), board: board)
        
        return score
    }
    
    private func createsDiscoveredAttack(_ move: ChessMove3D, board: ChessBoard3D) -> Bool {
        // Simplified check for discovered attacks
        // In a full implementation, this would check if moving this piece reveals an attack
        return false // Placeholder
    }
    
    private func createsFork(_ move: ChessMove3D, piece: ChessPiece3D, board: ChessBoard3D) -> Bool {
        // Simplified check for forks
        // In a full implementation, this would check if this move attacks multiple pieces
        return false // Placeholder
    }
    
    private func createsPin(_ move: ChessMove3D, piece: ChessPiece3D, board: ChessBoard3D) -> Bool {
        // Simplified check for pins
        // In a full implementation, this would check if this move pins an opponent piece
        return false // Placeholder
    }
    
    private func countPiecesInFile(_ file: Int, board: ChessBoard3D) -> Int {
        var count = 0
        for rank in 0..<8 {
            let position = ChessPosition3D(file: file, rank: rank, z: 0)
            if board.getPiece(at: position) != nil {
                count += 1
            }
        }
        return count
    }
    
    private func countPiecesInRank(_ rank: Int, board: ChessBoard3D) -> Int {
        var count = 0
        for file in 0..<8 {
            let position = ChessPosition3D(file: file, rank: rank, z: 0)
            if board.getPiece(at: position) != nil {
                count += 1
            }
        }
        return count
    }
    
    private func updateGamePhase() {
        let moveCount = moveHistory.count
        if moveCount < 15 {
            gamePhase = .opening
        } else if moveCount < 40 {
            gamePhase = .middlegame
        } else {
            gamePhase = .endgame
        }
    }
    
    // MARK: - Defensive and Anti-Repetitive Logic
    
    private func isDefensiveMove(_ move: ChessMove3D, piece: ChessPiece3D, board: ChessBoard3D) -> Bool {
        // Check if this move saves a piece from being captured
        let fromPosition = move.from
        
        // Check if the piece was under attack at its original position
        if isPieceUnderAttack(fromPosition, board: board) {
            return true
        }
        
        // Check if this move blocks an attack on another piece
        if blocksAttackOnPiece(move, board: board) {
            return true
        }
        
        return false
    }
    
    private func preventsCapture(_ move: ChessMove3D, piece: ChessPiece3D, board: ChessBoard3D) -> Bool {
        // Check if this move prevents an opponent from capturing our pieces
        let opponentColor: PieceColor = aiColor == .white ? .black : .white
        let opponentPieces = board.getPieces(of: opponentColor)
        
        for opponentPiece in opponentPieces {
            // Check if opponent can capture our piece after this move
            if canPieceCapture(opponentPiece, targetPosition: move.to, board: board) {
                return false // This move doesn't prevent capture
            }
        }
        
        return true
    }
    
    private func putsPieceInDanger(_ move: ChessMove3D, piece: ChessPiece3D, board: ChessBoard3D) -> Bool {
        // Check if this move puts our piece in danger in 3D
        let opponentColor: PieceColor = aiColor == .white ? .black : .white
        let opponentPieces = board.getPieces(of: opponentColor)
        
        for opponentPiece in opponentPieces {
            if canPieceCapture(opponentPiece, targetPosition: move.to, board: board) {
                return true
            }
        }
        
        // CRITICAL: Check for 3D threats (pieces that can attack from different Z levels)
        if isVulnerableTo3DAttack(move.to, board: board) {
            return true
        }
        
        return false
    }
    
    private func isVulnerableTo3DAttack(_ position: ChessPosition3D, board: ChessBoard3D) -> Bool {
        // Check if a position is vulnerable to attacks from different Z levels
        let opponentColor: PieceColor = aiColor == .white ? .black : .white
        let opponentPieces = board.getPieces(of: opponentColor)
        
        for opponentPiece in opponentPieces {
            // Check for vertical attacks (same file/rank, different Z)
            if opponentPiece.position.file == position.file &&
                opponentPiece.position.rank == position.rank &&
                opponentPiece.position.z != position.z {
                return true
            }
            
            // Check for 3D diagonal attacks
            let fileDiff = abs(opponentPiece.position.file - position.file)
            let rankDiff = abs(opponentPiece.position.rank - position.rank)
            let zDiff = abs(opponentPiece.position.z - position.z)
            
            if (fileDiff == rankDiff && rankDiff == zDiff) || // 3D diagonal
                (fileDiff == zDiff && rankDiff == 0) || // File-Z diagonal
                (rankDiff == zDiff && fileDiff == 0) { // Rank-Z diagonal
                return true
            }
        }
        
        return false
    }
    
    private func isRepetitiveMove(_ move: ChessMove3D) -> Bool {
        // Check if this move is repetitive (like moving rook back and forth)
        guard moveHistory.count >= 2 else { return false }
        
        let lastMove = moveHistory[moveHistory.count - 1]
        let secondLastMove = moveHistory[moveHistory.count - 2]
        
        // Check if this move reverses the last move
        if move.from == lastMove.to && move.to == lastMove.from {
            return true
        }
        
        // Check if this is the same piece moving between the same squares
        if move.from == secondLastMove.to && move.to == secondLastMove.from {
            return true
        }
        
        return false
    }
    
    // MARK: - High-Value Piece Protection
    
    private func isHighValuePiece(_ pieceType: PieceType) -> Bool {
        // Queen, rooks, and bishops are high-value pieces that need protection
        return pieceType == .queen || pieceType == .rook || pieceType == .bishop
    }
    
    private func evaluateHighValuePieceDefense(_ move: ChessMove3D, piece: ChessPiece3D, board: ChessBoard3D) -> Int {
        var score = 0
        let pieceValue = pieceValues[piece.type] ?? 0
        
        // Check if the piece is currently under attack
        if isPieceUnderAttack(move.from, board: board) {
            let attackerValue = getHighestAttackerValue(at: move.from, board: board)
            
            // If a low-value piece (pawn, knight) is attacking a high-value piece, this is critical
            if attackerValue < pieceValue {
                score += 2000 // Massive bonus for escaping from low-value attackers
                print("🤖 AI CRITICAL ESCAPE: \(piece.type.rawValue) escaping from \(attackerValue)-value attacker")
            } else {
                score += 500 // Good bonus for escaping from equal/higher value attackers
            }
        }
        
        // Check if the move destination is safer than current position
        let currentDanger = calculatePositionDanger(move.from, board: board)
        let destinationDanger = calculatePositionDanger(move.to, board: board)
        
        if destinationDanger < currentDanger {
            score += (currentDanger - destinationDanger) * 100 // Bonus for moving to safer position
            print("🤖 AI SAFETY IMPROVEMENT: \(piece.type.rawValue) moving from danger \(currentDanger) to \(destinationDanger)")
        } else if destinationDanger > currentDanger {
            score -= (destinationDanger - currentDanger) * 200 // Penalty for moving to more dangerous position
            print("🤖 AI DANGER INCREASE: \(piece.type.rawValue) moving to more dangerous position")
        }
        
        // Special protection for queen - she should be very defensive
        if piece.type == .queen {
            if isQueenUnderThreat(move.from, board: board) {
                score += 3000 // Massive bonus for queen escaping threats
                print("🤖 AI QUEEN PROTECTION: Queen escaping threat")
            }
            
            // Penalty for moving queen to exposed positions
            if isPositionExposed(move.to, board: board) {
                score -= 1000 // Heavy penalty for exposing queen
                print("🤖 AI QUEEN EXPOSURE: Penalty for exposing queen")
            }
        }
        
        return score
    }
    
    private func isPieceUnderAttack(_ position: ChessPosition3D, board: ChessBoard3D) -> Bool {
        let opponentColor: PieceColor = aiColor == .white ? .black : .white
        let opponentPieces = board.getPieces(of: opponentColor)
        
        for opponentPiece in opponentPieces {
            if canPieceCapture(opponentPiece, targetPosition: position, board: board) {
                return true
            }
        }
        return false
    }
    
    private func getHighestAttackerValue(at position: ChessPosition3D, board: ChessBoard3D) -> Int {
        let opponentColor: PieceColor = aiColor == .white ? .black : .white
        let opponentPieces = board.getPieces(of: opponentColor)
        var highestValue = 0
        
        for opponentPiece in opponentPieces {
            if canPieceCapture(opponentPiece, targetPosition: position, board: board) {
                let value = pieceValues[opponentPiece.type] ?? 0
                if value > highestValue {
                    highestValue = value
                }
            }
        }
        return highestValue
    }
    
    private func calculatePositionDanger(_ position: ChessPosition3D, board: ChessBoard3D) -> Int {
        let opponentColor: PieceColor = aiColor == .white ? .black : .white
        let opponentPieces = board.getPieces(of: opponentColor)
        var danger = 0
        
        for opponentPiece in opponentPieces {
            if canPieceCapture(opponentPiece, targetPosition: position, board: board) {
                danger += pieceValues[opponentPiece.type] ?? 0
            }
        }
        return danger
    }
    
    private func isQueenUnderThreat(_ position: ChessPosition3D, board: ChessBoard3D) -> Bool {
        // Check if queen is under immediate threat from any piece
        return isPieceUnderAttack(position, board: board)
    }
    
    private func isPositionExposed(_ position: ChessPosition3D, board: ChessBoard3D) -> Bool {
        // Check if a position is exposed (can be attacked by multiple pieces)
        let opponentColor: PieceColor = aiColor == .white ? .black : .white
        let opponentPieces = board.getPieces(of: opponentColor)
        var attackCount = 0
        
        for opponentPiece in opponentPieces {
            if canPieceCapture(opponentPiece, targetPosition: position, board: board) {
                attackCount += 1
                if attackCount >= 2 { // Exposed if 2 or more pieces can attack
                    return true
                }
            }
        }
        return false
    }
    
    private func canPieceCapture(_ piece: ChessPiece3D, targetPosition: ChessPosition3D, board: ChessBoard3D) -> Bool {
        // Check if a piece can capture at the target position
        let moves = board.getValidMoves(for: piece, checkEnPassant: false)
        return moves.contains { $0.to == targetPosition }
    }
    

    
    private func blocksAttackOnPiece(_ move: ChessMove3D, board: ChessBoard3D) -> Bool {
        // Check if this move blocks an attack on another piece
        let friendlyPieces = board.getPieces(of: aiColor)
        
        for friendlyPiece in friendlyPieces {
            if friendlyPiece.position != move.from && isPieceUnderAttack(friendlyPiece.position, board: board) {
                // Check if this move blocks the attack
                if blocksAttackPath(move, targetPiece: friendlyPiece, board: board) {
                    return true
                }
            }
        }
        
        return false
    }
    

    
    private func blocksAttackPath(_ move: ChessMove3D, targetPiece: ChessPiece3D, board: ChessBoard3D) -> Bool {
        // Simplified check - in a full implementation, this would check if the move blocks the attack path
        // For now, just check if the move is between the attacker and target
        return false // Placeholder
    }
    
    private func createsThreat(_ move: ChessMove3D, piece: ChessPiece3D, board: ChessBoard3D) -> Bool {
        // Check if this move creates a threat against opponent pieces
        let opponentColor: PieceColor = aiColor == .white ? .black : .white
        let opponentPieces = board.getPieces(of: opponentColor)
        
        for opponentPiece in opponentPieces {
            if canPieceCapture(piece, targetPosition: opponentPiece.position, board: board) {
                return true
            }
        }
        
        return false
    }
    
    private func evaluate3DPositioning(_ move: ChessMove3D, piece: ChessPiece3D, board: ChessBoard3D) -> Int {
        var score = 0
        
        // Bonus for controlling multiple Z levels
        if move.to.z == 1 {
            score += 15 // Middle level is most valuable
        } else if move.to.z == 0 || move.to.z == 2 {
            score += 10 // Outer levels are good
        }
        
        // Bonus for pieces that can attack in multiple dimensions
        switch piece.type {
        case .queen:
            // Queens are most valuable in 3D - they can attack in all directions
            score += 20
        case .bishop:
            // Bishops are valuable in 3D - they can attack diagonally in 3D
            score += 15
        case .rook:
            // Rooks are valuable in 3D - they can attack in straight lines in 3D
            score += 12
        case .knight:
            // Knights are valuable in 3D - they can make 3D L-shaped moves
            score += 10
        case .pawn:
            // Pawns are less valuable in 3D positioning
            score += 5
        case .king:
            // Kings prefer safe positions
            score += 8
        }
        
        // Bonus for controlling vertical space
        if controlsVerticalSpace(move.to, board: board) {
            score += 10
        }
        
        // Bonus for avoiding being pinned vertically
        if !isVerticallyPinned(move.to, board: board) {
            score += 8
        }
        
        return score
    }
    
    private func controlsVerticalSpace(_ position: ChessPosition3D, board: ChessBoard3D) -> Bool {
        // Check if this position controls vertical space (can attack up and down)
        let friendlyPieces = board.getPieces(of: aiColor)
        
        for piece in friendlyPieces {
            if piece.position.file == position.file && piece.position.rank == position.rank {
                // We have a piece in the same vertical line
                return true
            }
        }
        
        return false
    }
    
    private func isVerticallyPinned(_ position: ChessPosition3D, board: ChessBoard3D) -> Bool {
        // Check if this position is pinned vertically (can't move up/down)
        let opponentColor: PieceColor = aiColor == .white ? .black : .white
        let opponentPieces = board.getPieces(of: opponentColor)
        
        for opponentPiece in opponentPieces {
            // Check if opponent has pieces above and below this position
            if opponentPiece.position.file == position.file && opponentPiece.position.rank == position.rank {
                if opponentPiece.position.z < position.z && opponentPiece.position.z > position.z {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func evaluateKingSafety(_ move: ChessMove3D, board: ChessBoard3D) -> Int {
        var score = 0
        
        // CRITICAL: King should stay near the back rank and avoid center
        if aiColor == .white {
            // White king prefers back rank (rank 0) and should avoid center
            if move.to.rank == 0 {
                score += 50 // Strong preference for back rank
            } else if move.to.rank <= 1 {
                score += 30 // Good for staying near back
            } else if move.to.rank >= 3 {
                score -= 40 // Penalty for moving too far forward
            }
        } else {
            // Black king prefers back rank (rank 7) and should avoid center
            if move.to.rank == 7 {
                score += 50 // Strong preference for back rank
            } else if move.to.rank >= 6 {
                score += 30 // Good for staying near back
            } else if move.to.rank <= 4 {
                score -= 40 // Penalty for moving too far forward
            }
        }
        
        // CRITICAL: Avoid center files (files 2-5) for king
        if move.to.file >= 2 && move.to.file <= 5 {
            score -= 30 // Penalty for moving to center files
        }
        
        // CRITICAL: Prefer corner positions for king safety
        if (move.to.file == 0 || move.to.file == 7) && (move.to.rank == 0 || move.to.rank == 7) {
            score += 20 // Bonus for corner positions
        }
        
        // CRITICAL: Check if this move puts king in danger
        if putsPieceInDanger(move, piece: ChessPiece3D(type: .king, color: aiColor, position: move.to), board: board) {
            score -= 100 // Heavy penalty for dangerous king moves
        }
        
        // CRITICAL: Check if this move exposes king to multiple attackers
        let attackerCount = countAttackersOnPosition(move.to, board: board)
        if attackerCount > 1 {
            score -= attackerCount * 25 // Penalty for each attacker
        }
        
        return score
    }
    
    private func countAttackersOnPosition(_ position: ChessPosition3D, board: ChessBoard3D) -> Int {
        var count = 0
        let opponentColor: PieceColor = aiColor == .white ? .black : .white
        let opponentPieces = board.getPieces(of: opponentColor)
        
        for opponentPiece in opponentPieces {
            if canPieceCapture(opponentPiece, targetPosition: position, board: board) {
                count += 1
            }
        }
        
        return count
    }
    
    private func checkIfMoveBlocksPawns(_ move: ChessMove3D, board: ChessBoard3D) -> Int {
        var penalty = 0
        let toPosition = move.to
        
        // Check if this move blocks friendly pawns in adjacent files
        for fileOffset in [-1, 1] {
            let adjacentFile = toPosition.file + fileOffset
            if adjacentFile >= 0 && adjacentFile <= 7 {
                let adjacentPosition = ChessPosition3D(file: adjacentFile, rank: toPosition.rank, z: toPosition.z)
                if let adjacentPiece = board.getPiece(at: adjacentPosition),
                   adjacentPiece.type == .pawn && adjacentPiece.color == aiColor {
                    penalty += 10 // Blocking a friendly pawn
                }
            }
        }
        
        return penalty
    }
    
    private func isPassedPawn(_ move: ChessMove3D, board: ChessBoard3D) -> Bool {
        let toPosition = move.to
        
        // Check if there are any opponent pawns that can block this pawn
        for file in 0..<8 {
            if file == toPosition.file { continue } // Same file
            
            for rank in 0..<8 {
                let checkPosition = ChessPosition3D(file: file, rank: rank, z: toPosition.z)
                if let piece = board.getPiece(at: checkPosition),
                   piece.type == .pawn && piece.color != aiColor {
                    // Check if this opponent pawn can reach our pawn's path
                    if canOpponentPawnBlock(checkPosition, targetPosition: toPosition, board: board) {
                        return false
                    }
                }
            }
        }
        
        return true
    }
    
    private func canOpponentPawnBlock(_ pawnPosition: ChessPosition3D, targetPosition: ChessPosition3D, board: ChessBoard3D) -> Bool {
        // Simplified check - in a real implementation, this would be more complex
        // For now, just check if the opponent pawn is in a position to block
        let rankDiff = targetPosition.rank - pawnPosition.rank
        
        if aiColor == .white {
            return rankDiff > 0 && abs(targetPosition.file - pawnPosition.file) <= 1
        } else {
            return rankDiff < 0 && abs(targetPosition.file - pawnPosition.file) <= 1
        }
    }
    
    private func isEasilyCapturable(_ move: ChessMove3D, board: ChessBoard3D) -> Bool {
        let toPosition = move.to
        
        // Check if opponent pieces can easily capture this pawn
        for fileOffset in [-1, 1] {
            let adjacentFile = toPosition.file + fileOffset
            if adjacentFile >= 0 && adjacentFile <= 7 {
                let adjacentPosition = ChessPosition3D(file: adjacentFile, rank: toPosition.rank, z: toPosition.z)
                if let adjacentPiece = board.getPiece(at: adjacentPosition),
                   adjacentPiece.color != aiColor {
                    return true // Adjacent opponent piece can capture
                }
            }
        }
        
        return false
    }
    
    private func formsPawnChain(_ move: ChessMove3D, board: ChessBoard3D) -> Bool {
        let toPosition = move.to
        
        // Check if this move creates a pawn chain (connected pawns)
        for fileOffset in [-1, 1] {
            let adjacentFile = toPosition.file + fileOffset
            if adjacentFile >= 0 && adjacentFile <= 7 {
                let adjacentPosition = ChessPosition3D(file: adjacentFile, rank: toPosition.rank, z: toPosition.z)
                if let adjacentPiece = board.getPiece(at: adjacentPosition),
                   adjacentPiece.type == .pawn && adjacentPiece.color == aiColor {
                    return true // Connected to another pawn
                }
            }
        }
        return false
    }
    
    private func protectsKing(_ move: ChessMove3D, board: ChessBoard3D) -> Bool {
        let toPosition = move.to
        
        // Find our king
        let kingPosition = findKingPosition(board: board)
        guard let kingPos = kingPosition else { return false }
        
        // Check if this pawn move protects the king
        let distanceToKing = abs(toPosition.file - kingPos.file) + abs(toPosition.rank - kingPos.rank)
        return distanceToKing <= 2 // Within 2 squares of king
    }
    
    private func attacksOpponentKing(_ move: ChessMove3D, board: ChessBoard3D) -> Bool {
        let toPosition = move.to
        
        // Find opponent's king
        let opponentColor: PieceColor = aiColor == .white ? .black : .white
        let kingPosition = findKingPosition(board: board, color: opponentColor)
        guard let kingPos = kingPosition else { return false }
        
        // Check if this move advances toward opponent's king
        let distanceToOpponentKing = abs(toPosition.file - kingPos.file) + abs(toPosition.rank - kingPos.rank)
        return distanceToOpponentKing <= 3 // Within 3 squares of opponent king
    }
    
    private func createsIsolatedPawn(_ move: ChessMove3D, board: ChessBoard3D) -> Bool {
        let toPosition = move.to
        
        // Check if this move creates an isolated pawn (no friendly pawns in adjacent files)
        var hasAdjacentPawns = false
        for fileOffset in [-1, 1] {
            let adjacentFile = toPosition.file + fileOffset
            if adjacentFile >= 0 && adjacentFile <= 7 {
                // Check if there are any friendly pawns in adjacent files
                for rank in 0..<8 {
                    let checkPosition = ChessPosition3D(file: adjacentFile, rank: rank, z: toPosition.z)
                    if let piece = board.getPiece(at: checkPosition),
                       piece.type == .pawn && piece.color == aiColor {
                        hasAdjacentPawns = true
                        break
                    }
                }
            }
        }
        return !hasAdjacentPawns
    }
    
    private func opensPosition(_ move: ChessMove3D, board: ChessBoard3D) -> Bool {
        let toPosition = move.to
        
        // Check if this move opens up the position for other pieces
        // This is a simplified check - in reality, it would analyze piece mobility
        let centerFiles = [3, 4] // d and e files
        return centerFiles.contains(toPosition.file)
    }
    
    private func findKingPosition(board: ChessBoard3D, color: PieceColor? = nil) -> ChessPosition3D? {
        let targetColor = color ?? aiColor
        
        for (position, piece) in board.pieces {
            if piece.type == .king && piece.color == targetColor {
                return position
            }
        }
        return nil
    }
    
    // MARK: - Learning Methods
    func recordMove(_ move: ChessMove3D) {
        moveHistory.append(move)
        updateMoveTracking(for: move)
        print("🤖 AI learning: Recorded move \(move.from.stringValue) -> \(move.to.stringValue)")
    }
    
    func recordGameOutcome(_ outcome: GameOutcome) {
        gameOutcomes.append(outcome)
        print("🤖 AI learning: Game ended with \(outcome)")
        
        // Adjust strategy weights based on outcome
        adjustStrategyWeights(outcome: outcome)
    }
    
    private func adjustStrategyWeights(outcome: GameOutcome) {
        let learningRate = 0.1
        
        switch outcome {
        case .win:
            // Reinforce successful strategies
            for key in strategyWeights.keys {
                strategyWeights[key] = min(strategyWeights[key]! * (1 + learningRate), 2.0)
            }
            print("🤖 AI learning: Reinforcing strategies after win")
            
        case .loss:
            // Reduce weights of strategies that led to loss
            for key in strategyWeights.keys {
                strategyWeights[key] = max(strategyWeights[key]! * (1 - learningRate), 0.1)
            }
            print("🤖 AI learning: Reducing strategy weights after loss")
            
        case .draw:
            // Slight adjustment for draws
            for key in strategyWeights.keys {
                strategyWeights[key] = strategyWeights[key]! * (1 + learningRate * 0.1)
            }
            print("🤖 AI learning: Minor adjustment after draw")
            
        case .ongoing:
            break // No adjustment for ongoing games
        }
        
        // Print current strategy weights
        print("🤖 AI learning: Current strategy weights:")
        for (strategy, weight) in strategyWeights {
            print("  - \(strategy): \(weight)")
        }
        
        // Save updated weights to persistent storage
        saveLearningData()
    }
    
    private func applyLearningToEvaluation(_ baseScore: Int, move: ChessMove3D) -> Int {
        var adjustedScore = Double(baseScore)
        
        // Apply learned weights to different aspects of the move
        if move.to.rank > move.from.rank && aiColor == .white {
            adjustedScore *= strategyWeights["advancement"]!
        }
        if move.to.file >= 2 && move.to.file <= 5 {
            adjustedScore *= strategyWeights["center_control"]!
        }
        if checkIfMoveBlocksPawns(move, board: getBoard()!) == 0 {
            adjustedScore *= strategyWeights["pawn_structure"]!
        }
        if isPassedPawn(move, board: getBoard()!) {
            adjustedScore *= strategyWeights["passed_pawn"]!
        }
        if !isEasilyCapturable(move, board: getBoard()!) {
            adjustedScore *= strategyWeights["safety"]!
        }
        if formsPawnChain(move, board: getBoard()!) {
            adjustedScore *= strategyWeights["pawn_chain"]!
        }
        if protectsKing(move, board: getBoard()!) {
            adjustedScore *= strategyWeights["king_protection"]!
        }
        if attacksOpponentKing(move, board: getBoard()!) {
            adjustedScore *= strategyWeights["opponent_attack"]!
        }
        if !createsIsolatedPawn(move, board: getBoard()!) {
            adjustedScore *= strategyWeights["isolation_avoidance"]!
        }
        if opensPosition(move, board: getBoard()!) {
            adjustedScore *= strategyWeights["position_opening"]!
        }
        
        return Int(adjustedScore)
    }
    
    // MARK: - Position Evaluation
    
    private func evaluatePosition() -> Int {
        var score = 0
        
        // Material evaluation
        score += evaluateMaterial()
        
        // Position evaluation
        score += evaluatePositionalAdvantage()
        
        // Mobility evaluation
        score += evaluateMobility()
        
        // King safety evaluation
        score += evaluateKingSafety()
        
        // 3D-specific evaluation
        score += evaluate3DAdvantage()
        
        return score
    }
    
    private func evaluateMaterial() -> Int {
        guard let board = getBoard() else { return 0 }
        
        // Safety check for board corruption
        if !board.validateBoardState() {
            print("❌ AI error: Board validation failed in evaluateMaterial")
            return 0
        }
        
        var score = 0
        
        let allPieces = board.getAllPieces()
        if allPieces.isEmpty {
            print("❌ AI error: No pieces found in evaluateMaterial")
            return 0
        }
        
        for piece in allPieces {
            let value = pieceValues[piece.type] ?? 0
            if piece.color == aiColor {
                score += value
            } else {
                score -= value
            }
        }
        
        return score
    }
    
    private func evaluatePositionalAdvantage() -> Int {
        guard let board = getBoard() else { return 0 }
        
        // Safety check for board corruption
        if !board.validateBoardState() {
            print("❌ AI error: Board validation failed in evaluatePositionalAdvantage")
            return 0
        }
        
        var score = 0
        
        let allPieces = board.getAllPieces()
        if allPieces.isEmpty {
            print("❌ AI error: No pieces found in evaluatePositionalAdvantage")
            return 0
        }
        
        for piece in allPieces {
            let position = piece.position
            
            // Center control bonus
            if position.file >= 2 && position.file <= 5 && position.rank >= 2 && position.rank <= 5 {
                score += centerBonus * (piece.color == aiColor ? 1 : -1)
            }
            
            // Height advantage (higher boards are generally better)
            let heightBonus = position.z * 2
            score += heightBonus * (piece.color == aiColor ? 1 : -1)
            
            // Pawn structure evaluation
            if piece.type == .pawn {
                score += evaluatePawnStructure(for: piece)
            }
        }
        
        return score
    }
    
    private func evaluatePawnStructure(for pawn: ChessPiece3D) -> Int {
        guard let board = getBoard() else { return 0 }
        
        // Safety check for board corruption
        if !board.validateBoardState() {
            print("❌ AI error: Board validation failed in evaluatePawnStructure")
            return 0
        }
        
        var score = 0
        let position = pawn.position
        
        // Get all pieces safely
        let allPieces = board.getAllPieces()
        if allPieces.isEmpty {
            print("❌ AI error: No pieces found in evaluatePawnStructure")
            return 0
        }
        
        // Doubled pawns penalty
        let doubledPawns = allPieces.filter {
            $0.type == PieceType.pawn && $0.color == pawn.color && $0.position.file == position.file
        }.count
        if doubledPawns > 1 {
            score -= 20 * (doubledPawns - 1)
        }
        
        // Isolated pawns penalty
        let adjacentFiles = [position.file - 1, position.file + 1].filter { $0 >= 0 && $0 <= 7 }
        let hasAdjacentPawns = allPieces.contains {
            $0.type == PieceType.pawn && $0.color == pawn.color && adjacentFiles.contains($0.position.file)
        }
        if !hasAdjacentPawns {
            score -= 30
        }
        
        // Passed pawns bonus
        if isPassedPawn(pawn) {
            score += 50
        }
        
        return score * (pawn.color == aiColor ? 1 : -1)
    }
    
    private func isPassedPawn(_ pawn: ChessPiece3D) -> Bool {
        guard let board = getBoard() else { return false }
        
        let position = pawn.position
        let direction = pawn.color == .white ? 1 : -1
        
        // Check if there are any opponent pawns in front
        for rank in stride(from: position.rank + direction, through: pawn.color == .white ? 7 : 0, by: direction) {
            for z in 0...7 {
                let checkPosition = ChessPosition3D(file: position.file, rank: rank, z: z)
                if let piece = board.getPiece(at: checkPosition),
                    piece.type == PieceType.pawn && piece.color != pawn.color {
                    return false
                }
            }
        }
        
        return true
    }
    
    private func evaluateMobility() -> Int {
        let aiMoves = getAllValidMoves(for: aiColor).count
        let opponentMoves = getAllValidMoves(for: aiColor.opposite).count
        
        return (aiMoves - opponentMoves) * mobilityBonus
    }
    
    private func evaluateKingSafety() -> Int {
        guard let board = getBoard() else { return 0 }
        
        // Safety check for board corruption
        if !board.validateBoardState() {
            print("❌ AI error: Board validation failed in evaluateKingSafety")
            return 0
        }
        
        var score = 0
        
        let allPieces = board.getAllPieces()
        if allPieces.isEmpty {
            print("❌ AI error: No pieces found in evaluateKingSafety")
            return 0
        }
        
        guard let aiKing = allPieces.first(where: { $0.type == PieceType.king && $0.color == aiColor }) else {
            return 0
        }
        
        // Penalty for king in center in middlegame
        if aiKing.position.file >= 2 && aiKing.position.file <= 5 &&
            aiKing.position.rank >= 2 && aiKing.position.rank <= 5 {
            score -= 30
        }
        
        // Bonus for king safety (castled position)
        if aiKing.position.file == 6 || aiKing.position.file == 2 {
            score += 20
        }
        
        return score
    }
    
    private func evaluate3DAdvantage() -> Int {
        guard let board = getBoard() else { return 0 }
        
        // Safety check for board corruption
        if !board.validateBoardState() {
            print("❌ AI error: Board validation failed in evaluate3DAdvantage")
            return 0
        }
        
        var score = 0
        
        // Control of multiple levels
        let aiPieces = board.getPieces(of: aiColor)
        let opponentPieces = board.getPieces(of: aiColor.opposite)
        
        let aiLevels = Set(aiPieces.map { $0.position.z })
        let opponentLevels = Set(opponentPieces.map { $0.position.z })
        
        score += (aiLevels.count - opponentLevels.count) * 10
        
        // Height advantage for pieces
        for piece in aiPieces {
            if piece.type != .pawn {
                score += piece.position.z * 5
            }
        }
        
        for piece in opponentPieces {
            if piece.type != .pawn {
                score -= piece.position.z * 5
            }
        }
        
        return score
    }
    
    // MARK: - Check Detection
    
    private func isCheck(color: PieceColor) -> Bool {
        guard let board = getBoard() else { return false }
        
        guard let king = board.getAllPieces().first(where: { $0.type == PieceType.king && $0.color == color }) else {
            return false
        }
        
        let opponentPieces = board.getPieces(of: color.opposite)
        
        for piece in opponentPieces {
            if canPieceAttackPosition(piece: piece, targetPosition: king.position) {
                return true
            }
        }
        
        return false
    }
    
    private func canPieceAttackPosition(piece: ChessPiece3D, targetPosition: ChessPosition3D) -> Bool {
        guard let board = getBoard() else { return false }
        
        let moves = board.getValidMoves(for: piece, checkEnPassant: false)
        return moves.contains { $0.to == targetPosition }
    }
    
    // MARK: - Strategic Rules Implementation
    
    private func isBigPieceAvoidingPawnCapture(_ move: ChessMove3D, piece: ChessPiece3D, board: ChessBoard3D) -> Bool {
        // Check if this move saves a big piece from being captured by a pawn
        let opponentColor: PieceColor = self.aiColor == .white ? .black : .white
        let opponentPieces = board.getPieces(of: opponentColor)
        
        // Define big pieces (queen, rook, bishop, knight)
        let bigPieces: [PieceType] = [.queen, .rook, .bishop, .knight]
        
        // Only apply this rule to big pieces
        guard bigPieces.contains(piece.type) else { return false }
        
        // Check if the piece was under attack by a pawn at its original position
        for opponentPiece in opponentPieces {
            if opponentPiece.type == .pawn && self.canPieceCapture(opponentPiece, targetPosition: move.from, board: board) {
                // Only print once per move evaluation cycle
                let moveKey = "\(move.from.stringValue)->\(move.to.stringValue)"
                if !loggedStrategicMoves.contains(moveKey) {
                    print("🤖 AI Strategic Rule 1: \(piece.type.rawValue) at \(move.from.stringValue) avoiding capture by pawn at \(opponentPiece.position.stringValue)")
                    loggedStrategicMoves.insert(moveKey)
                }
                return true
            }
        }
        
        return false
    }
    
    private func isNonKingCapturePreferred(_ move: ChessMove3D, piece: ChessPiece3D, board: ChessBoard3D) -> Bool {
        // Check if this is a capture move by a non-king piece when a king could also capture
        guard move.capturedPiece != nil else { return false }
        guard piece.type != .king else { return false } // Only apply to non-king pieces
        
        // Check if the king could also capture the same piece
        let kingPieces = board.getPieces(of: self.aiColor).filter { $0.type == .king }
        
        for king in kingPieces {
            if self.canPieceCapture(king, targetPosition: move.to, board: board) {
                // Only print once per move evaluation cycle
                let moveKey = "\(move.from.stringValue)->\(move.to.stringValue)"
                if !loggedStrategicMoves.contains(moveKey) {
                    print("🤖 AI Strategic Rule 2: Using \(piece.type.rawValue) instead of king to capture \(move.capturedPiece!.type.rawValue) at \(move.to.stringValue)")
                    loggedStrategicMoves.insert(moveKey)
                }
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Data Persistence Methods
    
    private func loadLearningData() {
        // Load strategy weights
        if let savedWeights = userDefaults.object(forKey: strategyWeightsKey) as? [String: Double] {
            strategyWeights = savedWeights
            print("🤖 AI persistence: Loaded strategy weights from storage")
        } else {
            print("🤖 AI persistence: No saved strategy weights found, using defaults")
        }
        
        // Load game outcome statistics (we don't load full history to save memory)
        let totalGames = userDefaults.integer(forKey: totalGamesKey)
        let wins = userDefaults.integer(forKey: winsKey)
        let losses = userDefaults.integer(forKey: lossesKey)
        let draws = userDefaults.integer(forKey: drawsKey)
        
        print("🤖 AI persistence: Loaded game statistics - Games: \(totalGames), Wins: \(wins), Losses: \(losses), Draws: \(draws)")
    }
    
    private func saveLearningData() {
        // Save strategy weights
        userDefaults.set(strategyWeights, forKey: strategyWeightsKey)
        
        // Update game statistics
        let currentTotal = userDefaults.integer(forKey: totalGamesKey)
        let currentWins = userDefaults.integer(forKey: winsKey)
        let currentLosses = userDefaults.integer(forKey: lossesKey)
        let currentDraws = userDefaults.integer(forKey: drawsKey)
        
        // Count new outcomes since last save
        var newWins = 0
        var newLosses = 0
        var newDraws = 0
        
        for outcome in gameOutcomes {
            switch outcome {
            case .win: newWins += 1
            case .loss: newLosses += 1
            case .draw: newDraws += 1
            case .ongoing: break
            }
        }
        
        // Update totals
        userDefaults.set(currentTotal + gameOutcomes.count, forKey: totalGamesKey)
        userDefaults.set(currentWins + newWins, forKey: winsKey)
        userDefaults.set(currentLosses + newLosses, forKey: lossesKey)
        userDefaults.set(currentDraws + newDraws, forKey: drawsKey)
        
        // Clear current session outcomes (they're now saved in totals)
        gameOutcomes.removeAll()
        
        print("🤖 AI persistence: Saved learning data to storage")
    }
    
    func getTotalGames() -> Int {
        return userDefaults.integer(forKey: totalGamesKey) + gameOutcomes.count
    }
    
    func getWins() -> Int {
        let savedWins = userDefaults.integer(forKey: winsKey)
        let sessionWins = gameOutcomes.filter { $0 == .win }.count
        return savedWins + sessionWins
    }
    
    func getLosses() -> Int {
        let savedLosses = userDefaults.integer(forKey: lossesKey)
        let sessionLosses = gameOutcomes.filter { $0 == .loss }.count
        return savedLosses + sessionLosses
    }
    
    func getDraws() -> Int {
        let savedDraws = userDefaults.integer(forKey: drawsKey)
        let sessionDraws = gameOutcomes.filter { $0 == .draw }.count
        return savedDraws + sessionDraws
    }
    
    func getWinRate() -> Double {
        let total = getTotalGames()
        guard total > 0 else { return 0.0 }
        return Double(getWins()) / Double(total) * 100.0
    }
    
    // Reset all learning data (useful for testing or fresh start)
    func resetLearningData() {
        userDefaults.removeObject(forKey: strategyWeightsKey)
        userDefaults.removeObject(forKey: totalGamesKey)
        userDefaults.removeObject(forKey: winsKey)
        userDefaults.removeObject(forKey: lossesKey)
        userDefaults.removeObject(forKey: drawsKey)
        
        // Reset to default weights
        strategyWeights = [
            "advancement": 1.0,
            "center_control": 1.0,
            "pawn_structure": 1.0,
            "passed_pawn": 1.0,
            "safety": 1.0,
            "pawn_chain": 1.0,
            "king_protection": 1.0,
            "opponent_attack": 1.0,
            "isolation_avoidance": 1.0,
            "position_opening": 1.0,
            "piece_development": 1.0,
            "tactical_opportunity": 1.0,
            "king_activity": 1.0,
            "material_advantage": 1.0
        ]
        
        gameOutcomes.removeAll()
        moveHistory.removeAll()
        
        print("🤖 AI persistence: Reset all learning data")
    }
    
    // Export learning data as a readable summary
    func exportLearningDataSummary() -> String {
        var summary = "🤖 AI Learning Data Summary\n"
        summary += "==========================\n"
        summary += "Total Games: \(getTotalGames())\n"
        summary += "Wins: \(getWins()) (\(String(format: "%.1f", getWinRate()))%)\n"
        summary += "Losses: \(getLosses())\n"
        summary += "Draws: \(getDraws())\n\n"
        summary += "Strategy Weights:\n"
        
        let sortedWeights = strategyWeights.sorted { $0.value > $1.value }
        for (strategy, weight) in sortedWeights {
            summary += "- \(strategy): \(String(format: "%.2f", weight))\n"
        }
        
        return summary
    }
    
    // MARK: - Strategic Rules Implementation
    
    private func isValidStrategicMove(_ move: ChessMove3D) -> Bool {
        guard let board = getBoard() else { return false }
        guard let piece = board.getPiece(at: move.from) else { return false }
        
        let pieceId = "\(piece.color.rawValue)_\(piece.type.rawValue)_\(move.from.stringValue)"
        
        // Rule 1: For first 5 moves, don't move same piece more than twice unless about to be captured
        if totalMovesPlayed < 5 {
            if !violatesRule1(move: move, pieceId: pieceId) {
                print("🚫 Rule 1 violation: Piece \(pieceId) moved too many times in opening")
                return false
            }
        }
        
        // Rule 2: Avoid capture of big pieces by pawns unless it exposes king to check
        if !violatesRule2(move: move) {
            print("🚫 Rule 2 violation: Big piece would be captured by pawn without strategic benefit")
            return false
        }
        
        // Rule 3: Make Z-component move at least every 3 moves
        if !violatesRule3(move: move) {
            print("🚫 Rule 3 violation: No Z-axis move in too long")
            return false
        }
        
        // Rule 4: Position pawns defensively - offset diagonally for protection
        if !violatesRule4(move: move) {
            print("🚫 Rule 4 violation: Poor pawn positioning - breaks defensive structure")
            return false
        }
        
        // Rule 5: Only move pieces more than twice if capturing big pieces or checking
        if !violatesRule5(move: move, pieceId: pieceId) {
            print("🚫 Rule 5 violation: Moving same piece too often without strategic purpose")
            return false
        }
        
        // Rule 6: Rooks cannot make 1-square lateral moves unless under threat
        if !violatesRule6(move: move) {
            print("🚫 Rule 6 violation: Rook making unnecessary 1-square lateral move")
            return false
        }
        
        // Rule 7: Encourage pawn moves that create space for major pieces
        if !violatesRule7(move: move) {
            print("🚫 Rule 7 violation: Pawn move doesn't create space for major pieces")
            return false
        }
        
        // Rule 8: Encourage major piece development (bishops and rooks)
        if !violatesRule8(move: move) {
            print("🚫 Rule 8 violation: Major piece not being developed effectively")
            return false
        }
        
        // Rule 9: Knight restriction - can only move knight every third move
        if !violatesRule9(move: move) {
            print("🚫 Rule 9 violation: Knight moved too frequently")
            return false
        }
        
        // Rule 10: Pawn opening requirement - must move specific pawns to open bishop moves
        if !violatesRule10(move: move) {
            print("🚫 Rule 10 violation: Must move pawns to open bishop moves")
            return false
        }
        
        // Rule 11: Bishop requirement - after 5 moves, must move bishop
        if !violatesRule11(move: move) {
            print("🚫 Rule 11 violation: Must move bishop after 5 moves")
            return false
        }
        
        // Rule 12: Prevent repetitive rook moves (back and forth)
        if !violatesRule12(move: move) {
            print("🚫 Rule 12 violation: Repetitive rook move blocked")
            return false
        }
        
        return true
    }
    
    // Rule 1: First 5 moves - don't move same piece more than twice unless about to be captured
    private func violatesRule1(move: ChessMove3D, pieceId: String) -> Bool {
        let consecutiveMoves = pieceMoveCounts[pieceId] ?? 0
        
        if consecutiveMoves >= 2 {
            // Allow if piece is about to be captured
            return isPieceAboutToBeCaptured(at: move.from)
        }
        
        return true // Move is allowed
    }
    
    // Rule 2: Avoid big piece capture by pawns unless it exposes king to check
    private func violatesRule2(move: ChessMove3D) -> Bool {
        guard let board = getBoard() else { return true }
        guard let piece = board.getPiece(at: move.from) else { return true }
        
        // Check if this move puts a big piece in danger from enemy pawns
        if piece.type != .pawn && (piece.type == .queen || piece.type == .rook || piece.type == .bishop || piece.type == .knight) {
            let enemyColor = piece.color == .white ? PieceColor.black : PieceColor.white
            
            // Check if any enemy pawn can capture this piece at the destination
            if isPositionUnderPawnAttack(move.to, by: enemyColor) {
                // Allow only if it exposes enemy king to check
                return wouldExposeEnemyKingToCheck(move: move)
            }
        }
        
        return true // Move is allowed
    }
    
    // Rule 3: Make Z-component move at least every 3 moves
    private func violatesRule3(move: ChessMove3D) -> Bool {
        let hasZComponent = move.from.z != move.to.z
        
        if hasZComponent {
            return true // This move satisfies the rule
        }
        
        // If no Z-component and it's been 3+ moves, this violates the rule
        return movesSinceZAxisMove < 2
    }
    
    // Rule 4: Position pawns defensively - offset diagonally for protection
    private func violatesRule4(move: ChessMove3D) -> Bool {
        guard let board = getBoard() else { return true }
        guard let piece = board.getPiece(at: move.from) else { return true }
        
        // Only apply to pawn moves
        if piece.type != .pawn {
            return true // Rule doesn't apply to non-pawns
        }
        
        // Check if this pawn move creates or maintains good defensive structure
        // Look for friendly pieces that this pawn can protect diagonally
        let friendlyColor = piece.color
        let destination = move.to
        
        // Check diagonal positions that this pawn can protect
        let protectionSquares = [
            ChessPosition3D(file: destination.file - 1, rank: destination.rank + (friendlyColor == .white ? 1 : -1), z: destination.z),
            ChessPosition3D(file: destination.file + 1, rank: destination.rank + (friendlyColor == .white ? 1 : -1), z: destination.z)
        ]
        
        var protectsImportantPiece = false
        for square in protectionSquares {
            if square.file >= 0 && square.file <= 7 && square.rank >= 0 && square.rank <= 7 && square.z >= 0 && square.z <= 7 {
                if let protectedPiece = board.getPiece(at: square) {
                    if protectedPiece.color == friendlyColor &&
                        (protectedPiece.type == .knight || protectedPiece.type == .bishop ||
                         protectedPiece.type == .rook || protectedPiece.type == .queen) {
                        protectsImportantPiece = true
                        break
                    }
                }
            }
        }
        
        // Also check if this move leaves an important piece unprotected
        let currentProtectionSquares = [
            ChessPosition3D(file: move.from.file - 1, rank: move.from.rank + (friendlyColor == .white ? 1 : -1), z: move.from.z),
            ChessPosition3D(file: move.from.file + 1, rank: move.from.rank + (friendlyColor == .white ? 1 : -1), z: move.from.z)
        ]
        
        var leavesImportantPieceUnprotected = false
        for square in currentProtectionSquares {
            if square.file >= 0 && square.file <= 7 && square.rank >= 0 && square.rank <= 7 && square.z >= 0 && square.z <= 7 {
                if let currentlyProtectedPiece = board.getPiece(at: square) {
                    if currentlyProtectedPiece.color == friendlyColor &&
                        (currentlyProtectedPiece.type == .knight || currentlyProtectedPiece.type == .bishop ||
                         currentlyProtectedPiece.type == .rook || currentlyProtectedPiece.type == .queen) {
                        // Check if this piece will still be protected by other pawns
                        if !isProtectedByOtherPawns(square, excludingPawn: move.from, color: friendlyColor) {
                            leavesImportantPieceUnprotected = true
                            break
                        }
                    }
                }
            }
        }
        
        // Allow move if it protects important pieces or doesn't break protection
        return protectsImportantPiece || !leavesImportantPieceUnprotected
    }
    
    // Rule 5: Only move pieces more than twice if capturing big pieces or checking
    private func violatesRule5(move: ChessMove3D, pieceId: String) -> Bool {
        let consecutiveMoves = pieceMoveCounts[pieceId] ?? 0
        
        if consecutiveMoves >= 2 {
            // Allow if capturing a big piece
            if let targetPiece = getBoard()?.getPiece(at: move.to) {
                if targetPiece.type == .queen || targetPiece.type == .rook || targetPiece.type == .bishop {
                    return true
                }
            }
            
            // Allow if it puts enemy king in check
            return wouldPutEnemyKingInCheck(move: move)
        }
        
        return true // Move is allowed
    }
    
    // Rule 6: Rooks cannot make 1-square lateral moves unless under threat
    private func violatesRule6(move: ChessMove3D) -> Bool {
        guard let board = getBoard() else { return true }
        guard let piece = board.getPiece(at: move.from) else { return true }
        
        // Only applies to rooks
        if piece.type != .rook {
            return true // Rule doesn't apply, so it's valid
        }
        
        // Calculate move distance
        let fileDistance = abs(move.to.file - move.from.file)
        let rankDistance = abs(move.to.rank - move.from.rank)
        let zDistance = abs(move.to.z - move.from.z)
        
        // Check if it's a 1-square lateral move (horizontal or forward/backward, not vertical Z)
        let isOneSquareLateral = (fileDistance == 1 && rankDistance == 0 && zDistance == 0) ||
        (fileDistance == 0 && rankDistance == 1 && zDistance == 0)
        
        if !isOneSquareLateral {
            return true // Not a 1-square lateral move, so it's valid
        }
        
        print("🔍 Rule 6: Checking rook 1-square lateral move from \(move.from.stringValue) to \(move.to.stringValue)")
        
        // Allow if rook is under threat of capture at current position
        if isUnderThreat(position: move.from, piece: piece, board: board) {
            print("✅ Rule 6: Allowing 1-square rook move - rook is under threat")
            return true
        }
        
        // Allow if capturing an enemy piece
        if move.capturedPiece != nil {
            print("✅ Rule 6: Allowing 1-square rook move - capturing enemy piece")
            return true
        }
        
        // Allow if it puts enemy king in check
        if wouldPutEnemyKingInCheck(move: move) {
            print("✅ Rule 6: Allowing 1-square rook move - gives check")
            return true
        }
        
        print("❌ Rule 6: Blocking unnecessary 1-square rook lateral move")
        return false // Block this move
    }
    
    // Helper: Check if a piece is under threat of capture at a given position
    private func isUnderThreat(position: ChessPosition3D, piece: ChessPiece3D, board: ChessBoard3D) -> Bool {
        let enemyColor = piece.color == .white ? PieceColor.black : PieceColor.white
        let enemyPieces = board.getPieces(of: enemyColor)
        
        // Check if any enemy piece can attack this position
        for enemyPiece in enemyPieces {
            let enemyMoves = board.getValidMoves(for: enemyPiece, checkEnPassant: false)
            if enemyMoves.contains(where: { $0.to == position }) {
                return true
            }
        }
        
        return false
    }
    
    // Helper: Check if piece is about to be captured
    private func isPieceAboutToBeCaptured(at position: ChessPosition3D) -> Bool {
        guard let board = getBoard() else { return false }
        guard let piece = board.getPiece(at: position) else { return false }
        
        let enemyColor = piece.color == .white ? PieceColor.black : PieceColor.white
        let enemyMoves = getAllValidMoves(for: enemyColor)
        
        return enemyMoves.contains { $0.to == position }
    }
    
    // Helper: Check if position is under pawn attack
    private func isPositionUnderPawnAttack(_ position: ChessPosition3D, by color: PieceColor) -> Bool {
        guard let board = getBoard() else { return false }
        
        // Get all pawns of the attacking color
        let allPieces = board.getAllPieces()
        let pawns = allPieces.filter { $0.color == color && $0.type == .pawn }
        
        for pawn in pawns {
            let pawnMoves = board.getValidMoves(for: pawn, checkEnPassant: false)
            if pawnMoves.contains(where: { $0.to == position }) {
                return true
            }
        }
        
        return false
    }
    
    // Helper: Check if move would expose enemy king to check
    private func wouldExposeEnemyKingToCheck(move: ChessMove3D) -> Bool {
        guard let board = getBoard() else { return false }
        
        // Simulate the move
        let capturedPiece = board.getPiece(at: move.to)
        board.makeMove(move)
        
        let enemyColor = aiColor == .white ? PieceColor.black : PieceColor.white
        let wouldCheck = isCheck(color: enemyColor)
        
        // Undo the move
        board.undoMove(move, capturedPiece: capturedPiece)
        
        return wouldCheck
    }
    
    // Helper: Check if move would put enemy king in check
    private func wouldPutEnemyKingInCheck(move: ChessMove3D) -> Bool {
        return wouldExposeEnemyKingToCheck(move: move)
    }
    
    // Helper: Check if a move gives check to the opponent king
    private func givesCheck(_ move: ChessMove3D, board: ChessBoard3D) -> Bool {
        // Save the captured piece if any
        let capturedPiece = board.getPiece(at: move.to)
        
        // Temporarily make the move
        board.makeMove(move)
        
        // Check if opponent king is in check
        let opponentColor = aiColor == .white ? PieceColor.black : PieceColor.white
        let result = board.isCheck(color: opponentColor)
        
        // Undo the move
        board.undoMove(move, capturedPiece: capturedPiece)
        
        return result
    }
    
    // Helper: Check if a move would result in checkmate
    private func wouldBeCheckmate(_ move: ChessMove3D, board: ChessBoard3D) -> Bool {
        // First check if the move gives check
        if !givesCheck(move, board: board) {
            return false
        }
        
        // Save the captured piece if any
        let capturedPiece = board.getPiece(at: move.to)
        
        // Temporarily make the move
        board.makeMove(move)
        
        // Check if opponent is in checkmate
        let opponentColor = aiColor == .white ? PieceColor.black : PieceColor.white
        let result = board.isCheckmate(color: opponentColor)
        
        // Undo the move
        board.undoMove(move, capturedPiece: capturedPiece)
        
        return result
    }
    
    // Helper: Check if a square is protected by other pawns (excluding a specific pawn)
    private func isProtectedByOtherPawns(_ square: ChessPosition3D, excludingPawn: ChessPosition3D, color: PieceColor) -> Bool {
        guard let board = getBoard() else { return false }
        
        // Get all pawns of the same color
        let allPieces = board.getAllPieces()
        let pawns = allPieces.filter { $0.color == color && $0.type == .pawn && $0.position != excludingPawn }
        
        // Check if any of these pawns can protect the square
        for pawn in pawns {
            // Check if this pawn attacks the square diagonally
            let pawnDirection = color == .white ? 1 : -1
            let attackSquares = [
                ChessPosition3D(file: pawn.position.file - 1, rank: pawn.position.rank + pawnDirection, z: pawn.position.z),
                ChessPosition3D(file: pawn.position.file + 1, rank: pawn.position.rank + pawnDirection, z: pawn.position.z)
            ]
            
            if attackSquares.contains(square) {
                return true
            }
        }
        
        return false
    }
    
    // Update move tracking when AI makes a move
    private func updateMoveTracking(for move: ChessMove3D) {
        guard let board = getBoard() else { return }
        guard let piece = board.getPiece(at: move.to) else { return } // Piece is now at destination
        
        let pieceId = "\(piece.color.rawValue)_\(piece.type.rawValue)_\(move.from.stringValue)"
        
        // Update consecutive move count
        if lastMovedPiece == pieceId {
            pieceMoveCounts[pieceId] = (pieceMoveCounts[pieceId] ?? 0) + 1
        } else {
            // Reset all counts when moving a different piece
            pieceMoveCounts.removeAll()
            pieceMoveCounts[pieceId] = 1
            lastMovedPiece = pieceId
        }
        
        // Track Z-axis moves
        if move.from.z != move.to.z {
            movesSinceZAxisMove = 0
        } else {
            movesSinceZAxisMove += 1
        }
        
        totalMovesPlayed += 1
        
        // Track specific piece types for Rules 9-11
        if piece.type == .knight {
            lastKnightMoveNumber = totalMovesPlayed
            print("📊 AI Move Tracking: Knight moved at move \(totalMovesPlayed)")
        }
        
        if piece.type == .bishop {
            lastBishopMoveNumber = totalMovesPlayed
            print("📊 AI Move Tracking: Bishop moved at move \(totalMovesPlayed)")
        }
        
        // Track completed pawn moves for Rule 10
        if piece.type == .pawn {
            let moveKey = "\(move.from.stringValue)->\(move.to.stringValue)"
            completedPawnMoves.insert(moveKey)
            print("📊 AI Move Tracking: Pawn move completed: \(moveKey)")
        }
        
        // Add to AI move history
        aiMoveHistory.append(move)
        
        print("📊 AI Move Tracking: Piece \(pieceId) moved \(pieceMoveCounts[pieceId] ?? 0) times consecutively")
        print("📊 AI Move Tracking: \(movesSinceZAxisMove) moves since last Z-axis move")
        print("📊 AI Move Tracking: Total AI moves: \(totalMovesPlayed)")
    }
    
    // Reset tracking for new game
    func resetMoveTracking() {
        pieceMoveCounts.removeAll()
        lastMovedPiece = nil
        movesSinceZAxisMove = 0
        totalMovesPlayed = 0
        
        // Reset new tracking variables
        lastKnightMoveNumber = -1
        lastBishopMoveNumber = -1
        completedPawnMoves.removeAll()
        aiMoveHistory.removeAll()
        
        print("🔄 AI Move Tracking: Reset for new game")
    }
    
    // Rule 7: Encourage pawn moves that create space for major pieces
    private func violatesRule7(move: ChessMove3D) -> Bool {
        guard let board = getBoard() else { return true }
        guard let piece = board.getPiece(at: move.from) else { return true }
        
        // Only apply to pawn moves
        if piece.type != .pawn {
            return true // Rule doesn't apply to non-pawns
        }
        
        // Check if this pawn move creates space for bishops or rooks
        _ = move.to
        let color = piece.color
        
        // For bishops: Check if this opens diagonal paths
        let bishopSquares = getBishopDevelopmentSquares(color: color)
        for bishopSquare in bishopSquares {
            if let bishop = board.getPiece(at: bishopSquare) {
                if bishop.type == .bishop && bishop.color == color {
                    // Check if this pawn move opens a diagonal for the bishop
                    if opensDiagonalForBishop(from: bishopSquare, pawnMove: move) {
                        print("✅ Rule 7: Pawn move opens diagonal for bishop at \(bishopSquare.stringValue)")
                        return true
                    }
                }
            }
        }
        
        // For rooks: Check if this opens vertical paths
        let rookSquares = getRookDevelopmentSquares(color: color)
        for rookSquare in rookSquares {
            if let rook = board.getPiece(at: rookSquare) {
                if rook.type == .rook && rook.color == color {
                    // Check if this pawn move opens a vertical path for the rook
                    if opensVerticalForRook(from: rookSquare, pawnMove: move) {
                        print("✅ Rule 7: Pawn move opens vertical path for rook at \(rookSquare.stringValue)")
                        return true
                    }
                }
            }
        }
        
        // If no major piece development is enabled, this might be a poor pawn move
        // But don't be too restrictive - allow some pawn moves
        return totalMovesPlayed < 10 // Allow pawn moves in early game
    }
    
    // Rule 8: Encourage major piece development (bishops and rooks)
    private func violatesRule8(move: ChessMove3D) -> Bool {
        guard let board = getBoard() else { return true }
        guard let piece = board.getPiece(at: move.from) else { return true }
        
        // Only apply to bishops and rooks
        if piece.type != .bishop && piece.type != .rook {
            return true // Rule doesn't apply to other pieces
        }
        
        // Check if this move develops the piece effectively
        if piece.type == .bishop {
            return isValidBishopDevelopment(move: move)
        } else if piece.type == .rook {
            return isValidRookDevelopment(move: move)
        }
        
        return true
    }
    
    // Helper: Get bishop starting positions for a color
    private func getBishopDevelopmentSquares(color: PieceColor) -> [ChessPosition3D] {
        if color == .white {
            return [
                ChessPosition3D(file: 2, rank: 0, z: 0), // c1
                ChessPosition3D(file: 5, rank: 0, z: 0)  // f1
            ]
        } else {
            return [
                ChessPosition3D(file: 2, rank: 7, z: 0), // c8
                ChessPosition3D(file: 5, rank: 7, z: 0)  // f8
            ]
        }
    }
    
    // Helper: Get rook starting positions for a color
    private func getRookDevelopmentSquares(color: PieceColor) -> [ChessPosition3D] {
        if color == .white {
            return [
                ChessPosition3D(file: 0, rank: 0, z: 0), // a1
                ChessPosition3D(file: 7, rank: 0, z: 0)  // h1
            ]
        } else {
            return [
                ChessPosition3D(file: 0, rank: 7, z: 0), // a8
                ChessPosition3D(file: 7, rank: 7, z: 0)  // h8
            ]
        }
    }
    
    // Helper: Check if pawn move opens diagonal for bishop
    private func opensDiagonalForBishop(from bishopSquare: ChessPosition3D, pawnMove: ChessMove3D) -> Bool {
        // Check if the pawn move clears a diagonal path for the bishop
        let bishopFile = bishopSquare.file
        let bishopRank = bishopSquare.rank
        let bishopZ = bishopSquare.z
        
        // Check if pawn move is on the same diagonal as bishop
        let pawnFile = pawnMove.to.file
        let pawnRank = pawnMove.to.rank
        let pawnZ = pawnMove.to.z
        
        // Bishop can move diagonally in 3D space
        // Check if pawn move opens a diagonal path
        if abs(pawnFile - bishopFile) == abs(pawnRank - bishopRank) {
            // Same 2D diagonal
            if pawnZ == bishopZ || abs(pawnZ - bishopZ) == abs(pawnFile - bishopFile) {
                // Check if this creates a clear diagonal path
                return true
            }
        }
        
        return false
    }
    
    // Helper: Check if pawn move opens vertical path for rook
    private func opensVerticalForRook(from rookSquare: ChessPosition3D, pawnMove: ChessMove3D) -> Bool {
        // Check if the pawn move clears a vertical path for the rook
        let rookFile = rookSquare.file
        let rookZ = rookSquare.z
        
        let pawnFile = pawnMove.to.file
        let pawnZ = pawnMove.to.z
        
        // Rook can move vertically in 3D space
        // Check if pawn move opens a vertical path
        if pawnFile == rookFile {
            // Same file - check if this creates vertical space
            if pawnZ != rookZ {
                return true
            }
        }
        
        return false
    }
    
    // Helper: Check if bishop development is valid
    private func isValidBishopDevelopment(move: ChessMove3D) -> Bool {
        // Bishop should move to active squares that control important diagonals
        let destination = move.to
        
        // Prefer moves that control center or attack enemy territory
        let isCenterControl = (destination.file >= 2 && destination.file <= 5) &&
        (destination.rank >= 2 && destination.rank <= 5)
        
        let isAttacking = move.capturedPiece != nil
        
        let isActiveSquare = isCenterControl || isAttacking
        
        if isActiveSquare {
            print("✅ Rule 8: Bishop developing to active square \(destination.stringValue)")
            return true
        }
        
        // Allow some defensive bishop moves
        return totalMovesPlayed < 15
    }
    
    // Helper: Check if rook development is valid
    private func isValidRookDevelopment(move: ChessMove3D) -> Bool {
        // Rook should move to open files or ranks
        let destination = move.to
        
        // Check if this opens up the rook for horizontal/vertical movement
        let isOpeningFile = opensFileForRook(move: move)
        let isOpeningRank = opensRankForRook(move: move)
        let isAttacking = move.capturedPiece != nil
        
        if isOpeningFile || isOpeningRank || isAttacking {
            print("✅ Rule 8: Rook developing to open position \(destination.stringValue)")
            return true
        }
        
        // Allow some defensive rook moves
        return totalMovesPlayed < 20
    }
    
    // Helper: Check if rook move opens a file
    private func opensFileForRook(move: ChessMove3D) -> Bool {
        // Check if this move opens up vertical movement for the rook
        let destination = move.to
        let file = destination.file
        
        // Check if there are few pieces blocking this file
        guard let board = getBoard() else { return false }
        
        var piecesOnFile = 0
        for rank in 0...7 {
            for z in 0...7 {
                let position = ChessPosition3D(file: file, rank: rank, z: z)
                if board.getPiece(at: position) != nil {
                    piecesOnFile += 1
                }
            }
        }
        
        // Consider file "open" if it has few pieces
        return piecesOnFile <= 3
    }
    
    // Helper: Check if rook move opens a rank
    private func opensRankForRook(move: ChessMove3D) -> Bool {
        // Check if this move opens up horizontal movement for the rook
        let destination = move.to
        let rank = destination.rank
        let z = destination.z
        
        // Check if there are few pieces blocking this rank at this Z-level
        guard let board = getBoard() else { return false }
        
        var piecesOnRank = 0
        for file in 0...7 {
            let position = ChessPosition3D(file: file, rank: rank, z: z)
            if board.getPiece(at: position) != nil {
                piecesOnRank += 1
            }
        }
        
        // Consider rank "open" if it has few pieces
        return piecesOnRank <= 3
    }
    
    // Rule 9: Knight restriction - can only move knight every third move
    private func violatesRule9(move: ChessMove3D) -> Bool {
        guard let board = getBoard() else { return true }
        guard let piece = board.getPiece(at: move.from) else { return true }
        
        // Only apply to knights
        if piece.type != .knight {
            return true // Rule doesn't apply to other pieces
        }
        
        // Check if this is the third move or if we haven't moved a knight recently
        let lastKnightMove = getLastKnightMove()
        let movesSinceLastKnight = totalMovesPlayed - lastKnightMove
        
        // Allow knight moves if:
        // 1. It's been 2+ moves since last knight move, OR
        // 2. We're in early game (first 3 moves), OR
        // 3. This is a capture move
        if movesSinceLastKnight >= 2 || totalMovesPlayed < 3 || move.capturedPiece != nil {
            print("✅ Rule 9: Allowing knight move (moves since last: \(movesSinceLastKnight), total moves: \(totalMovesPlayed))")
            return true
        }
        
        print("🚫 Rule 9: Blocking knight move - only allowed every third move")
        return false
    }
    
    // Rule 10: Pawn opening requirement - must move specific pawns to open bishop moves
    private func violatesRule10(move: ChessMove3D) -> Bool {
        guard let board = getBoard() else { return true }
        guard let piece = board.getPiece(at: move.from) else { return true }
        
        // Only apply to pawns
        if piece.type != .pawn {
            return true // Rule doesn't apply to other pieces
        }
        
        // Always allow pawn captures
        if move.capturedPiece != nil {
            print("✅ Rule 10: Allowing pawn capture")
            return true
        }
        
        // Check if this is one of the required pawn moves
        let requiredPawnMoves = getRequiredPawnMoves()
        let moveKey = "\(move.from.stringValue)->\(move.to.stringValue)"
        
        if requiredPawnMoves.contains(moveKey) {
            print("✅ Rule 10: Allowing required pawn move \(moveKey)")
            return true
        }
        
        // Allow other pawn moves if we've already made the required ones
        if hasCompletedRequiredPawnMoves() {
            print("✅ Rule 10: Allowing pawn move - required moves completed")
            return true
        }
        
        // Allow pawn moves in early game (first 5 moves)
        if totalMovesPlayed < 5 {
            print("✅ Rule 10: Allowing pawn move in early game")
            return true
        }
        
        print("🚫 Rule 10: Blocking pawn move - must make required pawn moves first")
        return false
    }
    
    // Rule 11: Bishop requirement - after 5 moves, must move bishop
    private func violatesRule11(move: ChessMove3D) -> Bool {
        guard let board = getBoard() else { return true }
        guard let piece = board.getPiece(at: move.from) else { return true }
        
        // Only apply after 8 moves (give more time for development)
        if totalMovesPlayed < 8 {
            return true // Rule doesn't apply yet
        }
        
        // Check if we've moved a bishop recently
        let lastBishopMove = getLastBishopMove()
        let movesSinceLastBishop = totalMovesPlayed - lastBishopMove
        
        // If it's been more than 8 moves since last bishop move, force bishop move
        if movesSinceLastBishop >= 8 {
            if piece.type == .bishop {
                print("✅ Rule 11: Allowing required bishop move")
                return true
            } else {
                // Allow captures and checks even when bishop move is required
                if move.capturedPiece != nil || wouldPutEnemyKingInCheck(move: move) {
                    print("✅ Rule 11: Allowing capture/check despite bishop requirement")
                    return true
                }
                print("🚫 Rule 11: Blocking non-bishop move - must move bishop")
                return false
            }
        }
        
        return true // Bishop move not required yet
    }
    
    // Helper: Get the move number when knight was last moved
    private func getLastKnightMove() -> Int {
        return lastKnightMoveNumber
    }
    
    // Helper: Get the move number when bishop was last moved
    private func getLastBishopMove() -> Int {
        return lastBishopMoveNumber
    }
    
    // Helper: Get required pawn moves for opening
    private func getRequiredPawnMoves() -> [String] {
        // Return the specific pawn moves that must be made
        return [
            "ii b8->ii b7",
            "ii b7->i b7",
            "i b7->ii g8",
            "ii g8->ii g7",
            "ii g7->i g7"
        ]
    }
    
    // Helper: Check if required pawn moves have been completed
    private func hasCompletedRequiredPawnMoves() -> Bool {
        let requiredMoves = getRequiredPawnMoves()
        let completedCount = requiredMoves.filter { completedPawnMoves.contains($0) }.count
        print("📊 AI Pawn Tracking: \(completedCount)/\(requiredMoves.count) required pawn moves completed")
        return completedCount >= 3 // Allow other moves after 3 required pawn moves
    }
    
    // Helper: Check if a move would get the king out of check (simplified for speed)
    private func wouldMoveGetOutOfCheck(move: ChessMove3D) -> Bool {
        guard let board = getBoard() else { return false }
        
        // Quick check: if this move captures any piece, it might get us out of check
        if move.capturedPiece != nil {
            // Captures are likely to help - do a quick test
            let capturedPiece = board.getPiece(at: move.to)
            board.makeMove(move)
            let stillInCheck = board.isCheck(color: aiColor)
            board.undoMove(move, capturedPiece: capturedPiece)
            return !stillInCheck
        }
        
        // For non-capture moves, do a quick test
        let capturedPiece = board.getPiece(at: move.to)
        board.makeMove(move)
        
        // Check if king is still in check
        let stillInCheck = board.isCheck(color: aiColor)
        
        // Undo the move
        board.undoMove(move, capturedPiece: capturedPiece)
        
        // Return true if the move gets us out of check
        return !stillInCheck
    }
    
    // Helper: Check if king is currently in check
    private func isKingInCheck() -> Bool {
        guard let board = getBoard() else { return false }
        return board.isCheck(color: aiColor)
    }
    
    // Helper: Check if a move would leave king in check
    private func wouldMoveLeaveKingInCheck(move: ChessMove3D) -> Bool {
        guard let board = getBoard() else { return false }
        
        // Make the move temporarily
        let capturedPiece = board.getPiece(at: move.to)
        board.makeMove(move)
        
        // Check if king is in check
        let kingInCheck = board.isCheck(color: aiColor)
        
        // Undo the move
        board.undoMove(move, capturedPiece: capturedPiece)
        
        // Return true if the move leaves king in check
        return kingInCheck
    }
    
    // Helper: Check if a move would give check to opponent
    private func wouldMoveGiveCheck(move: ChessMove3D) -> Bool {
        guard let board = getBoard() else { return false }
        
        // Make the move temporarily
        let capturedPiece = board.getPiece(at: move.to)
        board.makeMove(move)
        
        // Check if opponent is in check
        let opponentInCheck = board.isCheck(color: aiColor.opposite)
        
        // Undo the move
        board.undoMove(move, capturedPiece: capturedPiece)
        
        // Return true if the move gives check
        return opponentInCheck
    }
    
    // Helper: Check if a move would put the moving piece in danger
    private func wouldMovePutPieceInDanger(move: ChessMove3D) -> Bool {
        guard let board = getBoard() else { return false }
        
        // Make the move temporarily
        let capturedPiece = board.getPiece(at: move.to)
        board.makeMove(move)
        
        // Check if the piece at the destination can be captured
        let pieceAtDestination = board.getPiece(at: move.to)
        if let piece = pieceAtDestination {
            let enemyColor = piece.color.opposite
            let enemyPieces = board.getPieces(of: enemyColor)
            
            for enemyPiece in enemyPieces {
                // Use a simpler check to avoid triggering debug output
                // Just check if the enemy piece can attack this square
                if canPieceAttackSquare(enemyPiece, targetSquare: move.to) {
                    // Undo the move
                    board.undoMove(move, capturedPiece: capturedPiece)
                    return true // Piece is in danger
                }
            }
        }
        
        // Undo the move
        board.undoMove(move, capturedPiece: capturedPiece)
        return false
    }
    
    // Helper: Check if a move is repetitive (same piece moving back and forth)
    private func isRepetitiveMove(move: ChessMove3D) -> Bool {
        // Check if this piece has moved recently
        _ = "\(move.from.stringValue)->\(move.to.stringValue)"
        
        // Check last few moves in AI history
        let recentMoves = Array(aiMoveHistory.suffix(4))
        let reverseMove = "\(move.to.stringValue)->\(move.from.stringValue)"
        
        // If we see the reverse of this move recently, it's repetitive
        for recentMove in recentMoves {
            let recentMoveId = "\(recentMove.from.stringValue)->\(recentMove.to.stringValue)"
            if recentMoveId == reverseMove {
                return true
            }
        }
        
        return false
    }
    
    // Helper: Check if king would be in danger at a specific position
    private func wouldKingBeInDangerAtPosition(_ position: ChessPosition3D) -> Bool {
        guard let board = getBoard() else { return false }
        
        // Check if any enemy piece can attack this position
        let enemyColor = aiColor.opposite
        let enemyPieces = board.getPieces(of: enemyColor)
        
        for enemyPiece in enemyPieces {
            let enemyMoves = board.getValidMoves(for: enemyPiece, checkEnPassant: false)
            if enemyMoves.contains(where: { $0.to == position }) {
                return true // King would be in danger at this position
            }
        }
        
        return false
    }
    
    // Helper: Check if a piece can attack a specific square (without triggering debug output)
    private func canPieceAttackSquare(_ piece: ChessPiece3D, targetSquare: ChessPosition3D) -> Bool {
        // Simple distance-based checks for each piece type
        let fileDiff = abs(targetSquare.file - piece.position.file)
        let rankDiff = abs(targetSquare.rank - piece.position.rank)
        let zDiff = abs(targetSquare.z - piece.position.z)
        
        switch piece.type {
        case .pawn:
            // Pawns can attack diagonally forward
            if piece.color == .white {
                return fileDiff == 1 && (targetSquare.rank - piece.position.rank) == 1 && zDiff == 0
            } else {
                return fileDiff == 1 && (piece.position.rank - targetSquare.rank) == 1 && zDiff == 0
            }
            
        case .rook:
            // Rooks can move in straight lines
            return (fileDiff == 0 && rankDiff == 0 && zDiff > 0) || // Same file/rank, different Z
            (fileDiff > 0 && rankDiff == 0 && zDiff == 0) || // Same rank/Z, different file
            (fileDiff == 0 && rankDiff > 0 && zDiff == 0)    // Same file/Z, different rank
            
        case .bishop:
            // Bishops can move diagonally
            return fileDiff == rankDiff && fileDiff > 0 && zDiff == 0 // 2D diagonal
            || (fileDiff == rankDiff && fileDiff == zDiff && fileDiff > 0) // 3D diagonal
            
        case .queen:
            // Queen combines rook and bishop moves
            return canPieceAttackSquare(ChessPiece3D(type: .rook, color: piece.color, position: piece.position), targetSquare: targetSquare) ||
            canPieceAttackSquare(ChessPiece3D(type: .bishop, color: piece.color, position: piece.position), targetSquare: targetSquare)
            
        case .knight:
            // Knights move in L-shape
            let totalDistance = fileDiff + rankDiff + zDiff
            return totalDistance == 3 && fileDiff <= 2 && rankDiff <= 2 && zDiff <= 2 &&
            (fileDiff == 0 || rankDiff == 0 || zDiff == 0) // One component must be 0
            
        case .king:
            // King can move one square in any direction
            return fileDiff <= 1 && rankDiff <= 1 && zDiff <= 1 && (fileDiff + rankDiff + zDiff) > 0
        }
    }
    
    // Rule 12: Prevent repetitive rook moves (back and forth)
    private func violatesRule12(move: ChessMove3D) -> Bool {
        guard let board = getBoard() else { return true }
        guard let piece = board.getPiece(at: move.from) else { return true }
        
        // Only apply to rooks
        if piece.type != .rook {
            return true // Rule doesn't apply to other pieces
        }
        
        // Check if this rook has moved recently
        let pieceId = "\(piece.color.rawValue)_\(piece.type.rawValue)_\(move.from.stringValue)"
        let consecutiveMoves = pieceMoveCounts[pieceId] ?? 0
        
        // Block if rook has moved 2+ times consecutively and this isn't a capture or check
        if consecutiveMoves >= 2 {
            if move.capturedPiece != nil || wouldPutEnemyKingInCheck(move: move) {
                print("✅ Rule 12: Allowing rook move - capture or check")
                return true
            }
            print("🚫 Rule 12: Blocking repetitive rook move")
            return false
        }
        
        return true
    }
    
    // MARK: - Move Prioritization
    
    /// Prioritizes pawns, knights, and bishops over king/queen moves when not under attack
    private func getPrioritizedMove(from moves: [ChessMove3D]) -> ChessMove3D {
        guard let board = getBoard() else { return moves.first! }
        
        // Check if king is in check - if so, prioritize king moves
        if board.isCheck(color: aiColor) {
            let kingMoves = moves.filter { move in
                if let piece = board.getPiece(at: move.from) {
                    return piece.type == .king
                }
                return false
            }
            if !kingMoves.isEmpty {
                print("🤖 AI priority: King in check - choosing king move")
                return kingMoves.first!
            }
        }
        
        // Priority order: pawns > knights > bishops > rooks > queens > kings
        let priorityOrder: [PieceType] = [.pawn, .knight, .bishop, .rook, .queen, .king]
        
        for pieceType in priorityOrder {
            let movesOfType = moves.filter { move in
                if let piece = board.getPiece(at: move.from) {
                    return piece.type == pieceType
                }
                return false
            }
            
            if !movesOfType.isEmpty {
                print("🤖 AI priority: Choosing \(pieceType.rawValue) move (priority level \(priorityOrder.firstIndex(of: pieceType)! + 1))")
                return movesOfType.first!
            }
        }
        
        // Fallback to first available move
        print("🤖 AI priority: No prioritized moves found - using first available")
        return moves.first!
    }
    
    // MARK: - AI Integration with Game Manager
    
    // Note: AI integration methods are now implemented in ChessGameManager.swift
    // This extension has been moved to the main ChessGameManager class
}
