package com.aj.mad_bunky

import io.flutter.embedding.android.FlutterActivity

import android.content.Intent

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.aj.mad_bunky/minimize"

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        io.flutter.plugin.common.MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "minimizeApp") {
                moveTaskToBack(true)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }
}
