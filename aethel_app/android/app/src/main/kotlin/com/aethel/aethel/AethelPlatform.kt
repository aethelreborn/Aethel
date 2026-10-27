package com.aethel.aethel

import android.app.Activity
import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.LinkedHashMap

/**
 * Flutter <-> Android bridge for the things Dart cannot reach on its own:
 * installed applications, usage access (app blocking) and the package
 * installer used by the in-app updater.
 */
class AethelPlatform(
    private val context: Context,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "aethel/platform"

        fun register(messenger: BinaryMessenger, context: Context) {
            MethodChannel(messenger, CHANNEL).setMethodCallHandler(
                AethelPlatform(context.applicationContext),
            )
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasUsageAccess" -> result.success(hasUsageAccess())
            "requestUsageAccess" -> {
                runCatching {
                    context.startActivity(
                        Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                }
                result.success(true)
            }
            "hasOverlayPermission" -> result.success(Settings.canDrawOverlays(context))
            "requestOverlayPermission" -> {
                runCatching {
                    context.startActivity(
                        Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:${context.packageName}"),
                        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                }
                result.success(true)
            }
            "hasAccessibilityBlocker" -> result.success(hasAccessibilityBlocker())
            "openNotificationSettings" -> {
                runCatching { openNotificationSettings() }
                result.success(true)
            }
            "openAccessibilitySettings" -> {
                runCatching {
                    context.startActivity(
                        Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                }
                result.success(true)
            }
            "listApps" -> result.success(listApps())
            "startBlock" -> {
                val untilMs = (call.argument<Number>("untilMs"))?.toLong() ?: 0L
                val names = call.argument<List<String>>("names").orEmpty()
                if (untilMs <= System.currentTimeMillis() || names.isEmpty()) {
                    BlockGuardService.stop(context)
                    result.success(false)
                } else if (!hasUsageAccess()) {
                    // queryEvents is empty without this grant, so the poller
                    // would run forever and never lift the block screen.
                    BlockGuardService.stop(context)
                    result.success(false)
                } else {
                    val packages = resolvePackages(names)
                    if (packages.isEmpty()) {
                        BlockGuardService.stop(context)
                        result.success(false)
                    } else {
                        val intent = Intent(context, BlockGuardService::class.java).apply {
                            putExtra(BlockGuardService.EXTRA_UNTIL, untilMs)
                            putStringArrayListExtra(
                                BlockGuardService.EXTRA_PACKAGES,
                                ArrayList(packages),
                            )
                        }
                        ContextCompat.startForegroundService(context, intent)
                        result.success(true)
                    }
                }
            }
            "stopBlock" -> {
                BlockGuardService.stop(context)
                result.success(true)
            }
            "installApk" -> {
                val path = call.arguments as? String
                if (path == null) {
                    result.error("bad_args", "Missing apk path", null)
                } else {
                    result.success(installApk(path))
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun hasAccessibilityBlocker(): Boolean {
        val expected = "${context.packageName}/${AethelAccessibilityService::class.java.name}"
        val enabled = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        return enabled.split(':').any { it.equals(expected, ignoreCase = true) }
    }

    private fun openNotificationSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.parse("package:${context.packageName}"))
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    /** Launchable apps only, so the list matches what the user can open. */
    private fun listApps(): List<Map<String, String>> {
        return labelledApps()
            .map { (id, name) -> mapOf("id" to id, "name" to name) }
            .sortedBy { it.getValue("name").lowercase() }
    }

    private fun labelledApps(): LinkedHashMap<String, String> {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolved = try {
            context.packageManager.queryIntentActivities(intent, 0)
        } catch (_: Exception) {
            emptyList()
        }
        val seen = LinkedHashMap<String, String>()
        for (info in resolved) {
            val packageName = info.activityInfo?.packageName ?: continue
            if (packageName == context.packageName) continue
            val label = info.loadLabel(context.packageManager).toString().trim()
            if (label.isEmpty()) continue
            if (seen.containsKey(packageName)) continue
            seen[packageName] = label
        }
        return seen
    }

    /**
     * Turns the display names the user picked in Flutter into the package
     * names the block service watches. Unknown names are dropped rather than
     * guessed at.
     */
    private fun resolvePackages(names: List<String>): List<String> {
        val byLabel = labelledApps()
            .entries
            .associate { (id, label) -> label.lowercase() to id }
        val packages = LinkedHashSet<String>()
        for (raw in names) {
            val key = raw.trim()
            if (key.isEmpty()) continue
            val lowered = key.lowercase()
            byLabel[lowered]?.let { packages.add(it) }
            if (lowered.contains('.')) packages.add(key)
        }
        return packages.toList()
    }

    private fun installApk(path: String): Boolean {
        val file = File(path)
        if (!file.exists()) return false
        return runCatching {
            val uri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                file,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        }.getOrDefault(false)
    }
}
