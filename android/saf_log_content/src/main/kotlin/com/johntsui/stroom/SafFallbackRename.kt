package com.johntsui.stroom

/** Reports whether a SAF fallback rename published the new file and removed its source. */
object SafFallbackRename {
    enum class Outcome {
        PUBLISH_FAILED,
        SOURCE_DELETE_FAILED,
        COMPLETE,
    }

    fun publishAndRemoveSource(
        publish: () -> Boolean,
        deleteSource: () -> Boolean,
    ): Outcome {
        if (!publish()) return Outcome.PUBLISH_FAILED

        val sourceRemoved = try {
            deleteSource()
        } catch (_: Exception) {
            false
        }
        return if (sourceRemoved) Outcome.COMPLETE else Outcome.SOURCE_DELETE_FAILED
    }
}
