package com.aj.mad_bunky

import android.content.Intent
import android.widget.RemoteViewsService

class MeSectionWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return MeSectionWidgetFactory(this.applicationContext, intent)
    }
}
