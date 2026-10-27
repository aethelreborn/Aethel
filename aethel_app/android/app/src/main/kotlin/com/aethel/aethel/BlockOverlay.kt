package com.aethel.aethel

import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager

/**
 * Draws the block wall over whatever application is in front.
 *
 * This is the primary enforcement path: WindowManager.addView does not go
 * through background-activity-start restrictions, so unlike launching
 * [BlockActivity] from the foreground service while e.g. YouTube is open,
 * the wall actually appears.
 */
class BlockOverlay(
    private val context: Context,
    private val until: Long,
) {

    private val handler = Handler(Looper.getMainLooper())
    private val windowManager =
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

    private var content: BlockWall.Content? = null
    private var blockedLabel: String? = null

    private val ticker = object : Runnable {
        override fun run() {
            val current = content ?: return
            val remaining = until - System.currentTimeMillis()
            if (remaining <= 0) {
                hide()
                return
            }
            current.countdown.text = BlockWall.formatRemaining(remaining)
            handler.postDelayed(this, 1000)
        }
    }

    fun isShowing(): Boolean = content != null

    /** Returns true when the wall is (or was already) on screen. */
    fun show(blockedPackage: String?): Boolean {
        if (!Settings.canDrawOverlays(context)) return false
        if (content != null) return true

        val label = blockedPackage?.let { resolveLabel(it) }
        blockedLabel = label
        val wall = BlockWall.build(
            context = context,
            blockedLabel = label,
            onBackToAethel = ::backToAethel,
        )
        wall.root.setOnKeyListener { _, keyCode, _ ->
            // The wall owns the back key so it cannot fall through to the
            // blocked application behind it. Leaving goes through the button.
            keyCode == KeyEvent.KEYCODE_BACK
        }
        wall.root.isFocusable = true
        wall.root.isFocusableInTouchMode = true
        wall.root.requestFocus()

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.OPAQUE,
        ).apply {
            gravity = Gravity.CENTER
            // No FLAG_NOT_FOCUSABLE: keys must land on the wall, not the
            // blocked app. No FLAG_NOT_TOUCHABLE / NOT_TOUCH_MODAL: taps on
            // the opaque wall must be consumed, never passed through.
        }

        return try {
            windowManager.addView(wall.root, params)
            content = wall
            wall.countdown.text = BlockWall.formatRemaining(
                until - System.currentTimeMillis(),
            )
            handler.removeCallbacks(ticker)
            handler.post(ticker)
            true
        } catch (_: Exception) {
            false
        }
    }

    fun hide() {
        handler.removeCallbacks(ticker)
        val current = content ?: return
        content = null
        runCatching { windowManager.removeView(current.root) }
    }

    private fun backToAethel() {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launch != null) {
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            runCatching { context.startActivity(launch) }
        }
        hide()
    }

    private fun resolveLabel(packageName: String): String? {
        return runCatching {
            val info = context.packageManager.getApplicationInfo(packageName, 0)
            context.packageManager.getApplicationLabel(info).toString()
        }.getOrNull()
    }
}
