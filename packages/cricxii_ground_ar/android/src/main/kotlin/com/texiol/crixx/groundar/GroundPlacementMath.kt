package com.texiol.crixx.groundar

import kotlin.math.atan2
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.math.max

/** Pure metre-based placement calculations, independent of Android/ARCore JNI. */
internal object GroundPlacementMath {
    data class Target(val x: Float, val y: Float, val z: Float, val yaw: Float)
    data class Alignment(val distance: Float, val endpointOffset: Float, val yawErrorDegrees: Float)

    fun direction(dx: Float, dz: Float): Float? {
        if (!dx.isFinite() || !dz.isFinite()) return null
        if (sqrt(dx * dx + dz * dz) < 1f) return null
        return atan2(dx, dz)
    }

    fun farEnd(x: Float, y: Float, z: Float, yaw: Float, length: Float): Target {
        require(listOf(x, y, z, yaw, length).all { it.isFinite() })
        require(length in 4f..40f)
        return Target(x + sin(yaw) * length, y, z + cos(yaw) * length,
            yaw + Math.PI.toFloat())
    }

    fun adjusted(x: Float, y: Float, z: Float, yaw: Float,
                 sideways: Float, forward: Float, vertical: Float, degrees: Float): Target {
        require(listOf(x, y, z, yaw, sideways, forward, vertical, degrees).all { it.isFinite() })
        return Target(
            x + cos(yaw) * sideways + sin(yaw) * forward,
            y + vertical,
            z - sin(yaw) * sideways + cos(yaw) * forward,
            yaw + Math.toRadians(degrees.toDouble()).toFloat(),
        )
    }

    fun alignment(near: Target, far: Target, targetLength: Float): Alignment {
        val expected = farEnd(near.x, near.y, near.z, near.yaw, targetLength)
        val dx = far.x - near.x
        val dz = far.z - near.z
        val offsetX = far.x - expected.x
        val offsetZ = far.z - expected.z
        val direction = atan2(dx, dz)
        fun angleError(first: Float, second: Float) =
            abs(atan2(sin(first - second), cos(first - second)))
        val angle = max(angleError(near.yaw, direction),
            angleError(far.yaw, direction + Math.PI.toFloat()))
        return Alignment(sqrt(dx * dx + dz * dz), sqrt(offsetX * offsetX + offsetZ * offsetZ),
            Math.toDegrees(angle.toDouble()).toFloat())
    }
}
