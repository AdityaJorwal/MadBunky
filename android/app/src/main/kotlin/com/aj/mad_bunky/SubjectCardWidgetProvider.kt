package com.aj.mad_bunky

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class SubjectCardWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            updateAppWidget(context, appWidgetManager, widgetId)
        }
    }

    companion object {
        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.widget_subject_card).apply {
                
                // 1. Interactive Buttons
                // Present
                val presentIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("madbunky://action/present?id=subject_card&widgetId=$widgetId")
                )
                // Wait, background intent is better for actions without opening app?
                // The user requested "intractable buttons... immediate data refresh".
                // If we use Activity intent, it opens the app.
                // If we use Background intent, it runs Dart code in background (if app is alive/registered).
                
                // Let's use Background Intent for Present/Absent/Proxy
                val backgroundIntent = Intent(context, SubjectCardWidgetProvider::class.java).apply {
                    action = "ACTION_HANDLE_WIDGET_CLICK"
                }

                // We need unique PendingIntents for each button/widget combo?
                // Yes, use requestCode.
                
                // Present
                setOnClickPendingIntent(R.id.btn_present, getPendingIntent(context, widgetId, "present"))
                // Absent
                setOnClickPendingIntent(R.id.btn_absent, getPendingIntent(context, widgetId, "absent"))
                 // Proxy
                setOnClickPendingIntent(R.id.btn_proxy, getPendingIntent(context, widgetId, "proxy"))
                
                // Undo? Optional.
                
                // Settings
                 val configIntent = Intent(context, SubjectCardConfigActivity::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                val configPendingIntent = PendingIntent.getActivity(
                    context,
                    widgetId,
                    configIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_btn_settings, configPendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }

        private fun getPendingIntent(context: Context, widgetId: Int, action: String): PendingIntent {
            val intent = Intent(context, SubjectCardWidgetProvider::class.java).apply {
                this.action = "ACTION_HANDLE_WIDGET_CLICK"
                putExtra("sub_action", action)
                putExtra("widget_id", widgetId)
                // Unique data to ensure Intent uniqueness
                data = Uri.parse("madbunky://widget/$widgetId/$action") 
            }
            return PendingIntent.getBroadcast(
                context,
                widgetId * 10 + action.hashCode(), // Unique request code
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
    }
    


    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        if (intent.action == "ACTION_HANDLE_WIDGET_CLICK") {
            val subAction = intent.getStringExtra("sub_action")
            val widgetId = intent.getIntExtra("widget_id", -1)
            
            if (widgetId != -1 && subAction != null) {
                // Forward to Flutter Background Handler
                // We use HomeWidgetBackgroundReceiver's standard mechanism via a delegate intent?
                // Or we construct the Intent that HomeWidget expects.
                
                val backgroundIntent = Intent(context, es.antonborri.home_widget.HomeWidgetBackgroundReceiver::class.java).apply {
                    action = "es.antonborri.home_widget.action.BACKGROUND"
                    data = Uri.parse("madbunky://action/$subAction?widgetId=$widgetId") 
                }
                context.sendBroadcast(backgroundIntent)
            }
        }
    }
    
    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        // Cleanup IDs from Shared Prefs
        // We can do this natively or wait for Flutter?
        // Native is faster cleanup.
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val key = "flutter.subject_card_widget_ids" // Flutter saves lists with prefix 'flutter.' typically?
        // Actually shared_preferences plugin uses 'flutter.' prefix.
        
        // Complex to parse List<String> from generic prefs on native side safely if encoding varies.
        // Easier: Just leave it. It's just an ID. 
        // Or send intent to Flutter to cleanup?
        // We'll skip complex cleanup for now.
    }
}
