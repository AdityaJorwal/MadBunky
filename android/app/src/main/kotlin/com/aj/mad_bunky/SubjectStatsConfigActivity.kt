package com.aj.mad_bunky

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.LinearLayout
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.TextView
import android.widget.Toast
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import androidx.appcompat.app.AppCompatActivity

class SubjectStatsConfigActivity : AppCompatActivity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private var selectedSubjectId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_widget_config)

        setResult(RESULT_CANCELED)

        val intent = intent
        val extras = intent.extras
        if (extras != null) {
            appWidgetId = extras.getInt(
                AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID
            )
        }

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        // Setup UI
        findViewById<TextView>(R.id.config_title).text = "Select Subject"
        
        findViewById<Button>(R.id.btn_save_widget).setOnClickListener {
            if (selectedSubjectId != null) {
                saveConfig(this, appWidgetId)
                
                // Trigger update - we rely on Flutter app to actually render content
                // But we can signal it via broadcast or by just storing the pref.
                // The provider onUpdate will be called, but it might not have the image yet.
                // We should ideally launch the background service to render it.
                // For now, let's finish configuration, and standard update cycle will pick it up
                // OR we trigger a background update via HomeWidgetPlugin if possible.
                
                // Notify AppWidgetManager
                val appWidgetManager = AppWidgetManager.getInstance(this)
                SubjectStatsWidgetProvider.updateAppWidget(this, appWidgetManager, appWidgetId)

                val resultValue = Intent()
                resultValue.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                setResult(RESULT_OK, resultValue)
                finish()
            } else {
                Toast.makeText(this, "Please select a subject", Toast.LENGTH_SHORT).show()
            }
        }
        
        // Blur
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            window.setDimAmount(0.3f) 
            try {
                 window.addFlags(android.view.WindowManager.LayoutParams.FLAG_BLUR_BEHIND)
                 val attrib = window.attributes
                 attrib.blurBehindRadius = 20
                 window.attributes = attrib
            } catch (e: Exception) {}
        }

        loadSubjects()
    }

    private fun loadSubjects() {
        val rootContainer = findViewById<LinearLayout>(R.id.subjects_container)
        rootContainer.removeAllViews()

        val widgetData = HomeWidgetPlugin.getData(this)
        val allSubjectsString = widgetData.getString("all_subjects_data", "[]")

        if (allSubjectsString == "[]" || allSubjectsString!!.isEmpty()) {
            val statusView = findViewById<TextView>(R.id.config_status)
            statusView.text = "No subjects found. Please open the app first."
            statusView.visibility = android.view.View.VISIBLE
            return
        }

        try {
            val allSubjects = JSONArray(allSubjectsString)
            if (allSubjects.length() > 0) {
                val radioGroup = RadioGroup(this)
                radioGroup.orientation = LinearLayout.VERTICAL
                
                // Container style
                radioGroup.setBackgroundResource(R.drawable.bg_config_section)
                val params = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
                radioGroup.layoutParams = params
                
                 // Load saved selection if editing
                // We use HomeWidgetPreferences as we saved there too
                val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                val savedId = prefs.getString("widget_$appWidgetId", null)

                for (i in 0 until allSubjects.length()) {
                    val subject = allSubjects.getJSONObject(i)
                    val name = subject.getString("name")
                    val id = subject.getString("id")

                    val radioButton = RadioButton(this)
                    radioButton.text = name
                    radioButton.setTextColor(android.graphics.Color.WHITE)
                    radioButton.textSize = 16f
                    radioButton.setPadding(24, 24, 24, 24)
                    radioButton.tag = id
                    
                    // Style radio button
                    // We might want to use a custom drawable selector for the button
                    // But standard Android radio is okay for now or we use text color change.
                    
                    if (id == savedId) {
                        radioButton.isChecked = true
                        selectedSubjectId = id
                    }

                    radioButton.setOnCheckedChangeListener { _, isChecked ->
                        if (isChecked) selectedSubjectId = id
                    }

                    radioGroup.addView(radioButton)
                }
                
                rootContainer.addView(radioGroup)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun saveConfig(context: Context, appWidgetId: Int) {
        // 1. Save to HomeWidgetPreferences (Redundant but safe for HomeWidget plugin)
        val hwPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        hwPrefs.edit().putString("widget_$appWidgetId", selectedSubjectId).apply()
        
        // 2. Save to FlutterSharedPreferences for WidgetIdManager
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val editor = flutterPrefs.edit()

        // A. Save the specific mapping
        editor.putString("flutter.widget_stats_$appWidgetId", selectedSubjectId)
        
        // B. Update the list of IDs
        var idListStr = flutterPrefs.getString("flutter.subject_stats_widget_ids_simple", "") ?: ""
        val ids = idListStr.split(",").filter { it.isNotEmpty() }.toMutableList()
        
        if (!ids.contains(appWidgetId.toString())) {
            ids.add(appWidgetId.toString())
        }
        
        val newListStr = ids.joinToString(",")
        editor.putString("flutter.subject_stats_widget_ids_simple", newListStr)
        
        editor.apply()
    }
}
