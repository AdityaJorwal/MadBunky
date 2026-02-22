package com.aj.mad_bunky

import android.content.Intent
import android.widget.RemoteViewsService

class MyDayWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return MyDayWidgetFactory(this.applicationContext, intent)
    }
}
