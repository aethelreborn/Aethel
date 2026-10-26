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

        fun stop(context: Context) {
            context.stopService(Intent(context, BlockGuardService::class.java))
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var until = 0L
    private var blocked = emptySet<String>()
    private var lastForeground: String? = null

    private val poller = object : Runnable {
        override fun run() {
            if (System.currentTimeMillis() >= until) {
                stopSelf()
                return
            }
            val foreground = currentForegroundPackage()
            if (foreground != null && foreground != lastForeground) {
                lastForeground = foreground
                if (foreground in blocked) {
                    showBlockScreen(foreground)
                }
            }
            handler.postDelayed(this, 700)
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
        handler.post(poller)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    private fun currentForegroundPackage(): String? {
        val usageStats =
            getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager ?: return null
        val now = System.currentTimeMillis()
        val events = usageStats.queryEvents(now - 5000, now)
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
            if (event.packageName == this.packageName) continue
            latest = event.timeStamp
            packageName = event.packageName
        }
        return packageName
    }

    private fun showBlockScreen(blockedPackage: String?) {
        val intent = Intent(this, BlockActivity::class.java).apply {
            putExtra(BlockActivity.EXTRA_UNTIL, until)
            putExtra(BlockActivity.EXTRA_PACKAGE, blockedPackage)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        startActivity(intent)
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
