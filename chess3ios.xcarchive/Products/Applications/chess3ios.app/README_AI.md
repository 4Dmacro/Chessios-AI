# 3D Chess AI Implementation

## Overview

This implementation adds a sophisticated AI opponent to your 3D chess game that understands all the unique 3D chess rules and can play strategically.

## Features

### 🤖 AI Capabilities
- **3D Move Generation**: Handles all Z-axis moves, 3D diagonals, and extended pawn movements
- **3D-Specific Rules**: Respects en passant only on 2D plane, 3D piece movement patterns
- **Position Evaluation**: Evaluates 3D board positions considering height advantage, material value, and strategic positioning
- **Multiple Difficulty Levels**: Easy (2-ply), Medium (3-ply), Hard (4-ply) search depths
- **Alpha-Beta Pruning**: Optimized search algorithm for better performance

### 🎯 AI Evaluation Factors
- **Material Value**: Standard chess piece values (pawn=100, queen=900, etc.)
- **Positional Advantage**: Center control, height advantage, pawn structure
- **3D-Specific Evaluation**: 
  - Height advantage for pieces
  - Control of multiple Z-levels
  - 3D mobility assessment
- **King Safety**: Penalizes exposed kings, rewards castled positions
- **Pawn Structure**: Evaluates doubled pawns, isolated pawns, passed pawns

### 🎮 User Interface
- **AI Activation**: Click "🤖 vs AI" to activate AI opponent
- **Manual AI Move**: Click "Manual AI Move" to trigger AI move manually
- **Visual Feedback**: AI thinking status and move execution feedback
- **Automatic Play**: AI automatically makes moves when it's its turn

## Technical Implementation

### Core Components

1. **ChessAI.swift**: Main AI engine with minimax algorithm and position evaluation
2. **ChessEngine.swift**: Enhanced with AI support methods (makeMove, undoMove, etc.)
3. **ChessGameManager.swift**: AI integration and move execution
4. **ContentView.swift**: AI controls and user interface

### Key Methods

#### AI Decision Making
```swift
func getBestMove() -> ChessMove3D?
```
- Uses minimax algorithm with alpha-beta pruning
- Evaluates all possible moves to specified depth
- Returns the best move based on position evaluation

#### Position Evaluation
```swift
private func evaluatePosition() -> Int
```
- Combines material, positional, mobility, and 3D-specific factors
- Returns numerical score (positive favors AI, negative favors opponent)

#### 3D Move Generation
```swift
private func getAllValidMoves(for color: PieceColor) -> [ChessMove3D]
```
- Generates all valid moves for a given color
- Respects all 3D chess rules and piece movement patterns

### 3D-Specific Features

#### Height Advantage
- Pieces on higher Z-levels get positional bonuses
- AI considers control of multiple levels as strategic advantage

#### 3D Diagonal Movement
- Bishops can move in 3D diagonals (file+Z, rank+Z, or all three axes)
- Queens combine rook and bishop movement in 3D space

#### Extended Pawn Rules
- 16 additional pawns on Z=1 level
- Pawns can move forward in rank and Z-axis
- En passant only works on 2D plane (same Z-level)

## Usage

### Starting AI Game
1. Launch the chess game
2. Click "🤖 vs AI" button to activate AI opponent
3. AI will play as Black, you play as White
4. AI automatically makes moves when it's its turn

### Manual AI Control
- Click "Manual AI Move" to trigger AI move manually
- Useful for testing or when you want to control AI timing

### Difficulty Levels
- **Easy**: 2-ply search (good for beginners)
- **Medium**: 3-ply search (balanced challenge)
- **Hard**: 4-ply search (strong opponent)

## Performance

- **Search Efficiency**: Alpha-beta pruning reduces search space significantly
- **Move Generation**: Optimized for 3D chess with 512 total squares
- **Evaluation Speed**: Fast position evaluation with multiple factors
- **Memory Usage**: Minimal memory footprint for move tree

## Future Enhancements

- **Opening Book**: Pre-calculated opening moves for 3D chess
- **Endgame Tables**: Specialized evaluation for endgame positions
- **Machine Learning**: Neural network-based position evaluation
- **Multi-threading**: Parallel search for deeper analysis
- **Move History**: Learning from previous games

## Debug Information

The AI provides detailed console output including:
- Move calculation time
- Position evaluation scores
- Move generation counts
- 3D-specific rule applications

Example output:
```
🤖 AI (black) calculating best move with difficulty: medium
🤖 AI found 24 valid moves
🤖 AI chose move: i a2 -> i a4
🤖 AI evaluation score: 150
🤖 AI calculation time: 0.234s
```

## Technical Notes

- AI uses the same board representation as the game engine
- All 3D chess rules are properly implemented and respected
- Move validation ensures legal moves only
- Position evaluation considers 3D-specific strategic elements
- Alpha-beta pruning optimizes search performance 