package com.texiol.crixx.groundar.rendering

import android.opengl.GLES20
import android.opengl.Matrix
import android.os.SystemClock
import com.google.ar.core.Plane
import com.google.ar.core.Pose
import com.google.ar.core.TrackingState
import java.nio.FloatBuffer
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.sqrt

/** Shows nearby observed surfaces with a subtle fill, world-aligned 25 cm grid and rim. */
internal class GroundSurfaceRenderer {
    private var program = 0
    private var positionLocation = -1
    private var fadeLocation = -1
    private var mvpLocation = -1
    private var modelLocation = -1
    private var originLocation = -1
    private var cameraLocation = -1
    private var selectedLocation = -1
    private var rimLocation = -1
    private val model = FloatArray(16)
    private val mvp = FloatArray(16)
    private val candidates = ArrayList<Candidate>(MAX_CACHED_PLANES)
    private val cache = LinkedHashMap<Plane, CachedPlane>()

    private class CachedPlane(
        var boundary: FloatArray = FloatArray(0),
        var buffer: FloatBuffer? = null,
        var fillCount: Int = 0,
        var rimCount: Int = 0,
        var checkedAt: Long = 0L,
        var seenAt: Long = 0L,
    )
    private data class Candidate(val plane: Plane, val distance: Float, val selected: Boolean)

    fun initialize() {
        program = 0
        cache.clear()
        program = createProgram(VERTEX, FRAGMENT)
        positionLocation = GLES20.glGetAttribLocation(program, "aPosition")
        fadeLocation = GLES20.glGetAttribLocation(program, "aFade")
        mvpLocation = GLES20.glGetUniformLocation(program, "uMvp")
        modelLocation = GLES20.glGetUniformLocation(program, "uModel")
        originLocation = GLES20.glGetUniformLocation(program, "uGridOrigin")
        cameraLocation = GLES20.glGetUniformLocation(program, "uCameraRelative")
        selectedLocation = GLES20.glGetUniformLocation(program, "uSelected")
        rimLocation = GLES20.glGetUniformLocation(program, "uRim")
    }

    fun draw(planes: Collection<Plane>, selectedPlane: Plane?, camera: Pose, viewProjection: FloatArray) {
        if (program == 0) return
        val now = SystemClock.uptimeMillis()
        val selected = selectedPlane?.subsumedBy ?: selectedPlane
        candidates.clear()
        // Keep just the closest few candidates while iterating, without sorting or
        // caching an entire room's long-lived plane collection every camera frame.
        for (plane in planes) {
            if (plane.trackingState != TrackingState.TRACKING || plane.subsumedBy != null ||
                plane.type != Plane.Type.HORIZONTAL_UPWARD_FACING) continue
            val pose = plane.centerPose
            val height = camera.ty() - pose.ty()
            if (!height.isFinite() || height < 0.08f || height > 3.5f) continue
            val dx = camera.tx() - pose.tx(); val dz = camera.tz() - pose.tz()
            val radius = sqrt(plane.extentX * plane.extentX + plane.extentZ * plane.extentZ) / 2f
            val distance = max(0f, sqrt(dx * dx + dz * dz) - radius)
            if (!distance.isFinite() || distance > MAX_DISTANCE) continue
            val candidate = Candidate(plane, distance, plane == selected)
            val insert = candidates.indexOfFirst {
                (candidate.selected && !it.selected) ||
                    (candidate.selected == it.selected && candidate.distance < it.distance)
            }.let { if (it < 0) candidates.size else it }
            if (insert < MAX_DRAWN_PLANES) {
                candidates.add(insert, candidate)
                if (candidates.size > MAX_DRAWN_PLANES) candidates.removeAt(candidates.lastIndex)
            }
        }
        if (candidates.isEmpty()) {
            prune(now)
            return
        }
        GLES20.glUseProgram(program)
        GLES20.glEnable(GLES20.GL_DEPTH_TEST)
        GLES20.glDepthMask(false) // Surface guidance must never occlude the pitch/stumps.
        GLES20.glDisable(GLES20.GL_CULL_FACE)
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
        // Subtract a metre-snapped world origin in the vertex shader. Mediump fragment
        // interpolation stays precise after walking 20-40 m, without a swimming grid.
        val originX = floor(camera.tx())
        val originZ = floor(camera.tz())
        GLES20.glUniform3f(originLocation, originX, camera.ty(), originZ)
        GLES20.glUniform3f(cameraLocation, camera.tx() - originX, 0f, camera.tz() - originZ)
        try {
            for (candidate in candidates.asReversed()) {
                val plane = candidate.plane
                val entry = cache.getOrPut(plane) { CachedPlane() }
                entry.seenAt = now
                if (now - entry.checkedAt >= 150L || entry.checkedAt == 0L) update(entry, plane, now)
                val vertices = entry.buffer ?: continue
                plane.centerPose.toMatrix(model, 0)
                if (model.any { !it.isFinite() }) continue
                Matrix.multiplyMM(mvp, 0, viewProjection, 0, model, 0)
                GLES20.glUniformMatrix4fv(mvpLocation, 1, false, mvp, 0)
                GLES20.glUniformMatrix4fv(modelLocation, 1, false, model, 0)
                GLES20.glUniform1f(selectedLocation, if (candidate.selected) 1f else 0f)
                vertices.position(0)
                GLES20.glVertexAttribPointer(positionLocation, 3, GLES20.GL_FLOAT, false, 16, vertices)
                vertices.position(3)
                GLES20.glVertexAttribPointer(fadeLocation, 1, GLES20.GL_FLOAT, false, 16, vertices)
                GLES20.glEnableVertexAttribArray(positionLocation)
                GLES20.glEnableVertexAttribArray(fadeLocation)
                GLES20.glUniform1f(rimLocation, 0f)
                GLES20.glDrawArrays(GLES20.GL_TRIANGLES, 0, entry.fillCount)
                GLES20.glUniform1f(rimLocation, 1f)
                GLES20.glDrawArrays(GLES20.GL_TRIANGLES, entry.fillCount, entry.rimCount)
            }
        } finally {
            GLES20.glDisableVertexAttribArray(positionLocation)
            GLES20.glDisableVertexAttribArray(fadeLocation)
            GLES20.glDepthMask(true)
            prune(now)
        }
    }

    private fun update(entry: CachedPlane, plane: Plane, now: Long) {
        entry.checkedAt = now
        val polygon = plane.polygon
        val sourceCount = polygon.limit() / 2
        val count = minOf(sourceCount, SurfaceMeshBuilder.MAX_BOUNDARY_VERTICES)
        if (count < 3 || polygon.limit() % 2 != 0) {
            entry.buffer = null
            return
        }
        var changed = entry.buffer == null || entry.boundary.size != count * 2
        if (!changed) for (index in 0 until count) {
            val offset = (index.toLong() * sourceCount / count).toInt() * 2
            if (polygon[offset] != entry.boundary[index * 2] ||
                polygon[offset + 1] != entry.boundary[index * 2 + 1]) {
                changed = true
                break
            }
        }
        if (!changed) return
        val boundary = FloatArray(count * 2)
        for (index in 0 until count) {
            val offset = (index.toLong() * sourceCount / count).toInt() * 2
            boundary[index * 2] = polygon[offset]
            boundary[index * 2 + 1] = polygon[offset + 1]
        }
        entry.boundary = boundary
        val mesh = SurfaceMeshBuilder.build(boundary)
        if (mesh == null) {
            entry.buffer = null
            return
        }
        val buffer = entry.buffer?.takeIf { it.capacity() >= mesh.vertices.size }?.apply {
            clear()
            put(mesh.vertices)
            flip()
        } ?: floatBuffer(mesh.vertices)
        entry.buffer = buffer
        entry.fillCount = mesh.fillVertexCount
        entry.rimCount = mesh.rimVertexCount
    }

    private fun prune(now: Long) {
        val iterator = cache.entries.iterator()
        while (iterator.hasNext()) {
            val entry = iterator.next()
            if (now - entry.value.seenAt > 3000L || entry.key.trackingState == TrackingState.STOPPED ||
                entry.key.subsumedBy != null) iterator.remove()
        }
        while (cache.size > MAX_CACHED_PLANES) {
            val oldest = cache.minByOrNull { it.value.seenAt }?.key ?: break
            cache.remove(oldest)
        }
    }

    fun release() {
        if (program != 0) GLES20.glDeleteProgram(program)
        program = 0
        cache.clear()
    }

    companion object {
        private const val MAX_DRAWN_PLANES = 3
        private const val MAX_CACHED_PLANES = 8
        private const val MAX_DISTANCE = 7f
        private const val VERTEX = """
            attribute vec3 aPosition;
            attribute float aFade;
            uniform mat4 uMvp;
            uniform mat4 uModel;
            uniform vec3 uGridOrigin;
            varying mediump vec3 vRelative;
            varying mediump float vFade;
            void main() {
                gl_Position = uMvp * vec4(aPosition, 1.0);
                vRelative = (uModel * vec4(aPosition, 1.0)).xyz - uGridOrigin;
                vFade = aFade;
            }
        """
        private const val FRAGMENT = """
            precision mediump float;
            uniform vec3 uCameraRelative;
            uniform float uSelected;
            uniform float uRim;
            varying mediump vec3 vRelative;
            varying mediump float vFade;
            void main() {
                float distanceMetres = length(vRelative - uCameraRelative);
                float distanceFade = 1.0 - smoothstep(4.5, 7.0, distanceMetres);
                if (distanceFade < 0.01) discard;
                float alpha;
                if (uRim > 0.5) {
                    alpha = sin(clamp(vFade, 0.0, 1.0) * 3.14159265) * mix(0.34, 0.75, uSelected);
                } else {
                    vec2 gridDistance = abs(fract(vRelative.xz / 0.25 + 0.5) - 0.5) * 0.25;
                    float stroke = clamp(0.0025 + distanceMetres * 0.0008, 0.0025, 0.009);
                    float grid = 1.0 - smoothstep(stroke, stroke * 1.7, min(gridDistance.x, gridDistance.y));
                    float edgeFade = smoothstep(0.0, 0.07, vFade);
                    alpha = (mix(0.035, 0.065, uSelected) + grid * mix(0.12, 0.23, uSelected)) * edgeFade;
                }
                gl_FragColor = vec4(mix(vec3(0.25, 0.77, 0.68), vec3(0.15, 0.96, 0.73), uSelected), alpha * distanceFade);
            }
        """
    }
}
