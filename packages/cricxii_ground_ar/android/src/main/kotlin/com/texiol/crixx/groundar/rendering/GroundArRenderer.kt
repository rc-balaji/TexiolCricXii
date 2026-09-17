package com.texiol.crixx.groundar.rendering

import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.opengl.Matrix
import com.google.ar.core.Coordinates2d
import com.google.ar.core.Frame
import com.google.ar.core.LightEstimate
import com.google.ar.core.Pose
import com.google.ar.core.TrackingState
import kotlin.math.atan2
import kotlin.math.ceil
import kotlin.math.min
import kotlin.math.sqrt

/**
 * GL-thread-only renderer. Activity owns Session, anchors, viewport and display rotation.
 * Each end pose is at the middle stump's ground contact, local +Y up and +Z towards the
 * opposite wicket. End objects remain local to their own anchors. The interpolated route
 * is a collection of short visual aids, not another measured/anchored ground surface.
 *
 * Call initialize after EVERY EGL context creation; then bind cameraTextureId to Session.
 * Camera background uses ARCore's display-coordinate transform, including device rotation.
 * All shaders and procedural geometry here are original, with no borrowed asset licenses.
 */
class GroundArRenderer {
    var cameraTextureId: Int = 0
        private set

    private var backgroundProgram = 0
    private var objectProgram = 0
    private var backgroundPosition = -1
    private var backgroundUv = -1
    private var backgroundSampler = -1
    private var objectPosition = -1
    private var objectNormal = -1
    private var objectOpacity = -1
    private var objectMvp = -1
    private var objectMv = -1
    private var objectNormalMatrix = -1
    private var objectColor = -1
    private var objectLit = -1
    private var objectWood = -1
    private var objectStumpBands = -1
    private var objectAmbient = -1
    private var objectLight = -1
    private var uvReady = false

    private val screen = floatBuffer(floatArrayOf(-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f))
    private val cameraUv = floatBuffer(FloatArray(8))
    private val rectangle = GlGeometry.rectangle()
    private val stump = GlGeometry.cylinder(roundedTop = true)
    private val cylinder = GlGeometry.cylinder()
    private val shadow = GlGeometry.shadow()
    private val ring = GlGeometry.ring()
    private val nearMatrix = FloatArray(16)
    private val farMatrix = FloatArray(16)
    private val aimMatrix = FloatArray(16)
    private val worldMatrix = FloatArray(16)
    private val localMatrix = FloatArray(16)
    private val modelMatrix = FloatArray(16)
    private val modelView = FloatArray(16)
    private val modelViewProjection = FloatArray(16)
    private val inverseModelView = FloatArray(16)
    private val normalMatrix = FloatArray(9)
    private val viewProjection = FloatArray(16)
    private val lightDirection = FloatArray(4)
    private val sunDirection = floatArrayOf(-0.35f, 0.86f, 0.4f, 0f)
    private var currentView = FloatArray(16)

    fun initialize() {
        // Old handles belong to the previous EGL context; do not delete them in a new one.
        cameraTextureId = 0
        backgroundProgram = 0
        objectProgram = 0
        uvReady = false
        try {
            backgroundProgram = createProgram(BACKGROUND_VERTEX, BACKGROUND_FRAGMENT)
            objectProgram = createProgram(OBJECT_VERTEX, OBJECT_FRAGMENT)
            backgroundPosition = GLES20.glGetAttribLocation(backgroundProgram, "aPosition")
            backgroundUv = GLES20.glGetAttribLocation(backgroundProgram, "aUv")
            backgroundSampler = GLES20.glGetUniformLocation(backgroundProgram, "uCamera")
            objectPosition = GLES20.glGetAttribLocation(objectProgram, "aPosition")
            objectNormal = GLES20.glGetAttribLocation(objectProgram, "aNormal")
            objectOpacity = GLES20.glGetAttribLocation(objectProgram, "aOpacity")
            objectMvp = GLES20.glGetUniformLocation(objectProgram, "uMvp")
            objectMv = GLES20.glGetUniformLocation(objectProgram, "uModelView")
            objectNormalMatrix = GLES20.glGetUniformLocation(objectProgram, "uNormalMatrix")
            objectColor = GLES20.glGetUniformLocation(objectProgram, "uColor")
            objectLit = GLES20.glGetUniformLocation(objectProgram, "uLit")
            objectWood = GLES20.glGetUniformLocation(objectProgram, "uWood")
            objectStumpBands = GLES20.glGetUniformLocation(objectProgram, "uStumpBands")
            objectAmbient = GLES20.glGetUniformLocation(objectProgram, "uAmbient")
            objectLight = GLES20.glGetUniformLocation(objectProgram, "uLight")
            val textures = IntArray(1)
            GLES20.glGenTextures(1, textures, 0)
            cameraTextureId = textures[0]
            check(cameraTextureId != 0) { "Unable to allocate the AR camera texture." }
            GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, cameraTextureId)
            GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, 0)
            GLES20.glClearColor(0.035f, 0.045f, 0.045f, 1f)
        } catch (failure: RuntimeException) {
            release()
            throw failure
        }
    }

    fun draw(
        frame: Frame,
        viewMatrix: FloatArray,
        projectionMatrix: FloatArray,
        nearPose: Pose?,
        farPose: Pose?,
        config: GroundRenderConfig,
        aimPose: Pose? = null,
    ) {
        if (backgroundProgram == 0 || objectProgram == 0) return
        GLES20.glDepthMask(true)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
        drawCamera(frame)
        if (frame.camera.trackingState != TrackingState.TRACKING ||
            !finiteMatrix(viewMatrix) || !finiteMatrix(projectionMatrix)) return

        currentView = viewMatrix
        Matrix.multiplyMM(viewProjection, 0, projectionMatrix, 0, viewMatrix, 0)
        GLES20.glUseProgram(objectProgram)
        GLES20.glEnable(GLES20.GL_DEPTH_TEST)
        GLES20.glDepthFunc(GLES20.GL_LEQUAL)
        GLES20.glDisable(GLES20.GL_CULL_FACE)
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
        Matrix.multiplyMV(lightDirection, 0, viewMatrix, 0, sunDirection, 0)
        GLES20.glUniform3f(objectLight, lightDirection[0], lightDirection[1], lightDirection[2])
        val estimate = frame.lightEstimate
        val intensity = if (estimate.state == LightEstimate.State.VALID)
            estimate.pixelIntensity.takeIf { it.isFinite() }?.coerceIn(0.55f, 1.35f) ?: 1f
        else 1f
        GLES20.glUniform1f(objectAmbient, intensity)

        val validNear = poseMatrix(nearPose, nearMatrix)
        val validFar = poseMatrix(farPose, farMatrix)
        if (validNear && validFar) drawRoute(config)
        if (validNear) drawEnd(nearMatrix, config, bowlingEnd = false)
        if (validFar) drawEnd(farMatrix, config, bowlingEnd = true)
        if (!config.locked && poseMatrix(aimPose, aimMatrix)) drawAim(aimMatrix)

        GLES20.glDepthMask(true)
        GLES20.glDisable(GLES20.GL_BLEND)
        GLES20.glUseProgram(0)
    }

    private fun drawCamera(frame: Frame) {
        if (frame.timestamp == 0L) return
        if (!uvReady || frame.hasDisplayGeometryChanged()) {
            screen.position(0)
            cameraUv.position(0)
            frame.transformCoordinates2d(Coordinates2d.OPENGL_NORMALIZED_DEVICE_COORDINATES,
                screen, Coordinates2d.TEXTURE_NORMALIZED, cameraUv)
            uvReady = true
        }
        GLES20.glDisable(GLES20.GL_DEPTH_TEST)
        GLES20.glDepthMask(false)
        GLES20.glDisable(GLES20.GL_BLEND)
        GLES20.glDisable(GLES20.GL_CULL_FACE)
        GLES20.glUseProgram(backgroundProgram)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, cameraTextureId)
        GLES20.glUniform1i(backgroundSampler, 0)
        screen.position(0)
        cameraUv.position(0)
        GLES20.glVertexAttribPointer(backgroundPosition, 2, GLES20.GL_FLOAT, false, 0, screen)
        GLES20.glVertexAttribPointer(backgroundUv, 2, GLES20.GL_FLOAT, false, 0, cameraUv)
        GLES20.glEnableVertexAttribArray(backgroundPosition)
        GLES20.glEnableVertexAttribArray(backgroundUv)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(backgroundPosition)
        GLES20.glDisableVertexAttribArray(backgroundUv)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, 0)
        GLES20.glDepthMask(true)
    }

    private fun drawEnd(base: FloatArray, config: GroundRenderConfig, bowlingEnd: Boolean) {
        if (config.showStumps) {
            // Small, soft ground contact shadows. They shade the camera image, never an
            // invented opaque ground plane, and do not claim real-scene depth occlusion.
            GLES20.glDepthMask(false)
            drawMesh(shadow, base, 0.045f, 0.003f, -0.07f, 0.24f, 1f, 0.14f, SHADOW)
            val spacing = GroundDimensions.WICKET_WIDTH / 2f - GroundDimensions.STUMP_RADIUS
            for (index in -1..1) {
                drawMesh(shadow, base, index * spacing, 0.004f, 0f,
                    0.057f, 1f, 0.05f, CONTACT_SHADOW)
            }
            GLES20.glDepthMask(true)
        }
        if (config.showCreases) drawCreases(base)
        if (config.wideGuides) {
            val halfWidth = finite(config.guideHalfWidthMetres, 0.9f).coerceIn(0.3f, 1.3f)
            // Amber dashed practice guides deliberately look different from legal white
            // creases. Their location is user-defined, not an automatic Wide-ball rule.
            for (side in intArrayOf(-1, 1)) {
                for (index in 0..5) {
                    rectangle(base, side * halfWidth, 0.014f, 0.1f + index * 0.22f,
                        0.035f, 0.12f, GUIDE)
                }
            }
        }
        if (bowlingEnd) drawRunUp(base, finite(config.runUpMetres, 0f).coerceIn(0f, 20f))
        if (config.showStumps) drawWicket(base)
        // Subtle end marker remains visible when stumps and creases are toggled off.
        drawMesh(ring, base, 0f, 0.009f, 0f, 0.19f, 1f, 0.19f,
            if (config.locked) LOCKED else TEAL)
    }

    private fun drawCreases(base: FloatArray) {
        val width = GroundDimensions.PAINT_WIDTH
        val popping = GroundDimensions.POPPING_DISTANCE
        // +Z is inward. Paint is in front of the exact back edge at z=0 / z=4ft.
        outlinedRectangle(base, 0f, width / 2f,
            GroundDimensions.BOWLING_LENGTH, width)
        outlinedRectangle(base, 0f, popping + width / 2f,
            GroundDimensions.POPPING_LENGTH, width)
        // Return lines' INSIDE edge is x=+/-4ft4in; all paint lies outside it.
        val centreZ = popping - GroundDimensions.RETURN_LENGTH / 2f
        for (side in intArrayOf(-1, 1)) {
            outlinedRectangle(base, side * (GroundDimensions.RETURN_HALF_WIDTH + width / 2f),
                centreZ, width, GroundDimensions.RETURN_LENGTH)
        }
        // A tiny centre tick references the middle stump without changing crease edges.
        rectangle(base, 0f, 0.015f, popping + 0.105f, 0.026f, 0.08f, TEAL)
    }

    private fun drawWicket(base: FloatArray) {
        val radius = GroundDimensions.STUMP_RADIUS
        val spacing = GroundDimensions.WICKET_WIDTH / 2f - radius
        for (index in -1..1) {
            val x = index * spacing
            drawMesh(stump, base, x, 0f, 0f, radius, GroundDimensions.STUMP_HEIGHT,
                radius, WOOD, lit = true, wood = true, stumpBands = true)
        }
        // Two turned wooden bails: narrower spigots resting across the stump tops,
        // rounded-looking central barrels. Top remains below the 1/2in allowance.
        for (side in intArrayOf(-1, 1)) {
            val centreX = side * spacing / 2f
            val length = 0.10795f
            drawMesh(cylinder, base, centreX - length / 2f, 0.715f, 0f,
                0.0038f, length, 0.0038f, WOOD_DARK, lit = true, rotateZ = -90f)
            drawMesh(cylinder, base, centreX - 0.028f, 0.715f, 0f,
                0.0065f, 0.056f, 0.0065f, WOOD, lit = true, wood = true, rotateZ = -90f)
        }
    }

    private fun drawRoute(config: GroundRenderConfig) {
        val dx = farMatrix[12] - nearMatrix[12]
        val dy = farMatrix[13] - nearMatrix[13]
        val dz = farMatrix[14] - nearMatrix[14]
        val length = sqrt(dx * dx + dz * dz)
        if (!length.isFinite() || length < 0.25f || length > 60f) return
        val xAxisX = dz / length
        val xAxisZ = -dx / length
        val yaw = Math.toDegrees(atan2(dx, dz).toDouble()).toFloat()
        val count = ceil(length / 0.8f).toInt().coerceAtMost(80)
        // No single 20-40m mesh is attached to either end. Each short visual marker
        // follows an interpolation between the two live endpoint positions.
        for (index in 1 until count) {
            val fraction = index.toFloat() / count
            val distance = fraction * length
            if (distance < 1.65f || length - distance < 1.65f) continue
            Matrix.setIdentityM(worldMatrix, 0)
            Matrix.translateM(worldMatrix, 0, nearMatrix[12] + dx * fraction,
                nearMatrix[13] + dy * fraction, nearMatrix[14] + dz * fraction)
            Matrix.rotateM(worldMatrix, 0, yaw, 0f, 1f, 0f)
            rectangle(worldMatrix, 0f, 0.012f, 0f, 0.022f, 0.18f, ROUTE)
            if (config.showCreases) {
                for (side in intArrayOf(-1, 1)) {
                    rectangle(worldMatrix, side * GroundDimensions.PITCH_WIDTH / 2f,
                        0.01f, 0f, 0.022f, 0.3f, PITCH_EDGE)
                }
            }
        }
        // Ensure non-finite transformations never reach GLES even for drifted anchors.
        check(xAxisX.isFinite() && xAxisZ.isFinite())
    }

    private fun drawRunUp(base: FloatArray, length: Float) {
        if (length < 0.1f) return
        val count = ceil(length / 0.6f).toInt()
        for (index in 1..count) {
            val z = -min(index * 0.6f, length)
            rectangle(base, 0f, 0.012f, z, 0.022f, 0.16f, RUN_UP)
        }
        rectangle(base, 0f, 0.012f, -length, 0.55f, 0.035f, RUN_UP)
    }

    private fun drawAim(base: FloatArray) {
        drawMesh(shadow, base, 0f, 0.002f, 0f, 0.18f, 1f, 0.18f, SHADOW)
        drawMesh(ring, base, 0f, 0.013f, 0f, 0.13f, 1f, 0.13f, TEAL)
        rectangle(base, 0f, 0.014f, 0f, 0.066f, 0.008f, WHITE)
        rectangle(base, 0f, 0.014f, 0f, 0.008f, 0.066f, WHITE)
    }

    private fun outlinedRectangle(base: FloatArray, x: Float, z: Float, width: Float, length: Float) {
        // A narrow dark halo gives white marking contrast on concrete and dry pale soil.
        rectangle(base, x, 0.007f, z, width + 0.009f, length + 0.009f, LINE_HALO)
        rectangle(base, x, 0.01f, z, width, length, WHITE)
    }

    private fun rectangle(base: FloatArray, x: Float, y: Float, z: Float,
                          width: Float, length: Float, color: FloatArray) {
        drawMesh(rectangle, base, x, y, z, width, 1f, length, color)
    }

    private fun drawMesh(mesh: GlMesh, base: FloatArray, x: Float, y: Float, z: Float,
                         scaleX: Float, scaleY: Float, scaleZ: Float, color: FloatArray,
                         lit: Boolean = false, wood: Boolean = false, rotateZ: Float = 0f,
                         stumpBands: Boolean = false) {
        Matrix.setIdentityM(localMatrix, 0)
        Matrix.translateM(localMatrix, 0, x, y, z)
        if (rotateZ != 0f) Matrix.rotateM(localMatrix, 0, rotateZ, 0f, 0f, 1f)
        Matrix.scaleM(localMatrix, 0, scaleX, scaleY, scaleZ)
        Matrix.multiplyMM(modelMatrix, 0, base, 0, localMatrix, 0)
        Matrix.multiplyMM(modelView, 0, currentView, 0, modelMatrix, 0)
        Matrix.multiplyMM(modelViewProjection, 0, viewProjection, 0, modelMatrix, 0)
        if (!finiteMatrix(modelViewProjection)) return
        if (lit) {
            // Inverse-transpose is essential: stumps are very non-uniformly scaled.
            if (!Matrix.invertM(inverseModelView, 0, modelView, 0)) return
            for (column in 0..2) for (row in 0..2) {
                normalMatrix[column * 3 + row] = inverseModelView[row * 4 + column]
            }
        } else {
            normalMatrix.fill(0f)
            normalMatrix[0] = 1f; normalMatrix[4] = 1f; normalMatrix[8] = 1f
        }
        GLES20.glUniformMatrix4fv(objectMvp, 1, false, modelViewProjection, 0)
        GLES20.glUniformMatrix4fv(objectMv, 1, false, modelView, 0)
        GLES20.glUniformMatrix3fv(objectNormalMatrix, 1, false, normalMatrix, 0)
        GLES20.glUniform4fv(objectColor, 1, color, 0)
        GLES20.glUniform1f(objectLit, if (lit) 1f else 0f)
        GLES20.glUniform1f(objectWood, if (wood) 1f else 0f)
        GLES20.glUniform1f(objectStumpBands, if (stumpBands) 1f else 0f)
        mesh.draw(objectPosition, objectNormal, objectOpacity)
    }

    /** Only call with this renderer's EGL context current (for example queueEvent). */
    fun release() {
        if (backgroundProgram != 0) GLES20.glDeleteProgram(backgroundProgram)
        if (objectProgram != 0) GLES20.glDeleteProgram(objectProgram)
        if (cameraTextureId != 0) GLES20.glDeleteTextures(1, intArrayOf(cameraTextureId), 0)
        backgroundProgram = 0
        objectProgram = 0
        cameraTextureId = 0
        uvReady = false
    }

    private fun poseMatrix(pose: Pose?, destination: FloatArray): Boolean {
        if (pose == null) return false
        pose.toMatrix(destination, 0)
        return finiteMatrix(destination)
    }

    private fun finiteMatrix(values: FloatArray): Boolean =
        values.size == 16 && values.all { it.isFinite() }

    private fun finite(value: Float, fallback: Float): Float = if (value.isFinite()) value else fallback

    companion object {
        private val WHITE = floatArrayOf(0.98f, 0.99f, 1f, 1f)
        private val LINE_HALO = floatArrayOf(0.015f, 0.06f, 0.05f, 0.82f)
        private val TEAL = floatArrayOf(0.1f, 0.94f, 0.74f, 0.95f)
        private val LOCKED = floatArrayOf(0.13f, 0.87f, 0.52f, 0.75f)
        private val WOOD = floatArrayOf(0.92f, 0.78f, 0.51f, 1f)
        private val WOOD_DARK = floatArrayOf(0.56f, 0.34f, 0.15f, 1f)
        private val SHADOW = floatArrayOf(0.025f, 0.035f, 0.025f, 0.24f)
        private val CONTACT_SHADOW = floatArrayOf(0.015f, 0.02f, 0.015f, 0.47f)
        private val GUIDE = floatArrayOf(1f, 0.69f, 0.15f, 0.96f)
        private val ROUTE = floatArrayOf(0.21f, 0.88f, 0.78f, 0.62f)
        private val PITCH_EDGE = floatArrayOf(0.95f, 0.99f, 0.97f, 0.55f)
        private val RUN_UP = floatArrayOf(0.4f, 0.73f, 1f, 0.75f)

        private const val BACKGROUND_VERTEX = """
            attribute vec2 aPosition;
            attribute vec2 aUv;
            varying mediump vec2 vUv;
            void main() { gl_Position = vec4(aPosition, 0.0, 1.0); vUv = aUv; }
        """
        private const val BACKGROUND_FRAGMENT = """
            #extension GL_OES_EGL_image_external : require
            precision mediump float;
            uniform samplerExternalOES uCamera;
            varying mediump vec2 vUv;
            void main() { gl_FragColor = texture2D(uCamera, vUv); }
        """
        private const val OBJECT_VERTEX = """
            uniform mat4 uMvp;
            uniform mat4 uModelView;
            uniform mat3 uNormalMatrix;
            attribute vec3 aPosition;
            attribute vec3 aNormal;
            attribute float aOpacity;
            varying mediump vec3 vNormal;
            varying mediump vec3 vEye;
            varying mediump vec3 vLocal;
            varying mediump float vOpacity;
            void main() {
                gl_Position = uMvp * vec4(aPosition, 1.0);
                vNormal = uNormalMatrix * aNormal;
                vEye = (uModelView * vec4(aPosition, 1.0)).xyz;
                vLocal = aPosition;
                vOpacity = aOpacity;
            }
        """
        private const val OBJECT_FRAGMENT = """
            precision mediump float;
            uniform vec4 uColor;
            uniform float uLit;
            uniform float uWood;
            uniform float uStumpBands;
            uniform float uAmbient;
            uniform vec3 uLight;
            varying mediump vec3 vNormal;
            varying mediump vec3 vEye;
            varying mediump vec3 vLocal;
            varying mediump float vOpacity;
            void main() {
                vec3 color = uColor.rgb;
                if (uWood > 0.5) {
                    float grain = sin(atan(vLocal.z, vLocal.x) * 33.0 +
                                      vLocal.y * 5.0 + sin(vLocal.y * 15.0) * 0.5);
                    color *= 0.97 + 0.03 * grain;
                }
                // Paint shares the stump's single depth surface. Separate cylinders
                // only micrometres above it shimmer on mobile depth buffers.
                if (uStumpBands > 0.5) {
                    float heightMetres = vLocal.y * 0.7112;
                    if (heightMetres >= 0.590 && heightMetres <= 0.622) {
                        color = vec3(0.025, 0.42, 0.32);
                    } else if (heightMetres >= 0.634 && heightMetres <= 0.643) {
                        color = vec3(0.56, 0.34, 0.15);
                    }
                }
                if (uLit > 0.5) {
                    vec3 normal = normalize(vNormal);
                    vec3 light = normalize(uLight);
                    float diffuse = max(dot(normal, light), 0.0);
                    vec3 halfDirection = normalize(light + normalize(-vEye));
                    float specular = pow(max(dot(normal, halfDirection), 0.0), 28.0);
                    color *= (0.47 + 0.53 * diffuse) * uAmbient;
                    color += vec3(0.16) * specular;
                }
                gl_FragColor = vec4(color, uColor.a * vOpacity);
            }
        """
    }
}
