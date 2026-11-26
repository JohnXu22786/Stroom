package com.johntsui.stroom

/** Holds the one SAF picker callback allowed while the system picker is open. */
internal class SafPickerPendingResult<T : Any> {
    private var pending: T? = null

    fun trySet(result: T): Boolean {
        if (pending != null) return false
        pending = result
        return true
    }

    fun take(): T? {
        val result = pending
        pending = null
        return result
    }

    fun clear(result: T): Boolean {
        if (pending !== result) return false
        pending = null
        return true
    }
}
