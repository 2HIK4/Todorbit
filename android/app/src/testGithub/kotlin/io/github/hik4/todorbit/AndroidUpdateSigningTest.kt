package io.github.hik4.todorbit

import org.junit.Assert.*
import org.junit.Test

class AndroidUpdateSigningTest {
    private val production = setOf(AndroidUpdateSigning.production)
    @Test fun matchingProduction() {
        assertNull(AndroidUpdateSigning.failure(production, production, false))
    }
    @Test fun developmentMigration() {
        assertTrue(AndroidUpdateSigning.failure(production, setOf("debug"), true)!!.contains("development certificate"))
    }
    @Test fun wrongPublisher() {
        assertTrue(AndroidUpdateSigning.failure(setOf("substituted"), production, false)!!.contains("Unexpected APK publisher"))
        assertNotNull(AndroidUpdateSigning.failure(emptySet(), emptySet(), false))
    }
    @Test fun unexpectedInstalledPublisher() {
        assertTrue(AndroidUpdateSigning.failure(production, setOf("other"), false)!!.contains("installed publisher differs"))
    }
    @Test fun developmentFixturesRemainRestrictedToDebugBuilds() {
        assertNull(AndroidUpdateSigning.failure(setOf("debug"), setOf("debug"), true, true))
        assertNotNull(AndroidUpdateSigning.failure(setOf("debug"), setOf("debug"), true))
        assertNotNull(AndroidUpdateSigning.failure(setOf("other"), setOf("debug"), true, true))
    }
}
