# CLAUDE.md — Vepo (iOS Hydration Monitor)

## Project Identity

**Vepo** is a passive hydration monitoring system for autistic individuals who struggle with interoception. An ESP32 smart water bottle sends IMU data over BLE to this iOS app, which detects drinking events, tracks temporal gaps, and sends gentle reminders.

**This is NOT a fitness/volume tracker.** The core value is detecting *time gaps* between drinks and providing low-friction environmental support.

## Tech Stack

- **Language:** Swift (Swift concurrency: async/await)
- **UI:** SwiftUI + MVVM
- **Persistence:** SwiftData
- **BLE:** CoreBluetooth
- **Notifications:** UNUserNotificationCenter
- **Haptics:** CoreHaptics
- **Target:** iOS 17+
- **Future:** CoreML + DBSCAN clustering

## Architecture

```
ESP32 (bottle) —[BLE]—> iOS App —> SwiftData (local)
                                 —> Notifications
                                 —> Haptics
                                 —> (Future) CoreML
```

### Modules

| Module | Responsibility |
|---|---|
| `BLEManager` | BLE lifecycle — scan, connect, discover characteristics, receive data. `CBCentralManager` + `CBPeripheralDelegate`. |
| `SensorDataProcessor` | Parses sensor readings, runs drink detection FSM (lift -> tilt -> return). |
| `LocalDataStore` | Persists drink events and session metadata via SwiftData. Offline-first. |
| `NotificationService` | Monitors `time_since_last_drink`, triggers reminders when threshold exceeded. |

Modules must stay **decoupled** — BLEManager must not know about UI.

## BLE Protocol

- ESP32 advertises a known service UUID
- App scans, connects, discovers GATT service, subscribes to notify characteristics
- Incoming packets: raw bytes -> `acc_x, acc_y, acc_z, gyro_x, gyro_y, gyro_z` + timestamp
- Auto-reconnect on disconnect

## Drink Detection (Rule-Based FSM)

```
Idle -> PickedUp -> Tilted/Drinking -> PutDown -> Idle
```

Three-phase motion sequence from IMU data:
1. **Lift** — acceleration spike (z-axis)
2. **Tilt** — sustained gyroscope rotation (x-axis)
3. **Return** — acceleration/gyro stabilize to resting thresholds

Constraints:
- Full sequence within 2-5 seconds
- Exclude continuous motion (walking)
- Minimum thresholds filter noise (backpack, desk bumps)

Sip event conjunction:
```
sip_event =
  (tilt_angle > threshold for >= t seconds)
  AND (lift_event OR acceleration pattern consistent with lifting)
  AND (NOT shake pattern)
```

## Signal Processing

- **Smoothing:** Rolling mean (0.3-1.0s window) on accel/gyro
- **Magnitude:** `|a| = sqrt(ax^2 + ay^2 + az^2)`
- **Complementary filter:** Fuses accelerometer (long-term stable) + gyroscope (short-term stable)
- **Thresholding:** Lift = `|a|` spike; Drinking = tilt angle above threshold for >= X seconds

## Data Schema

### Raw Sensor Data
`timestamp`, `acc_x`, `acc_y`, `acc_z`, `gyro_x`, `gyro_y`, `gyro_z`

### Event Level
`event_detected` (binary), `time_since_last_drink` (minutes), `event_duration` (seconds)

### Session & Context
`session_id`, `user_id`

### Derived Features (future ML)
`window_mean_acc`, `window_variance_acc`, `event_frequency`

## Notifications

- Default threshold: 60 minutes without drink event
- Local push via UNUserNotificationCenter — brief, unobtrusive
- Haptic feedback via CoreHaptics — subtle vibration
- Focus Mode compatible
- Future: adaptive thresholds from DBSCAN clustering

## UI Principles

- **Minimal, low-friction** — reduce cognitive load
- **Clear typography, muted colors** — avoid sensory overload
- **No manual logging** — everything is passive/automatic

### Views
1. **Connection Status** — BLE state + scan/pair button
2. **Event Log** — Chronological drink events with timestamps and intervals
3. **Session Summary** — Total events, longest gap, live time-since-last-drink counter

## User Settings

- Reminder wait time (gap before notification)
- Notification type: vibration, visual, or both
- Reminder pause periods (sleep, activities)

## Code Conventions

- All sensor thresholds as **named constants** with comments explaining rationale and units
- SwiftUI + MVVM pattern
- Swift concurrency (async/await) for BLE and data operations
- Immutable data patterns — create new objects, don't mutate
- Graceful BLE disconnection recovery — never crash on bad sensor data
- Small, focused files (200-400 lines typical, 800 max)
- Functions under 50 lines
- No magic numbers

## Commands

```bash
# Build (Xcode)
xcodebuild -scheme Vepo -destination 'platform=iOS Simulator,name=iPhone 15'

# Tests
xcodebuild test -scheme Vepo -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Links

- **Trello:** https://trello.com/invite/b/698fcb72e3e2f1820949ceca/ATTI84aad7992f6dbf42c58a4558fe3aa4ee45C21AA2/vepocaeebraaocge
- **GitHub:** https://github.com/EstebanCaso/Vepo
- **ML Proposal:** https://www.overleaf.com/read/hvgsvtyrkjdx#b0380d
