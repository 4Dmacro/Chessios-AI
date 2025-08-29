# Fix Code Signing for Chess3 Target

## Quick Fix Steps:

### Option 1: Disable Code Signing (Easiest for Development)
1. In Xcode, select the **chess3 target**
2. Go to **"Build Settings"** tab
3. Search for **"Code Signing"**
4. Set **"Code Signing Identity"** to **"Don't Code Sign"**
5. Set **"Code Signing Style"** to **"Manual"**

### Option 2: Configure Code Signing Properly
1. In Xcode, select the **chess3 target**
2. Go to **"Signing & Capabilities"** tab
3. Set **Team** to your development team (or "None")
4. Check **"Automatically manage signing"**
5. Make sure **Bundle Identifier** is unique (e.g., `com.yourcompany.chess3`)

### Option 3: Use Simulator Only
1. Set **"Code Signing Identity"** to **"Don't Code Sign"**
2. Run the app in **Simulator** instead of on device
3. This bypasses code signing requirements

## After Making Changes:
1. **Clean Build Folder** (Product → Clean Build Folder)
2. **Build** the project (⌘+B)
3. **Run** the app (⌘+R)

## Common Issues:
- **"No signing certificate"**: Use Option 1 above
- **"Bundle identifier already exists"**: Change the bundle ID to be unique
- **"Team not found"**: Set Team to "None" for local development

## For Distribution:
If you plan to distribute the app later, you'll need proper code signing with a valid Apple Developer account.

