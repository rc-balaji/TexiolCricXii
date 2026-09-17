package com.texiol.crixx.groundar.rendering

import android.opengl.GLES20
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

internal fun floatBuffer(values: FloatArray): FloatBuffer =
    ByteBuffer.allocateDirect(values.size * 4).order(ByteOrder.nativeOrder())
        .asFloatBuffer().apply { put(values); position(0) }

/** Original geometry; each vertex is position.xyz, normal.xyz, opacity. */
internal class GlMesh(values: FloatArray) {
    val vertices = floatBuffer(values)
    val count = values.size / 7

    fun draw(position: Int, normal: Int, opacity: Int) {
        vertices.position(0)
        GLES20.glVertexAttribPointer(position, 3, GLES20.GL_FLOAT, false, 28, vertices)
        vertices.position(3)
        GLES20.glVertexAttribPointer(normal, 3, GLES20.GL_FLOAT, false, 28, vertices)
        vertices.position(6)
        GLES20.glVertexAttribPointer(opacity, 1, GLES20.GL_FLOAT, false, 28, vertices)
        GLES20.glEnableVertexAttribArray(position)
        GLES20.glEnableVertexAttribArray(normal)
        GLES20.glEnableVertexAttribArray(opacity)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLES, 0, count)
        GLES20.glDisableVertexAttribArray(position)
        GLES20.glDisableVertexAttribArray(normal)
        GLES20.glDisableVertexAttribArray(opacity)
    }
}

internal object GlGeometry {
    fun rectangle(): GlMesh {
        val result = ArrayList<Float>()
        for (point in arrayOf(
            floatArrayOf(-0.5f, -0.5f), floatArrayOf(-0.5f, 0.5f), floatArrayOf(0.5f, -0.5f),
            floatArrayOf(0.5f, -0.5f), floatArrayOf(-0.5f, 0.5f), floatArrayOf(0.5f, 0.5f),
        )) add(result, point[0], 0f, point[1], 0f, 1f, 0f)
        return GlMesh(result.toFloatArray())
    }

    fun cylinder(roundedTop: Boolean = false): GlMesh {
        val profile = if (roundedTop) arrayOf(
            floatArrayOf(0f, 0.93f), floatArrayOf(0.015f, 1f),
            floatArrayOf(0.974f, 1f), floatArrayOf(0.993f, 0.82f), floatArrayOf(1f, 0f),
        ) else arrayOf(floatArrayOf(0f, 1f), floatArrayOf(1f, 1f))
        val data = ArrayList<Float>()
        val segments = 24
        for (level in 0 until profile.size - 1) {
            val a = profile[level]
            val b = profile[level + 1]
            val slope = (a[1] - b[1]) / (b[0] - a[0])
            val norm = sqrt(1f + slope * slope)
            for (segment in 0 until segments) {
                val angles = floatArrayOf(
                    (segment * 2 * PI / segments).toFloat(),
                    ((segment + 1) * 2 * PI / segments).toFloat(),
                )
                for ((height, angleIndex) in arrayOf(
                    Pair(a, 0), Pair(b, 0), Pair(a, 1),
                    Pair(a, 1), Pair(b, 0), Pair(b, 1),
                )) {
                    val x = cos(angles[angleIndex])
                    val z = sin(angles[angleIndex])
                    add(data, height[1] * x, height[0], height[1] * z,
                        x / norm, slope / norm, z / norm)
                }
            }
        }
        for (cap in 0..1) {
            val y = cap.toFloat()
            val radius = if (cap == 0) profile.first()[1] else profile.last()[1]
            if (radius == 0f) continue
            val normalY = if (cap == 0) -1f else 1f
            for (segment in 0 until segments) {
                add(data, 0f, y, 0f, 0f, normalY, 0f)
                for (end in 0..1) {
                    val angle = ((segment + end) * 2 * PI / segments).toFloat()
                    add(data, cos(angle) * radius, y, sin(angle) * radius,
                        0f, normalY, 0f)
                }
            }
        }
        return GlMesh(data.toFloatArray())
    }

    fun shadow(): GlMesh {
        val data = ArrayList<Float>()
        // A translucent centre fading to zero at the perimeter, with no texture dependency.
        for (segment in 0 until 40) {
            add(data, 0f, 0f, 0f, 0f, 1f, 0f, 1f)
            for (end in 0..1) {
                val angle = ((segment + end) * 2 * PI / 40).toFloat()
                add(data, cos(angle), 0f, sin(angle), 0f, 1f, 0f, 0f)
            }
        }
        return GlMesh(data.toFloatArray())
    }

    fun ring(): GlMesh {
        val data = ArrayList<Float>()
        for (segment in 0 until 64) {
            val angles = floatArrayOf(
                (segment * 2 * PI / 64).toFloat(),
                ((segment + 1) * 2 * PI / 64).toFloat(),
            )
            for ((radius, angleIndex) in arrayOf(
                Pair(0.86f, 0), Pair(1f, 0), Pair(0.86f, 1),
                Pair(0.86f, 1), Pair(1f, 0), Pair(1f, 1),
            )) add(data, cos(angles[angleIndex]) * radius, 0f,
                sin(angles[angleIndex]) * radius, 0f, 1f, 0f)
        }
        return GlMesh(data.toFloatArray())
    }

    private fun add(data: MutableList<Float>, x: Float, y: Float, z: Float,
                    nx: Float, ny: Float, nz: Float, opacity: Float = 1f) {
        data.add(x); data.add(y); data.add(z)
        data.add(nx); data.add(ny); data.add(nz); data.add(opacity)
    }
}

internal fun createProgram(vertexSource: String, fragmentSource: String): Int {
    fun shader(type: Int, source: String): Int {
        val id = GLES20.glCreateShader(type)
        check(id != 0) { "Unable to allocate AR shader." }
        GLES20.glShaderSource(id, source)
        GLES20.glCompileShader(id)
        val result = IntArray(1)
        GLES20.glGetShaderiv(id, GLES20.GL_COMPILE_STATUS, result, 0)
        if (result[0] == 0) {
            val info = GLES20.glGetShaderInfoLog(id)
            GLES20.glDeleteShader(id)
            error("AR shader compilation failed: $info")
        }
        return id
    }
    val vertex = shader(GLES20.GL_VERTEX_SHADER, vertexSource)
    var fragment = 0
    var program = 0
    try {
        fragment = shader(GLES20.GL_FRAGMENT_SHADER, fragmentSource)
        program = GLES20.glCreateProgram()
        check(program != 0) { "Unable to allocate AR program." }
        GLES20.glAttachShader(program, vertex)
        GLES20.glAttachShader(program, fragment)
        GLES20.glLinkProgram(program)
        val result = IntArray(1)
        GLES20.glGetProgramiv(program, GLES20.GL_LINK_STATUS, result, 0)
        check(result[0] != 0) { "AR shader link failed: ${GLES20.glGetProgramInfoLog(program)}" }
        return program
    } catch (failure: RuntimeException) {
        if (program != 0) GLES20.glDeleteProgram(program)
        throw failure
    } finally {
        GLES20.glDeleteShader(vertex)
        if (fragment != 0) GLES20.glDeleteShader(fragment)
    }
}
