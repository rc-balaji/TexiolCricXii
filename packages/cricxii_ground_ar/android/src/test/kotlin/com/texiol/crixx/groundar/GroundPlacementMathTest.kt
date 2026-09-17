package com.texiol.crixx.groundar

import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt
import org.junit.Assert.*
import org.junit.Test

class GroundPlacementMathTest {
    @Test fun selectedDirectionNeedsSeparatedFiniteGroundHits() {
        assertNull(GroundPlacementMath.direction(.2f, .3f))
        assertNull(GroundPlacementMath.direction(Float.NaN, 3f))
        assertNull(GroundPlacementMath.direction(3f, Float.POSITIVE_INFINITY))
        assertEquals(0f, GroundPlacementMath.direction(0f, 1f)!!, .00001f)
        assertEquals(Math.PI.toFloat() / 2f, GroundPlacementMath.direction(2f, 0f)!!, .00001f)
    }

    @Test fun bothEndsStayStandardDistanceAtEveryHeadingAndFaceInward() {
        for (degrees in -180..180 step 15) {
            val yaw = Math.toRadians(degrees.toDouble()).toFloat()
            val far = GroundPlacementMath.farEnd(2f, -.4f, 5f, yaw, 20.1168f)
            val dx = far.x - 2f; val dz = far.z - 5f
            assertEquals(20.1168f, sqrt(dx * dx + dz * dz), .00001f)
            assertEquals(-.4f, far.y, 0f)
            assertEquals(-sin(yaw), sin(far.yaw), .00001f)
            assertEquals(-cos(yaw), cos(far.yaw), .00001f)
        }
    }

    @Test fun nudgeUsesPitchAxesRatherThanWorldAxes() {
        val moved = GroundPlacementMath.adjusted(1f, 2f, 3f,
            Math.PI.toFloat() / 2f, .05f, .05f, 2f)
        assertEquals(1.05f, moved.x, .00001f)
        assertEquals(2f, moved.y, 0f)
        assertEquals(2.95f, moved.z, .00001f)
        assertEquals(Math.toRadians(92.0).toFloat(), moved.yaw, .00001f)
    }

    @Test fun alignmentReportsLateralDriftAndYawWithoutChangingTheEndpoints() {
        val near = GroundPlacementMath.Target(0f, 0f, 0f, 0f)
        val good = GroundPlacementMath.farEnd(0f, 0f, 0f, 0f, 20.1168f)
        val aligned = GroundPlacementMath.alignment(near, good, 20.1168f)
        assertEquals(0f, aligned.endpointOffset, .00001f)
        assertEquals(0f, aligned.yawErrorDegrees, .00001f)
        val shifted = good.copy(x = .2f, yaw = good.yaw + .1f)
        val drift = GroundPlacementMath.alignment(near, shifted, 20.1168f)
        assertEquals(.2f, drift.endpointOffset, .00001f)
        assertTrue(drift.yawErrorDegrees > 3f)
        assertEquals(.2f, shifted.x, 0f)
    }

    @Test fun alignmentTreatsWrappedHeadingsAsEquivalentAndIgnoresGroundHeightDifference() {
        val near = GroundPlacementMath.Target(3f, 1f, -4f, Math.PI.toFloat())
        val far = GroundPlacementMath.farEnd(near.x, near.y, near.z, near.yaw, 10f)
            .copy(y = 1.2f, yaw = 0f)
        val alignment = GroundPlacementMath.alignment(near, far, 10f)
        assertEquals(10f, alignment.distance, .00001f)
        assertEquals(0f, alignment.endpointOffset, .00001f)
        assertEquals(0f, alignment.yawErrorDegrees, .0001f)
    }

    @Test(expected = IllegalArgumentException::class)
    fun invalidGeometryNeverReachesTheRenderer() {
        GroundPlacementMath.farEnd(0f, 0f, 0f, Float.NaN, 20f)
    }

    @Test(expected = IllegalArgumentException::class)
    fun unboundedLengthIsRejected() {
        GroundPlacementMath.farEnd(0f, 0f, 0f, 0f, 400f)
    }
}
