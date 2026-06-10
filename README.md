# Gravity Notes 🚀

A modern, high-performance Android notes app built using **Flutter**, featuring **Material 3 design**, persistent local storage with **SQLite**, responsive layouts, and advanced note organization.

---

## ✨ Features
* **Full CRUD Operations**: Create, view, edit, and delete notes instantly.
* **Pin Notes**: Pin important notes to keep them anchored at the top of the dashboard.
* **Persistent Local Storage**: SQLite integration ensures your data is saved securely on-device and persists between app restarts.
* **Powerful Search**: Instant search filtering across title and content with query matching.
* **Smart Sorting**: Order notes by:
  * 📅 Newest First
  * ⏳ Oldest First
  * 🔤 Alphabetical (A-Z)
* **Custom Background Colors**: Assign beautiful, premium pastels/accent colors to individual notes.
* **Material Design 3**: Modern aesthetics including cards, glassmorphism search, dynamic dark/light themes, and responsive staggered grids (Pinterest-style).
* **Word & Character Counters**: Real-time stats displayed inside the note editor.

---

## 📂 Architecture & Directory Structure
The project follows a **Clean Architecture** style, splitting files logically:

```
lib/
├── main.dart                 # App initialization & Material 3 Theme setup
├── models/
│   └── note.dart             # Note data structure, DB-mapping & helpers
├── services/
│   └── database_service.dart # SQLite DB helper (open, upgrade, CRUD queries)
├── providers/
│   └── notes_provider.dart   # App state management, filtering & sorting logic
└── views/
    ├── screens/
    │   ├── notes_list_screen.dart # Main dashboard (Staggered Grid / List views)
    │   └── note_editor_screen.dart # Rich Note Editor with color picking
    └── widgets/
        ├── empty_state.dart       # Premium illustration shown when notes are empty
        ├── note_card.dart         # Stylized card layout with pinning icons
        ├── search_bar_widget.dart # Premium Glassmorphism search input
        └── sort_filter_sheet.dart # Material 3 bottom-sheet with sort toggles
```

---

## 🛠️ Build & Installation Guide (Android)

Follow these steps to set up the project on your local machine and deploy it to a physical Android device or emulator.

### Prerequisites
1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install/windows).
2. Install [Android Studio](https://developer.android.com/studio) and configure the Android SDK.
3. Ensure you have an Android device with **USB Debugging** enabled, or a running Android Emulator.

---

### Step 1: Initialize Platform Directories
Because platform wrappers are environment-specific, they are not committed to source control. Scaffold the Android project wrapper using your installed Flutter version:
```bash
# Navigate to the project root directory
cd gravity_notes

# Scaffold native platform folders (including android/)
flutter create --platforms=android .
```

### Step 2: Fetch Dependencies
Download the packages defined in `pubspec.yaml`:
```bash
flutter pub get
```

### Step 3: Run the Application
Start the development server and run the app on your connected device/emulator:
```bash
# Check if your device/emulator is detected
flutter devices

# Run the app in Debug mode
flutter run
```

### Step 4: Build Release APK (Production)
To build a production-ready, highly-optimized release APK:
```bash
flutter build apk --release
```
The compiled APK will be located at:
`build/app/outputs/flutter-apk/app-release.apk`

---

## 🎨 Premium Theme Customization
Gravity Notes implements custom **Light and Dark Color Schemes** carefully chosen for high visual contrast and premium appearance:
* **Seed Color**: Deep Purple (`0xFF6750A4`)
* **Note Accent Colors**: A curated collection of soft, harmonious, Material-compliant pastel shades (Lavender, Soft Blue, Sage Green, Soft Coral, Creamy Peach, Mint, Pale Amber, and Classic Grey/Charcoal) that render beautifully in both light and dark settings.
