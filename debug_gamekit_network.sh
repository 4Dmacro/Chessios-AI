#!/bin/bash

echo "🔍 GameKit Network Diagnostics for macOS"
echo "========================================"

echo ""
echo "1. Checking Game Center status..."
if system_profiler SPGameCenterDataType | grep -q "Game Center: Enabled"; then
    echo "✅ Game Center is enabled"
else
    echo "❌ Game Center may not be enabled"
fi

echo ""
echo "2. Checking network permissions..."
echo "   Looking for network entitlements in app bundles..."

# Find all .app bundles in the current directory and subdirectories
find . -name "*.app" -type d | while read app_path; do
    echo "   Checking: $app_path"
    if [ -f "$app_path/Contents/embedded.provisionprofile" ]; then
        echo "   ✅ Has embedded provisioning profile"
    else
        echo "   ⚠️  No embedded provisioning profile"
    fi
    
    if [ -f "$app_path/Contents/Info.plist" ]; then
        echo "   ✅ Has Info.plist"
    else
        echo "   ❌ Missing Info.plist"
    fi
done

echo ""
echo "3. Checking firewall status..."
if /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate | grep -q "Firewall is enabled"; then
    echo "⚠️  Firewall is enabled - this may block GameKit connections"
    echo "   Consider temporarily disabling firewall for testing"
else
    echo "✅ Firewall is disabled"
fi

echo ""
echo "4. Checking network interfaces..."
networksetup -listallnetworkservices | while read service; do
    if [ "$service" != "An asterisk (*) denotes that a network service is disabled." ]; then
        echo "   Network service: $service"
        if networksetup -getinfo "$service" 2>/dev/null | grep -q "Connected: Yes"; then
            echo "   ✅ Connected"
        else
            echo "   ❌ Not connected"
        fi
    fi
done

echo ""
echo "5. GameKit Troubleshooting Steps:"
echo "   • Ensure both devices are signed into the same Apple ID"
echo "   • Try running the app outside of Xcode (Product → Archive → Distribute)"
echo "   • Check that both devices are on the same network"
echo "   • Temporarily disable firewall for testing"
echo "   • Ensure Game Center is enabled in System Preferences"
echo "   • Try signing out and back into Game Center"

echo ""
echo "6. Network Entitlements Check:"
echo "   The app should have these entitlements:"
echo "   • com.apple.security.network.client"
echo "   • com.apple.security.network.server" 
echo "   • com.apple.security.network.peer-to-peer"
echo "   • com.apple.developer.game-center"

echo ""
echo "🔍 Diagnostics complete!"

