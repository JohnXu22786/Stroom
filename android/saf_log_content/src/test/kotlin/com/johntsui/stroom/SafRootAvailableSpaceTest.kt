package com.johntsui.stroom

import org.junit.Assert.assertEquals
import org.junit.Test

class SafRootAvailableSpaceTest {
    @Test
    fun selectsAvailableBytesForSelectedProviderRoot() {
        val availableBytes =
            SafRootAvailableSpace.select(
                providerRootDocumentId = "sdcard:",
                roots =
                    listOf(
                        SafRootAvailableSpace.Root("primary:", 120L),
                        SafRootAvailableSpace.Root("sdcard:", 450L),
                    ),
            )

        assertEquals(450L, availableBytes)
    }

    @Test
    fun returnsUnknownWhenProviderDoesNotIdentifySelectedRoot() {
        val unavailable =
            SafRootAvailableSpace.select(
                providerRootDocumentId = "sdcard:",
                roots = listOf(SafRootAvailableSpace.Root("sdcard:", -1L)),
            )
        // A tree document ID can look like it belongs to this root, but that string
        // convention is not provider evidence that the selected document is there.
        val noPathEvidence =
            SafRootAvailableSpace.select(
                providerRootDocumentId = null,
                roots =
                    listOf(
                        SafRootAvailableSpace.Root("primary:", 120L),
                        SafRootAvailableSpace.Root("external:", 450L),
                    ),
            )
        val mismatchedProviderRoot =
            SafRootAvailableSpace.select(
                providerRootDocumentId = "external:",
                roots = listOf(SafRootAvailableSpace.Root("primary:", 120L)),
            )

        assertEquals(-1L, unavailable)
        assertEquals(-1L, noPathEvidence)
        assertEquals(-1L, mismatchedProviderRoot)
    }
}
