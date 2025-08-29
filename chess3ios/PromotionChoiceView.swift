import SwiftUI

struct PromotionChoiceView: View {
    @ObservedObject var chessGame: ChessGameManager
    
    private var promotionColor: PieceColor {
        // Use the current turn to determine the piece color
        // When a pawn reaches the promotion rank, it's the current player's turn
        return chessGame.getCurrentTurn()
    }
    
    private var buttonColor: Color {
        return promotionColor == .white ? Color.red : Color.blue
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Choose Promotion Piece")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Select which piece your pawn should promote to:")
                .font(.body)
                .foregroundColor(.secondary)
            
            HStack(spacing: 20) {
                ForEach(chessGame.promotionChoices, id: \.self) { pieceType in
                    Button(action: {
                        chessGame.selectPromotionPiece(pieceType)
                    }) {
                        VStack {
                            Text(pieceIcon(for: pieceType))
                                .font(.system(size: 40))
                            Text(pieceType.rawValue.capitalized)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .frame(width: 80, height: 80)
                        .background(buttonColor.opacity(0.1))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(buttonColor, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 200)
    }
    
    private func pieceIcon(for pieceType: PieceType) -> String {
        switch pieceType {
        case .queen:
            return "♕"
        case .rook:
            return "♖"
        case .bishop:
            return "♗"
        case .knight:
            return "♘"
        default:
            return "♕"
        }
    }
}

#Preview {
    let chessGame = ChessGameManager()
    chessGame.showPromotionChoice = true
    return PromotionChoiceView(chessGame: chessGame)
}

