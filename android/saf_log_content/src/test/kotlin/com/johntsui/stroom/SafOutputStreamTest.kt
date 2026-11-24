package com.johntsui.stroom

import java.io.ByteArrayOutputStream
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SafOutputStreamTest {
    @Test
    fun missingStreamRunsCleanupAndDoesNotReportWriteSuccess() {
        var cleanupCalled = false
        var writeCalled = false

        val wrote =
            SafOutputStream.writeIfAvailable(
                outputStream = null,
                onUnavailable = { cleanupCalled = true },
                write = { writeCalled = true },
            )

        assertFalse(wrote)
        assertTrue(cleanupCalled)
        assertFalse(writeCalled)
    }

    @Test
    fun availableStreamWritesBytes() {
        val output = ByteArrayOutputStream()

        val wrote =
            SafOutputStream.writeIfAvailable(
                outputStream = output,
                onUnavailable = { throw AssertionError("unexpected missing stream") },
                write = { it.write(byteArrayOf(1, 2, 3)) },
            )

        assertTrue(wrote)
        assertTrue(output.toByteArray().contentEquals(byteArrayOf(1, 2, 3)))
    }
}
