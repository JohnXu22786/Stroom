package com.johntsui.stroom

import java.io.OutputStream

/** Writes to an opened SAF stream, reporting whether the provider supplied one. */
object SafOutputStream {
    fun writeIfAvailable(
        outputStream: OutputStream?,
        onUnavailable: () -> Unit,
        write: (OutputStream) -> Unit,
    ): Boolean {
        if (outputStream == null) {
            onUnavailable()
            return false
        }

        outputStream.use(write)
        return true
    }
}
