package com.johntsui.stroom

import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.OutputStream
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SafStagedWriteTest {
    @Test
    fun failedStagedDocumentCreationDoesNotPublishOrDeleteExistingBackup() {
        val documents = mutableMapOf("backup.zip" to "old backup")
        var published = false

        val wrote =
            SafStagedWrite.writeAndPublish(
                createStagedDocument = { false },
                openOutputStream = { error("stream must not open") },
                writePayload = { error("payload must not be written") },
                publish = {
                    published = true
                    true
                },
                deleteStagedDocument = { documents.remove("backup.zip.tmp") },
            )

        assertFalse(wrote)
        assertFalse(published)
        assertEquals("old backup", documents["backup.zip"])
        assertFalse(documents.containsKey("backup.zip.tmp"))
    }

    @Test
    fun unavailableOutputStreamLeavesOldBackupAndNeverPublishes() {
        val documents = mutableMapOf("backup.zip" to "old backup", "backup.zip.tmp" to "")
        var published = false

        val wrote =
            SafStagedWrite.writeAndPublish(
                createStagedDocument = { true },
                openOutputStream = { null },
                writePayload = { error("payload must not be written") },
                publish = {
                    published = true
                    true
                },
                deleteStagedDocument = { documents.remove("backup.zip.tmp") },
            )

        assertFalse(wrote)
        assertFalse(published)
        assertEquals("old backup", documents["backup.zip"])
        assertFalse(documents.containsKey("backup.zip.tmp"))
    }

    @Test
    fun interruptedWriteCleansStagedFileAndDoesNotPublishPartialPayload() {
        val documents = mutableMapOf("backup.zip" to "old backup", "backup.zip.tmp" to "")
        val partialOutput = ByteArrayOutputStream()
        var published = false

        try {
            SafStagedWrite.writeAndPublish(
                createStagedDocument = { true },
                openOutputStream = { partialOutput },
                writePayload = {
                    it.write("partial".toByteArray())
                    throw IOException("interrupted")
                },
                publish = {
                    published = true
                    documents["backup.zip"] = partialOutput.toString()
                    true
                },
                deleteStagedDocument = { documents.remove("backup.zip.tmp") },
            )
        } catch (_: IOException) {
            // A failed payload write is reported to the caller after staged cleanup.
        }

        assertFalse(published)
        assertEquals("old backup", documents["backup.zip"])
        assertFalse(documents.containsKey("backup.zip.tmp"))
    }

    @Test
    fun publishesOnlyAfterOutputStreamClosesSuccessfully() {
        val documents = mutableMapOf("backup.zip" to "old backup", "backup.zip.tmp" to "")
        var streamClosed = false

        val wrote =
            SafStagedWrite.writeAndPublish(
                createStagedDocument = { true },
                openOutputStream = {
                    object : OutputStream() {
                        override fun write(value: Int) {
                            documents["backup.zip.tmp"] += value.toChar()
                        }

                        override fun close() {
                            streamClosed = true
                        }
                    }
                },
                writePayload = { it.write("complete".toByteArray()) },
                publish = {
                    assertTrue(streamClosed)
                    documents["backup.zip"] = documents.remove("backup.zip.tmp")!!
                    true
                },
                deleteStagedDocument = { documents.remove("backup.zip.tmp") },
            )

        assertTrue(wrote)
        assertEquals("complete", documents["backup.zip"])
        assertFalse(documents.containsKey("backup.zip.tmp"))
    }
}
