package com.johntsui.stroom

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
