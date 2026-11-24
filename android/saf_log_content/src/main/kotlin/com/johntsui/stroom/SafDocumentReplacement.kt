package com.johntsui.stroom

/** Promotes a fully written SAF document while retaining the previous one on failure. */
object SafDocumentReplacement {
    fun commit(
        originalName: String,
        stagedName: String,
        rollbackName: String,
        renameDocument: (fromName: String, toName: String) -> Boolean,
        deleteDocument: (name: String) -> Boolean,
    ): Boolean {
        if (!renameDocument(originalName, rollbackName)) return false

        val promoted =
            try {
                renameDocument(stagedName, originalName)
            } catch (failure: Exception) {
                restorePreviousDocument(originalName, rollbackName, renameDocument)
                throw failure
            }

        if (!promoted) {
            restorePreviousDocument(originalName, rollbackName, renameDocument)
            return false
        }

        // The new file is committed. A cleanup failure only leaves a redundant old copy.
        runCatching { deleteDocument(rollbackName) }
        return true
    }

    private fun restorePreviousDocument(
        originalName: String,
        rollbackName: String,
        renameDocument: (fromName: String, toName: String) -> Boolean,
    ) {
        val restored =
            try {
                renameDocument(rollbackName, originalName)
            } catch (failure: Exception) {
                throw IllegalStateException(
                    recoveryFailureMessage(originalName, rollbackName),
                    failure,
                )
            }
        if (!restored) {
            throw IllegalStateException(recoveryFailureMessage(originalName, rollbackName))
        }
    }

    private fun recoveryFailureMessage(
        originalName: String,
        rollbackName: String,
    ) = "Replacement failed; the previous backup remains in the SAF directory as " +
        "$rollbackName because it could not be restored to $originalName"
}
