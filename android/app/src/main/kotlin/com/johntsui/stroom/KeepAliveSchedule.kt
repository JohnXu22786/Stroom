package com.johntsui.stroom

internal fun scheduleWithActiveIntent(
    persistActiveIntent: () -> Boolean,
    schedule: () -> Boolean,
): Boolean {
    if (!persistActiveIntent()) return false
    return schedule()
}
