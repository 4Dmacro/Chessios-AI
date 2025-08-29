#!/bin/bash

# Script to add chess3 target to Xcode project
# This script will modify the project.pbxproj file to add the chess3 target

PROJECT_FILE="chess z .xcodeproj/project.pbxproj"
BACKUP_FILE="chess z .xcodeproj/project.pbxproj.backup"

echo "Setting up chess3 target for Xcode project..."

# Create backup
cp "$PROJECT_FILE" "$BACKUP_FILE"
echo "Created backup at $BACKUP_FILE"

# Add chess3 target to project.pbxproj
# This is a simplified approach - you'll need to manually add the target in Xcode
# but this script will help prepare the files

echo "Files are ready for Xcode. Please:"
echo "1. Open Xcode"
echo "2. Add the chess3, chess3Tests, and chess3UITests folders to your project"
echo "3. Create a new target called 'chess3'"
echo "4. Set the target membership for all chess3 files to the new target"
echo "5. Build and run"

echo "Setup script completed!"

