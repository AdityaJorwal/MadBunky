# 🎓 MadBunky

> Smart Attendance & "Bunk Budget" Intelligence — Designed for students, by students. Bunk responsibly.

Welcome to **MadBunky**, the ultimate academic companion designed to manage your attendance intelligently so you can focus on learning (and living). Built on a robust local-first database, MadBunky gives you full transparency over your attendance metrics without sacrificing your privacy.

Made with ❤️ by **AJ**

---

## 🚀 Core Features

### 📅 Smart Attendance Tracking
*   **Visual Dashboard**: See your attendance at a glance with beautiful, color-coded subject cards.
*   **One-Tap Marking**: Quickly mark classes as Present, Absent, or Proxy/Cancelled.
*   **History Log**: A detailed history of every class attended or missed with exact date and time.

### 🧠 "Bunk Budget" Intelligence (Proprietary)
*   **Safe Bunks Calculator**: Don't guess. The app tells you exactly **how many classes you can safely miss** while staying above your target (e.g., 75%).
*   **Recovery Mode**: If you are running low on attendance, we calculate exactly how many consecutive classes you must attend to get back on track.

### 🤖 Automation Suite
*   **Geofence Reminders**: (Opt-in) Set your college location. The app nudges you to mark attendance when you enter or leave campus. Never forget again.
*   **WiFi Auto-Detect**: (Opt-in) The app wakes up when you connect to your College WiFi, offering a "Quick Mark" notification.

### 📅 Smart Timetable
*   **OCR Import**: Scan your paper timetable or a screenshot. AI automatically parses subjects and times.
*   **Day/Week View**: Switch between a focused daily schedule and a comprehensive weekly overview.

### 📊 Insightful Analytics
*   **Trend Analysis**: Watch your attendance trends over time. Are you slacking off on Fridays? The data knows.
*   **Subject Stats**: Deep dive into specific subjects to see your performance.

### 🎨 Premium Customization
*   **Theme Engine**: Pure Black (AMOLED), Material You, and beautiful dynamic UI options.
*   **Haptic Interface**: Feel the interactions with a satisfying, tactile user interface.

### ☁️ Sync & Backup
*   **Local First**: Your data stays on your device. Privacy first.
*   **Cloud Backup**: Securely export your database to your own Google Drive or storage.
*   **P2P Sync**: Transfer data between devices easily.

---

## 🛠️ Getting Started

### Prerequisites

To build and run MadBunky, ensure you have the following installed:
*   [Flutter SDK](https://flutter.dev/docs/get-started/install) (v3.5.0 or later recommended)
*   [Dart SDK](https://dart.dev/get-dart)
*   An IDE (e.g., VS Code or Android Studio) with Flutter/Dart extensions
*   Android SDK & Emulator (for Android development) or Xcode & Simulator (for iOS development)

### Installation

1.  **Clone the Repository**:
    ```bash
    git clone https://github.com/AdityaJorwal/MadBunky.git
    cd MadBunky
    ```

2.  **Install Dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Generate Code / Code Generation** (if using build_runner):
    ```bash
    dart run build_runner build --delete-conflicting-outputs
    ```

### Running the App

To run the application in development mode:

```bash
flutter run
```

To run build analyzer or check for static issues:

```bash
flutter analyze
```

---

## 📂 Repository Structure

*   `lib/` - Main source code of the Flutter application.
*   `assets/` - Fonts, localization files, and static icons/images.
*   `scripts/` - Utility scripts for build tasks, icon optimization, and wave analysis.
*   `test/` - Automated unit, widget, and integration tests.
    *   `test/scratch/` - Reproduction scripts and temporary logic sandboxes.

---
*Bunk responsibly and let MadBunky do the math.*
