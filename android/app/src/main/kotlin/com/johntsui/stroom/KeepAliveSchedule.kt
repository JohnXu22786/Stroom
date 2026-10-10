package com.johntsui.stroom

internal fun scheduleWithActiveIntent(
    persistActiveIntent: () -> Unit,
    schedule: () -> Boolean,
): Boolean {
    persistActiveIntent()
    return schedule()
}
