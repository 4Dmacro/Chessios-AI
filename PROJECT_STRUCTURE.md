# Chess Project Structure

## 📁 **Project Organization**

### **🎯 Main Apps**

#### **chess3/** - macOS Version
- **Platform**: macOS 14.6+
- **Purpose**: Desktop chess game with mouse interactions
- **Key Files**:
  - `chess3App.swift` - macOS app entry point
  - `GameKitManager.swift` - macOS GameKit integration
  - `MultiplayerView.swift` - macOS multiplayer interface
  - `ContentView.swift` - macOS UI with mouse interactions
  - `ChessPieceController.swift` - Mouse-based 3D interactions
  - `chess3.entitlements` - macOS entitlements

#### **chess3ios/** - iOS Version
- **Platform**: iOS 14.0+ (iPhone + iPad)
- **Purpose**: Mobile chess game with touch interactions
- **Key Files**:
  - `chess3iosApp.swift` - iOS app entry point
  - `GameKitManager.swift` - iOS GameKit integration
  - `MultiplayerView.swift` - iOS multiplayer interface
  - `ContentView.swift` - iOS UI with touch interactions
  - `ChessPieceController.swift` - Touch-based 3D interactions
  - `chess3ios.entitlements` - iOS entitlements

### **🔄 Shared Files (Both Apps)**

#### **Core Logic** (Identical in both apps)
- `ChessEngine.swift` - Core chess rules and board logic
- `ChessAI.swift` - AI move generation and evaluation
- `ChessGameManager.swift` - Game state management
- `PromotionChoiceView.swift` - Pawn promotion UI
- `ScreenSpaceSelection.swift` - Screen space utilities

#### **Assets** (Identical in both apps)
- `Assets.xcassets/` - App icons and UI assets
- `*.usdz` - 3D chess piece models
- `*.scn` - SceneKit scene files
- `README_AI.md` - AI documentation

### **📱 Platform-Specific Differences**

#### **macOS (chess3/)**
- **Input**: Mouse clicks and drags
- **UI**: Desktop-style controls and layout
- **GameKit**: macOS-specific presentation
- **Window Management**: NSApplication-based

#### **iOS (chess3ios/)**
- **Input**: Touch taps and drags
- **UI**: Mobile-responsive design
- **GameKit**: iOS-specific presentation
- **Window Management**: UIApplication-based

## 🚀 **Next Steps**

### **For Xcode Setup:**

1. **Create iOS Target**:
   - File → New → Target → iOS → App
   - Name: "chess3ios"
   - Language: Swift
   - Interface: SwiftUI
   - Deployment: iOS 14.0+

2. **Add Files to iOS Target**:
   - Add all files from `chess3ios/` folder
   - Ensure Game Center capability is enabled

3. **Configure Entitlements**:
   - Add `chess3ios.entitlements` to iOS target
   - Enable Game Center capability

### **For Development:**

1. **macOS Development**: Work in `chess3/` folder
2. **iOS Development**: Work in `chess3ios/` folder
3. **Shared Logic**: Update both folders when changing core logic
4. **Testing**: Test both platforms independently

## 📋 **File Mapping**

| Purpose | macOS (chess3/) | iOS (chess3ios/) |
|---------|-----------------|------------------|
| App Entry | `chess3App.swift` | `chess3iosApp.swift` |
| GameKit | `GameKitManager.swift` | `GameKitManager.swift` |
| Multiplayer UI | `MultiplayerView.swift` | `MultiplayerView.swift` |
| Main UI | `ContentView.swift` | `ContentView.swift` |
| 3D Interactions | `ChessPieceController.swift` | `ChessPieceController.swift` |
| Entitlements | `chess3.entitlements` | `chess3ios.entitlements` |

## 🎯 **Benefits of This Structure**

1. **Clear Separation**: No confusion between platforms
2. **Independent Development**: Can work on each platform separately
3. **Shared Logic**: Core chess logic stays synchronized
4. **Platform Optimization**: Each version optimized for its platform
5. **Easier Testing**: Can test each platform independently
6. **Cleaner Code**: No platform-specific conditionals cluttering the code

## 🔧 **Development Workflow**

1. **Core Logic Changes**: Update both `chess3/` and `chess3ios/`
2. **Platform-Specific Changes**: Update only the relevant platform folder
3. **Testing**: Test each platform separately
4. **Deployment**: Deploy each platform independently

This structure gives you the best of both worlds - shared logic for consistency, but platform-specific implementations for optimal user experience!

