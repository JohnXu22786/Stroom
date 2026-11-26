package com.johntsui.stroom

/** Ensures a rename only runs when its source document exists. */
object SafRenameSource {
    fun <T> withSource(
        source: T?,
        onMissingSource: () -> Unit,
        renameSource: (T) -> Unit,
    ) {
        if (source == null) {
            onMissingSource()
        } else {
            renameSource(source)
        }
    }
}
