package com.aj.mad_bunky

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class SubjectStatsWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: android.content.SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
             updateAppWidget(context, appWidgetManager, widgetId, widgetData)
        }
    }

    companion object {
        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int, widgetData: android.content.SharedPreferences? = null) {
             val prefs = widgetData ?: context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
             
            val views = RemoteViews(context.packageName, R.layout.widget_subject_stats).apply {
                // Image Loading Logic
                val imageKey = prefs.getString("filename_$widgetId", null)
                if (imageKey != null) {
                    val file = java.io.File(context.filesDir, imageKey)
                    if (file.exists()) {
                        val bitmap = android.graphics.BitmapFactory.decodeFile(file.absolutePath)
                        setImageViewBitmap(R.id.widget_image, bitmap)
                    } else {
                        // Try with .png extension (HomeWidget sometimes adds it)
                         val filePng = java.io.File(context.filesDir, "$imageKey.png")
                         if (filePng.exists()) {
                             val bitmap = android.graphics.BitmapFactory.decodeFile(filePng.absolutePath)
                             setImageViewBitmap(R.id.widget_image, bitmap)
                         }
                    }
                }

                // Header Click: Open App
                val launchIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.widget_root, launchIntent)

                // Settings Button Click
                val configIntent = Intent(context, SubjectStatsConfigActivity::class.java).apply {
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
    }
}
