package com.johntsui.stroom

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class KeepAliveScheduleTest {
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
    fun explicitStartSchedulingRetriesOnceAndPreservesInitialFailureResult() {
        val retryQueue = mutableListOf<() -> Unit>()
        var scheduleAttempts = 0
        var watchdogActive = false
        var alarmScheduled = false
        val serviceEnabled = true
        val watchdogEnabled = true
        val schedule = {
            scheduleAttempts++
            watchdogActive = true
            alarmScheduled = scheduleAttempts == 2
            alarmScheduled
        }

        val scheduled = scheduleAlarmWithRetry(
            schedule = schedule,
            retrySchedule = schedule,
            isStillActive = { watchdogActive && serviceEnabled && watchdogEnabled },
            retryLater = { retryQueue += it },
        )

        assertFalse(scheduled)
        assertEquals(1, scheduleAttempts)
        assertEquals(1, retryQueue.size)
        assertTrue(watchdogActive)
        assertFalse(alarmScheduled)

        retryQueue.single().invoke()

        assertEquals(2, scheduleAttempts)
        assertTrue(watchdogActive && serviceEnabled && watchdogEnabled)
        assertTrue(alarmScheduled)
        assertFalse(scheduled)
        assertEquals(1, retryQueue.size)
    }

    @Test
    fun persistentExplicitStartSchedulingFailureStaysReportableAndDoesNotLoop() {
        val retryQueue = mutableListOf<() -> Unit>()
        var scheduleAttempts = 0
        var watchdogActive = false
        var alarmScheduled = false
        val schedule = {
            scheduleAttempts++
            watchdogActive = true
            alarmScheduled = false
            alarmScheduled
        }

        val scheduled = scheduleAlarmWithRetry(
            schedule = schedule,
            retrySchedule = schedule,
            isStillActive = { true },
            retryLater = { retryQueue += it },
        )

        assertFalse(scheduled)
        assertEquals(1, scheduleAttempts)
        assertEquals(1, retryQueue.size)
        assertTrue(watchdogActive)
        assertFalse(alarmScheduled)

        retryQueue.single().invoke()

        assertEquals(2, scheduleAttempts)
        assertEquals(1, retryQueue.size)
        assertTrue(watchdogActive)
        assertFalse(alarmScheduled)
    }

    @Test
    fun queuedExplicitStartRetryDoesNotRearmAfterKeepAliveIsDisabled() {
        for (disable in listOf("active", "service", "watchdog")) {
            val retryQueue = mutableListOf<() -> Unit>()
            var scheduleAttempts = 0
            var watchdogActive = false
            var serviceEnabled = true
            var watchdogEnabled = true

            scheduleAlarmWithRetry(
                schedule = { ++scheduleAttempts; watchdogActive = true; false },
                retrySchedule = { ++scheduleAttempts; true },
                isStillActive = { watchdogActive && serviceEnabled && watchdogEnabled },
                retryLater = { retryQueue += it },
            )
            when (disable) {
                "active" -> watchdogActive = false
                "service" -> serviceEnabled = false
                "watchdog" -> watchdogEnabled = false
            }

            retryQueue.single().invoke()

            assertEquals("$disable must suppress retry", 1, scheduleAttempts)
        }
    }

    @Test
    fun failedRearmRetriesOnceWithTheSelectedNormalOrBackoffInterval() {
        for (selectedInterval in listOf(
            KeepAliveReceiver.KEEP_ALIVE_INTERVAL_MS,
            KeepAliveReceiver.FAILURE_BACKOFF_INTERVAL_MS,
        )) {
            val retryQueue = mutableListOf<() -> Unit>()
            val scheduledIntervals = mutableListOf<Long>()
            var scheduleAttempts = 0
            val keepAliveActive = true
            val serviceEnabled = true
            val watchdogEnabled = true

            val scheduled = scheduleAlarmWithRetryAtInterval(
                intervalMs = selectedInterval,
                scheduleAtInterval = { interval ->
                    scheduledIntervals += interval
                    ++scheduleAttempts == 2
                },
                isStillActive = { keepAliveActive && serviceEnabled && watchdogEnabled },
                retryLater = { retryQueue += it },
            )

            assertFalse(scheduled)
            assertEquals(1, scheduleAttempts)
            assertEquals(1, retryQueue.size)

            retryQueue.single().invoke()

            assertEquals(2, scheduleAttempts)
            assertEquals(listOf(selectedInterval, selectedInterval), scheduledIntervals)
            assertEquals(1, retryQueue.size)
        }
    }

    @Test
    fun queuedRearmRetryDoesNotScheduleAfterKeepAliveIntentIsDisabled() {
        for (disable in listOf("active", "service", "watchdog")) {
            val retryQueue = mutableListOf<() -> Unit>()
            var scheduleAttempts = 0
            var keepAliveActive = true
            var serviceEnabled = true
            var watchdogEnabled = true

            scheduleAlarmWithRetryAtInterval(
                intervalMs = KeepAliveReceiver.KEEP_ALIVE_INTERVAL_MS,
                scheduleAtInterval = { ++scheduleAttempts; false },
                isStillActive = { keepAliveActive && serviceEnabled && watchdogEnabled },
                retryLater = { retryQueue += it },
            )
            when (disable) {
                "active" -> keepAliveActive = false
                "service" -> serviceEnabled = false
                "watchdog" -> watchdogEnabled = false
            }

            retryQueue.single().invoke()

            assertEquals("$disable must suppress retry", 1, scheduleAttempts)
        }
    }

    @Test
    fun failedReceiverSchedulingQueuesRetryWithCurrentInterval() {
        val retryQueue = mutableListOf<() -> Unit>()
        var scheduleAttempts = 0
        var watchdogActive = true
        var currentInterval = 30
        var scheduledInterval = 0

        val scheduled = scheduleAlarmWithRetry(
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

        scheduleAlarmWithRetry(
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
