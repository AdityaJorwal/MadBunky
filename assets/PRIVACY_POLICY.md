# Privacy Policy — MadBunky Pro

**Effective Date:** May 29, 2026  
**Last Updated:** May 29, 2026  
**App Name:** MadBunky Pro  
**Developer:** Aditya Jorwal  
**Contact:** [your-contact@email.com]  
**Platform:** Android & iOS

---

## Introduction

MadBunky Pro ("the App", "we", "our", or "us") is a mobile application designed to help students intelligently track academic attendance. We are committed to being transparent about how the App handles your information.

This Privacy Policy explains:
- What data the App collects
- Why it collects it
- How it is stored and processed
- With whom it may be shared
- Your rights over your data

By using MadBunky Pro, you agree to the practices described in this Privacy Policy.

---

## 1. Guiding Principles

MadBunky Pro is built on a **"Local-First, Privacy-First"** philosophy:

1. **Your academic data never leaves your device** unless you explicitly request a cloud backup.
2. **No advertising SDKs** are included in the App.
3. **No third-party analytics** (e.g., Firebase Analytics, Mixpanel) are used to track user behaviour.
4. All machine learning features (OCR scanning) are performed **entirely on-device**.
5. You remain in full control of your data at all times.

---

## 2. Data We Collect & Why

### 2.1 Academic & Attendance Data

| Data | Purpose | Where Stored |
|------|---------|-------------|
| Subject names, teacher names, topics | Core attendance tracking | On-device (SharedPreferences/JSON) |
| Attendance counters (present, absent, proxy, ambiguous) | Attendance percentage calculation | On-device |
| Class session records (date, time, status) | Schedule and history tracking | On-device |
| Schedule templates (weekly timetable) | Recurring notification scheduling | On-device |
| Attendance log history (timestamps, actions) | History, undo, analytics | On-device |

**Retention:** This data is retained indefinitely on-device until you delete the App or clear its data. It is never automatically transmitted anywhere.

---

### 2.2 Location Data (Geofence Feature — Opt-In)

The App may request access to your device's precise location **only if you enable the Geofence Attendance feature** in Settings.

| Data | Purpose | Where Stored |
|------|---------|-------------|
| Current GPS coordinates (during active class sessions only) | Detect if you are within campus radius to auto-mark attendance | Processed in memory; **not stored permanently** |
| Campus zone coordinates (lat, lng, radius) you define | Define your college geofence | On-device only |
| Background location access | Monitor geofence during class sessions while App is in background | Processed in background service; not uploaded |

**Retention policy:**
- Your current GPS coordinates are used momentarily to check distance from your campus zone. They are **not saved to disk, not logged permanently, and not transmitted**.
- The brief geofence check history (last 100 entries) stored in `bg_history_log` includes approximate coordinates in condensed form for debug visibility within the App. This data stays entirely on-device.
- Campus zone coordinates you enter are saved locally and remain until you delete them.

**You are always in control:** You can disable the Geofence feature at any time in Settings → Automation → Disable Geofence. When disabled, the App does not access your location.

**Background Location:** MadBunky Pro requests `ACCESS_BACKGROUND_LOCATION` permission on Android. This is solely to allow the foreground service to check your location during scheduled class hours. This is disclosed during the permission request flow as required by Google Play policy.

---

### 2.3 Network Information (WiFi Trigger — Opt-In)

If you enable the **WiFi Attendance Trigger** feature:

| Data | Purpose | Where Stored |
|------|---------|-------------|
| Current WiFi SSID (network name) | Detect connection to campus WiFi to auto-mark attendance | Not stored; checked in memory only |
| Trusted SSID list you configure | Matching against current network | On-device only |

- The App reads your current WiFi SSID periodically during active class sessions.
- SSID data is not transmitted, not logged permanently, and not shared.
- Reading WiFi SSID on Android requires Location permission (mandated by Android OS, not by us for location purposes).

---

### 2.4 Camera Access (OCR Scanner — On Demand)

If you use the **Timetable Scanner** feature:

| Data | Purpose | Where Stored |
|------|---------|-------------|
| Camera image / photo | Scan printed timetable for automatic import | Processed on-device; temporary file only |
| Scanned image file | ML Kit text recognition | Processed by on-device ML Kit model; deleted after parsing |

- Images are **never uploaded** to any server.
- Text recognition is performed by **Google ML Kit's on-device model**. No image data is sent to Google's servers.
- Scanned images are saved temporarily to the App's private cache directory and deleted after parsing is complete.

---

### 2.5 Google Account Data (Optional — Cloud Features Only)

If you choose to sign in with Google:

| Data | Purpose | Scope Requested |
|------|---------|----------------|
| Google email address | Used to derive the AES-256 encryption key for your Drive backup; identifies your account | Read-only identity |
| Google Calendar events (read-only) | Display your calendar events alongside your class schedule | `calendar.readonly` |
| Google Drive (app-specific folder only) | Store encrypted backup file; this folder is private and not visible in Drive UI | `drive.appdata` |

**Important notes:**
- Google Sign-In is entirely **optional**. All core features work without any Google account.
- We do **not** read your full Google Drive, Gmail, Contacts, or any other Google service.
- The `calendar.readonly` scope grants read-only access to your primary calendar only for displaying events. We do not write to or modify your calendar.
- The `drive.appdata` scope restricts our access to a **private app-specific folder** that cannot be accessed by any other app or visible in the standard Drive interface. Only the App can read/write this folder.
- We do not store your Google credentials. The OAuth tokens are managed by the Google Sign-In SDK and stored securely by the operating system.

---

### 2.6 User Profile Data

| Data | Purpose | Where Stored |
|------|---------|-------------|
| Your name | Displayed on home screen and PDF reports | On-device only |
| Your institution name | Displayed on home screen and PDF reports | On-device only |

This data never leaves your device unless you include it in a backup.

---

### 2.7 App Settings & Preferences

All app settings (theme mode, notification preferences, automation toggles, SSID list, geofence locations) are stored locally in your device's `SharedPreferences`. They are included in backups only if you explicitly create one.

---

### 2.8 Diagnostic & Debug Logs

For debugging purposes, the App maintains an internal log file (`LogService`):

- Logs contain app lifecycle events, service status, and error traces.
- Logs **do not contain** personal attendance data, location coordinates, or network names.
- Logs are stored in the App's private files directory and are **never automatically transmitted**.
- Accessible only through the in-app Debug Log Viewer (Settings → Debug Tools).

---

## 3. Data Storage & Security

### 3.1 Local Storage
All your data is stored in:
- **`SharedPreferences`**: Serialized JSON for subjects, sessions, schedule, and settings
- **App's private files directory**: Log files, cached notification images
- **App's cache directory**: Temporary scan images (auto-deleted)

No database server is used. Your data is contained entirely within the App's sandboxed storage on your device.

### 3.2 Encryption (Cloud Backups Only)
When you choose to back up to Google Drive:
- Your data is encrypted using **AES-256 in CBC mode** before upload
- The encryption key is derived from your Google email address + a static salt using **SHA-256 hashing**
- The initialization vector (IV) is randomly generated per backup
- The encrypted file format is: `IV_BASE64:CIPHERTEXT_BASE64`
- **Without your Google account**, the backup file cannot be decrypted

### 3.3 Secure Storage
- Authentication tokens are handled by the OS-level secure storage (Google Sign-In SDK)
- Sensitive configuration (encryption keys, API credentials) are not stored in plaintext

### 3.4 Limitations
No electronic storage method is 100% secure. While we implement industry-standard security measures, we cannot guarantee absolute security of data stored on your device or transmitted over the internet.

---

## 4. Data Sharing

We do **not** sell, rent, or share your personal information with third parties for their marketing or commercial purposes.

### 4.1 Third-Party Services Used

| Service | Purpose | Data Shared | Data Processing Location |
|---------|---------|-------------|--------------------------|
| Google ML Kit | On-device OCR for timetable scanning | Camera images (processed locally) | **On-device only** — no data sent to Google |
| Google Sign-In / Firebase Auth | Optional authentication | Your Google account tokens | Google servers (OAuth standard flow) |
| Google Calendar API | Read calendar events (optional) | OAuth token only | Google servers |
| Google Drive API | Store encrypted backup (optional) | Encrypted backup file | Google's `appdata` folder |

### 4.2 Legal Disclosures
We may disclose your information if required by law, court order, or governmental authority. We will notify you of such requests to the extent permitted by law.

---

## 5. Permissions Breakdown

### Android Permissions

| Permission | Why It's Needed | Required? |
|-----------|----------------|-----------|
| `POST_NOTIFICATIONS` | Show class reminders and attendance prompts | Yes (core feature) |
| `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` | Schedule class notifications at precise times | Yes (core feature) |
| `VIBRATE` | Vibrate for notifications | Yes |
| `USE_FULL_SCREEN_INTENT` | Show class notifications over lock screen | Yes |
| `RECEIVE_BOOT_COMPLETED` | Reschedule notifications after device reboot | Yes |
| `FOREGROUND_SERVICE` | Run background attendance checking | Only with automation |
| `FOREGROUND_SERVICE_LOCATION` | Location access in foreground service | Only with Geofence |
| `FOREGROUND_SERVICE_DATA_SYNC` | Sync operations in foreground service | Only with automation |
| `WAKE_LOCK` | Keep CPU awake for time-critical checks | Only with automation |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Prevent OS from killing background service | Only with automation |
| `ACCESS_FINE_LOCATION` | Precise GPS for geofence | Only with Geofence enabled |
| `ACCESS_COARSE_LOCATION` | Approximate location (WiFi SSID reading) | Only with WiFi/Geofence |
| `ACCESS_BACKGROUND_LOCATION` | Location checks during class while app is in background | Only with Geofence enabled |
| `ACCESS_WIFI_STATE` | Read current WiFi SSID | Only with WiFi Trigger |
| `ACCESS_NETWORK_STATE` | Monitor network connectivity | Optional features |
| `INTERNET` | Google Sign-In, Calendar sync, Drive backup | Only with cloud features |
| `CAMERA` | Timetable OCR scanning | Only when using scanner |
| `NEARBY_WIFI_DEVICES` | Local network discovery (Android 13+) | Only with WiFi Trigger |

### iOS Permissions

| Permission | Why It's Needed | Required? |
|-----------|----------------|-----------|
| Location When In Use | Geofence campus detection | Only with Geofence |
| Location Always | Background geofence monitoring | Only with Geofence |
| Camera | Timetable OCR scanning | Only when using scanner |
| Photo Library | Import timetable images | Only when using scanner |
| Notifications | Class reminders and alerts | Yes (core feature) |
| Background App Refresh | Background attendance monitoring | Only with automation |

---

## 6. Children's Privacy

MadBunky Pro is designed for use by **students at the college/university level** (typically age 17 and above). We do not knowingly collect personal information from children under the age of 13 (or under 16 where required by local law).

If you are a parent or guardian and believe your child has provided us with personal information, please contact us immediately. We will delete the data as soon as practicable.

---

## 7. Your Rights & Controls

Regardless of your location, you have the following rights over your data:

| Right | How to Exercise |
|-------|----------------|
| **Access** | View all your data directly within the App at any time |
| **Correction** | Edit any subject, session, or profile data directly in the App |
| **Deletion** | Delete individual subjects, sessions, logs — or all data via Settings → Clear All Data |
| **Portability** | Export your data as CSV or JSON backup at any time |
| **Withdraw Consent (Location)** | Disable Geofence/WiFi features or revoke location permission in device Settings |
| **Withdraw Consent (Google)** | Sign out of Google from within the App or revoke access from your Google Account settings |

**To delete all your data:** Settings → Debug Tools → Clear All Data (or uninstall the App).

---

## 8. Data Retention

| Data Category | Retention Period |
|--------------|-----------------|
| Attendance records, subjects, sessions | Until you delete them or uninstall the App |
| App settings | Until you clear them or uninstall the App |
| Diagnostic logs | Rolling window; oldest entries overwritten automatically |
| Temporary scan images | Deleted immediately after OCR processing |
| Background check history | Rolling 100-entry cap; oldest entries overwritten |
| Google Drive backup | Until you delete it from Drive or the App deletes it on next backup |

---

## 9. Data Transfers

Your data is stored locally on your device and is **not transferred internationally** by default.

When using optional cloud features (Google Sign-In, Drive backup, Calendar sync), your data may be processed by Google's servers in accordance with Google's own Privacy Policy: https://policies.google.com/privacy

---

## 10. Third-Party Links

The App may display information or navigation that could lead to external websites or Google services. This Privacy Policy applies solely to MadBunky Pro. We are not responsible for the privacy practices of any third-party services linked from the App.

---

## 11. Changes to This Privacy Policy

We may update this Privacy Policy from time to time to reflect changes in the App's features or applicable laws. When we make significant changes, we will:
- Update the **"Last Updated"** date at the top of this document
- Where required by law, seek your fresh consent

We encourage you to review this policy periodically.

---

## 12. Contact Us

If you have any questions, concerns, or requests regarding this Privacy Policy or the App's data practices, please contact us:

**Developer:** Aditya Jorwal  
**Email:** [your-contact@email.com]  
**GitHub:** https://github.com/AdityaJorwal/MadBunky  

We aim to respond to all privacy inquiries within 30 days.

---

*MadBunky Pro is committed to your privacy. Your data. Your control.*
