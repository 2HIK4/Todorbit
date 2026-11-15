package io.github.hik4.todorbit

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.*
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime

class SurfaceRefreshPolicyTest {
    @Test fun refreshReceiverIsPrivate() {
        val factory = DocumentBuilderFactory.newInstance().apply { isNamespaceAware = true }
        val document = factory.newDocumentBuilder().parse(File("src/main/AndroidManifest.xml"))
        val receivers = document.getElementsByTagName("receiver")
        val android = "http://schemas.android.com/apk/res/android"
        val receiver = (0 until receivers.length).map { receivers.item(it) as org.w3c.dom.Element }
            .single { it.getAttributeNS(android, "name") == ".SurfaceRefreshReceiver" }
        assertEquals("External apps must not invoke refresh/reminder jobs", "false",
            receiver.getAttributeNS(android, "exported"))
    }

    @Test fun onlyKnownSystemAndPrivateAlarmActionsAreAccepted() {
        assertFalse(SurfaceRefreshPolicy.accepts(null))
        assertFalse(SurfaceRefreshPolicy.accepts("attacker.refresh"))
        assertFalse(SurfaceRefreshPolicy.accepts("android.intent.action.DATE_CHANGED"))
        for (action in listOf("midnight", "BOOT_COMPLETED", "MY_PACKAGE_REPLACED", "TIME_SET", "TIMEZONE_CHANGED", "LOCALE_CHANGED")) {
            assertTrue(SurfaceRefreshPolicy.accepts(if (action == "midnight") action else "android.intent.action.$action"))
        }
        assertTrue(SurfaceRefreshPolicy.accepts("android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED"))
    }

    @Test fun nextRefreshUsesLocalCivilMidnightAcrossDstAndZoneChanges() {
        for ((date, hours) in listOf("2026-03-08" to 23L, "2026-11-01" to 25L)) {
            val now = LocalDate.parse(date).atStartOfDay(ZoneId.of("America/New_York"))
            assertEquals(hours * 3_600_000, SurfaceRefreshPolicy.nextMidnight(now) - now.toInstant().toEpochMilli())
        }
        val instant = ZonedDateTime.parse("2026-11-15T22:00:00Z")
        val amman = instant.withZoneSameInstant(ZoneId.of("Asia/Amman"))
        assertEquals(ZonedDateTime.parse("2026-11-17T00:00:00+03:00").toInstant().toEpochMilli(),
            SurfaceRefreshPolicy.nextMidnight(amman))
        assertNotEquals(SurfaceRefreshPolicy.nextMidnight(instant), SurfaceRefreshPolicy.nextMidnight(amman))
    }

    @Test fun followTodayMovesButExplicitPerInstanceBrowsingSurvivesMidnight() {
        val first = LocalDate.parse("2026-11-01")
        val last = LocalDate.parse("2026-11-30")
        val before = LocalDate.parse("2026-11-15")
        val after = before.plusDays(1)
        assertEquals(before, SurfaceRefreshPolicy.selectedDay(null, before, first, last))
        assertEquals(after, SurfaceRefreshPolicy.selectedDay(null, after, first, last))
        assertEquals(first, SurfaceRefreshPolicy.selectedDay(first.toString(), after, first, last))
        assertEquals(after, SurfaceRefreshPolicy.selectedDay("invalid", after, first, last))
        assertEquals(after, SurfaceRefreshPolicy.selectedDay("2027-01-01", after, first, last))
        // No shared selection state: another instance in Today mode still advances.
        assertEquals(after, SurfaceRefreshPolicy.selectedDay(null, after, first, last))
    }
}
