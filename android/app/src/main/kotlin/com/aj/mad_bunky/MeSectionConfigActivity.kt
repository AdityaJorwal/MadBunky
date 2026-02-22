package com.aj.mad_bunky

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.CheckBox
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

import androidx.appcompat.app.AppCompatActivity

class MeSectionConfigActivity : AppCompatActivity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private val selectedSubjects = mutableSetOf<String>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_widget_config)

        // Set the result to CANCELED. This will cause the widget host to cancel
        // out of the widget placement if the user presses the back button.
        setResult(RESULT_CANCELED)

        try {
            // Find the widget ID from the intent.
            val intent = intent
            val extras = intent.extras
            if (extras != null) {
                appWidgetId = extras.getInt(
                    AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID
                )
            }

            // If this activity was started with an intent without an app widget ID, finish with an error.
            if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
                finish()
                return
            }

            findViewById<Button>(R.id.btn_save_widget).setOnClickListener {
                try {
                    val context = this@MeSectionConfigActivity
                    saveConfig(context, appWidgetId)

                    // It is the responsibility of the configuration activity to update the app widget
                    val appWidgetManager = AppWidgetManager.getInstance(context)
                    MeSectionWidgetProvider.updateAppWidget(context, appWidgetManager, appWidgetId)

                    // Make sure we pass back the original appWidgetId
                    val resultValue = Intent()
                    resultValue.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    setResult(RESULT_OK, resultValue)
                    finish()
                } catch (e: Exception) {
                    e.printStackTrace()
                    Toast.makeText(this, "Error saving widget: ${e.message}", Toast.LENGTH_SHORT).show()
                }
            }
            
            // Enable blur behind
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                window.setDimAmount(0.3f) // Dim slightly LESS if we have blur
                try {
                     window.addFlags(android.view.WindowManager.LayoutParams.FLAG_BLUR_BEHIND)
                     val attrib = window.attributes
                     attrib.blurBehindRadius = 20
                     window.attributes = attrib
                } catch (e: Exception) {
                    // Ignore if not supported or restricted
                }
            } else {
                 window.setDimAmount(0.5f) // Fallback dim
            }

            loadSections()
        } catch (e: Exception) {
            e.printStackTrace()
            Toast.makeText(this, "Error initializing widget config: ${e.message}", Toast.LENGTH_LONG).show()
            finish()
        }
    }

    private fun loadSections() {
        val rootContainer = findViewById<LinearLayout>(R.id.subjects_container)
        val statusView = findViewById<TextView>(R.id.config_status)
        
        rootContainer.removeAllViews() // Clear existing

        val widgetData = HomeWidgetPlugin.getData(this)
        val allSubjectsString = widgetData.getString("all_subjects_data", "[]")
        val allGroupsString = widgetData.getString("all_groups_data", "[]") // Load groups
        
        if ((allSubjectsString == "[]" || allSubjectsString!!.isEmpty()) && 
            (allGroupsString == "[]" || allGroupsString!!.isEmpty())) {
            statusView.text = "No data found. Please open the app first."
            statusView.visibility = android.view.View.VISIBLE
            return
        }

        try {
            // 1. Subjects Section
            val allSubjects = JSONArray(allSubjectsString)
            if (allSubjects.length() > 0) {
                addSectionHeader(rootContainer, "Subjects")
                val sectionContainer = createSectionContainer(rootContainer)
                
                for (i in 0 until allSubjects.length()) {
                    val subject = allSubjects.getJSONObject(i)
                    val name = subject.getString("name")
                    val id = subject.getString("id")
                    
                    addItemView(sectionContainer, name, id, i == allSubjects.length() - 1)
                }
            }

            // 2. Groups Section
            val allGroups = JSONArray(allGroupsString)
            if (allGroups.length() > 0) {
                addSpace(rootContainer, 24)
                addSectionHeader(rootContainer, "Groups") // "Folder" section
                val sectionContainer = createSectionContainer(rootContainer)
                
                for (i in 0 until allGroups.length()) {
                    val group = allGroups.getJSONObject(i)
                    val name = group.getString("name")
                    val id = group.getString("id")
                    
                    addItemView(sectionContainer, name, id, i == allGroups.length() - 1)
                }
            }

        } catch (e: Exception) {
            e.printStackTrace()
             statusView.text = "Error: ${e.message}"
            statusView.visibility = android.view.View.VISIBLE
        }
    }

    private fun addSectionHeader(parent: LinearLayout, title: String) {
        val header = TextView(this)
        header.text = title
        header.textSize = 16f
        // Used a salmon-ish color similar to screenshot approx #E57373 or closer to app theme?
        // Let's use #FFAB91 (Light Salmon) or plain white/accent if safer. 
        // User screenshot had "Functionality" in Salmon.
        header.setTextColor(android.graphics.Color.parseColor("#FFAB91")) 
        header.setPadding(12, 0, 0, 16) // Left padding alignment
        parent.addView(header)
    }

    private fun createSectionContainer(parent: LinearLayout): LinearLayout {
        val container = LinearLayout(this)
        container.orientation = LinearLayout.VERTICAL
        container.setBackgroundResource(R.drawable.bg_config_section)
        
        val params = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        )
        container.layoutParams = params
        parent.addView(container)
        return container
    }
    
    private fun addSpace(parent: LinearLayout, heightDp: Int) {
         val space = android.view.View(this)
         space.layoutParams = LinearLayout.LayoutParams(
             LinearLayout.LayoutParams.MATCH_PARENT,
             (heightDp * resources.displayMetrics.density).toInt()
         )
         parent.addView(space)
    }

    private fun addItemView(container: LinearLayout, name: String, id: String, isLast: Boolean) {
        val itemView = layoutInflater.inflate(R.layout.item_config_subject, container, false)
        val nameView = itemView.findViewById<TextView>(R.id.subject_name)
        val switchView = itemView.findViewById<android.widget.CompoundButton>(R.id.subject_switch) // Switch is CompoundButton base
        
        nameView.text = name

        // Check if selected
        switchView.isChecked = selectedSubjects.contains(id)

        switchView.setOnCheckedChangeListener { _, isChecked ->
            if (isChecked) {
                selectedSubjects.add(id)
            } else {
                selectedSubjects.remove(id)
            }
        }
        
        container.addView(itemView)
        
        // Add divider if not last
        if (!isLast) {
            val divider = android.view.View(this)
            divider.layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, 
                (1 * resources.displayMetrics.density).toInt()
            ).apply {
                setMargins((20 * resources.displayMetrics.density).toInt(), 0, (20 * resources.displayMetrics.density).toInt(), 0)
            }
            divider.setBackgroundColor(android.graphics.Color.parseColor("#1AFFFFFF")) // Subtle divider
            container.addView(divider)
        }
    }

    private fun saveConfig(context: Context, appWidgetId: Int) {
        val prefs = context.getSharedPreferences("MeSectionWidgetConfig", Context.MODE_PRIVATE)
        prefs.edit().putStringSet("widget_$appWidgetId", selectedSubjects).apply()
    }
}
