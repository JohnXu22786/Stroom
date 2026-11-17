package com.johntsui.stroom

/** Appends only the portion of a batch not already present at the file suffix. */
object LogContentAppend {
    fun append(existing: String, incoming: String): String {
        if (incoming.isEmpty()) return existing

        val prefixLengths = IntArray(incoming.length)
        for (index in 1 until incoming.length) {
            var matched = prefixLengths[index - 1]
            while (matched > 0 && incoming[index] != incoming[matched]) {
                matched = prefixLengths[matched - 1]
            }
            if (incoming[index] == incoming[matched]) matched++
            prefixLengths[index] = matched
        }

        var matched = 0
        val suffixStart = (existing.length - incoming.length).coerceAtLeast(0)
        for (index in suffixStart until existing.length) {
            while (matched > 0 && incoming[matched] != existing[index]) {
                matched = prefixLengths[matched - 1]
            }
            if (incoming[matched] == existing[index]) matched++
            if (matched == incoming.length && index < existing.lastIndex) {
                matched = prefixLengths[matched - 1]
            }
        }

        return existing + incoming.substring(matched)
    }
}
