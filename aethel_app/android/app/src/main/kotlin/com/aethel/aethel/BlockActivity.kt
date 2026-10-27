package com.aethel.aethel

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper

/**
 * Full-screen fallback wall, used when the system overlay cannot be drawn
 * (Display-over-other-apps not granted yet) but an activity launch is still
 * allowed. The layout itself lives in [BlockWall] so both paths look and
 * behave the same.
 */
class BlockActivity : Activity() {

    companion object {
        const val EXTRA_UNTIL = "until"
        const val EXTRA_PACKAGE = "blocked_package"
    }

    private val handler = Handler(Looper.getMainLooper())
    private var until = 0L
    private lateinit var wall: BlockWall.Content

    private val ticker = object : Runnable {
        override fun run() {
            val remaining = until - System.currentTimeMillis()
            if (remaining <= 0) {
                finish()
                return
            }
            wall.countdown.text = BlockWall.formatRemaining(remaining)
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        until = intent.getLongExtra(EXTRA_UNTIL, System.currentTimeMillis())
        val blockedName = resolveLabel(intent.getStringExtra(EXTRA_PACKAGE))
        wall = BlockWall.build(
            context = this,
            blockedLabel = blockedName,
            onBackToAethel = {
                packageManager.getLaunchIntentForPackage(packageName)?.let { launch ->
                    launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(launch)
                }
                finish()
            },
        )
        setContentView(wall.root)
        handler.post(ticker)
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Keep the wall up; leaving is done through "Back to Aethel".
        moveTaskToBack(true)
    }

    private fun resolveLabel(packageName: String?): String? {
        if (packageName.isNullOrBlank()) return null
        return runCatching {
            val info = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(info).toString()
        }.getOrNull()
    }
}
