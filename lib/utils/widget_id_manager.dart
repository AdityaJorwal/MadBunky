import 'package:shared_preferences/shared_preferences.dart';

class WidgetIdManager {
  static const String _keySubjectCardIdsSimple =
      'subject_card_widget_ids_simple';

  static Future<void> addSubjectCardWidget(
      int widgetId, String subjectId) async {
    final prefs = await SharedPreferences.getInstance();

    // update list of IDs (Simple comma separated)
    String listStr = prefs.getString(_keySubjectCardIdsSimple) ?? "";
    List<String> ids = listStr.split(',').where((e) => e.isNotEmpty).toList();

    if (!ids.contains(widgetId.toString())) {
      ids.add(widgetId.toString());
      await prefs.setString(_keySubjectCardIdsSimple, ids.join(','));
    }

    // Save mapping in HomeWidget friendly way via standard prefs
    // Since 'HomeWidget.getWidgetData' usually looks in default prefs or specific file,
    // we save here for Flutter internal use.
    await prefs.setString('widget_$widgetId', subjectId);
  }

  static Future<List<int>> getSubjectCardWidgetIds() async {
    final prefs = await SharedPreferences.getInstance();
    String listStr = prefs.getString(_keySubjectCardIdsSimple) ?? "";
    if (listStr.isEmpty) return [];

    return listStr
        .split(',')
        .map((e) => int.tryParse(e))
        .whereType<int>()
        .toList();
  }

  static Future<String?> getSubjectIdForWidget(int widgetId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('widget_$widgetId');
  }

  static Future<void> removeSubjectCardWidget(int widgetId) async {
    final prefs = await SharedPreferences.getInstance();
    String listStr = prefs.getString(_keySubjectCardIdsSimple) ?? "";
    List<String> ids = listStr.split(',').where((e) => e.isNotEmpty).toList();

    if (ids.remove(widgetId.toString())) {
      await prefs.setString(_keySubjectCardIdsSimple, ids.join(','));
    }
    await prefs.remove('widget_$widgetId');
  }

  // --- Subject Stats Widget ---
  static const String _keySubjectStatsIdsSimple =
      'subject_stats_widget_ids_simple';

  static Future<void> addSubjectStatsWidget(
      int widgetId, String subjectId) async {
    final prefs = await SharedPreferences.getInstance();
    String listStr = prefs.getString(_keySubjectStatsIdsSimple) ?? "";
    List<String> ids = listStr.split(',').where((e) => e.isNotEmpty).toList();

    if (!ids.contains(widgetId.toString())) {
      ids.add(widgetId.toString());
      await prefs.setString(_keySubjectStatsIdsSimple, ids.join(','));
    }
    await prefs.setString('widget_stats_$widgetId', subjectId);
  }

  static Future<List<int>> getSubjectStatsWidgetIds() async {
    final prefs = await SharedPreferences.getInstance();
    String listStr = prefs.getString(_keySubjectStatsIdsSimple) ?? "";
    if (listStr.isEmpty) return [];

    return listStr
        .split(',')
        .map((e) => int.tryParse(e))
        .whereType<int>()
        .toList();
  }

  static Future<String?> getSubjectIdForStatsWidget(int widgetId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('widget_stats_$widgetId');
  }

  static Future<void> removeSubjectStatsWidget(int widgetId) async {
    final prefs = await SharedPreferences.getInstance();
    String listStr = prefs.getString(_keySubjectStatsIdsSimple) ?? "";
    List<String> ids = listStr.split(',').where((e) => e.isNotEmpty).toList();

    if (ids.remove(widgetId.toString())) {
      await prefs.setString(_keySubjectStatsIdsSimple, ids.join(','));
    }
    await prefs.remove('widget_stats_$widgetId');
  }
}
