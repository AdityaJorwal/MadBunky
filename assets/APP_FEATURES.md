# MadBunky Pro — Complete Feature Reference

> **Version:** 1.0.0 · **Platform:** Android & iOS · **Built With:** Flutter  
> *The intelligent academic attendance companion built for students who bunk responsibly.*

---

## Table of Contents

1. [Core Attendance Tracking](#1-core-attendance-tracking)
2. [Bunk Budget Intelligence Engine](#2-bunk-budget-intelligence-engine)
3. [Smart Timetable & Schedule Management](#3-smart-timetable--schedule-management)
4. [Automation Suite](#4-automation-suite)
5. [Notification System](#5-notification-system)
6. [Analytics & Statistics](#6-analytics--statistics)
7. [Calendar Integration](#7-calendar-integration)
8. [Home Screen Widgets](#8-home-screen-widgets)
9. [Live Activities (iOS)](#9-live-activities-ios)
10. [Quick Settings Tile (Android)](#10-quick-settings-tile-android)
11. [OCR Timetable Scanner](#11-ocr-timetable-scanner)
12. [Backup & Restore System](#12-backup--restore-system)
13. [Theme & Customization Engine](#13-theme--customization-engine)
14. [Holiday Awareness](#14-holiday-awareness)
15. [Sync & Import/Export](#15-sync--importexport)
16. [Authentication & User Profiles](#16-authentication--user-profiles)
17. [Background Service & Power Management](#17-background-service--power-management)
18. [Debug & Developer Tools](#18-debug--developer-tools)
19. [Data Models Overview](#19-data-models-overview)
20. [Settings Reference](#20-settings-reference)

---

## 1. Core Attendance Tracking

The heart of MadBunky Pro is its clean, fast, and expressive attendance tracking system.

### 1.1 Subject Management
- **Add / Edit / Delete Subjects** — Each subject stores:
  - Name, optional teacher name, optional topic/notes
  - Color accent (custom or system color)
  - Target attendance percentage (default: 75%, fully customizable)
  - Attendance counters: `present`, `absent`, `proxy`, `ambiguous`
  - Full history log of every marking action
- **Subject Groups (Folders)** — Subjects can be organized into named groups/folders with optional color accents. Groups are collapsible on the home screen for better organization.
- **Show Outline Toggle** — Optional card outline for visual differentiation between subjects.

### 1.2 One-Tap Attendance Marking
Four marking states are supported:
| Status | Meaning | Counter |
|--------|---------|---------|
| **Present** ✅ | Attended the class | `present++` |
| **Absent** ❌ | Missed the class | `absent++` |
| **Proxy** ⚡ | Marked present by a friend | `proxy++` |
| **Ambiguous** ❓ | Uncertain/partially attended | `ambiguous++` |

> **Note:** Both `present` and `proxy` counts toward the attendance percentage — the app treats them as equivalent for calculation purposes.

### 1.3 Attendance Log History
Every action (manual, scheduled, proxy, or auto-marked) is timestamped and saved:
- **LogType** enum: `manual`, `schedule`, `proxy`, `auto`
- Each log stores: timestamp, status, log type, related session ID, and scheduled date
- Logs are accessible per-subject and displayed in reverse-chronological order
- Logs can be deleted individually

### 1.4 Visual Dashboard (Home Screen)
- Color-coded subject cards with:
  - Live attendance percentage badge
  - Health status indicator ("Can miss 3 classes", "Must attend 5 classes", "On track")
  - Subject group membership
  - Quick-action buttons for all four statuses
- Animated, staggered card list with Material 3 design
- Pull-to-refresh and swipe-to-edit gestures

---

## 2. Bunk Budget Intelligence Engine

The proprietary **Bunk Budget** algorithm is what makes MadBunky Pro truly smart. It answers two critical questions in real-time:

### 2.1 "Can Miss" Calculator
> *"How many classes can I safely skip?"*

**Formula (O(1) computation):**
```
canMiss = floor((effectivePresent × 100) / targetPercentage) − totalClasses
```
- If `canMiss > 0` → Shows **"Can miss upcoming X classes"** in green
- Computed instantly without iterative simulation

### 2.2 "Must Attend" Calculator
> *"How many consecutive classes must I attend to recover?"*

**Formula (O(1) computation):**
```
mustAttend = ceil((target × total − 100 × effectivePresent) / (100 − target))
```
- If below target → Shows **"Must attend upcoming X classes"** in red
- Special case for 100% target: Shows **"Cannot reach 100%"** if already below

### 2.3 Status States
| State | Color | Condition |
|-------|-------|-----------|
| Can miss X classes | 🟢 Green | Above target with buffer |
| On track, cannot miss next | 🟡 Orange | Exactly at target |
| Must attend X classes | 🔴 Red | Below target |
| Cannot reach 100% | 🔴 Red | 100% target already violated |
| No classes recorded | 🟡 Orange | `total == 0` |

### 2.4 Smart Bunking Toggle
- When **Smart Bunking** is enabled, the geofence auto-mark feature can decide whether to mark a session based on your current attendance health for that subject
- Prevents over-attendance logging when you're already safely above target

---

## 3. Smart Timetable & Schedule Management

### 3.1 Weekly Schedule Templates
- Create recurring class entries (templates) that define:
  - Subject name & linked subject ID
  - Day of week (Monday–Sunday)
  - Start & end time
  - Color, teacher name, topic
  - `hasTime` flag for all-day events
- Templates automatically generate `ClassSession` objects for each occurrence
- Multiple sessions per day per subject supported

### 3.2 Schedule Viewer (Day & Week View)
- **Day View**: Shows a vertical timeline of all sessions for the selected day
- **Week View**: Bird's eye view of the full week with color-coded blocks
- Sessions display teacher, topic, time, status badge, and cancellation state
- Quick-swipe or tap actions to mark attendance directly from the timetable

### 3.3 Session Management (ClassSession)
Each session on the calendar is a `ClassSession` object with:
- `id`, `subjectName`, `subjectId`, `templateId` (for linking)
- `startTime`, `endTime` (full DateTime with date)
- `colorValue`, `isCancelled`, `status` (pending/present/absent/proxy/ambiguous)
- `isConcrete` (user-confirmed vs auto-generated), `hasTime`, `isEvent`
- Teacher name, topic, batch

### 3.4 Event Support
- Non-class events can be added to the schedule (flagged with `isEvent: true`)
- Events appear on the calendar but do not affect attendance percentages

### 3.5 Cancel / Edit Sessions
- Mark individual sessions as **cancelled** — excluded from tracking
- Edit session details inline (start/end time, teacher, topic)
- Bulk operations available in the schedule grid view

### 3.6 Schedules Grid Screen
- Visual monthly or multi-week grid overview of all sessions
- Quick navigation between weeks/months
- Color-coded by subject for at-a-glance insight

---

## 4. Automation Suite

MadBunky Pro supports three automated attendance detection mechanisms, all **opt-in** and configurable.

### 4.1 Geofence Auto-Detection
- **How it works**: The background service monitors your GPS location. If you are within the radius of a configured campus zone during an active class session, attendance is automatically marked **Present**.
- **Configuration**:
  - Add multiple named campus locations (name, latitude, longitude, radius in meters)
  - Link specific locations to specific subjects (for multi-campus students)
  - If no subjects linked to a location → applies to **all subjects**
- **Segmented Checking**: During an active session, location is checked in 5 equal-time segments (3 segments in Battery Saver mode) within the valid window (excluding first/last 10 minutes of class)
- **Start/End Buffer Zones**: No location checks in the first and last 10 minutes of class (2 minutes for classes < 40 minutes)
- **Trust Mode**: Once auto-marked Present for a session, GPS checks stop for that session to save battery
- **Entry Alert**: A one-time notification is pushed when you enter campus during an active session (if Geofence Alerts are enabled)

### 4.2 WiFi Auto-Detection
- **How it works**: The background service reads the current WiFi SSID. If it matches a configured campus SSID, attendance is marked **Present**.
- **Configuration**: Add multiple campus WiFi SSIDs (supports networks without special characters)
- **Battery Saver Priority**: When Battery Saver is ON, if WiFi match is found, geofence check is skipped entirely
- **Combined Mode**: Both WiFi + Geofence can be active — WiFi is checked first, geofence as fallback

### 4.3 Smart Background Loop
- The background service uses a **Smart Sleep** algorithm:
  - Sleeps until the next session starts (no wasted cycles)
  - Wakes up in segments during active sessions
  - Sleeps up to 30 minutes in standby (no upcoming sessions)
  - Minimum 30-second sleep to prevent OEM battery optimization killing the process
- Supports interrupt signals: The main app can wake the background loop instantly on data changes

---

## 5. Notification System

MadBunky Pro features a rich, multi-layered notification system with actionable notifications.

### 5.1 Scheduled Class Notifications
- Notifications fire at the **start time** of each scheduled class session
- Full notification details include:
  - Subject name, teacher name, session time, topic
  - **Rich Image Notification** (Android): A custom-rendered card image showing class details
  - **Three Action Buttons**: Present ✅ / Proxy ⚡ / Absent ❌ — directly in the notification shade
- Marking status from notification immediately updates both `Subject` counters and the `ClassSession`

### 5.2 Ongoing (Sticky) Notifications
- During an active session, a persistent notification shows:
  - Subject name, remaining time, progress percentage
  - Live progress bar
  - Status badge updates in real-time when marked from notification
  - Disappears automatically when class ends

### 5.3 Silent Mode
- When **Silent Notifications** are enabled, class notifications arrive without sound or vibration
- Useful for libraries, exams, or quiet environments

### 5.4 Geofence Entry Alerts
- When entering a campus geofence during an active session, a one-time alert fires: *"You reached campus 📍 — Don't forget to mark attendance for [Subject]"*
- Controlled by the **Geofence Alerts** toggle

### 5.5 WiFi Connect Prompts
- When connecting to a campus WiFi network during active hours, a quick prompt appears in the notification shade

### 5.6 Background Service Status Notification
- Optional persistent notification showing background service status ("Active • Monitoring...", "Waiting • Next: [Subject] @ HH:MM")
- Enables monitoring background service health without opening the app

### 5.7 Notification Actions (Background Processing)
All notification actions are handled in a **background isolate** — no need to open the app:
1. Action received → `handleAction()` runs in background isolate
2. Subject counters updated in `SharedPreferences`
3. Session record created/updated in `SharedPreferences`
4. Background service isolate notified via `IsolateNameServer` port
5. Main app isolate notified to reload UI state
6. Live Activity (iOS) updated with new status

### 5.8 Confirmation Feedback
After marking from a notification, a 3-second countdown confirmation notification appears:
- *"You marked Present (3)"* → *"(2)"* → *"(1)"* → dismisses automatically

---

## 6. Analytics & Statistics

### 6.1 Stats Screen
- **Overall Summary**: Total classes, attended, missed across all subjects
- **Per-Subject Breakdown**: Bar or pie chart showing individual subject attendance
- **Weekly Trend Chart**: Attendance rate over the past several weeks (via `fl_chart`)
- **Day-of-Week Analysis**: Which days of the week you attend/miss most

### 6.2 Stats Detail Screen
- Drill down into a single subject's complete history
- View attendance log entries with timestamps
- Trend chart for that specific subject over time

### 6.3 Charts
- Built using the `fl_chart` package
- Smooth animations on load and data change
- Color-coded to match subject colors

---

## 7. Calendar Integration

### 7.1 In-App Calendar View
- Monthly/weekly calendar embedded in the home screen (toggleable)
- Days with classes highlighted; days with fully attended sessions shown distinctly
- Tap a day to jump to that day's schedule

### 7.2 Google Calendar Sync (Read-Only)
- Connect your Google Account to pull events from your **primary Google Calendar**
- Events are mapped to `ClassSession` objects with extracted teacher/topic from event descriptions
- Supports structured description format: `topic - [topic] , teacher - [teacher]`
- Falls back to heuristic parsing if structured format not present
- Syncs events for the current week on demand or automatically (if Auto Sync enabled)

### 7.3 Device Calendar Integration
- Read/write to device calendars via `device_calendar` package
- Export sessions to device calendar for visibility in stock calendar apps

### 7.4 Holiday Calendar
- Holidays imported from Google Calendar are displayed on the attendance calendar
- Manual holidays can be added and are excluded from class day counts

---

## 8. Home Screen Widgets

Three Android home screen widgets available (configurable):

### 8.1 My Day Widget
- Shows today's schedule as a scrollable list
- Displays subject name, start/end time, and current status
- Tapping a session opens the app directly to that session
- Updates automatically when app data changes

### 8.2 Subject Stats Widget
- Configurable: choose which subject to display
- Shows attendance percentage, can-miss count, and health status
- Visual color indicator matching subject color

### 8.3 Subject Card Widget
- Compact card with quick-mark buttons for Present / Proxy / Absent
- One-tap marking without opening the app
- Configurable per widget instance

---

## 9. Live Activities (iOS)

- **iOS-only** feature using the `live_activities` package
- Shows an always-visible activity island/banner during an active class session
- Displays: subject name, remaining time, live progress, current status
- Updates every background loop cycle (typically every 1–5 minutes during class)
- Ends automatically when the session ends (± buffer)
- Synced with notification actions — marking via notification updates the Live Activity

---

## 10. Quick Settings Tile (Android)

- A **Quick Settings Tile** ("Quick Mark") accessible from the Android notification shade pull-down
- Allows one-tap attendance marking without unlocking the device or opening the app
- Implemented via `quick_settings` package + `QuickSettingsService` binding

---

## 11. OCR Timetable Scanner

### 11.1 Camera Scan
- Use the device camera to scan a **printed timetable**
- Powered by **Google ML Kit Text Recognition** (on-device, no data sent to servers)
- Supports document scanning via `google_mlkit_document_scanner`

### 11.2 Image Import
- Import timetable images from gallery
- Supports image cropping (`image_cropper`) before scanning

### 11.3 PDF Import
- Import timetable from a PDF file
- Parses class names, times, and days via `schedule_parsing_utils`

### 11.4 Auto Parsing
- `MegaScheduleParser` orchestrates parsing across multiple formats
- Detected subjects and time slots are shown for user confirmation before saving
- Uses grid analysis and line enhancement for table-based timetables (`ScanStructure`)

### 11.5 Sharing Intent
- The app registers as a share target for PDF, text, and image files
- Send a timetable PDF from another app → MadBunky Pro opens and auto-parses it

---

## 12. Backup & Restore System

### 12.1 Local Backup (Export)
- Export entire app database as a `.mb` or `.json` file
- Saved to a user-chosen location via file picker
- Supports CSV export of attendance data

### 12.2 Google Drive Cloud Backup
- **AES-256 encrypted** backup uploaded to user's Google Drive (app-specific `appdata` folder — private, not visible in Drive UI)
- Encryption key derived from user's Google email + a static salt via SHA-256 hashing
- Backup format: `IV_BASE64:CIPHERTEXT_BASE64` stored in `madbunky_backup.json`
- **Auto Backup**: When enabled, backs up automatically 1 minute after any data change (debounced)
- **Single Slot**: Old backups are deleted before uploading a new one

### 12.3 Data Keys Backed Up
All critical user data is included:
- Subjects, Groups, Schedule Templates, Class Sessions
- User name & institute
- All app settings (theme, automation flags, WiFi SSIDs, campus locations, etc.)

### 12.4 Restore
- Select a backup file from Google Drive
- Decryption uses the currently signed-in Google account email
- Restores all data to `SharedPreferences` immediately

### 12.5 P2P Transfer
- Export schedule templates (`.MBweektemplate`) for sharing between devices
- Share via any file-sharing app; MadBunky Pro opens and imports automatically

---

## 13. Theme & Customization Engine

### 13.1 Theme Modes
| Mode | Description |
|------|-------------|
| **System** | Follows device light/dark preference |
| **Light** | Always light mode |
| **Dark** | Always dark mode |

### 13.2 Material You (Dynamic Color)
- When enabled, the app derives its color palette from your device wallpaper (Android 12+)
- Uses `dynamic_color` package for seamless integration

### 13.3 Theme Presets
Multiple pre-built color presets available:
- Default Gray, Pastel Red, Ocean Blue, Forest Green, Sunset Orange, and more
- Each preset defines a full `ColorScheme` for both light and dark modes

### 13.4 Custom Theme Color
- Pick any color using the full-spectrum `FlexColorPicker`
- Applied as the seed color for the entire Material 3 color system

### 13.5 Neon Mode
- A special visual overlay that adds glowing neon accents to UI elements
- Toggle in Settings → Appearance

### 13.6 AMOLED / Pure Black Mode
- Dark theme with true black backgrounds for OLED screens
- Maximum battery savings on AMOLED displays

### 13.7 Google Fonts
- Uses `google_fonts` package for typography (e.g., Inter, Outfit)
- Consistent across all screens and widgets

---

## 14. Holiday Awareness

- **Enable Holiday Awareness** toggle in Settings
- When enabled, the app marks national/public holidays on the calendar
- `HolidayService` fetches holidays (from Google Calendar or a built-in list)
- Three holiday types: `user` (manually added), `national` (system), `calendar` (from Google Calendar)
- Holidays prevent sessions from being counted as "missed" for attendance calculations
- Holiday screen with search and date navigation

---

## 15. Sync & Import/Export

### 15.1 CSV Export
- Export attendance data as a `.csv` file for use in Excel or Google Sheets
- Configurable date range export

### 15.2 PDF Report Generation
- Generate styled PDF attendance reports using the `printing` + `pdf` packages
- Export per-subject or full summary reports
- Share directly via share sheet

### 15.3 File Sharing & Deep Linking
The app handles incoming shared files:
- `.MB` / `.mb` → Backup restore
- `.MBweektemplate` / `.mbweektemplate` → Schedule import
- PDF, image, text files → Timetable scanner

---

## 16. Authentication & User Profiles

### 16.1 User Profile
- Name and institute stored locally (`UserProfile` model)
- Displayed on the home screen and PDF reports

### 16.2 Authentication Modes
| Mode | Description |
|------|-------------|
| **Guest Mode** | No sign-in required; full local functionality |
| **Google Sign-In** | Enables Google Calendar sync + Drive backup |

- Firebase Auth + `google_sign_in` for OAuth flow
- Silent sign-in on app resume to restore session
- Auth state persisted in `SharedPreferences` (`auth_type` key)

### 16.3 Google OAuth Scopes
The app requests only two scopes:
- `https://www.googleapis.com/auth/calendar.readonly` — Read-only calendar events
- `https://www.googleapis.com/auth/drive.appdata` — Private app backup folder only

---

## 17. Background Service & Power Management

### 17.1 Foreground Service (Android)
- Runs as a persistent **foreground service** (visible notification) when automation features are active
- Service type: `location | dataSync`
- Automatically stops when all automation features are disabled

### 17.2 Battery Saver Mode
When **Battery Saver** is enabled:
- Geofence accuracy reduced from `high` (GPS ~10m) to `medium` (Cell/WiFi ~100m)
- Background loop runs in 3 segments instead of 5 during active sessions
- WiFi match short-circuits geofence check entirely

### 17.3 OEM Compatibility
- Minimum 30-second sleep enforced to prevent aggressive OEM battery managers (Xiaomi, Samsung) from killing the process
- Long standby sleep capped at 15 minutes to keep notification fresh

### 17.4 Boot Persistence
- App registers `RECEIVE_BOOT_COMPLETED` to reschedule notifications after device reboot
- Service auto-restarts on boot if automation was active

---

## 18. Debug & Developer Tools

Available in Settings → Debug Tools (dev builds):

- **Log Viewer**: Live stream of `LogService` entries from all isolates
- **Service Status Panel**: Real-time background service state, WiFi status, geofence distance, heartbeat count
- **BG History Log**: Last 100 background check events with timestamps, WiFi status, geo status, and coordinates
- **Force Notifications**: Manually trigger test class notifications
- **Clear Data**: Nuclear option to wipe all app data
- **Crash Test**: Force an uncaught exception for crash reporting validation

---

## 19. Data Models Overview

| Model | Purpose | Key Fields |
|-------|---------|------------|
| `Subject` | A tracked academic subject | name, present, absent, proxy, ambiguous, target%, logs, color |
| `AttendanceLog` | Individual attendance event | timestamp, status, logType, sessionId |
| `ScheduleTemplate` | Recurring weekly class definition | dayOfWeek, startTime, endTime, subjectId |
| `ClassSession` | A concrete class occurrence on a date | startTime, endTime, status, isCancelled, isEvent |
| `Group` | Subject folder/organizer | name, subjectIds, color |
| `LocationItem` | Campus geofence zone | lat, lng, radius, subjectIds |
| `AppSettings` | All user preferences | theme, automation toggles, SSID list, locations |
| `UserProfile` | User name & institution | name, institute |
| `HolidayItem` | A holiday entry | date, name, type |
| `ScanStructure` | OCR grid analysis result | verticalLines, horizontalLines, slope |

---

## 20. Settings Reference

| Setting | Default | Description |
|---------|---------|-------------|
| Theme Mode | System | Light / Dark / System |
| Material You | ✅ On | Dynamic wallpaper-based colors |
| Theme Preset | Default Gray | Pre-built color palette |
| Custom Theme Color | None | Full custom color picker |
| Neon Mode | ❌ Off | Neon glow accents |
| Show Calendar | ✅ On | Calendar widget on home screen |
| Enable Notifications | ✅ On | Class start notifications |
| Class Alerts | ✅ On | Scheduled class notification |
| Silent Notifications | ❌ Off | No sound/vibration on notif |
| Background Status Notification | ✅ On | Foreground service status bar |
| Smart Bunking | ✅ On | Bunk budget awareness |
| Enable Geofence | ❌ Off | GPS campus auto-detection |
| Geofence Alerts | ✅ On | Entry alert when reaching campus |
| Enable WiFi Trigger | ❌ Off | WiFi SSID campus auto-detection |
| Battery Saver | ❌ Off | Reduced accuracy for lower drain |
| Holiday Awareness | ❌ Off | Mark holidays on calendar |
| Live Activity (iOS) | ❌ Off | Dynamic Island class tracker |
| Auto Backup | ❌ Off | Debounced auto Drive backup |
| Auto Sync Google Calendar | ❌ Off | Auto pull calendar events |

---

*MadBunky Pro — Built for students who want control over their attendance, not the other way around.*  
*© 2026 MadBunky. All rights reserved.*
