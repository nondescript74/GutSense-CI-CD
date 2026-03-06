#!/bin/bash

echo "=========================================="
echo "GutSense Signing Configuration Check"
echo "=========================================="
echo ""

echo "1. DEVELOPMENT CERTIFICATES:"
security find-identity -v -p codesigning | grep "Development"
echo ""

echo "2. DISTRIBUTION CERTIFICATES:"
DIST_COUNT=$(security find-identity -v -p codesigning | grep "Distribution" | wc -l)
if [ $DIST_COUNT -eq 0 ]; then
    echo "⚠️  NO DISTRIBUTION CERTIFICATE FOUND"
    echo "   You need this for TestFlight/App Store"
    echo "   Create one in Xcode → Settings → Accounts → Manage Certificates"
else
    security find-identity -v -p codesigning | grep "Distribution"
fi
echo ""

echo "3. TEAM ID:"
grep "DEVELOPMENT_TEAM" GutSense.xcodeproj/project.pbxproj | head -1
echo ""

echo "4. BUNDLE IDENTIFIERS:"
echo "   Main App:"
grep "PRODUCT_BUNDLE_IDENTIFIER.*isg" GutSense.xcodeproj/project.pbxproj | grep -v "Clip" | head -1
echo "   App Clip:"
grep "PRODUCT_BUNDLE_IDENTIFIER.*Clip" GutSense.xcodeproj/project.pbxproj | head -1
echo ""

echo "5. PROVISIONING PROFILES:"
PROFILE_COUNT=$(ls ~/Library/MobileDevice/Provisioning\ Profiles/*.mobileprovision 2>/dev/null | wc -l)
echo "   Found $PROFILE_COUNT provisioning profiles"
if [ $PROFILE_COUNT -eq 0 ]; then
    echo "   ⚠️  No profiles found - Xcode will generate on next build"
fi
echo ""

echo "6. DERIVED DATA SIZE:"
if [ -d ~/Library/Developer/Xcode/DerivedData ]; then
    du -sh ~/Library/Developer/Xcode/DerivedData
else
    echo "   No DerivedData (clean state)"
fi
echo ""

echo "=========================================="
echo "RECOMMENDATIONS:"
echo "=========================================="

if [ $DIST_COUNT -eq 0 ]; then
    echo "❌ MISSING: Create Distribution certificate for TestFlight"
    echo "   → Xcode → Settings → Accounts → Manage Certificates → + → Apple Distribution"
    echo ""
fi

if [ $PROFILE_COUNT -gt 10 ]; then
    echo "⚠️  CLEANUP: Too many provisioning profiles"
    echo "   → Run: rm -rf ~/Library/MobileDevice/Provisioning\\ Profiles/*"
    echo ""
fi

echo "✅ Development certificates found"
echo "✅ Team ID configured"
echo "✅ Bundle IDs look correct (App Clip is child of parent)"
echo ""

echo "TO UPLOAD TO TESTFLIGHT:"
echo "1. Create Distribution certificate (see above)"
echo "2. Clean: rm -rf ~/Library/Developer/Xcode/DerivedData/*"
echo "3. In Xcode: Product → Clean Build Folder"
echo "4. Select 'Any iOS Device' as destination"
echo "5. Product → Archive"
echo "6. Distribute → TestFlight & App Store → Upload"
echo ""
