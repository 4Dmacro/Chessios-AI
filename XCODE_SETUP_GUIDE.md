# Xcode Setup Guide for Chess3 Target

## Step 1: Add Files to Project
1. In Xcode, right-click on the project root (blue "chess z" icon)
2. Select "Add Files to 'chess z'"
3. Navigate to your project folder
4. Select the `chess3` folder and click "Add"
5. Repeat for `chess3Tests` and `chess3UITests` folders

## Step 2: Create New Target
1. Go to **File → New → Target**
2. Choose **macOS → App**
3. Set Product Name: `chess3`
4. Set Bundle Identifier: `com.yourcompany.chess3` (adjust as needed)
5. Choose **SwiftUI** interface
6. **Uncheck** "Use Core Data"
7. **Uncheck** "Include Tests" (we already have them)
8. Click **Finish**

## Step 3: Set Target Membership
1. Select all files in the `chess3` folder in Project Navigator
2. Open the **File Inspector** (right sidebar)
3. Under **Target Membership**, check the box for `chess3`
4. Repeat for all test files in `chess3Tests` and `chess3UITests`

## Step 4: Build and Test
1. Select the `chess3` scheme from the scheme dropdown
2. Build the project (⌘+B)
3. Run the app (⌘+R)

## Troubleshooting
- If you get build errors, make sure all files are added to the correct target
- Check that `aerialchess.usdz` is included in the `chess3` target
- Verify that the bundle identifier is unique

## Next Steps
After setup, you may need to:
1. Update piece mapping for the new `aerialchess.usdz` model
2. Test piece selection and movement
3. Adjust camera controls if needed

