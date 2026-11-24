package com.johntsui.stroom

import java.io.OutputStream

/** Writes a SAF document under a temporary name and publishes it only after close succeeds. */
object SafStagedWrite {
    fun writeAndPublish(
        createStagedDocument: () -> Boolean,
        openOutputStream: () -> OutputStream?,
        writePayload: (OutputStream) -> Unit,
        publish: () -> Boolean,
        deleteStagedDocument: () -> Unit,
    ): Boolean {
        var published = false
        try {
            if (!createStagedDocument()) return false

            val streamOpened =
                SafOutputStream.writeIfAvailable(
                    outputStream = openOutputStream(),
                    onUnavailable = {},
                    write = writePayload,
                )
            if (!streamOpened) return false

            published = publish()
            return published
        } finally {
            if (!published) deleteStagedDocument()
        }
    }
}
