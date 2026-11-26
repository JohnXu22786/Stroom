package com.johntsui.stroom

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class SafRenameSourceTest {
    @Test
    fun missingSourceReportsRenameErrorWithoutCreatingDestination() {
        val documents = mutableMapOf<String, String>()
        var errorCode: String? = null

        SafRenameSource.withSource(
            source = documents["missing.tmp"],
            onMissingSource = { errorCode = "RENAME_FAILED" },
            renameSource = { source -> documents["renamed.zip"] = source },
        )

        assertEquals("RENAME_FAILED", errorCode)
        assertFalse(documents.containsKey("renamed.zip"))
    }
}
