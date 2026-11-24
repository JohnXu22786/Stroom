package com.johntsui.stroom

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class SafDocumentReplacementTest {
    @Test
    fun failedReplacementRestoresExistingDocumentBytes() {
        val documents =
            mutableMapOf(
                "backup.zip" to "old backup".toByteArray(),
                "backup.zip.tmp" to "new backup".toByteArray(),
            )

        val committed =
            SafDocumentReplacement.commit(
                originalName = "backup.zip",
                stagedName = "backup.zip.tmp",
                rollbackName = "backup.zip.rollback",
                renameDocument = { from, to ->
                    if (from == "backup.zip.tmp" && to == "backup.zip") {
                        false
                    } else {
                        documents.remove(from)?.let { documents[to] = it } != null
                    }
                },
                deleteDocument = { documents.remove(it) != null },
            )

        assertFalse(committed)
        assertEquals("old backup", String(documents.getValue("backup.zip")))
    }

    @Test
    fun failedRestorationKeepsOldBytesAtNamedRecoveryEntry() {
        val documents =
            mutableMapOf(
                "backup.zip" to "old backup".toByteArray(),
                "backup.zip.tmp" to "new backup".toByteArray(),
            )

        val failure =
            try {
                SafDocumentReplacement.commit(
                    originalName = "backup.zip",
                    stagedName = "backup.zip.tmp",
                    rollbackName = "backup.zip.rollback",
                    renameDocument = { from, to ->
                        if (from == "backup.zip.tmp" && to == "backup.zip") {
                            false
                        } else if (from == "backup.zip.rollback" && to == "backup.zip") {
                            throw IllegalArgumentException("provider rename failed")
                        } else {
                            documents.remove(from)?.let { documents[to] = it } != null
                        }
                    },
                    deleteDocument = { documents.remove(it) != null },
                )
                throw AssertionError("Expected failed restoration to report the recovery filename")
            } catch (e: IllegalStateException) {
                e
            }

        assertEquals("old backup", String(documents.getValue("backup.zip.rollback")))
        assertEquals(
            "Replacement failed; the previous backup remains in the SAF directory as " +
                "backup.zip.rollback because it could not be restored to backup.zip",
            failure.message,
        )
    }

    @Test
    fun unsupportedRenameLeavesExistingDocumentUntouched() {
        val documents =
            mutableMapOf(
                "backup.zip" to "old backup".toByteArray(),
                "backup.zip.tmp" to "new backup".toByteArray(),
            )

        val committed =
            SafDocumentReplacement.commit(
                originalName = "backup.zip",
                stagedName = "backup.zip.tmp",
                rollbackName = "backup.zip.rollback",
                renameDocument = { _, _ -> false },
                deleteDocument = { documents.remove(it) != null },
            )

        assertFalse(committed)
        assertEquals("old backup", String(documents.getValue("backup.zip")))
    }
}
