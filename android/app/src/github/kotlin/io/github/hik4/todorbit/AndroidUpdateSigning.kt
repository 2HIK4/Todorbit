package io.github.hik4.todorbit

/** Decisions are separate from the cryptographic APK verification. */
internal object AndroidUpdateSigning {
    const val production = "00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99"

    fun failure(candidate: Set<String>, installed: Set<String>, development: Boolean,
                allowDevelopment: Boolean = false): String? {
        if (candidate.isEmpty() || (candidate != setOf(production) &&
                !(allowDevelopment && candidate == installed))) {
            return "Unexpected APK publisher. Download only the official Todorbit release; keep your installed app and data."
        }
        if (candidate == installed) return null
        return if (development)
            "This installation uses a development certificate and cannot update to the production beta. Export and verify a backup first; follow the signing migration guide before replacing the app. Do not uninstall without a verified backup."
        else "The installed publisher differs from the official update. Keep your data and contact the publisher; do not uninstall to fix this."
    }
}
