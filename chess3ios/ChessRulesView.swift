//
//  ChessRulesView.swift
//  chess3
//
//  Created by Gareth Costa on 8/9/2025.
//

import SwiftUI

struct ChessRulesView: View {
    @Binding var isPresented: Bool
    @State private var hideTimer: Timer?
    @State private var buttonVisible = true
    @State private var buttonTimer: Timer?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("3D Chess Rules and Instructions")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Group {
                    
                    Text("Quick Start")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("• Tap pieces to select, tap distance to select squares moved, tap move arrows for direction - the piece will move automatically thereafter")
                    Text("• iPhone and iPad - Pinch to zoom in/out on Movement, Game Centre and Camera controls")
                    Text("• Use camera controls to adjust zoom and board height, and reset to default position")
                    Text("• Play Mode: Standard chess gameplay for two players on one device and use Learn mode to move red pieces only to understand the controls")
                    Text("• When using Game Centre mode, if you have problems connecting, close the app, sign out of Game Centre in your device Settings, sign in again and restart the app, it should reconnect and allow match connections. Press Force GC Reset if problems persist")
                    
                    
                    Text("General Rules")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("• Chess 3D is closely based on the rules of traditional 2D chess")
                    Text("• There are eight 64-square boards for a total of 512 squares for pieces to move to")
                    Text("• Red pieces are traditional “white” pieces and blue pieces are “black” pieces for visual clarity in the computer rendered 3D scene")
                    Text("• Rank 1-8 ( 3D x-component) and File a-h (3D y-component) are the same as traditional chess. The eight vertically stacked boards are numbered i - viii (3D z-component). The current square location of the piece is listed as - z, file(y), rank(X)  - eg. iii g4")
                    Text("• All the pieces move in the same basic way as in traditional chess but they can also have a vertical component (z-direction in 3D axes) to the basic traditional chess move. All pieces can move up or down within normal piece-specific constraints if they are on higher board level than z = i. See more below")
                    Text("• Piece captures work in traditional 2D-move directions and 3D-move directions")
                    Text("• There are currently 44 pieces in a Chess 3D game")
                    Text("• On level z = i the piece layout is the same as traditional chess with 16 pieces including king and queen")
                    Text("• There are another 16 “extended pawns” on z = ii")
                    Text("• On levels v - viii there are a further 12 “aerial” pieces - two bishops, one rook, one knight and eight pawns positioned three pieces per level. See below")
                    Text("• The piece layout may change in the future depending on player feedback")
                    
                }
                
                Group {
                    Text("Basic Movement")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("• Each piece can move in its traditional 2D pattern plus vertical movement component")
                    Text("• Pawns move forward one square or up/down one level and capture with a diagonal x-component, either traditional 2D capture or a 3D capture with changes in z,y,x")
                    Text("• Pawns on levels z = i and ii can open with a two-square move forwards or up. Aerial pawns (z = v-viii) can only move one square for the first move")
                    Text("• Rooks move horizontally, vertically, and can change levels in straight lines")
                    Text("• Bishops can move diagonally in 3D - z,y,x changes using orange move-arrows, or they and can change z-levels diagonally in 2D planes - z,x or z,y - using the purple move-arrows")
                    Text("• Knights move in two-click L-shapes and can jump to different levels, with first click the two-square move direction, followed by the one-square move direction.")
                    Text("• Queens combine rook and bishop movement in 3D space")
                    Text("• Kings move one square in any direction including up/down")
                }
                
                Group {
                    Text("Special Rules")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("• Castling: King and rook can castle on level z = i if they haven't moved and the path is clear")
                    Text("• En Passant: Pawns can capture diagonally forward if opponent pawn moved two spaces on z = i only")
                    Text("• Pawn Promotion: Pawns promote to queen, rook, bishop, or knight when reaching the opposite end on levels z = i and viii only")
                    
                   
                }
                
                Group {
                    Text("3D Specific Rules")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("• Pieces can attack across different levels if they have line of sight")
                    Text("• Pawns can capture with diagonal forward, up or down moves")
                    Text("• Vertical-component movement counts as one move, not separate from horizontal")
                    Text("• Pieces cannot move through other pieces (except knights)")
                    Text("• Board rotates to show different perspectives during gameplay")
                    Text("• Captured pieces are moved to graveyard areas on the sides")
                }
                
                Group {
                    Text("Game Modes")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("• Play Mode: Standard chess gameplay for two players on one device")
                    Text("• Learn Mode: Practice moves in succession on red/white pieces without changes to black")
                    Text("• AI Opponent: Play against computer")
                    Text("• Multiplayer: Play against other players via Apple Game Center")
                }
                
                Group {
                    Text("Controls")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("• Tap pieces to select, tap distance to select squares moved, tap move arrows for direction")
                    Text("• Red, green and yellow arrows are for traditional 2D moves, blue arrows for vertical z-moves, orange arrows for full 3D moves and purple arrows for 2D vertical-plane moves")
                    Text("• Drag to rotate board view")
                    Text("• iOS - Pinch to zoom in/out on controls only, use buttons to zoom in and out on the boards and pieces")
                    Text("• Use camera controls to adjust zoom and board height, and reset to default position")
                    Text("• Cancel moves within 5 seconds or they will be confirmed and the play turn will rotate")
                    Text("• Press New Game to reset the boards")
                    Text("• Press Flip boards in Game Centre mode to rotate black/white player")
                }
                
                Group {
                    Text("Learn More")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Link("Visit our Website for more information", destination: URL(string: "https://www.3dchesscubed.com/")!)
                        .foregroundColor(.blue)
                        .underline()
                    
                    Link("Visit our Youtube channel for tutorials", destination: URL(string: "https://www.youtube.com/channel/UCpAyiD9_XSkWPk7YObMUIfQ")!)
                        .foregroundColor(.blue)
                        .underline()
                    
                    Link("Follow us on X", destination: URL(string: "https://x.com/3DChesscube")!)
                        .foregroundColor(.blue)
                        .underline()
                    
                    Text("• Contact us: 3dchesscube@gmail.com")
                    
                    Text("• This game is the copyright of GR Costa, patent pending")
                }
            }
            .padding()
        }
        .frame(maxWidth: 400, maxHeight: 600)
        .background(.regularMaterial)
        .cornerRadius(12)
        //.onAppear {
            // Start 20-second timer to auto-hide
          //  hideTimer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: //false) { _ in
              //  isPresented = false
       //     }
      //  }
      //  .onDisappear {
       //     hideTimer?.invalidate()
       //     hideTimer = nil
       // }
    }
}

#Preview {
    ChessRulesView(isPresented: .constant(true))
}
