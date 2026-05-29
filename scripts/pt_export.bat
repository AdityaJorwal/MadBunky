@echo off
mkdir ui_export 2>nul
mkdir ui_export\widgets 2>nul
mkdir ui_export\widgets\animations 2>nul
mkdir ui_export\utils 2>nul
copy lib\theme.dart ui_export\theme.dart
copy lib\widgets\optimized_glass.dart ui_export\widgets\optimized_glass.dart
copy lib\widgets\glass_dialog.dart ui_export\widgets\glass_dialog.dart
copy lib\widgets\glass_color_picker_dialog.dart ui_export\widgets\glass_color_picker_dialog.dart
copy lib\widgets\thunder_overlay.dart ui_export\widgets\thunder_overlay.dart
copy lib\widgets\bouncing_widget.dart ui_export\widgets\bouncing_widget.dart
copy lib\widgets\morphing_widget.dart ui_export\widgets\morphing_widget.dart
copy lib\widgets\morphing_text.dart ui_export\widgets\morphing_text.dart
copy lib\widgets\spark_widget.dart ui_export\widgets\spark_widget.dart
copy lib\widgets\non_clipping_size_transition.dart ui_export\widgets\non_clipping_size_transition.dart
copy lib\widgets\animations\particle_text.dart ui_export\widgets\animations\particle_text.dart
copy lib\widgets\unified_top_bar.dart ui_export\widgets\unified_top_bar.dart
copy lib\widgets\custom_snackbar.dart ui_export\widgets\custom_snackbar.dart
copy lib\widgets\fab_actions.dart ui_export\widgets\fab_actions.dart
copy lib\widgets\qr_loading_indicator.dart ui_export\widgets\qr_loading_indicator.dart
copy lib\widgets\rounded_donut_chart.dart ui_export\widgets\rounded_donut_chart.dart
copy lib\widgets\vertical_dialer.dart ui_export\widgets\vertical_dialer.dart
copy lib\widgets\horizontal_dial.dart ui_export\widgets\horizontal_dial.dart
copy lib\widgets\duration_chip.dart ui_export\widgets\duration_chip.dart
copy lib\widgets\notification_card.dart ui_export\widgets\notification_card.dart
copy lib\utils\mad_haptics.dart ui_export\utils\mad_haptics.dart
copy lib\utils\morph_dialog.dart ui_export\utils\morph_dialog.dart
echo Done
