package com.aethel.aethel

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat

/**
 * The wall a blocked application runs into. Shows how long is left and one
 * way back into Aethel, plus an explicit way to stop the block.
 */
class BlockActivity : Activity() {

    companion object {
        const val EXTRA_UNTIL = "until"
        const val EXTRA_PACKAGE = "blocked_package"
    }

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var countdown: TextView
    private var until = 0L

    private val ticker = object : Runnable {
        override fun run() {
            val remaining = until - System.currentTimeMillis()
            if (remaining <= 0) {
                finish()
                return
            }
            countdown.text = formatRemaining(remaining)
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        until = intent.getLongExtra(EXTRA_UNTIL, System.currentTimeMillis())
        buildLayout()
        handler.post(ticker)
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        moveTaskToBack(true)
    }

    private fun buildLayout() {
        val paper = color(R.color.aethel_paper)
        val ink = color(R.color.aethel_ink)
        val muted = color(R.color.aethel_muted)
        val teal = color(R.color.aethel_teal)
        val brass = color(R.color.aethel_brass)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(paper)
            setPadding(dp(30), dp(24), dp(30), dp(24))
        }

        root.addView(label("FOCUS MODE", brass, 13f, letterSpacing = 2.2f))
        root.addView(spacer(16))
        root.addView(label("This one can wait.", ink, 32f, bold = true))
        root.addView(spacer(12))

        val blockedName = resolveLabel(intent.getStringExtra(EXTRA_PACKAGE))
        val body = if (blockedName != null) {
            "$blockedName is blocked while your focus session runs. " +
                "The block lifts by itself when the timer does."
        } else {
            "Apps on your block list stay closed while your focus session runs. " +
                "The block lifts by itself when the timer does."
        }
        root.addView(label(body, muted, 16f, lineSpacing = 1.4f))
        root.addView(spacer(30))

        countdown = TextView(this).apply {
            setTextColor(ink)
            textSize = 58f
            setTypeface(null, Typeface.BOLD)
            gravity = Gravity.CENTER
        }
        root.addView(countdown, matchWrap())
        root.addView(spacer(6))
        root.addView(label("left on this session", muted, 13f))
        root.addView(spacer(34))

        val primary = Button(this).apply {
            text = "Back to Aethel"
            textSize = 15f
            setTextColor(Color.parseColor("#F7F4EC"))
            isAllCaps = false
            background = pill(teal)
            setPadding(dp(28), dp(14), dp(28), dp(14))
            setOnClickListener {
                packageManager.getLaunchIntentForPackage(packageName)?.let { launch ->
                    launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(launch)
                }
                finish()
            }
        }
        root.addView(primary, matchWrap())
        root.addView(spacer(8))

        val secondary = Button(this).apply {
            text = "End the block"
            textSize = 14f
            setTextColor(muted)
            isAllCaps = false
            background = pill(Color.TRANSPARENT)
            setPadding(dp(28), dp(12), dp(28), dp(12))
            setOnClickListener { confirmEnd() }
        }
        root.addView(secondary, matchWrap())

        setContentView(root)
    }

    private fun confirmEnd() {
        AlertDialog.Builder(this)
            .setTitle("End the block?")
            .setMessage(
                "Blocked apps open again right away, and the rest of this " +
                    "session will not keep them closed.",
            )
            .setPositiveButton("End block") { _, _ ->
                BlockGuardService.stop(this)
                finish()
            }
            .setNegativeButton("Keep blocking", null)
            .show()
    }

    private fun resolveLabel(packageName: String?): String? {
        if (packageName.isNullOrBlank()) return null
        return runCatching {
            val info = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(info).toString()
        }.getOrNull()
    }

    private fun formatRemaining(millis: Long): String {
        val totalSeconds = (millis / 1000).toInt()
        val hours = totalSeconds / 3600
        val minutes = (totalSeconds % 3600) / 60
        val seconds = totalSeconds % 60
        return if (hours > 0) {
            String.format("%d:%02d:%02d", hours, minutes, seconds)
        } else {
            String.format("%02d:%02d", minutes, seconds)
        }
    }

    private fun label(
        text: String,
        color: Int,
        sizeSp: Float,
        bold: Boolean = false,
        letterSpacing: Float = 0f,
        lineSpacing: Float = 1f,
    ): TextView {
        return TextView(this).apply {
            this.text = text
            setTextColor(color)
            textSize = sizeSp
            if (bold) setTypeface(null, Typeface.BOLD)
            if (letterSpacing != 0f) this.letterSpacing = letterSpacing / sizeSp
            if (lineSpacing != 1f) setLineSpacing(0f, lineSpacing)
        }
    }

    private fun pill(fill: Int): GradientDrawable =
        GradientDrawable().apply {
            cornerRadius = dp(999).toFloat()
            setColor(fill)
        }

    private fun spacer(dpValue: Int): View =
        View(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(dpValue),
            )
        }

    private fun matchWrap() = LinearLayout.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.WRAP_CONTENT,
    )

    private fun color(id: Int): Int = ContextCompat.getColor(this, id)

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()
}
