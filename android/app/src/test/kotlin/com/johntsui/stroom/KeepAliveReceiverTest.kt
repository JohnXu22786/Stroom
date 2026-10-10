package com.johntsui.stroom

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class KeepAliveReceiverTest {
    @Test
    fun failedSchedulingKeepsWatchdogEligibleForRecoveryAndReturnsFailure() {
        var watchdogActive = false
        var scheduleSawActiveIntent = false
        val serviceEnabled = true
        val watchdogEnabled = true

        val scheduleSucceeded = scheduleWithActiveIntent(
            persistActiveIntent = { watchdogActive = true },
            schedule = {
                scheduleSawActiveIntent = watchdogActive
                false
            },
        )

        assertFalse(scheduleSucceeded)
        assertTrue(scheduleSawActiveIntent)
        assertTrue(watchdogActive && serviceEnabled && watchdogEnabled)
    }
}
