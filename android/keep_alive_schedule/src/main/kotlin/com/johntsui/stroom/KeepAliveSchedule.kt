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

internal fun scheduleWithExactRevocationFallback(
    canScheduleExact: Boolean,
    scheduleExact: () -> Boolean,
    scheduleRevocationFallback: () -> Boolean,
    cancelRevocationFallback: () -> Unit,
    scheduleInexactPrimary: () -> Boolean,
): Boolean {
    if (canScheduleExact && scheduleExact() && scheduleRevocationFallback()) return true
    cancelRevocationFallback()
    return scheduleInexactPrimary()
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

internal fun scheduleWithActiveIntent(
    persistActiveIntent: () -> Boolean,
    schedule: () -> Boolean,
): Boolean {
    if (!persistActiveIntent()) return false
    return schedule()
}

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
