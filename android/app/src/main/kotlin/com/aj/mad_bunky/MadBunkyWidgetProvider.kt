package com.aj.mad_bunky

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class MadBunkyWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                // Open App on Click
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)

                // Load Image
                val imagePath = widgetData.getString("my_day_widget_image", null)
                if (imagePath != null) {
                    val bitmap = android.graphics.BitmapFactory.decodeFile(imagePath)
                    setImageViewBitmap(R.id.widget_image, bitmap)
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
