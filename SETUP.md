# Xcode Setup Guide

## 1. Create Xcode Project

1. Open Xcode → File → New → Project
2. Choose **iOS → App**
3. Settings:
   - Product Name: `Vepo`
   - Team: Your team
   - Organization Identifier: `com.vepo`
   - Interface: **SwiftUI**
   - Storage: **SwiftData**
   - Language: **Swift**
4. Save to a temporary location

## 2. Replace Source Files

1. Delete the auto-generated `ContentView.swift` and `VepoApp.swift` from the project
2. Drag the entire `Vepo/` folder from this repo into the Xcode project navigator
3. Drag the `VepoTests/` folder into the test target
4. Make sure "Copy items if needed" is checked
5. Add files to the `Vepo` target (source) or `VepoTests` target (tests)

## 3. Configure Info.plist

The `Info.plist` is already created with all required entries. In Xcode:
1. Go to project settings → Info tab
2. Verify these keys are present:
   - `NSBluetoothAlwaysUsageDescription`
   - `NSBluetoothPeripheralUsageDescription`
   - `UIBackgroundModes` → `bluetooth-central`, `processing`

## 4. Configure Entitlements

1. Select the project → Signing & Capabilities
2. Add **Background Modes** → check "Uses Bluetooth LE accessories"
3. The `Vepo.entitlements` file handles this

## 5. Set Deployment Target

1. Project → General → Minimum Deployments → **iOS 17.0**

## 6. Test with Mock BLE (No Physical Bottle Needed)

To run the app with simulated sensor data:

1. Edit Scheme → Run → Arguments → Environment Variables
2. Add: `USE_MOCK_BLE` = `1`
3. Run the app — it will auto-connect and simulate drink events every 45 seconds

To use the real BLE bottle, remove or set `USE_MOCK_BLE` = `0`.

## 7. Run Tests

```
Cmd+U to run all tests
```

Tests use in-memory SwiftData containers — no device or BLE required.

## 8. Previews

All views have SwiftUI previews configured in `PreviewHelpers.swift`.
Open any view file and the canvas will show a live preview with mock data.
