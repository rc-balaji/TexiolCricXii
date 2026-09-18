package com.texiol.crixx.groundar

import org.junit.Assert.*
import org.junit.Test

class GroundTargetReadinessTest {
    private val ground = GroundTargetReadiness.Candidate(1, 0f, 0f, -2f, 2f)

    @Test fun placementRequiresSustainedFreshFramesOnTheSameSurface() {
        val gate = GroundTargetReadiness()
        for (time in 0L..500L step 100) assertFalse(gate.observe(time, time + 1, true, ground))
        assertTrue(gate.observe(600, 601, true, ground))
        assertFalse(gate.readyFor(600, true, ground.copy(surfaceId = 2)))
        assertFalse(gate.readyFor(600, true, ground.copy(x = .3f)))
        assertTrue(gate.readyFor(600, true, ground.copy(x = .02f)))
    }

    @Test fun aRepeatedCameraFrameCannotBecomeReadyByWaiting() {
        val gate = GroundTargetReadiness()
        assertFalse(gate.observe(0, 1000, true, ground))
        assertFalse(gate.observe(600, 1000, true, ground))
        assertFalse(gate.readyFor(600, true, ground))
        assertFalse(gate.observe(700, 2000, true, ground))
    }

    @Test fun trackingLossAndSurfaceChangesRequireANewHold() {
        val gate = GroundTargetReadiness()
        for (time in 0L..600L step 100) gate.observe(time, time + 1, true, ground)
        assertFalse(gate.observe(650, 651, false, ground))
        assertFalse(gate.observe(700, 701, true, ground))
        assertFalse(gate.observe(800, 801, true, ground.copy(surfaceId = 2)))
        assertFalse(gate.observe(900, 901, true, ground))
        gate.reset()
        assertFalse(gate.readyFor(900, true, ground))
    }

    @Test fun gapsInvalidHitsAndUnreasonableDistanceNeverPermitPlacement() {
        val gate = GroundTargetReadiness()
        for (time in 0L..600L step 100) gate.observe(time, time + 1, true, ground)
        assertFalse(gate.readyFor(1000, true, ground))
        assertFalse(gate.observe(1000, 1001, true, ground))
        assertFalse(gate.observe(1100, 1101, true, ground.copy(cameraDistanceMetres = 6f)))
        assertFalse(gate.observe(1200, 1201, true, ground.copy(x = Float.NaN)))
        assertFalse(gate.observe(1300, 1301, true, null))
    }
}
