package com.texiol.crixx.groundar

/** Time-based qualification of an observed ground target; owns no ARCore objects. */
internal class GroundTargetReadiness(
    private val holdMillis: Long = 600,
    private val maximumGapMillis: Long = 350,
    private val positionToleranceMetres: Float = .12f,
) {
    data class Candidate(
        val surfaceId: Int,
        val x: Float,
        val y: Float,
        val z: Float,
        val cameraDistanceMetres: Float,
    )

    private var reference: Candidate? = null
    private var sinceMillis: Long? = null
    private var lastObservationMillis: Long? = null
    private var lastFrameTimestamp = 0L

    fun reset() {
        reference = null
        sinceMillis = null
        lastObservationMillis = null
        lastFrameTimestamp = 0L
    }

    fun observe(nowMillis: Long, frameTimestamp: Long, tracking: Boolean, candidate: Candidate?): Boolean {
        if (!tracking || frameTimestamp <= 0L || !valid(candidate)) {
            reset()
            return false
        }
        if (frameTimestamp == lastFrameTimestamp) return readyFor(nowMillis, tracking, candidate)
        val previousTime = lastObservationMillis
        if (previousTime == null || nowMillis < previousTime ||
            frameTimestamp < lastFrameTimestamp || nowMillis - previousTime > maximumGapMillis || !sameTarget(candidate)) {
            reference = candidate
            sinceMillis = nowMillis
        }
        lastObservationMillis = nowMillis
        lastFrameTimestamp = frameTimestamp
        return readyFor(nowMillis, tracking, candidate)
    }

    /** Off-centre taps cannot borrow readiness from a different ground target. */
    fun readyFor(nowMillis: Long, tracking: Boolean, candidate: Candidate?): Boolean {
        val since = sinceMillis ?: return false
        val observed = lastObservationMillis ?: return false
        return tracking && valid(candidate) && sameTarget(candidate) &&
            nowMillis >= observed && nowMillis - observed <= maximumGapMillis &&
            observed - since >= holdMillis
    }

    private fun valid(candidate: Candidate?): Boolean = candidate != null &&
        candidate.x.isFinite() && candidate.y.isFinite() && candidate.z.isFinite() &&
        candidate.cameraDistanceMetres.isFinite() && candidate.cameraDistanceMetres in 0f..5f

    private fun sameTarget(candidate: Candidate?): Boolean {
        val first = reference ?: return false
        if (candidate == null || candidate.surfaceId != first.surfaceId) return false
        val dx = candidate.x - first.x
        val dy = candidate.y - first.y
        val dz = candidate.z - first.z
        return dx * dx + dy * dy + dz * dz <= positionToleranceMetres * positionToleranceMetres
    }
}
