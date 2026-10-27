package com.aethel.aethel

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat

/**
 * Watches which application is in the foreground while a focus session is
 * running and lifts the block screen whenever a blocked one comes up.
 *
 * Requires the usage-access grant the app asks for in the permission sheet.
 */
class BlockGuardService : Service() {

    companion object {
        const val EXTRA_UNTIL = "until"
        const val EXTRA_PACKAGES = "packages"
        const val CHANNEL_ID = "aethel_block_guard"
        const val NOTIFICATION_ID = 4711
        private const val POLL_INTERVAL_MS = 700L
        private const val SEED_WINDOW_MS = 60_000L
        private const val TRACK_WINDOW_MS = 5_000L
        private const val RELAUNCH_COOLDOWN_MS = 2_000L

        fun stop(context: Context) {
            context.stopService(Intent(context, BlockGuardService::class.java))
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var until = 0L
    private var blocked = emptySet<String>()
    private var lastBlockShownAt = 0L
    private var seededForeground = false
    private var overlay: BlockOverlay? = null

    private val poller = object : Runnable {
        override fun run() {
            if (System.currentTimeMillis() >= until) {
                stopSelf()
                return
            }
            // First poll looks back far enough to catch an app that was
            // already foreground when the session started. Later polls only
            // need the recent window because we re-check every tick.
            val windowMs = if (seededForeground) TRACK_WINDOW_MS else SEED_WINDOW_MS
            val foreground = currentForegroundPackage(windowMs)
            if (foreground != null) {
                seededForeground = true
                considerBlock(foreground)
            }
            handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    /** Shared by the usage-stats poller and the accessibility fast path. */
    private fun considerBlock(foreground: String) {
        if (foreground !in blocked) return
        val now = System.currentTimeMillis()
        // Re-check membership every time, not only on change: after leaving
        // the wall the foreground is still the blocked app and an
        // equality-only check would never re-block. The cooldown stops a
        // relaunch loop while the wall is already up.
        if (now - lastBlockShownAt >= RELAUNCH_COOLDOWN_MS) {
            lastBlockShownAt = now
            showBlockScreen(foreground)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        until = intent?.getLongExtra(EXTRA_UNTIL, 0L) ?: 0L
        blocked = (intent?.getStringArrayListExtra(EXTRA_PACKAGES) ?: arrayListOf())
            .filter { it.isNotBlank() }
            .toSet()
        startForegroundNotification()

        handler.removeCallbacks(poller)
        if (blocked.isEmpty() || until <= System.currentTimeMillis()) {
            stopSelf()
            return START_NOT_STICKY
        }
        overlay?.hide()
        overlay = BlockOverlay(this, until)
        // Accessibility events fire the moment a window changes, so the wall
        // can rise before the usage-stats poll would have noticed.
        BlockEvents.listener = { packageName ->
            handler.post {
                seededForeground = true
                considerBlock(packageName)
            }
        }
        handler.post(poller)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        BlockEvents.listener = null
        overlay?.hide()
        overlay = null
        super.onDestroy()
    }

    private fun currentForegroundPackage(windowMs: Long = TRACK_WINDOW_MS): String? {
        val usageStats =
            getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager ?: return null
        val now = System.currentTimeMillis()
        val events = usageStats.queryEvents(now - windowMs, now)
        val event = UsageEvents.Event()
        var latest = 0L
        var packageName: String? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val isResume = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                event.eventType == UsageEvents.Event.ACTIVITY_RESUMED
            } else {
                @Suppress("DEPRECATION")
                event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND
            }
            if (!isResume) continue
            if (event.timeStamp < latest) continue
            latest = event.timeStamp
            // Own-package resume (Aethel or BlockActivity) means the user is
            // inside us, not in a blocked app — store null so a stale third-
            // party resume older than this one is not mistaken for foreground.
            packageName =
                if (event.packageName == this.packageName) null else event.packageName
        }
        return packageName
    }

    private fun showBlockScreen(blockedPackage: String?) {
        // Overlay first: WindowManager.addView is not subject to
        // background-activity-start rules, so it works while the blocked app
        // is foreground. The activity path is a fallback for when overlay
        // permission is missing (and BAL is exempted by an enabled
        // accessibility service).
        if (overlay?.show(blockedPackage) == true) return
        val intent = Intent(this, BlockActivity::class.java).apply {
            putExtra(BlockActivity.EXTRA_UNTIL, until)
            putExtra(BlockActivity.EXTRA_PACKAGE, blockedPackage)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        runCatching { startActivity(intent) }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Focus sessions",
            NotificationManager.IMPORTANCE_LOW,
        )
        channel.description = "Keeps focus sessions running and apps blocked."
        manager.createNotificationChannel(channel)
    }

    private fun startForegroundNotification() {
        val openApp = PendingIntent.getActivity(
            this,
            0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Focus mode is on")
            .setContentText("Blocked apps stay closed until the session ends.")
            .setSmallIcon(R.drawable.ic_notification)
            .setOngoing(true)
            .setContentIntent(openApp)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }
}
