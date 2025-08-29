# Device Adaptive ContentView Guide

## Overview

The `DeviceAdaptiveContentView` provides automatic UI adaptation for different iOS devices (iPhone vs iPad) with gesture-based UI scaling capabilities.

## Key Features

### 1. **Automatic Device Detection**
- **iPhone**: Compact layout with smaller controls
- **iPad**: Full layout with larger controls
- Uses SwiftUI's `@Environment(\.horizontalSizeClass)` and `@Environment(\.verticalSizeClass)`

### 2. **Gesture-Based UI Scaling**
- **Pinch to Zoom UI**: Use pinch gestures to scale the entire UI
- **Scale Range**: 0.3x to 2.5x (automatically clamped)
- **Smooth Animation**: Real-time scaling with gesture feedback

### 3. **Adaptive Layouts**

#### iPhone Layout (Compact)
- **Top Controls**: Camera and game controls in horizontal layout
- **Bottom Controls**: Piece controller at bottom
- **Smaller Buttons**: Compact button style with reduced padding
- **Optimized Spacing**: Reduced spacing for smaller screens

#### iPad Layout (Full)
- **Side Controls**: Camera and game controls on left side
- **Right Controls**: Piece controller on right side
- **Larger Buttons**: Full-size buttons with more padding
- **Generous Spacing**: Comfortable spacing for larger screens

## How to Use

### 1. **Replace Your Current ContentView**
```swift
// In your App.swift file, change:
ContentView()
// To:
DeviceAdaptiveContentView()
```

### 2. **Gesture Controls**
- **Tap**: Select chess pieces
- **Drag**: Rotate the chess board
- **Pinch**: Scale the UI controls (new feature!)

### 3. **UI Scaling**
- Pinch outward to make UI larger
- Pinch inward to make UI smaller
- UI automatically snaps to reasonable bounds (0.5x to 2.0x)

## Customization

### Button Styles
- `CompactButtonStyle`: For iPhone (smaller, tighter)
- `AdaptiveButtonStyle`: For iPad (larger, more spacious)

### Adaptive Sizing
```swift
private var buttonFontSize: Font {
    isIPhone ? .caption2 : .caption
}

private var buttonSpacing: CGFloat {
    isIPhone ? 6 : 12
}
```

## Benefits

1. **Better iPhone Experience**: Compact controls that don't overwhelm the screen
2. **Optimal iPad Experience**: Full-size controls that use the larger screen space
3. **Accessibility**: Users can scale UI to their preference
4. **Future-Proof**: Automatically adapts to new device sizes
5. **Consistent Codebase**: Single view handles all device types

## Implementation Notes

- All game logic is preserved from the original ContentView
- SceneKit integration remains unchanged
- AI functionality works identically
- Touch handling is optimized for each device type

## Testing

Test on different devices/simulators:
- iPhone SE (smallest)
- iPhone 15 Pro (medium)
- iPhone 15 Pro Max (large)
- iPad (regular)
- iPad Pro (largest)

The UI will automatically adapt to each device's characteristics.

