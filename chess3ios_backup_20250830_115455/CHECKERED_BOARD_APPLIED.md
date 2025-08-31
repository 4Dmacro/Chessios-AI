# Checkered Board Pattern Applied to iOS

## 🎯 **Changes Applied**

### **1. Added Plane Counter**
```swift
// Counter for chess board squares to create checkered pattern
private var planeCounter: Int = 0
```

### **2. Updated Chess Board Glass Function**
Applied the checkered pattern logic from macOS:
```swift
// Apply proper chess board pattern: first square (a1) should be dark
if planeCounter % 2 == 1 {
    // light tint (white squares) - for odd-numbered planes
    glassMaterial.diffuse.contents = UIColor(red: 0.95, green: 0.98, blue: 1.0, alpha: 0.1)
} else {
    // dark tint (black squares) - for even-numbered planes  
    glassMaterial.diffuse.contents = UIColor(red: 0.7, green: 0.8, blue: 0.9, alpha: 0.25)
}
```

### **3. Enhanced Material Properties**
- **Transparency**: 0.15 (reduced from 0.3)
- **Transparency Mode**: `.aOne`
- **Metalness**: 0.0
- **Roughness**: 0.1 (more subtle glass effect)

### **4. Smart Material Application**
- **Plane geometries** → Get checkered board pattern
- **Other geometries** → Get regular liquid glass
- **Chess pieces** → Keep original Blender materials

## 🎮 **Expected Results**

Now you should see:
1. **Checkered board pattern** - Alternating light and dark squares
2. **Proper chess board layout** - Queens on their own colored squares
3. **Subtle glass effect** - Transparent, reflective squares
4. **Original piece materials** - Chess pieces unchanged

## 🔍 **What to Look For**

- **Light squares** - Very light blue tint (odd-numbered planes)
- **Dark squares** - Darker blue tint (even-numbered planes)
- **Proper pattern** - Standard chess board layout
- **Glass transparency** - Subtle, not overwhelming

## 🚀 **Debug Output**

Look for these messages:
```
🔷 Applied light glass to plane 1: [square name]
🔷 Applied dark glass to plane 2: [square name]
🔷 Applied glass material to plane: [square name]
```

The chess board should now have the proper checkered pattern like in the macOS version! 🎯

