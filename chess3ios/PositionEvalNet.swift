//
//  PositionEvalNet.swift
//  chess3ios
//
//  Small int8 evaluation net for the search leaves.
//  Material stays exact. The net adds a positional score from an accumulator
//  that is updated one piece at a time when a move is made or undone.
//  The output weights are chosen by the two kings' levels (8 x 8 buckets).
//  Correction history nudges that score from completed searches, and is
//  clamped so it cannot hide a hanging piece.
//

import Foundation

final class PositionEvalNet {
    static let hidden = 8
    static let featureCount = 6 * 2 * 8 * 8 * 8
    static let buckets = 64

    private let featureWeights: [Int8]
    private let outputWeights: [Int8]

    private var material = 0
    private var accumulator: [Int32]
    private var whiteKingZ = 0
    private var blackKingZ = 7

    private struct Frame {
        var material: Int
        var accumulator: [Int32]
        var whiteKingZ: Int
        var blackKingZ: Int
    }
    private var undoStack: [Frame] = []

    private struct Correction {
        var sum = 0
        var count = 0
    }
    private var corrections = [Correction](repeating: Correction(), count: 256)

    private let pieceValue: [PieceType: Int] = [
        .pawn: 100,
        .knight: 320,
        .bishop: 330,
        .rook: 500,
        .queen: 900,
        .king: 20000
    ]

    init() {
        var features = [Int8](repeating: 0, count: Self.featureCount * Self.hidden)
        for type in [PieceType.pawn, .rook, .knight, .bishop, .queen, .king] {
            for color in [PieceColor.white, .black] {
                for z in 0..<8 {
                    for file in 0..<8 {
                        for rank in 0..<8 {
                            let position = ChessPosition3D(file: file, rank: rank, z: z)
                            let index = Self.featureIndex(type: type, color: color, position: position) * Self.hidden
                            let sign: Int8 = color == .white ? 1 : -1
                            let center = Int8(3 - min(abs(file - 3), abs(file - 4)))
                            let forward = Int8(color == .white ? rank : (7 - rank))
                            let level = Int8(color == .white ? z : (7 - z))
                            let centerScale: Int8 = type == .pawn ? 2 : 4
                            let forwardScale: Int8 = type == .pawn ? 3 : 1
                            features[index] = center * centerScale * sign
                            features[index + 1] = forward * forwardScale * sign
                            features[index + 2] = level * sign
                        }
                    }
                }
            }
        }
        featureWeights = features

        var outputs = [Int8](repeating: 0, count: Self.buckets * Self.hidden)
        for bucket in 0..<Self.buckets {
            let base = bucket * Self.hidden
            outputs[base] = 1
            outputs[base + 1] = 1
            outputs[base + 2] = 1
        }
        outputWeights = outputs
        accumulator = [Int32](repeating: 0, count: Self.hidden)
    }

    func refresh(pieces: [ChessPiece3D]) {
        material = 0
        accumulator = [Int32](repeating: 0, count: Self.hidden)
        whiteKingZ = 0
        blackKingZ = 7
        undoStack.removeAll(keepingCapacity: true)
        for piece in pieces {
            add(piece)
            if piece.type == .king {
                if piece.color == .white {
                    whiteKingZ = piece.position.z
                } else if piece.color == .black {
                    blackKingZ = piece.position.z
                }
            }
        }
    }

    func apply(_ move: ChessMove3D, captured: ChessPiece3D?) {
        undoStack.append(Frame(material: material, accumulator: accumulator, whiteKingZ: whiteKingZ, blackKingZ: blackKingZ))
        remove(move.piece)
        let arrived: ChessPiece3D
        if let promotion = move.promotionType {
            arrived = ChessPiece3D(type: promotion, color: move.piece.color, position: move.to, hasMoved: true)
        } else {
            arrived = move.piece.moved(to: move.to)
        }
        add(arrived)
        if let captured {
            remove(captured)
        }
        if move.isCastling {
            let rookFile = move.to.file > move.from.file ? 7 : 0
            let rookToFile = move.to.file > move.from.file ? move.to.file - 1 : move.to.file + 1
            let rookFrom = ChessPosition3D(file: rookFile, rank: move.from.rank, z: move.from.z)
            let rookTo = ChessPosition3D(file: rookToFile, rank: move.from.rank, z: move.from.z)
            remove(ChessPiece3D(type: .rook, color: move.piece.color, position: rookFrom))
            add(ChessPiece3D(type: .rook, color: move.piece.color, position: rookTo, hasMoved: true))
        }
        if move.piece.type == .king {
            if move.piece.color == .white {
                whiteKingZ = move.to.z
            } else if move.piece.color == .black {
                blackKingZ = move.to.z
            }
        }
    }

    func revert() {
        guard let frame = undoStack.popLast() else { return }
        material = frame.material
        accumulator = frame.accumulator
        whiteKingZ = frame.whiteKingZ
        blackKingZ = frame.blackKingZ
    }

    /// Positive when the position is good for `aiColor`.
    func score(for aiColor: PieceColor) -> Int {
        let whiteScore = material + positional() + correction()
        return aiColor == .white ? whiteScore : -whiteScore
    }

    func correction() -> Int {
        let entry = corrections[bucketKey()]
        guard entry.count > 0 else { return 0 }
        let average = entry.sum / entry.count
        return max(-60, min(60, average / 2))
    }

    /// Remember how far a finished search disagreed with this position's static score.
    func note(searchScore: Int, aiColor: PieceColor) {
        let searchWhite = aiColor == .white ? searchScore : -searchScore
        let staticWhite = material + positional() + correction()
        let delta = max(-200, min(200, searchWhite - staticWhite))
        var entry = corrections[bucketKey()]
        entry.sum += delta
        entry.count += 1
        if entry.count > 12 {
            entry.sum /= 2
            entry.count = max(1, entry.count / 2)
        }
        corrections[bucketKey()] = entry
    }

    private func positional() -> Int {
        let bucket = min(Self.buckets - 1, max(0, whiteKingZ) * 8 + max(0, blackKingZ))
        let base = bucket * Self.hidden
        var sum = 0
        for hidden in 0..<Self.hidden {
            sum += Int(accumulator[hidden]) * Int(outputWeights[base + hidden])
        }
        return sum
    }

    private func bucketKey() -> Int {
        let materialBand = min(3, abs(material) / 800)
        return (min(7, max(0, whiteKingZ)) << 5) | (min(7, max(0, blackKingZ)) << 2) | materialBand
    }

    private func add(_ piece: ChessPiece3D) {
        guard piece.color == .white || piece.color == .black else { return }
        material += piece.color == .white ? (pieceValue[piece.type] ?? 0) : -(pieceValue[piece.type] ?? 0)
        accumulate(piece, delta: 1)
    }

    private func remove(_ piece: ChessPiece3D) {
        guard piece.color == .white || piece.color == .black else { return }
        material -= piece.color == .white ? (pieceValue[piece.type] ?? 0) : -(pieceValue[piece.type] ?? 0)
        accumulate(piece, delta: -1)
    }

    private func accumulate(_ piece: ChessPiece3D, delta: Int32) {
        let index = Self.featureIndex(type: piece.type, color: piece.color, position: piece.position) * Self.hidden
        guard index >= 0, index + Self.hidden <= featureWeights.count else { return }
        for hidden in 0..<Self.hidden {
            accumulator[hidden] += delta * Int32(featureWeights[index + hidden])
        }
    }

    private static func featureIndex(type: PieceType, color: PieceColor, position: ChessPosition3D) -> Int {
        let typeIndex: Int
        switch type {
        case .pawn: typeIndex = 0
        case .rook: typeIndex = 1
        case .knight: typeIndex = 2
        case .bishop: typeIndex = 3
        case .queen: typeIndex = 4
        case .king: typeIndex = 5
        }
        let colorIndex = color == .white ? 0 : 1
        let z = min(7, max(0, position.z))
        let file = min(7, max(0, position.file))
        let rank = min(7, max(0, position.rank))
        return (((typeIndex * 2 + colorIndex) * 8 + z) * 8 + file) * 8 + rank
    }
}
