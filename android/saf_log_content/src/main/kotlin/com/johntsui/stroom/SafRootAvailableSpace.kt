package com.johntsui.stroom

/** Selects capacity only when the provider identifies the selected document's root. */
internal object SafRootAvailableSpace {
    data class Root(
        val documentId: String,
        val availableBytes: Long,
    )

    fun select(providerRootDocumentId: String?, roots: List<Root>): Long {
        val selected = roots.singleOrNull { it.documentId == providerRootDocumentId }
        return selected?.availableBytes?.takeIf { it >= 0L } ?: -1L
    }
}
