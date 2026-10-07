package com.fourcus.fourcus

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

/**
 * Exposes Android UsageStatsManager to Dart over the
 * `dev.fourcus/usage` MethodChannel.
 *
 * Methods:
 * - hasPermission(): Boolean — is usage access granted?
 * - requestPermission(): void — opens the Usage Access settings screen.
 * - getUsageStats({dateKey: "yyyy-MM-dd"}): Map with
 *   {totalMinutes: Int, unlocks: Int, apps: [{name, minutes}]}.
 *
 * NOTE: unlock count is not exposed by UsageStatsManager. An approximation
 * via UsageEvents (event type SCREEN_INTERACTIVE / USER_INTERACTION with
 * className patterns) is possible but needs an extra event query; returning
 * 0 for now. See commented hint in getUsageStats().
 */
class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "dev.fourcus/usage"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(hasUsagePermission())
                "requestPermission" -> {
                    openUsageAccessSettings()
                    result.success(true)
                }
                "getUsageStats" -> {
                    val dateKey = call.argument<String>("dateKey")
                    try {
                        result.success(getUsageStats(dateKey))
                    } catch (e: Exception) {
                        result.error("USAGE_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasUsagePermission(): Boolean {
        val appOps =
            getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun openUsageAccessSettings() {
        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
    }

    private fun getUsageStats(dateKey: String?): Map<String, Any> {
        val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply {
            timeZone = TimeZone.getDefault()
        }
        val cal = Calendar.getInstance()
        if (dateKey != null) {
            cal.time = sdf.parse(dateKey) ?: cal.time
        }
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val start = cal.timeInMillis
        cal.add(Calendar.DAY_OF_YEAR, 1)
        val end = cal.timeInMillis

        val usageStatsManager =
            getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val stats = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            start,
            end
        ) ?: emptyList()

        var totalMs = 0L
        val apps = stats
            .filter { it.totalTimeInForeground > 0 }
            .sortedByDescending { it.totalTimeInForeground }
            .take(10)
            .map { stat ->
                totalMs += stat.totalTimeInForeground
                mapOf(
                    "name" to stat.packageName,
                    "minutes" to (stat.totalTimeInForeground / 60000).toInt()
                )
            }

        // Unlock count: UsageStatsManager does not expose it. To approximate,
        // query UsageEvents for the same window and count SCREEN_INTERACTIVE
        // events (or KEYGUARD_HIDDEN transitions). Left as 0 intentionally.
        val unlocks = 0

        return mapOf(
            "totalMinutes" to (totalMs / 60000).toInt(),
            "unlocks" to unlocks,
            "apps" to apps
        )
    }
}
