package com.aj.mad_bunky

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class MyDayWidgetFactory(private val context: Context, intent: Intent) : RemoteViewsService.RemoteViewsFactory {
    private var data: JSONArray = JSONArray()

    override fun onCreate() {
        loadData()
    }

    override fun onDataSetChanged() {
        loadData()
    }
    
    private fun loadData() {
        try {
            val widgetData = HomeWidgetPlugin.getData(context)
            val jsonString = widgetData.getString("my_day_data", "[]")
            data = JSONArray(jsonString)
        } catch (e: Exception) {
            e.printStackTrace()
            data = JSONArray()
        }
    }

    override fun onDestroy() {
        data = JSONArray()
    }

    override fun getCount(): Int {
        return data.length()
    }

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.item_widget_class_session)
        
        try {
            val item = data.getJSONObject(position)
            val subjectName = item.optString("subjectName", "Unknown")
            val startTimeMs = item.optLong("startTime", 0)
            val endTimeMs = item.optLong("endTime", 0)
            val status = item.optInt("status", 0) // 0: pending, 1: present, 2: absent, 3: proxy
            val colorValue = item.optInt("color", -1) // Expecting ARGB int
            
            // Time Formatting
            val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
            val startTime = timeFormat.format(Date(startTimeMs))
            val endTime = timeFormat.format(Date(endTimeMs))
            val timeText = "$startTime -\n$endTime"

            views.setTextViewText(R.id.widget_time, timeText)
            views.setTextViewText(R.id.widget_subject, subjectName)

            // Status Styling
            // 0: pending (Gray), 1: present (Green), 2: absent (Red), 3: proxy (Yellow)
            val statusColor = when(status) {
                1 -> Color.parseColor("#4CAF50") // Green
                2 -> Color.parseColor("#F44336") // Red
                3 -> Color.parseColor("#FFC107") // Amber
                else -> Color.parseColor("#424242") // Gray
            }
            
            // Left Bar Indicator
            views.setInt(R.id.widget_indicator_bar, "setColorFilter", statusColor)
            
            // Status Logic
            if (status == 0) { // Pending
                views.setViewVisibility(R.id.widget_btn_present, View.VISIBLE)
                views.setViewVisibility(R.id.widget_btn_absent, View.VISIBLE)
                views.setViewVisibility(R.id.widget_btn_proxy, View.VISIBLE)
                views.setViewVisibility(R.id.widget_status_icon, View.GONE)
                
                // Check Button (Present)
                val presentIntent = Intent()
                presentIntent.putExtra("sub_action", "present")
                presentIntent.putExtra("session_id", item.optString("id"))
                presentIntent.data = android.net.Uri.parse("madbunky://action/present?id=${item.optString("id")}")
                views.setOnClickFillInIntent(R.id.widget_btn_present, presentIntent)

                // Absent Button
                val absentIntent = Intent()
                absentIntent.putExtra("sub_action", "absent")
                absentIntent.putExtra("session_id", item.optString("id"))
                absentIntent.data = android.net.Uri.parse("madbunky://action/absent?id=${item.optString("id")}")
                views.setOnClickFillInIntent(R.id.widget_btn_absent, absentIntent)
                
                // Proxy Button
                val proxyIntent = Intent()
                proxyIntent.putExtra("sub_action", "proxy")
                proxyIntent.putExtra("session_id", item.optString("id"))
                proxyIntent.data = android.net.Uri.parse("madbunky://action/proxy?id=${item.optString("id")}")
                views.setOnClickFillInIntent(R.id.widget_btn_proxy, proxyIntent)
            } else {
                // Completed
                views.setViewVisibility(R.id.widget_btn_present, View.GONE)
                views.setViewVisibility(R.id.widget_btn_absent, View.GONE)
                views.setViewVisibility(R.id.widget_btn_proxy, View.GONE)
                views.setViewVisibility(R.id.widget_status_icon, View.VISIBLE)
                
                val iconResId = when(status) {
                    1 -> R.drawable.ic_check // Present
                    2 -> R.drawable.ic_close // Absent (Need to ensure this exists or use logic)
                    3 -> R.drawable.ic_proxy // Proxy
                    else -> 0
                }
                
                if (iconResId != 0) {
                     views.setImageViewResource(R.id.widget_status_icon, iconResId)
                     // Re-apply tint if needed, or assume icons are white and we tint them?
                     // Let's tint them to match status color for consistency
                     views.setInt(R.id.widget_status_icon, "setColorFilter", statusColor)
                }
            }

            // Item Click (To Open App)
            val openAppIntent = Intent()
            openAppIntent.putExtra("sub_action", "open")
            openAppIntent.putExtra("session_id", item.optString("id"))
            views.setOnClickFillInIntent(R.id.widget_item_container, openAppIntent)
            
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return views
    }

    override fun getLoadingView(): RemoteViews? {
        return null
    }

    override fun getViewTypeCount(): Int {
        return 1
    }

    override fun getItemId(position: Int): Long {
        return position.toLong()
    }

    override fun hasStableIds(): Boolean {
        return true
    }
}
