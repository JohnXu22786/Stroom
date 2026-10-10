package com.johntsui.stroom

import org.junit.Assert.assertEquals
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
            persistActiveIntent = {
                watchdogActive = true
                true
            },
            schedule = {
                scheduleSawActiveIntent = watchdogActive
                false
            },
        )

        assertFalse(scheduleSucceeded)
        assertTrue(scheduleSawActiveIntent)
        assertTrue(watchdogActive && serviceEnabled && watchdogEnabled)
    }

    @Test
    fun failedActiveIntentPersistencePreventsSchedulingAndReturnsFailure() {
        var scheduleAttempted = false

        val scheduleSucceeded = scheduleWithActiveIntent(
            persistActiveIntent = { false },
            schedule = {
                scheduleAttempted = true
                true
            },
        )

        assertFalse(scheduleSucceeded)
        assertFalse(scheduleAttempted)
    }

    @Test
    fun failedReceiverSchedulingQueuesRetryWithCurrentInterval() {
        val retryQueue = mutableListOf<() -> Unit>()
        var scheduleAttempts = 0
        var watchdogActive = true
        var currentInterval = 30
        var scheduledInterval = 0

        val scheduled = scheduleReceiverAlarmWithRetry(
            schedule = {
                ++scheduleAttempts
                scheduledInterval = currentInterval
                false
            },
            retrySchedule = {
                ++scheduleAttempts
                scheduledInterval = currentInterval
                true
            },
            isStillActive = { watchdogActive },
            retryLater = { retryQueue += it },
        )

        assertFalse(scheduled)
        assertEquals(1, scheduleAttempts)
        assertEquals(1, retryQueue.size)

        currentInterval = 5
        retryQueue.single().invoke()

        assertEquals(2, scheduleAttempts)
        assertEquals(5, scheduledInterval)
    }

    @Test
    fun queuedReceiverRetryDoesNotRearmAfterExplicitCancellation() {
        val retryQueue = mutableListOf<() -> Unit>()
        var scheduleAttempts = 0
        var watchdogActive = true

        scheduleReceiverAlarmWithRetry(
            schedule = {
                ++scheduleAttempts
                false
            },
            retrySchedule = { ++scheduleAttempts > 1 },
            isStillActive = { watchdogActive },
            retryLater = { retryQueue += it },
        )
        watchdogActive = false

        retryQueue.single().invoke()

        assertEquals(1, scheduleAttempts)
    }
}
