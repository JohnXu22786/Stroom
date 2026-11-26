package com.johntsui.stroom

import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class SafPickerPendingResultTest {
    @Test
    fun secondPickerIsRejectedWithoutReplacingFirstResult() {
        val pending = SafPickerPendingResult<Any>()
        val firstResult = Any()
        val secondResult = Any()

        assertTrue(pending.trySet(firstResult))
        assertFalse(pending.trySet(secondResult))

        assertSame(firstResult, pending.take())
        assertNull(pending.take())
    }
}
