package com.johntsui.stroom

internal object KeepAliveScheduleIntervals {
    const val KEEP_ALIVE_INTERVAL_MS = 5 * 60 * 1000L
    const val FAILURE_BACKOFF_INTERVAL_MS = 30 * 60 * 1000L
}

internal const val KEEP_ALIVE_ALARM_ACTION = "com.johntsui.stroom.KEEP_ALIVE"
internal const val KEEP_ALIVE_REVOCATION_BACKUP_ACTION = "com.johntsui.stroom.KEEP_ALIVE_REVOCATION_BACKUP"
internal const val KEEP_ALIVE_ALARM_REQUEST_CODE = 2001
internal const val KEEP_ALIVE_REVOCATION_BACKUP_REQUEST_CODE = 2002
internal const val KEEP_ALIVE_REVOCATION_BACKUP_GRACE_MS = 60_000L

internal fun revocationBackupTriggerAt(exactTriggerAt: Long): Long =
    exactTriggerAt + KEEP_ALIVE_REVOCATION_BACKUP_GRACE_MS

internal fun scheduleCompatibleRevocationBackup(
    supportsAllowWhileIdle: Boolean,
    scheduleAllowWhileIdle: () -> Boolean,
    scheduleLegacy: () -> Boolean,
): Boolean = if (supportsAllowWhileIdle) {
    scheduleAllowWhileIdle()
} else {
    scheduleLegacy()
}

internal fun scheduleWithExactRevocationFallback(
    canScheduleExact: Boolean,
    scheduleExact: () -> Boolean,
    scheduleRevocationFallback: () -> Boolean,
    scheduleInexactPrimary: () -> Boolean,
): Boolean {
    val exactScheduled = canScheduleExact && scheduleExact()
    if (exactScheduled) {
        if (scheduleRevocationFallback()) return true

        // The exact primary is already queued with its PendingIntent. Retrying
        // it as inexact would replace the foreground-service-eligible alarm.
        // Retry only the missing backup; a failed retry remains eligible for
        // the caller's bounded scheduling retry.
        return scheduleRevocationFallback()
    }

    if (scheduleInexactPrimary()) {
        // Keep a same-generation recovery delivery in case this one-shot is
        // consumed and the process stops before the receiver can rearm it. The
        // caller also needs the backup result to retry if only the primary was
        // successfully scheduled.
        return scheduleRevocationFallback()
    }

    // Keep any already queued backup alive if the replacement primary failed.
    // When there was no backup, make one last bounded attempt to leave a future
    // receiver delivery that can recover the watchdog.
    val fallbackScheduled = scheduleRevocationFallback()
    return fallbackScheduled
}

internal fun claimAlarmDeliveryGeneration(
    scheduledGeneration: Long,
    currentGeneration: Long,
    keepAliveActive: Boolean,
): Long? = if (keepAliveActive && scheduledGeneration == currentGeneration) {
    currentGeneration + 1
} else {
    null
}

internal enum class AlarmGenerationClaimResult {
    CLAIMED,
    STALE,
    PERSISTENCE_FAILED,
}

internal fun claimAlarmDeliveryGeneration(
    scheduledGeneration: Long,
    currentGeneration: Long,
    keepAliveActive: Boolean,
    persistGeneration: (Long) -> Boolean,
): AlarmGenerationClaimResult {
    val invalidatedGeneration = claimAlarmDeliveryGeneration(
        scheduledGeneration = scheduledGeneration,
        currentGeneration = currentGeneration,
        keepAliveActive = keepAliveActive,
    ) ?: return AlarmGenerationClaimResult.STALE

    return if (persistGeneration(invalidatedGeneration)) {
        AlarmGenerationClaimResult.CLAIMED
    } else {
        // SharedPreferences updates its in-memory map before commit() reports a
        // disk-write failure. Restore the token so the paired alarm can retry.
        persistGeneration(currentGeneration)
        AlarmGenerationClaimResult.PERSISTENCE_FAILED
    }
}

/**
 * Tracks claims for this process so a paired alarm left one generation behind
 * by process death can recover without admitting a same-process duplicate.
 */
internal class AlarmDeliveryGenerationClaims {
    private var lastClaimedGeneration: Long? = null

    fun claim(
        scheduledGeneration: Long,
        currentGeneration: Long,
        keepAliveActive: Boolean,
        persistGeneration: (Long) -> Boolean,
    ): AlarmGenerationClaimResult {
        if (!keepAliveActive) return AlarmGenerationClaimResult.STALE

        if (scheduledGeneration == currentGeneration) {
            val result = claimAlarmDeliveryGeneration(
                scheduledGeneration = scheduledGeneration,
                currentGeneration = currentGeneration,
                keepAliveActive = keepAliveActive,
                persistGeneration = persistGeneration,
            )
            if (result == AlarmGenerationClaimResult.CLAIMED) {
                lastClaimedGeneration = scheduledGeneration
            }
            return result
        }

        val isInterruptedClaimRecovery = scheduledGeneration == currentGeneration - 1L &&
            scheduledGeneration != lastClaimedGeneration
        if (!isInterruptedClaimRecovery) return AlarmGenerationClaimResult.STALE

        // Reuse currentGeneration: the receiver updates the pending alarm token
        // while rearming, and a paired delivery can recover after process death.
        lastClaimedGeneration = scheduledGeneration
        return AlarmGenerationClaimResult.CLAIMED
    }
}

internal fun persistNextAlarmGeneration(
    currentGeneration: Long,
    persistGeneration: (Long) -> Boolean,
): Long? {
    val nextGeneration = currentGeneration + 1L
    return if (persistGeneration(nextGeneration)) {
        nextGeneration
    } else {
        // SharedPreferences changes its in-memory map even when commit() fails.
        persistGeneration(currentGeneration)
        null
    }
}

internal fun scheduleWithActiveIntent(
    persistActiveIntent: () -> Boolean,
    schedule: () -> Boolean,
): Boolean {
    if (!persistActiveIntent()) return false
    return schedule()
}

internal fun scheduleFailedStopRecovery(
    watchdogEnabled: Boolean,
    persistEnabledIntent: () -> Boolean,
    scheduleWatchdog: () -> Boolean,
): Boolean = scheduleWithActiveIntent(
    persistActiveIntent = persistEnabledIntent,
    schedule = { if (watchdogEnabled) scheduleWatchdog() else true },
)

internal fun scheduleAlarmWithRetry(
    schedule: () -> Boolean,
    retrySchedule: () -> Boolean,
    isStillActive: () -> Boolean,
    retryLater: (() -> Unit) -> Unit,
): Boolean {
    if (schedule()) return true
    retryLater {
        if (isStillActive()) retrySchedule()
    }
    return false
}

internal fun scheduleAlarmWithRetryAtInterval(
    intervalMs: Long,
    scheduleAtInterval: (Long) -> Boolean,
    isStillActive: () -> Boolean,
    retryLater: (() -> Unit) -> Unit,
): Boolean = scheduleAlarmWithRetry(
    schedule = { scheduleAtInterval(intervalMs) },
    retrySchedule = { scheduleAtInterval(intervalMs) },
    isStillActive = isStillActive,
    retryLater = retryLater,
)
