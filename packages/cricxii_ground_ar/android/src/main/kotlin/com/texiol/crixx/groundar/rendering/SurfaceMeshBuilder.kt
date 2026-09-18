package com.texiol.crixx.groundar.rendering

import kotlin.math.abs
import kotlin.math.min
import kotlin.math.sqrt

/** Pure geometry for the convex boundary ARCore actually detected; never an extent rectangle. */
internal object SurfaceMeshBuilder {
    const val MAX_BOUNDARY_VERTICES = 128
    private const val EPSILON = 0.00001f

    data class Mesh(
        val vertices: FloatArray, // x, y, z, edge fade; triangles, fill followed by rim.
        val fillVertexCount: Int,
        val rimVertexCount: Int,
        val radius: Float,
    )

    fun build(boundary: FloatArray): Mesh? {
        if (boundary.size < 6 || boundary.size % 2 != 0 ||
            boundary.any { !it.isFinite() || abs(it) > 1000f }) return null
        val sourceCount = boundary.size / 2
        val sampledCount = min(sourceCount, MAX_BOUNDARY_VERTICES)
        val points = ArrayList<Point>(sampledCount)
        for (index in 0 until sampledCount) {
            val offset = (index.toLong() * sourceCount / sampledCount).toInt() * 2
            val point = Point(boundary[offset], boundary[offset + 1])
            if (points.isEmpty() || distance(points.last(), point) > EPSILON) points.add(point)
        }
        if (points.size > 2 && distance(points.first(), points.last()) < EPSILON) points.removeAt(points.lastIndex)
        if (points.size < 3) return null
        var signedArea = 0f
        var crossSign = 0f
        for (index in points.indices) {
            val a = points[index]
            val b = points[(index + 1) % points.size]
            val c = points[(index + 2) % points.size]
            signedArea += a.x * b.z - b.x * a.z
            val cross = (b.x - a.x) * (c.z - b.z) - (b.z - a.z) * (c.x - b.x)
            if (abs(cross) > EPSILON) {
                if (crossSign != 0f && cross * crossSign < 0f) return null
                crossSign = cross
            }
        }
        if (!signedArea.isFinite() || abs(signedArea) < 0.04f) return null
        val centre = Point(points.sumOf { it.x.toDouble() }.toFloat() / points.size,
            points.sumOf { it.z.toDouble() }.toFloat() / points.size)
        var insideDistance = Float.MAX_VALUE
        var radius = 0f
        for (index in points.indices) {
            val a = points[index]
            val b = points[(index + 1) % points.size]
            val length = distance(a, b)
            if (length <= EPSILON) continue
            insideDistance = min(insideDistance,
                abs((b.x - a.x) * (centre.z - a.z) - (b.z - a.z) * (centre.x - a.x)) / length)
            radius = maxOf(radius, sqrt(a.x * a.x + a.z * a.z))
        }
        if (!insideDistance.isFinite() || insideDistance < EPSILON) return null
        val rimWidth = min(0.045f, insideDistance * 0.2f)
        // Moving each boundary vertex toward an interior point always stays inside a
        // convex polygon, including very acute corners. No miter can spill outside it.
        val inner = points.map { point ->
            val scale = min(0.2f, rimWidth / distance(point, centre))
            Point(point.x + (centre.x - point.x) * scale,
                point.z + (centre.z - point.z) * scale)
        }
        val fillCount = points.size * 3
        val rimCount = points.size * 6
        val vertices = FloatArray((fillCount + rimCount) * 4)
        var cursor = 0
        fun vertex(point: Point, fade: Float) {
            vertices[cursor++] = point.x
            vertices[cursor++] = 0.002f
            vertices[cursor++] = point.z
            vertices[cursor++] = fade
        }
        for (index in points.indices) {
            vertex(centre, insideDistance)
            vertex(points[index], 0f)
            vertex(points[(index + 1) % points.size], 0f)
        }
        for (index in points.indices) {
            val next = (index + 1) % points.size
            vertex(points[index], 0f); vertex(inner[index], 1f); vertex(points[next], 0f)
            vertex(points[next], 0f); vertex(inner[index], 1f); vertex(inner[next], 1f)
        }
        return Mesh(vertices, fillCount, rimCount, radius)
    }

    private data class Point(val x: Float, val z: Float)
    private fun distance(a: Point, b: Point): Float {
        val x = a.x - b.x; val z = a.z - b.z
        return sqrt(x * x + z * z)
    }
}
