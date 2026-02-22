# Task: Optimizing Battery & UI

## Objective
Optimize the application for reduced battery consumption by implementing conditional UI effects (disabling blur) and adjusting background service settings (GPS accuracy, check frequency) when "Battery Saver Mode" is enabled.

## Progress
### UI Optimizations
- [x] Create `OptimizedGlass` widget to conditionally render `BackdropFilter` or opaque `Container`.
- [x] Replace `GlassContainer` with `OptimizedGlass` in:
    - `lib/widgets/unified_top_bar.dart`
    - `lib/screens/main_scaffold.dart`
    - `lib/screens/home_screen.dart` (Subject Options)
    - `lib/utils/morph_dialog.dart` (Dialogs)
    - `lib/widgets/fab_actions.dart` (Autocomplete Options)

### Background Service Optimizations
- [x] Update `lib/services/background_service.dart` to check `enableBatterySaver` pref.
- [x] Reduce GPS accuracy to `LocationAccuracy.medium` (WiFi/Cell) when saver is ON.
- [x] Reduce monitoring check frequency segments from 5 to 3 when saver is ON.
- [x] Prioritize WiFi checks to skip Geofencing entirely when saver is ON.

### Settings UI
- [x] Fix `lib/screens/settings_screen.dart` to ensure "Battery Saver Mode" toggle is always visible and not hidden behind Geofence/enablement logic.
- [x] Update description text in Settings to detailed UI & Background impact.

### Code Quality
- [x] Resolve lint errors in modified files.
- [x] Remove unused imports.

## Next Steps
1. **Physical Testing (User)**:
   - Toggle Battery Saver ON. verify blur disappears from TopBar, Dialogs, etc.
   - Verify Background Service runs with "Low GPS Accuracy" notification or logs.
   - [x] verify Battery Saver Mode toggle stays ON after app restart. (Fixed copyWith bug)
2. **Performance Monitoring**:
   - Check battery usage statistics after 24h of usage.
