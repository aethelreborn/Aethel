package com.aethel.aethel

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent

/**
 * Single process-wide hook the block service listens on. Accessibility
 * events arrive in microseconds where the usage-stats poll takes up to a
 * poll interval, so the wall can rise almost the moment a blocked app
 * becomes visible.
 */
object BlockEvents {
    @Volatile
    var listener: ((String) -> Unit)? = null
}

/**
 * Reports window/state changes to [BlockEvents]. Detection only — the wall
 * itself is drawn by [BlockOverlay] or [BlockActivity] via BlockGuardService.
 * Enabled separately by the user in system Accessibility settings.
 */
class AethelAccessibilityService : AccessibilityService() {

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val packageName = event.packageName?.toString() ?: return
        if (packageName == this.packageName) return
        BlockEvents.listener?.invoke(packageName)
    }

    override fun onInterrupt() = Unit
}
