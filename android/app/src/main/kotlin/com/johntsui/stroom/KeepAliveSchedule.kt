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
