package com.texiol.crixx.groundar.rendering

import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin
import org.junit.Assert.*
import org.junit.Test

class SurfaceMeshBuilderTest {
    @Test fun fillCoversTheDetectedPolygonRatherThanItsBoundingRectangle() {
        val boundary = floatArrayOf(-2f, -1f, 1f, -1f, 2f, 0f, 1f, 1f, -2f, 1f)
        val mesh = SurfaceMeshBuilder.build(boundary)!!
        assertEquals(polygonArea(boundary), fillArea(mesh), .00001f)
        assertTrue(fillArea(mesh) < 8f) // Its extent rectangle would include undetected corners.
        assertAllInside(mesh, boundary)
    }

    @Test fun clockwiseAndCounterclockwiseBoundariesCoverTheSameSurface() {
        val forward = floatArrayOf(-1f, -1f, 1f, -1f, 1f, 1f, -1f, 1f)
        val reverse = floatArrayOf(-1f, 1f, 1f, 1f, 1f, -1f, -1f, -1f)
        assertEquals(4f, fillArea(SurfaceMeshBuilder.build(forward)!!), .00001f)
        assertEquals(4f, fillArea(SurfaceMeshBuilder.build(reverse)!!), .00001f)
    }

    @Test fun featheredRimNeverSpillsOutsideAnAcuteDetectedTriangle() {
        val boundary = floatArrayOf(0f, 0f, 4f, 0f, .03f, .2f)
        val mesh = SurfaceMeshBuilder.build(boundary)!!
        assertAllInside(mesh, boundary)
        for (vertex in mesh.fillVertexCount until mesh.fillVertexCount + mesh.rimVertexCount) {
            assertTrue(mesh.vertices[vertex * 4 + 3] in 0f..1f)
        }
    }

    @Test fun duplicateClosureAndRepeatedVerticesDoNotGenerateInvalidGeometry() {
        val boundary = floatArrayOf(0f, 0f, 2f, 0f, 2f, 0f, 2f, 1f, 0f, 1f, 0f, 0f)
        val mesh = SurfaceMeshBuilder.build(boundary)!!
        assertEquals(2f, fillArea(mesh), .00001f)
        assertTrue(mesh.vertices.all { it.isFinite() })
        assertAllInside(mesh, floatArrayOf(0f, 0f, 2f, 0f, 2f, 1f, 0f, 1f))
    }

    @Test fun malformedOrUnusableBoundariesProduceNoInventedSurface() {
        assertNull(SurfaceMeshBuilder.build(floatArrayOf()))
        assertNull(SurfaceMeshBuilder.build(floatArrayOf(0f, 0f, 1f)))
        assertNull(SurfaceMeshBuilder.build(floatArrayOf(0f, 0f, 1f, 0f, 2f, 0f)))
        assertNull(SurfaceMeshBuilder.build(floatArrayOf(0f, 0f, Float.NaN, 1f, 1f, 0f)))
        assertNull(SurfaceMeshBuilder.build(floatArrayOf(0f, 0f, Float.POSITIVE_INFINITY, 1f, 1f, 0f)))
        assertNull(SurfaceMeshBuilder.build(floatArrayOf(0f, 0f, .01f, 0f, .01f, .01f)))
        assertNull(SurfaceMeshBuilder.build(floatArrayOf(0f, 0f, 2f, 0f, .5f, .5f, 2f, 2f, 0f, 2f)))
    }

    @Test fun largeBoundariesStayWithinTheMobileVertexBudget() {
        val count = 1024
        val boundary = FloatArray(count * 2)
        for (index in 0 until count) {
            val angle = index * Math.PI * 2 / count
            boundary[index * 2] = (cos(angle) * 2).toFloat()
            boundary[index * 2 + 1] = (sin(angle) * 2).toFloat()
        }
        val mesh = SurfaceMeshBuilder.build(boundary)!!
        assertTrue(mesh.fillVertexCount <= SurfaceMeshBuilder.MAX_BOUNDARY_VERTICES * 3)
        assertTrue(mesh.rimVertexCount <= SurfaceMeshBuilder.MAX_BOUNDARY_VERTICES * 6)
        assertTrue(fillArea(mesh) <= polygonArea(boundary) + .0001f)
        for (vertex in 0 until mesh.vertices.size / 4) {
            val x = mesh.vertices[vertex * 4]; val z = mesh.vertices[vertex * 4 + 2]
            assertTrue(x * x + z * z <= 4.0001f)
        }
    }

    private fun assertAllInside(mesh: SurfaceMeshBuilder.Mesh, boundary: FloatArray) {
        for (vertex in 0 until mesh.vertices.size / 4) {
            val x = mesh.vertices[vertex * 4]; val z = mesh.vertices[vertex * 4 + 2]
            var sign = 0f
            for (index in 0 until boundary.size / 2) {
                val next = (index + 1) % (boundary.size / 2)
                val ax = boundary[index * 2]; val az = boundary[index * 2 + 1]
                val bx = boundary[next * 2]; val bz = boundary[next * 2 + 1]
                val cross = (bx - ax) * (z - az) - (bz - az) * (x - ax)
                if (abs(cross) < .00001f) continue
                assertTrue("Rendered vertex lies outside the detected polygon", sign == 0f || cross * sign >= 0f)
                sign = cross
            }
        }
    }

    private fun polygonArea(boundary: FloatArray): Float {
        var area = 0f
        for (index in 0 until boundary.size / 2) {
            val next = (index + 1) % (boundary.size / 2)
            area += boundary[index * 2] * boundary[next * 2 + 1] -
                boundary[next * 2] * boundary[index * 2 + 1]
        }
        return abs(area) / 2f
    }

    private fun fillArea(mesh: SurfaceMeshBuilder.Mesh): Float {
        var area = 0f
        for (vertex in 0 until mesh.fillVertexCount step 3) {
            val offset = vertex * 4
            val ax = mesh.vertices[offset]; val az = mesh.vertices[offset + 2]
            val bx = mesh.vertices[offset + 4]; val bz = mesh.vertices[offset + 6]
            val cx = mesh.vertices[offset + 8]; val cz = mesh.vertices[offset + 10]
            area += abs((bx - ax) * (cz - az) - (bz - az) * (cx - ax)) / 2f
        }
        return area
    }
}
