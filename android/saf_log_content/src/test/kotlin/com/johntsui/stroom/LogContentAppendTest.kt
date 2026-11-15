package com.johntsui.stroom

import org.junit.Assert.assertEquals
import org.junit.Test

class LogContentAppendTest {
    @Test
    fun retryContainingPreviouslyAppendedBatchAddsOnlyNewSuffix() {
        val existing = "older entry\npending batch\n"
        val retry = "pending batch\nnew batch\n"

        assertEquals(
            "older entry\npending batch\nnew batch\n",
            LogContentAppend.append(existing, retry),
        )
    }

    @Test
    fun exactRetryDoesNotDuplicateContent() {
        val existing = "older entry\nnew batch\n"

        assertEquals(existing, LogContentAppend.append(existing, "new batch\n"))
    }

    @Test
    fun newBatchWithoutOverlapIsAppended() {
        assertEquals(
            "older entry\nnew batch\n",
            LogContentAppend.append("older entry\n", "new batch\n"),
        )
    }
}
