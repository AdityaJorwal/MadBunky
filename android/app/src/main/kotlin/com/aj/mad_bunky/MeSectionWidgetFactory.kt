package com.aj.mad_bunky

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

class MeSectionWidgetFactory(private val context: Context, intent: Intent) : RemoteViewsService.RemoteViewsFactory {
    private var data: JSONArray = JSONArray()
    private val appWidgetId: Int = intent.getIntExtra(android.appwidget.AppWidgetManager.EXTRA_APPWIDGET_ID, android.appwidget.AppWidgetManager.INVALID_APPWIDGET_ID)
    private var selectedSubjects: Set<String> = emptySet()

    override fun onCreate() {
        loadData()
    }

    override fun onDataSetChanged() {
        loadData()
    }
    
    private fun loadData() {
        try {
            // Load configuration
            val prefs = context.getSharedPreferences("MeSectionWidgetConfig", Context.MODE_PRIVATE)
            // Use MutableSet because we might need to modify it? No, just read.
            selectedSubjects = prefs.getStringSet("widget_$appWidgetId", emptySet()) ?: emptySet()
            
            // Load data
            val widgetData = HomeWidgetPlugin.getData(context)
            val allSubjectsString = widgetData.getString("all_subjects_data", "[]")
            val allGroupsString = widgetData.getString("all_groups_data", "[]") // Load groups
            
            val allSubjects = JSONArray(allSubjectsString)
            val allGroups = JSONArray(allGroupsString)
            
            // Filter and Merge
            data = JSONArray()
            val hasSelection = selectedSubjects.isNotEmpty()
            
            // 1. Add matching Subjects
            for (i in 0 until allSubjects.length()) {
                val item = allSubjects.getJSONObject(i)
                if (!hasSelection || selectedSubjects.contains(item.optString("id"))) {
                    data.put(item)
                }
            }
            
            // 2. Add matching Groups
             for (i in 0 until allGroups.length()) {
                val item = allGroups.getJSONObject(i)
                if (!hasSelection || selectedSubjects.contains(item.optString("id"))) {
                    // Start of group indication (optional: append " (Group)" to name?)
                    // item.put("name", item.getString("name") + " 📁") // quick hack for visual distinction
                    data.put(item)
                }
            }

        } catch (e: Exception) {
            e.printStackTrace()
             // data remains empty JSONArray
        }
    }

    override fun onDestroy() {
         data = JSONArray()
    }

    override fun getCount(): Int {
        // Return count or 0
        return data.length()
    }

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.item_widget_me_section)
        try {
            val item = data.getJSONObject(position)
            views.setTextViewText(R.id.widget_me_subject, item.optString("name"))
            
            val percentage = item.optDouble("percentage", 0.0)
            views.setTextViewText(R.id.widget_me_percent, "${percentage.toInt()}%")
            
            val prediction = item.optInt("prediction", 0)
             val predictionText = if (prediction > 0) "Bunk $prediction" else "Attend ${-prediction}"
            views.setTextViewText(R.id.widget_me_prediction, predictionText)
            
            // Color coding
             if (percentage >= 75) {
                 // Safe Zone
                 views.setTextColor(R.id.widget_me_percent, android.graphics.Color.parseColor("#4CAF50")) // Green 500
                 views.setTextColor(R.id.widget_me_prediction, android.graphics.Color.parseColor("#81C784")) // Green 300 (Softer)
             } else {
                 // Danger Zone
                 views.setTextColor(R.id.widget_me_percent, android.graphics.Color.parseColor("#F44336")) // Red 500
                 views.setTextColor(R.id.widget_me_prediction, android.graphics.Color.parseColor("#E57373")) // Red 300 (Softer)
             }
             
            // Open App on Item Click
            val fillInIntent = Intent()
            fillInIntent.putExtra("sub_action", "open")
            views.setOnClickFillInIntent(R.id.widget_me_item_container, fillInIntent)

        } catch (e: Exception) {
            e.printStackTrace()
        }
        return views
    }

    override fun getLoadingView(): RemoteViews? { return null }
    override fun getViewTypeCount(): Int { return 1 }
    override fun getItemId(position: Int): Long { return position.toLong() }
    override fun hasStableIds(): Boolean { return true }
}
