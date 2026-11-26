package com.johntsui.stroom

import org.junit.Assert.assertEquals
import org.junit.Test

class SafFallbackRenameTest {
    @Test
    fun failedSourceDeletionReportsPartialRenameAndKeepsBothDocuments() {
        val documents =
            mutableMapOf(
                "backup.tmp" to "original backup".toByteArray(),
            )

        val outcome =
            SafFallbackRename.publishAndRemoveSource(
                publish = {
                    documents["backup.zip"] = documents.getValue("backup.tmp").copyOf()
                    true
                },
                deleteSource = {
                    false
                },
            )

        assertEquals(SafFallbackRename.Outcome.SOURCE_DELETE_FAILED, outcome)
        assertEquals("original backup", String(documents.getValue("backup.tmp")))
        assertEquals("original backup", String(documents.getValue("backup.zip")))
    }
}
