package com.aethel.aethel

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat

/**
 * The shared block wall layout, used both as the full-screen [BlockActivity]
 * and as the system overlay drawn by [BlockOverlay]. Deliberately has no
 * "end the block" affordance — leaving the wall means going back to Aethel
 * and pausing or ending the session there.
 */
internal object BlockWall {

    class Content(
        val root: LinearLayout,
        val countdown: TextView,
    )

    fun build(
        context: Context,
        blockedLabel: String?,
        onBackToAethel: () -> Unit,
    ): Content {
        val paper = color(context, R.color.aethel_paper)
        val ink = color(context, R.color.aethel_ink)
        val muted = color(context, R.color.aethel_muted)
        val teal = color(context, R.color.aethel_teal)
        val brass = color(context, R.color.aethel_brass)

        val root = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(paper)
            setPadding(dp(context, 30), dp(context, 24), dp(context, 30), dp(context, 24))
        }

        root.addView(label(context, "FOCUS MODE", brass, 13f, letterSpacing = 2.2f))
        root.addView(spacer(context, 16))
        root.addView(label(context, "This one can wait.", ink, 32f, bold = true))
        root.addView(spacer(context, 12))

        val body = if (blockedLabel != null) {
            "$blockedLabel is blocked while your focus session runs. " +
                "The block lifts by itself when the timer does."
        } else {
            "Apps on your block list stay closed while your focus session runs. " +
                "The block lifts by itself when the timer does."
        }
        root.addView(label(context, body, muted, 16f, lineSpacing = 1.4f))
        root.addView(spacer(context, 30))

        val countdown = TextView(context).apply {
            setTextColor(ink)
            textSize = 58f
            setTypeface(null, Typeface.BOLD)
            gravity = Gravity.CENTER
        }
        root.addView(countdown, matchWrap())
        root.addView(spacer(context, 6))
        root.addView(label(context, "left on this session", muted, 13f))
        root.addView(spacer(context, 34))

        val primary = Button(context).apply {
            text = "Back to Aethel"
            textSize = 15f
            setTextColor(Color.parseColor("#F7F4EC"))
            isAllCaps = false
            background = pill(context, teal)
            setPadding(dp(context, 28), dp(context, 14), dp(context, 28), dp(context, 14))
            setOnClickListener { onBackToAethel() }
        }
        root.addView(primary, matchWrap())

        return Content(root, countdown)
    }

    fun formatRemaining(millis: Long): String {
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
        context: Context,
        text: String,
        color: Int,
        sizeSp: Float,
        bold: Boolean = false,
        letterSpacing: Float = 0f,
        lineSpacing: Float = 1f,
    ): TextView {
        return TextView(context).apply {
            this.text = text
            setTextColor(color)
            textSize = sizeSp
            if (bold) setTypeface(null, Typeface.BOLD)
            if (letterSpacing != 0f) this.letterSpacing = letterSpacing / sizeSp
            if (lineSpacing != 1f) setLineSpacing(0f, lineSpacing)
        }
    }

    private fun pill(context: Context, fill: Int): GradientDrawable =
        GradientDrawable().apply {
            cornerRadius = dp(context, 999).toFloat()
            setColor(fill)
        }

    private fun spacer(context: Context, dpValue: Int): View =
        View(context).apply {
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(context, dpValue),
            )
        }

    private fun matchWrap() = LinearLayout.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.WRAP_CONTENT,
    )

    private fun color(context: Context, id: Int): Int =
        ContextCompat.getColor(context, id)

    private fun dp(context: Context, value: Int): Int =
        (value * context.resources.displayMetrics.density).toInt()
}
