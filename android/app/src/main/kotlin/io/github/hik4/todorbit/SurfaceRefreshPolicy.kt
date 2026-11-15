package io.github.hik4.todorbit

import java.time.LocalDate
import java.time.ZonedDateTime

/** Calendar policy without Android dependencies, for deterministic lifecycle checks. */
internal object SurfaceRefreshPolicy {
    // Preserve the identity of alarms issued by earlier APKs.
    const val MIDNIGHT = "midnight"
    fun accepts(action: String?): Boolean = action == MIDNIGHT || action in setOf(
        "android.intent.action.BOOT_COMPLETED",
        "android.intent.action.MY_PACKAGE_REPLACED",
        "android.intent.action.TIME_SET",
        "android.intent.action.TIMEZONE_CHANGED",
        "android.intent.action.LOCALE_CHANGED",
        "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED",
    )

    fun nextMidnight(now: ZonedDateTime): Long =
        now.toLocalDate().plusDays(1).atStartOfDay(now.zone).toInstant().toEpochMilli()

    fun selectedDay(stored: String?, today: LocalDate, first: LocalDate, last: LocalDate): LocalDate {
        val selected = try { LocalDate.parse(stored) } catch (_: Exception) { return today }
        return if (selected < first || selected > last) today else selected
    }
}
