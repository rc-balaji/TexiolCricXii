package com.texiol.crixx.groundar

import org.junit.Assert.*
import org.junit.Test

class GroundLayoutTest {
    @Test fun defaultsAreStandardPitchAndOptInWideGuides() {
        val layout = GroundLayout.fromMap(null)
        assertEquals(20.1168f, layout.lengthMetres, .00001f)
        assertFalse(layout.wideGuides)
        assertFalse(layout.locked)
        assertTrue(layout.showCreases)
        assertTrue(layout.showStumps)
    }

    @Test fun untrustedNumbersAreFiniteAndBounded() {
        val layout = GroundLayout.fromMap(mapOf(
            "lengthMetres" to Double.NaN,
            "runUpMetres" to Double.POSITIVE_INFINITY,
            "wideOffsetMetres" to -100,
            "wideGuides" to "true",
        ))
        assertEquals(20.1168f, layout.lengthMetres, .00001f)
        assertEquals(0f, layout.runUpMetres, 0f)
        assertEquals(.3f, layout.wideOffsetMetres, 0f)
        assertFalse(layout.wideGuides)
        val clipped = GroundLayout.fromMap(mapOf(
            "lengthMetres" to 1000, "runUpMetres" to -5, "wideOffsetMetres" to 100,
        ))
        assertEquals(40f, clipped.lengthMetres, 0f)
        assertEquals(0f, clipped.runUpMetres, 0f)
        assertEquals(1.3f, clipped.wideOffsetMetres, 0f)
    }

    @Test fun roundTripContainsSettingsWithoutWorldCoordinates() {
        val layout = GroundLayout.fromMap(mapOf(
            "lengthMetres" to 12.0, "wideGuides" to true, "wideOffsetMetres" to 1.1,
            "runUpMetres" to 0, "showStumps" to false, "locked" to true,
            "nearAnchor" to listOf(10, 20, 30), "worldPose" to "untrusted",
        ))
        assertEquals(layout, GroundLayout.fromJson(layout.toJson()))
        assertEquals(setOf("version", "lengthMetres", "wideGuides", "wideOffsetMetres",
            "runUpMetres", "showCreases", "showStumps", "locked"), layout.asMap().keys)
        assertEquals(1, layout.asMap()["version"])
    }

    @Test fun malformedSavedLayoutSafelyFallsBack() {
        assertEquals(GroundLayout(), GroundLayout.fromJson("not json"))
        assertEquals(GroundLayout(), GroundLayout.fromJson(null))
    }
}
