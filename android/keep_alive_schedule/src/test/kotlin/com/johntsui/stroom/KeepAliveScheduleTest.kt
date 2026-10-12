package com.johntsui.stroom

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class KeepAliveScheduleTest {
    @Test
    fun exactWatchdogAndRevocationBackupUseDistinctPendingIntentIdentity() {
        assertNotEquals(KEEP_ALIVE_ALARM_ACTION, KEEP_ALIVE_REVOCATION_BACKUP_ACTION)
        assertNotEquals(KEEP_ALIVE_ALARM_REQUEST_CODE, KEEP_ALIVE_REVOCATION_BACKUP_REQUEST_CODE)
    }

    @Test
    fun exactSchedulingAlsoArmsInexactRevocationBackup() {
        val exactTriggerAt = 300_000L
        assertEquals(60_000L, revocationBackupTriggerAt(exactTriggerAt) - exactTriggerAt)
        val operations = mutableListOf<String>()

        val scheduled = scheduleWithExactRevocationFallback(
            canScheduleExact = true,
            scheduleExact = { operations += "exact"; true },
            scheduleRevocationFallback = { operations += "backup"; true },
            cancelRevocationFallback = { operations += "cancel-backup" },
            scheduleInexactPrimary = { operations += "inexact-primary"; true },
        )

        assertTrue(scheduled)
        assertEquals(listOf("exact", "backup"), operations)
    }

    @Test
    fun unavailableOrDeniedExactSchedulingKeepsOnlyTheInexactPrimaryAlarm() {
        val operations = mutableListOf<String>()

        val scheduled = scheduleWithExactRevocationFallback(
            canScheduleExact = false,
            scheduleExact = { operations += "exact"; true },
            scheduleRevocationFallback = { operations += "backup"; true },
            cancelRevocationFallback = { operations += "cancel-backup" },
            scheduleInexactPrimary = { operations += "inexact-primary"; true },
        )

        assertTrue(scheduled)
        assertEquals(listOf("cancel-backup", "inexact-primary"), operations)

        operations.clear()
        val exactAttemptFailed = scheduleWithExactRevocationFallback(
            canScheduleExact = true,
            scheduleExact = { operations += "exact"; false },
            scheduleRevocationFallback = { operations += "backup"; true },
            cancelRevocationFallback = { operations += "cancel-backup" },
            scheduleInexactPrimary = { operations += "inexact-primary"; true },
        )

        assertTrue(exactAttemptFailed)
        assertEquals(listOf("exact", "cancel-backup", "inexact-primary"), operations)
    }

    @Test
    fun failedRevocationBackupFallsBackToOneInexactPrimaryAlarm() {
        val operations = mutableListOf<String>()

        val scheduled = scheduleWithExactRevocationFallback(
            canScheduleExact = true,
            scheduleExact = { operations += "exact"; true },
            scheduleRevocationFallback = { operations += "backup"; false },
            cancelRevocationFallback = { operations += "cancel-backup" },
            scheduleInexactPrimary = { operations += "inexact-primary"; true },
        )

        assertTrue(scheduled)
        assertEquals(listOf("exact", "backup", "cancel-backup", "inexact-primary"), operations)
    }

    @Test
    fun pairedAlarmDeliveryIsClaimedOnceInEitherDeliveryOrder() {
        for (deliveryOrder in listOf(listOf("exact", "backup"), listOf("backup", "exact"))) {
            var currentGeneration = 17L
            val handledDeliveries = mutableListOf<String>()

            for (delivery in deliveryOrder) {
                val result = claimAlarmDeliveryGeneration(
                    scheduledGeneration = 17L,
                    currentGeneration = currentGeneration,
                    keepAliveActive = true,
                    persistGeneration = { generation ->
                        currentGeneration = generation
                        true
                    },
                )
                if (result == AlarmGenerationClaimResult.CLAIMED) {
                    handledDeliveries += delivery
                }
            }

            assertEquals(listOf(deliveryOrder.first()), handledDeliveries)
            assertEquals(18L, currentGeneration)
        }
    }

    @Test
    fun failedClaimCommitRestoresGenerationSoPairedAlarmCanRecover() {
        var currentGeneration = 17L
        var failedClaimCommit = false
        val persistGeneration: (Long) -> Boolean = { generation ->
            // SharedPreferences updates its in-memory value even when commit() fails.
            currentGeneration = generation
            if (generation == 18L && !failedClaimCommit) {
                failedClaimCommit = true
                false
            } else {
                true
            }
        }

        val firstDelivery = claimAlarmDeliveryGeneration(
            scheduledGeneration = 17L,
            currentGeneration = currentGeneration,
            keepAliveActive = true,
            persistGeneration = persistGeneration,
        )

        assertEquals(AlarmGenerationClaimResult.PERSISTENCE_FAILED, firstDelivery)
        assertEquals(17L, currentGeneration)

        val pairedBackup = claimAlarmDeliveryGeneration(
            scheduledGeneration = 17L,
            currentGeneration = currentGeneration,
            keepAliveActive = true,
            persistGeneration = persistGeneration,
        )

        assertEquals(AlarmGenerationClaimResult.CLAIMED, pairedBackup)
        assertEquals(18L, currentGeneration)
    }

    @Test
    fun failedGenerationCommitRetryKeepsPreviousAlarmGenerationUsable() {
        var currentGeneration = 41L
        var scheduleAttempts = 0
        val retryQueue = mutableListOf<() -> Unit>()
        val schedule = {
            scheduleAttempts++
            persistNextAlarmGeneration(currentGeneration) { generation ->
                // SharedPreferences updates memory before commit() can fail.
                currentGeneration = generation
                false
            } != null
        }

        val scheduled = scheduleAlarmWithRetry(
            schedule = schedule,
            retrySchedule = schedule,
            isStillActive = { true },
            retryLater = { retryQueue += it },
        )

        assertFalse(scheduled)
        assertEquals(1, scheduleAttempts)
        assertEquals(41L, currentGeneration)

        retryQueue.single().invoke()

        assertEquals(2, scheduleAttempts)
        assertEquals(41L, currentGeneration)

        val priorAlarmClaim = claimAlarmDeliveryGeneration(
            scheduledGeneration = 41L,
            currentGeneration = currentGeneration,
            keepAliveActive = true,
            persistGeneration = { generation ->
                currentGeneration = generation
                true
            },
        )

        assertEquals(AlarmGenerationClaimResult.CLAIMED, priorAlarmClaim)
        assertEquals(42L, currentGeneration)
    }

    @Test
    fun explicitStopRejectsQueuedAlarmGeneration() {
        var persistAttempted = false

        assertEquals(
            AlarmGenerationClaimResult.STALE,
            claimAlarmDeliveryGeneration(
                scheduledGeneration = 17L,
                currentGeneration = 17L,
                keepAliveActive = false,
                persistGeneration = { persistAttempted = true; true },
            ),
        )
        assertFalse(persistAttempted)
    }

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
            KeepAliveScheduleIntervals.KEEP_ALIVE_INTERVAL_MS,
            KeepAliveScheduleIntervals.FAILURE_BACKOFF_INTERVAL_MS,
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
                intervalMs = KeepAliveScheduleIntervals.KEEP_ALIVE_INTERVAL_MS,
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
