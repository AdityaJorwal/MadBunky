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

class SubjectCardConfigActivity : AppCompatActivity() {

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

        findViewById<TextView>(R.id.config_title).text = "Select Subject for Card"
        
        findViewById<Button>(R.id.btn_save_widget).setOnClickListener {
            if (selectedSubjectId != null) {
                saveConfig(this, appWidgetId)
                
                // Trigger update
                val appWidgetManager = AppWidgetManager.getInstance(this)
                SubjectCardWidgetProvider.updateAppWidget(this, appWidgetManager, appWidgetId)

                val resultValue = Intent()
                resultValue.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                setResult(RESULT_OK, resultValue)
                finish()
            } else {
                Toast.makeText(this, "Please select a subject", Toast.LENGTH_SHORT).show()
            }
        }
        
        // Blur support
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
                 radioGroup.setBackgroundResource(R.drawable.bg_config_section)
                
                // Ensure previously selected is checked if editing
                // Note: We use "SubjectCardWidgetConfig" preference file here? 
                // Wait, Flutter side logic will need to read these mappings.
                // In previous widget, we struggled with this. 
                // Ideally we save to the DEFAULT shared prefs so HomeWidget can read it OR 
                // we save to our own file and `WidgetService` reads it (if we can).
                
                // Let's rely on `WidgetIdManager` style logic:
                // We MUST save the mapping 'widget_$ID' -> 'subjectID' where Flutter can find it.
                // Flutter's SharedPreferences plugin reads from default prefs (usually 'FlutterSharedPreferences' on Android).
                // `HomeWidgetPlugin.getData(this)` reads from 'HomeWidgetPreferences'.
                // If we save to 'HomeWidgetPreferences', Flutter `HomeWidget.getWidgetData` can read it.
                // So let's use `HomeWidgetPlugin.saveData` logic? 
                // `HomeWidgetPlugin` has a helper or we just open that SharedPreferences file.
                // The filename is "HomeWidgetPreferences".
                
                val savedId = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                    .getString("widget_$appWidgetId", null)

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
        // Save to HomeWidgetPreferences so FLUTTER can read it via HomeWidget.getWidgetData
        val hwPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE) // Name used by plugin
        val editor = hwPrefs.edit()
        editor.putString("widget_$appWidgetId", selectedSubjectId)
        
        // ALSO update the ID list for our `WidgetIdManager` logic?
        // Flutter side `WidgetIdManager` reads 'subject_card_widget_ids' from `FlutterSharedPreferences` (Default plugin repo).
        // It's messy to coordinate multiple Pref files.
        // EASIEST: Save to standard "FlutterSharedPreferences" so `shared_preferences` plugin sees it.
        // `HomeWidget.getWidgetData` expects "HomeWidgetPreferences".
        // `WidgetIdManager` (using shared_preferences pkg) expects "FlutterSharedPreferences".
        
        // Solution: Save to BOTH or save specifically for who needs what.
        
        // 1. Save for HomeWidget (Image update)
        editor.apply() 
        
        // 2. Save for WidgetIdManager (Flutter ID tracking)
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val flutterEditor = flutterPrefs.edit()
        
        // Add to list
        val key = "flutter.subject_card_widget_ids" // Plugin adds 'flutter.' prefix to keys? NO. 
        // The file is "FlutterSharedPreferences". Keys inside have "flutter." prefix IF set from Flutter.
        // IF set from Android, we must add "flutter." prefix if we want Flutter to see it standardly.
        
        val listStr = flutterPrefs.getString("flutter.subject_card_widget_ids", null)
        // Parsing list is hard (custom format). 
        // Let's just SAVE the single `widget_$appWidgetId` here too (with prefix).
        flutterEditor.putString("flutter.widget_$appWidgetId", selectedSubjectId)
        
        // We CAN'T easily update the LIST encoded string from Native without risking corruption.
        // Logic: We will let Flutter `WidgetService` discover the new widget by checking ALL widgets? No.
        
        // NEW STRATEGY: 
        // Just save `widget_$id` -> `subjectId` in HomeWidget prefs.
        // In Flutter `WidgetService`:
        // We iterate `HomeWidget.getWidgetIds` (Wait, we can't).
        // 
        // OKAY, we MUST save the ID list here natively in a format Flutter can read, OR
        // we use a simple delimited string "id1,id2,id3".
        
        var idListStr = flutterPrefs.getString("flutter.subject_card_widget_ids_simple", "") ?: ""
        val ids = idListStr.split(",").filter { it.isNotEmpty() }.toMutableList()
        if (!ids.contains(appWidgetId.toString())) {
            ids.add(appWidgetId.toString())
        }
        val newListStr = ids.joinToString(",")
        flutterEditor.putString("flutter.subject_card_widget_ids_simple", newListStr)
        
        flutterEditor.apply()
    }
}
