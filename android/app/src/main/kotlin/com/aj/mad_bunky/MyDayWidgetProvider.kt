package com.aj.mad_bunky

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.*

class MyDayWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: android.content.SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_my_day).apply {
                
                // Set Date
                val dateFormat = SimpleDateFormat("EEE, MMM d", Locale.getDefault())
                setTextViewText(R.id.widget_date, dateFormat.format(Date()))

                // Set Adapter
                val intent = Intent(context, MyDayWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                    data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                }
                setRemoteAdapter(R.id.widget_list_view, intent)
                setEmptyView(R.id.widget_list_view, R.id.widget_empty_view)

                // TEMPLATE: We use a BROADCAST template to handle button clicks in background
                // We will point to THIS provider's BroadcastReceiver to route events
                val itemClickIntent = Intent(context, MyDayWidgetProvider::class.java).apply {
                    action = "ACTION_HANDLE_WIDGET_CLICK"
                }
                val pendingIntentTemplate = PendingIntent.getBroadcast(
                    context, 
                    widgetId, 
                    itemClickIntent, 
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                )
                setPendingIntentTemplate(R.id.widget_list_view, pendingIntentTemplate)

                // Header Click: Open App
                val launchIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.widget_header, launchIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list_view)
        }
    }

    // Custom receive to router
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "ACTION_HANDLE_WIDGET_CLICK") {
            val type = intent.getStringExtra("sub_action")
            
            if (type == "present" || type == "proxy" || type == "absent") {
                // Show Debug Toast
                android.widget.Toast.makeText(context, "Marking ${type.capitalize()}...", android.widget.Toast.LENGTH_SHORT).show()

                // Forward to HomeWidgetBackgroundReceiver
                val dataUri = intent.data
                if (dataUri != null) {
                    val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(context, dataUri)
                    backgroundIntent.send()
                }
            } else {
                // Open App (Default click on item)
                val launchIntent = Intent(context, MainActivity::class.java)
                launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                context.startActivity(launchIntent)
            }
        }
        super.onReceive(context, intent)
    }
}
