package com.texiol.crixx.groundar

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.os.Bundle
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.Switch
import android.widget.TextView
import android.widget.Toast
import com.google.ar.core.Anchor
import com.google.ar.core.ArCoreApk
import com.google.ar.core.Config
import com.google.ar.core.Frame
import com.google.ar.core.HitResult
import com.google.ar.core.Plane
import com.google.ar.core.Pose
import com.google.ar.core.Session
import com.google.ar.core.TrackingFailureReason
import com.google.ar.core.TrackingState
import com.google.ar.core.exceptions.CameraNotAvailableException
import com.google.ar.core.exceptions.UnavailableApkTooOldException
import com.google.ar.core.exceptions.UnavailableArcoreNotInstalledException
import com.google.ar.core.exceptions.UnavailableDeviceNotCompatibleException
import com.google.ar.core.exceptions.UnavailableSdkTooOldException
import com.google.ar.core.exceptions.UnavailableUserDeclinedInstallationException
import com.texiol.crixx.groundar.rendering.GroundArRenderer
import com.texiol.crixx.groundar.rendering.GroundRenderConfig
import java.util.ArrayDeque
import java.util.concurrent.ConcurrentLinkedQueue
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/** A real ARCore camera/plane/anchor session, entirely separate from score data. */
class GroundArActivity : Activity(), GLSurfaceView.Renderer {
    private lateinit var surface: GLSurfaceView
    private lateinit var status: TextView
    private lateinit var stage: TextView
    private lateinit var placeButton: Button
    private lateinit var lockButton: Button
    private lateinit var moveButton: Button
    private val renderer = GroundArRenderer()
    @Volatile private var session: Session? = null
    @Volatile private var layout = GroundLayout()
    @Volatile private var tracking = false
    @Volatile private var moveArmed = false
    @Volatile private var finishingScene = false
    @Volatile private var saveRequested = false
    @Volatile private var renderingFailed = false
    private var installRequested = false
    private var permissionRequested = false
    private var resumed = false
    private var surfaceRunning = false
    private var failureDialog = false
    private var unregisterBack: (() -> Unit)? = null
    private var textureSession: Session? = null
    @Volatile private var width = 1
    @Volatile private var height = 1
    private var lastUiUpdate = 0L
    private val viewMatrix = FloatArray(16)
    private val projectionMatrix = FloatArray(16)
    private val taps = ConcurrentLinkedQueue<Tap>()

    // These structures are owned only by the GL thread. Undo keeps anchors alive
    // rather than recreating far-away anchors from saved coordinates.
    private var placement = Placement()
    private val history = ArrayDeque<SceneState>()
    private val future = ArrayDeque<SceneState>()
    private val ownedAnchors = mutableSetOf<Anchor>()

    private data class Tap(val x: Float, val y: Float)
    private data class Placement(
        val near: Anchor? = null,
        val far: Anchor? = null,
        val virtualNear: Pose? = null,
        val virtualFar: Pose? = null,
        val nearOffset: Pose = Pose.IDENTITY,
        val farOffset: Pose = Pose.IDENTITY,
        val directionChosen: Boolean = false,
    ) {
        fun nearPose(): Pose? = virtualNear ?: near?.pose?.compose(nearOffset)
        fun farPose(): Pose? = virtualFar ?: far?.pose?.compose(farOffset)
        fun hasNear() = virtualNear != null || near != null
        fun hasFar() = virtualFar != null || far != null
    }
    private data class SceneState(val placement: Placement, val layout: GroundLayout)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.statusBarColor = Color.rgb(9, 18, 24)
        window.navigationBarColor = Color.rgb(9, 18, 24)
        // Restoring preferences never pretends to restore a physical location.
        layout = GroundLayout.fromJson(
            savedInstanceState?.getString(LAYOUT_EXTRA)
                ?: intent.getStringExtra(LAYOUT_EXTRA),
        ).copy(locked = false)
        installRequested = savedInstanceState?.getBoolean("installRequested") ?: false
        buildUi()
        if (Build.VERSION.SDK_INT >= 33) {
            unregisterBack = Api33Back.register(this) { saveAndFinish() }
        }
    }

    private fun buildUi() {
        val root = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }
        surface = GLSurfaceView(this).apply {
            preserveEGLContextOnPause = true
            setEGLContextClientVersion(2)
            setEGLConfigChooser(8, 8, 8, 8, 16, 0)
            setRenderer(this@GroundArActivity)
            renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
        }
        root.addView(surface, FrameLayout.LayoutParams(-1, -1))
        var downX = 0f
        var downY = 0f
        surface.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> { downX = event.x; downY = event.y }
                MotionEvent.ACTION_UP -> {
                    if (abs(event.x - downX) + abs(event.y - downY) < dp(18)) {
                        taps.offer(Tap(event.x, event.y))
                        surface.performClick()
                    }
                }
            }
            true
        }

        val top = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(14), dp(10), dp(14), dp(10))
            background = rounded(0xDD0B171F.toInt(), 20f)
        }
        val heading = LinearLayout(this).apply { gravity = Gravity.CENTER_VERTICAL }
        val back = control("‹", 36) { saveAndFinish() }
        back.contentDescription = "Return to ground preview and save settings"
        heading.addView(back)
        heading.addView(label("GROUND AR", 17, true), LinearLayout.LayoutParams(0, -2, 1f))
        heading.addView(control("Save", 65) { saveAndFinish() })
        top.addView(heading)
        stage = label("01  /  PLACE 3D PITCH", 11, true).apply {
            setTextColor(0xFF78E7BA.toInt())
            setPadding(0, dp(6), 0, dp(5))
        }
        status = label("Tap Place to create the pitch. Scan is optional for refinement.", 13)
        top.addView(stage)
        top.addView(status)
        top.addView(label("Visual guide • verify distances on the ground", 10).apply {
            setTextColor(0xFFB4C5CC.toInt()); setPadding(0, dp(7), 0, 0)
        })
        root.addView(top, FrameLayout.LayoutParams(-1, -2, Gravity.TOP).apply {
            setMargins(dp(12), dp(12), dp(12), 0)
        })

        val bottom = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(10), dp(10), dp(10), dp(10))
            background = rounded(0xEE0B171F.toInt(), 20f)
        }
        val primary = LinearLayout(this).apply { gravity = Gravity.CENTER_VERTICAL }
        placeButton = control("Place batting end", 0) { taps.offer(Tap(width / 2f, height / 2f)) }
        placeButton.setTextColor(0xFF092B21.toInt())
        placeButton.background = rounded(0xFF78E7BA.toInt(), 12f)
        primary.addView(placeButton, LinearLayout.LayoutParams(0, dp(48), 1f).apply {
            marginEnd = dp(8)
        })
        lockButton = control("Lock", 76) { onGl {
            if (!placement.hasFar()) { hint("Place the pitch before locking."); return@onGl }
            if (!tracking) { hint("Wait for tracking to recover."); return@onGl }
            layout = layout.copy(locked = !layout.locked)
            moveArmed = false
        } }
        primary.addView(lockButton)
        bottom.addView(primary)

        val actions = LinearLayout(this)
        moveButton = control("Move", 74) { onGl {
            if (!editable()) return@onGl
            moveArmed = !moveArmed
            hint(if (moveArmed) "Tap scanned ground for the new batting end." else "Move cancelled.")
        } }
        actions.addView(moveButton)
        actions.addView(control("Undo", 74) { onGl {
            if (layout.locked) { hint("Unlock before undoing a change."); return@onGl }
            val previous = history.pollLast()
            if (previous == null) { hint("No change to undo."); return@onGl }
            future.addLast(SceneState(placement, layout))
            placement = previous.placement
            layout = previous.layout.copy(locked = false)
            moveArmed = false
            cleanupAnchors()
        } })
        actions.addView(control("Redo", 74) { onGl {
            if (layout.locked) { hint("Unlock before redoing a change."); return@onGl }
            val next = future.pollLast()
            if (next == null) { hint("No change to redo."); return@onGl }
            history.addLast(SceneState(placement, layout))
            placement = next.placement
            layout = next.layout.copy(locked = false)
            moveArmed = false
            cleanupAnchors()
        } })
        actions.addView(control("Settings", 94) { showSettings() })
        actions.addView(control("Remove", 90) { onGl {
            if (layout.locked) { hint("Unlock before removing the pitch."); return@onGl }
            remember(); placement = Placement(); moveArmed = false; cleanupAnchors()
        } })
        actions.addView(control("Reset", 80) {
            if (layout.locked) { hint("Unlock before resetting the ground."); return@control }
            AlertDialog.Builder(this).setTitle("Reset this ground?")
                .setMessage("Remove both ends and return to the standard 22-yard layout. You can undo this within this session.")
                .setNegativeButton("Keep", null)
                .setPositiveButton("Reset") { _, _ -> onGl {
                    remember(); placement = Placement(); layout = GroundLayout()
                    moveArmed = false; cleanupAnchors()
                } }.show()
        })
        bottom.addView(horizontal(actions))
        val fine = LinearLayout(this)
        fine.addView(control("↶ 2°", 66) { onGl { adjust(0f, 0f, 0f, -2f) } })
        fine.addView(control("↷ 2°", 66) { onGl { adjust(0f, 0f, 0f, 2f) } })
        fine.addView(control("← 5cm", 80) { onGl { adjust(-.05f, 0f, 0f, 0f) } })
        fine.addView(control("5cm →", 80) { onGl { adjust(.05f, 0f, 0f, 0f) } })
        fine.addView(control("↑ 5cm", 80) { onGl { adjust(0f, 0f, .05f, 0f) } })
        fine.addView(control("↓ 5cm", 80) { onGl { adjust(0f, 0f, -.05f, 0f) } })
        bottom.addView(horizontal(fine))
        root.addView(bottom, FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM).apply {
            setMargins(dp(12), 0, dp(12), dp(12))
        })
        root.setOnApplyWindowInsetsListener { view, insets ->
            view.setPadding(insets.systemWindowInsetLeft, insets.systemWindowInsetTop,
                insets.systemWindowInsetRight, insets.systemWindowInsetBottom)
            insets
        }
        setContentView(root)
    }

    override fun onResume() {
        super.onResume()
        resumed = true
        startSession()
    }

    private fun startSession() {
        if (!resumed || finishingScene || saveRequested || failureDialog || surfaceRunning) return
        if (checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            if (!permissionRequested) {
                permissionRequested = true
                requestPermissions(arrayOf(Manifest.permission.CAMERA), CAMERA_PERMISSION)
            }
            return
        }
        try {
            if (session == null) {
                when (ArCoreApk.getInstance().requestInstall(this, !installRequested)) {
                    ArCoreApk.InstallStatus.INSTALL_REQUESTED -> {
                        installRequested = true
                        status.text = "Complete Google Play Services for AR installation to continue."
                        return
                    }
                    ArCoreApk.InstallStatus.INSTALLED -> Unit
                }
                val created = Session(this)
                try {
                    created.configure(Config(created).apply {
                        planeFindingMode = Config.PlaneFindingMode.HORIZONTAL
                        focusMode = Config.FocusMode.AUTO
                        updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
                        lightEstimationMode = Config.LightEstimationMode.AMBIENT_INTENSITY
                    })
                    session = created
                } catch (error: Exception) {
                    created.close()
                    throw error
                }
            }
            session!!.resume()
            surface.onResume()
            surfaceRunning = true
        } catch (_: UnavailableUserDeclinedInstallationException) {
            showFailure("AR installation was cancelled. The ground preview is still available.")
        } catch (_: UnavailableDeviceNotCompatibleException) {
            showFailure("This phone does not support ARCore. Use the interactive ground preview instead.")
        } catch (_: UnavailableArcoreNotInstalledException) {
            showFailure("Google Play Services for AR is not installed. Install it, then reopen Ground AR.")
        } catch (_: UnavailableApkTooOldException) {
            showFailure("Update Google Play Services for AR, then reopen Ground AR.")
        } catch (_: UnavailableSdkTooOldException) {
            showFailure("This device needs a newer Ground AR build. The ground preview remains available.")
        } catch (_: CameraNotAvailableException) {
            showFailure("The camera is in use or unavailable. Close other camera apps and try again.")
        } catch (_: SecurityException) {
            showFailure("Camera permission is needed for Ground AR. You can continue using the ground preview.")
        } catch (_: Exception) {
            showFailure("Ground AR could not start on this phone. Return to the preview and try again.")
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != CAMERA_PERMISSION) return
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            startSession()
        } else {
            failureDialog = true
            val builder = AlertDialog.Builder(this)
                .setTitle("Camera access is off")
                .setMessage("Ground AR uses the camera for live ground tracking. The preview works without camera access.")
                .setNegativeButton("Use preview") { _, _ -> saveAndFinish() }
                .setOnCancelListener { saveAndFinish() }
            if (!shouldShowRequestPermissionRationale(Manifest.permission.CAMERA)) {
                builder.setPositiveButton("App settings") { _, _ ->
                    failureDialog = false
                    permissionRequested = false
                    startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.parse("package:$packageName")))
                }
            } else {
                builder.setPositiveButton("Allow camera") { _, _ ->
                    failureDialog = false; permissionRequested = false; startSession()
                }
            }
            builder.show()
        }
    }

    override fun onPause() {
        resumed = false
        // Stop all frame updates before pausing the camera/session.
        if (::surface.isInitialized) surface.onPause()
        surfaceRunning = false
        session?.pause()
        super.onPause()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        outState.putString(LAYOUT_EXTRA, layout.toJson())
        outState.putBoolean("installRequested", installRequested)
        super.onSaveInstanceState(outState)
    }

    override fun onDestroy() {
        unregisterBack?.invoke()
        unregisterBack = null
        val closing = session
        session = null
        // onPause has joined the rendering thread before these anchors are freed.
        ownedAnchors.forEach { it.detach() }
        ownedAnchors.clear()
        history.clear()
        future.clear()
        if (closing != null) Thread({ closing.close() }, "ground-ar-close").start()
        super.onDestroy()
    }

    @Deprecated("Android callback retained for devices from API 24")
    override fun onBackPressed() = saveAndFinish()

    private fun saveAndFinish() {
        if (finishingScene || saveRequested) return
        saveRequested = true
        if (surfaceRunning && !renderingFailed) {
            // Existing settings/lock commands finish first on their owning GL
            // thread. New commands stop at the UI boundary once Save is tapped.
            surface.queueEvent {
                val saved = layout.toJson()
                runOnUiThread { completeFinish(saved) }
            }
            // A stopped/lost GL surface must never trap the user in this screen.
            surface.postDelayed({ completeFinish(layout.toJson()) }, 750)
        } else {
            completeFinish(layout.toJson())
        }
    }

    private fun completeFinish(saved: String) {
        if (finishingScene || isDestroyed) return
        finishingScene = true
        setResult(RESULT_OK, Intent().putExtra(LAYOUT_EXTRA, saved))
        finish()
    }

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        try {
            renderer.initialize()
            textureSession = null
        } catch (_: Exception) {
            renderingFailed = true
            runOnUiThread { showFailure("This phone could not create the AR graphics view. Use the ground preview.") }
        }
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        this.width = width.coerceAtLeast(1)
        this.height = height.coerceAtLeast(1)
        GLES20.glViewport(0, 0, width, height)
    }

    override fun onDrawFrame(gl: GL10?) {
        val current = session ?: return
        if (finishingScene || renderingFailed) return
        try {
            if (textureSession !== current) {
                current.setCameraTextureName(renderer.cameraTextureId)
                textureSession = current
            }
            @Suppress("DEPRECATION")
            current.setDisplayGeometry(windowManager.defaultDisplay.rotation, width, height)
            val frame = current.update()
            val camera = frame.camera
            tracking = camera.trackingState == TrackingState.TRACKING
            camera.getViewMatrix(viewMatrix, 0)
            camera.getProjectionMatrix(projectionMatrix, 0, .1f, 80f)
            val centerHit = if (tracking) groundHit(frame, width / 2f, height / 2f) else null
            var tap = taps.poll()
            while (tap != null) {
                if (tracking) handleTap(frame, tap) else hint("Tracking is paused. Move slowly and scan the ground.")
                tap = taps.poll()
            }
            val nearTracked = placement.near?.trackingState == TrackingState.TRACKING
            val farTracked = placement.far?.trackingState == TrackingState.TRACKING
            val near = if (tracking && (nearTracked || placement.virtualNear != null)) placement.nearPose() else null
            val far = if (tracking && (farTracked || placement.virtualFar != null)) placement.farPose() else null
            // An unconfirmed end is only an aim marker, never a claimed anchor.
            val aim = if (placement.directionChosen && !placement.hasFar() && near != null) {
                predictedFar(near)
            } else if (!layout.locked && (!placement.hasNear() || !placement.directionChosen || moveArmed)) {
                centerHit?.hitPose
            } else null
            renderer.draw(frame, viewMatrix, projectionMatrix, near, far, renderConfig(), aim)
            updateStatus(frame, centerHit, nearTracked, farTracked)
        } catch (_: CameraNotAvailableException) {
            renderingFailed = true
            runOnUiThread { showFailure("The camera stopped. Return to the preview, close other camera apps and reopen AR.") }
        } catch (_: Exception) {
            tracking = false
            renderingFailed = true
            runOnUiThread { showFailure("Ground tracking stopped unexpectedly. Reopen AR and scan the ground again.") }
        }
    }

    private fun groundHit(frame: Frame, x: Float, y: Float): HitResult? =
        frame.hitTest(x, y).firstOrNull { hit ->
            val plane = hit.trackable as? Plane
            plane != null && plane.trackingState == TrackingState.TRACKING &&
                plane.type == Plane.Type.HORIZONTAL_UPWARD_FACING && plane.isPoseInPolygon(hit.hitPose)
        }

    private fun handleTap(frame: Frame, tap: Tap) {
        if (layout.locked) { hint("Unlock to adjust the ground."); return }
        if (placement.near != null && placement.near?.trackingState != TrackingState.TRACKING && !moveArmed) {
            hint("Wait for the batting-end anchor to track again, or use Move to place it on newly scanned ground."); return
        }
        val hit = groundHit(frame, tap.x, tap.y)
        if (hit == null && placement.hasNear() && !moveArmed) {
            hint("The pitch is already placed. Use the adjustment controls to refine it."); return
        }
        val near = placement.nearPose()
        when {
            near == null || moveArmed -> {
                remember()
                val newNear = hit?.hitPose ?: virtualPlacementPose(frame.camera.pose)
                val newAnchor = hit?.createAnchor()?.also { ownedAnchors.add(it) }
                val facing = yawPose(newNear.tx(), newNear.ty(), newNear.tz(), cameraYaw(frame.camera.pose))
                val nearPose = yawPose(newNear.tx(), newNear.ty(), newNear.tz(), yaw(facing))
                placement = if (newAnchor != null) {
                    Placement(
                        near = newAnchor,
                        nearOffset = newAnchor.pose.inverse().compose(nearPose),
                        virtualFar = predictedFar(nearPose),
                        directionChosen = true,
                    )
                } else {
                    Placement(
                        virtualNear = nearPose,
                        virtualFar = predictedFar(nearPose),
                        directionChosen = true,
                    )
                }
                moveArmed = false
                cleanupAnchors()
                hint("Pitch placed. Adjust rotation and height, then move the phone down to check the ground.")
            }
            !placement.directionChosen -> {
                if (hit == null) {
                    hint("Tap Place again after pointing the phone toward the pitch direction."); return
                }
                val dx = hit.hitPose.tx() - near.tx()
                val dz = hit.hitPose.tz() - near.tz()
                val direction = GroundPlacementMath.direction(dx, dz)
                if (direction == null) {
                    hint("Choose a direction at least 1 metre from the batting end."); return
                }
                if (abs(hit.hitPose.ty() - near.ty()) > .4f) {
                    hint("Choose direction on the same ground level."); return
                }
                remember()
                val facing = yawPose(near.tx(), near.ty(), near.tz(), direction)
                placement = placement.copy(
                    nearOffset = placement.near!!.pose.inverse().compose(facing),
                    virtualFar = predictedFar(facing),
                    directionChosen = true,
                )
                hint("Direction set. Bowling end was placed automatically.")
            }
            else -> hint("Use Move, rotate or the 5 cm controls to adjust the pitch.")
        }
    }

    private fun editable(): Boolean {
        if (layout.locked) { hint("Unlock before editing."); return false }
        if (!tracking) { hint("Wait for tracking to recover."); return false }
        if (!placement.hasNear()) { hint("Place the batting end first."); return false }
        if (placement.near?.trackingState != TrackingState.TRACKING ||
            (placement.far != null && placement.far?.trackingState != TrackingState.TRACKING)) {
            hint("Wait for both placed ends to track before making fine adjustments."); return false
        }
        return true
    }

    private fun adjust(sideways: Float, forward: Float, vertical: Float, degrees: Float) {
        if (!editable()) return
        val near = placement.nearPose() ?: return
        val adjusted = GroundPlacementMath.adjusted(near.tx(), near.ty(), near.tz(),
            yaw(near), sideways, forward, vertical, degrees)
        val target = yawPose(adjusted.x, adjusted.y, adjusted.z, adjusted.yaw)
        remember()
        placement = if (placement.near != null) {
            val nearOffset = placement.near.pose.inverse().compose(target)
            if (translationLength(nearOffset) > 1f) {
                hint("For a larger adjustment, use Move and scan the new position.")
                return
            }
            placement.copy(nearOffset = nearOffset, virtualFar = null)
        } else {
            placement.copy(virtualNear = target, virtualFar = null)
        }
        realignFar()
        cleanupAnchors()
    }

    /** Keep small edits attached to both local anchors; large edits need rescan. */
    private fun realignFar() {
        val near = placement.nearPose() ?: return
        val expected = predictedFar(near)
        val anchor = placement.far
        if (anchor == null) {
            placement = placement.copy(virtualFar = expected)
            return
        }
        // Fine controls are horizontal. Preserve the independently detected
        // bowling-end ground height instead of projecting it onto near-end Y.
        val groundHeight = placement.farPose()?.ty() ?: expected.ty()
        val target = yawPose(expected.tx(), groundHeight, expected.tz(), yaw(expected))
        val offset = anchor.pose.inverse().compose(target)
        if (translationLength(offset) > 1f) {
            placement = placement.copy(far = null, farOffset = Pose.IDENTITY)
            layout = layout.copy(locked = false)
            hint("The bowling end moved. Walk to its marker and confirm it again.")
        } else {
            placement = placement.copy(farOffset = offset)
        }
    }

    private fun predictedFar(near: Pose): Pose {
        val target = GroundPlacementMath.farEnd(near.tx(), near.ty(), near.tz(),
            yaw(near), layout.lengthMetres)
        return yawPose(target.x, target.y, target.z, target.yaw)
    }

    private fun virtualPlacementPose(camera: Pose): Pose {
        val yaw = cameraYaw(camera)
        val distance = 1.2f
        return yawPose(
            camera.tx() + sin(yaw) * distance,
            camera.ty() - 1.2f,
            camera.tz() + cos(yaw) * distance,
            yaw,
        )
    }

    private fun cameraYaw(camera: Pose): Float = atan2(camera.zAxis[0], camera.zAxis[2])

    private fun remember() {
        future.clear()
        history.addLast(SceneState(placement, layout))
        while (history.size > 20) history.removeFirst()
        cleanupAnchors()
    }

    private fun cleanupAnchors() {
        val retained = mutableSetOf<Anchor>()
        fun retain(value: Placement) { value.near?.let(retained::add); value.far?.let(retained::add) }
        retain(placement)
        history.forEach { retain(it.placement) }
        future.forEach { retain(it.placement) }
        val old = ownedAnchors.filter { it !in retained }
        old.forEach { it.detach(); ownedAnchors.remove(it) }
    }

    private fun updateStatus(frame: Frame, hit: HitResult?, nearTracked: Boolean, farTracked: Boolean) {
        val now = SystemClock.uptimeMillis()
        if (now - lastUiUpdate < 250) return
        lastUiUpdate = now
        val hasNear = placement.hasNear()
        val hasFar = placement.hasFar()
        val directed = placement.directionChosen
        val locked = layout.locked
        val near = if (nearTracked) placement.nearPose() else null
        val far = if (farTracked) placement.farPose() else null
        val alignment = if (tracking && near != null && far != null) {
            GroundPlacementMath.alignment(
                GroundPlacementMath.Target(near.tx(), near.ty(), near.tz(), yaw(near)),
                GroundPlacementMath.Target(far.tx(), far.ty(), far.tz(), yaw(far)),
                layout.lengthMetres,
            )
        } else null
        val shifted = alignment != null &&
            (alignment.endpointOffset > .15f || alignment.yawErrorDegrees > 3f)
        val spacing = alignment?.let {
            "${format(it.distance)} m tracked / ${format(layout.lengthMetres)} m target"
        } ?: "${format(layout.lengthMetres)} m target"
        val summary = when {
            !tracking -> when (frame.camera.trackingFailureReason) {
                TrackingFailureReason.INSUFFICIENT_LIGHT -> "More light is needed. Move to a brighter area."
                TrackingFailureReason.INSUFFICIENT_FEATURES -> "Scan textured ground; plain surfaces are difficult to track."
                TrackingFailureReason.EXCESSIVE_MOTION -> "Slow down and hold the phone steady."
                TrackingFailureReason.CAMERA_UNAVAILABLE -> "The camera is unavailable. Close other camera apps."
                else -> "Tracking paused. Move slowly and rescan the same surroundings."
            }
            hasNear && placement.near != null && !nearTracked -> "Batting-end anchor tracking is paused. The visual pitch remains fixed."
            hasFar && placement.far != null && !farTracked -> "Bowling-end anchor tracking is paused. The visual pitch remains fixed."
            moveArmed -> "Tap detected ground to reposition the batting end and choose direction again."
            !hasNear -> "Tap Place to create a stable 3D pitch. Scan is optional."
            !directed -> "Point the phone in the pitch direction, then tap the ground."
            !hasFar -> "Adjust the batting end; the bowling end will appear automatically."
            shifted -> "$spacing. Alignment shifted (${format(alignment!!.endpointOffset)} m / ${format(alignment.yawErrorDegrees)}°). Recheck the ends before marking."
            locked -> "$spacing • locked. Walk around to inspect. Verify with a tape before marking."
            else -> "$spacing. Adjust, inspect, then lock."
        }
        runOnUiThread {
            if (finishingScene || failureDialog) return@runOnUiThread
            stage.text = when {
                !tracking -> "TRACKING PAUSED"
                !hasNear -> "01  /  PLACE 3D PITCH"
                !directed -> "02  /  CHOOSE DIRECTION"
                !hasFar -> "03  /  SET BOWLING END"
                shifted -> "CHECK ALIGNMENT  /  TRACKING SHIFT"
                locked -> "GROUND READY  /  LOCKED"
                else -> "04  /  ADJUST & LOCK"
            }
            status.text = summary
            placeButton.text = when {
                moveArmed -> "Place new batting end"
                !hasNear -> "Place pitch"
                !directed -> "Set direction"
                !hasFar -> "Place bowling end"
                else -> "Both ends placed"
            }
            placeButton.isEnabled = tracking && !locked && (!hasFar || moveArmed)
            placeButton.alpha = if (placeButton.isEnabled) 1f else .55f
            lockButton.text = if (locked) "Unlock" else "Lock"
            lockButton.isEnabled = tracking && hasFar && (nearTracked || placement.virtualNear != null) &&
                (farTracked || placement.virtualFar != null)
            moveButton.text = if (moveArmed) "Cancel" else "Move"
        }
    }

    private fun showSettings() {
        if (layout.locked) { hint("Unlock before changing the layout."); return }
        val original = layout
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; setPadding(dp(24), dp(8), dp(24), dp(16))
        }
        content.addView(label("Pitch length in metres (4–40)", 13))
        val length = numeric(original.lengthMetres)
        content.addView(length)
        content.addView(control("Use standard 22 yards", 230) { length.setText("20.1168") })
        val creases = settingSwitch("Crease markings", original.showCreases)
        val stumps = settingSwitch("Stumps and bails", original.showStumps)
        val wides = settingSwitch("Wide crease guides (striker + non-striker)", original.wideGuides)
        content.addView(creases); content.addView(stumps); content.addView(wides)
        content.addView(label("Wide guide offset from centre (0.3–1.3 m)", 12))
        val wideOffset = numeric(original.wideOffsetMetres)
        content.addView(wideOffset)
        content.addView(label("Bowling-end run-up (0–20 m; 0 hides)", 12))
        val runUp = numeric(original.runUpMetres)
        content.addView(runUp)
        content.addView(label("Wide crease guides are shown at both striker and non-striker ends. They are a drawing aid, not an umpiring decision.", 12))
        val dialog = AlertDialog.Builder(this).setTitle("Ground layout")
            .setView(ScrollView(this).apply { addView(content) })
            .setNegativeButton("Cancel", null).setPositiveButton("Apply", null).create()
        dialog.setOnShowListener {
            dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener {
                fun valid(field: EditText, low: Float, high: Float): Float? {
                    val value = field.text.toString().trim().toFloatOrNull()
                    if (value == null || !value.isFinite() || value !in low..high) {
                        field.error = "Enter a value from $low to $high"; return null
                    }
                    return value
                }
                val metres = valid(length, 4f, 40f) ?: return@setOnClickListener
                val offset = valid(wideOffset, .3f, 1.3f) ?: return@setOnClickListener
                val run = valid(runUp, 0f, 20f) ?: return@setOnClickListener
                val showCreases = creases.isChecked
                val showStumps = stumps.isChecked
                val showWides = wides.isChecked
                onGl {
                    remember()
                    val lengthChanged = abs(layout.lengthMetres - metres) > .00001f
                    layout = layout.copy(lengthMetres = metres, showCreases = showCreases,
                        showStumps = showStumps, wideGuides = showWides,
                        wideOffsetMetres = offset, runUpMetres = run)
                    if (lengthChanged) realignFar()
                    cleanupAnchors()
                }
                dialog.dismiss()
            }
        }
        dialog.show()
    }

    private fun renderConfig() = GroundRenderConfig(
        lengthMetres = layout.lengthMetres, wideGuides = layout.wideGuides,
        guideHalfWidthMetres = layout.wideOffsetMetres,
        runUpMetres = layout.runUpMetres, showCreases = layout.showCreases,
        showStumps = layout.showStumps, locked = layout.locked,
    )

    private fun showFailure(message: String) {
        if (failureDialog || finishingScene || isFinishing || isDestroyed) return
        failureDialog = true
        status.text = message
        AlertDialog.Builder(this).setTitle("Ground AR unavailable").setMessage(message)
            .setPositiveButton("Return to preview") { _, _ -> saveAndFinish() }
            .setOnCancelListener { saveAndFinish() }.show()
    }

    private fun onGl(action: () -> Unit) {
        if (saveRequested || finishingScene) return
        surface.queueEvent {
            if (!finishingScene) {
                action()
                lastUiUpdate = 0
            }
        }
    }

    private fun hint(text: String) = runOnUiThread {
        if (!finishingScene) Toast.makeText(this, text, Toast.LENGTH_LONG).show()
    }

    private fun label(text: String, size: Int, bold: Boolean = false) = TextView(this).apply {
        this.text = text; textSize = size.toFloat(); setTextColor(Color.WHITE)
        if (bold) setTypeface(typeface, Typeface.BOLD)
    }

    private fun control(text: String, width: Int, action: () -> Unit) = Button(this).apply {
        this.text = text; textSize = 12f; isAllCaps = false
        setTextColor(Color.WHITE); minWidth = 0; minimumWidth = 0
        setPadding(dp(8), 0, dp(8), 0)
        background = rounded(0xFF20343F.toInt(), 10f)
        layoutParams = LinearLayout.LayoutParams(dp(width), dp(44)).apply {
            setMargins(dp(3), dp(4), dp(3), dp(4))
        }
        setOnClickListener { action() }
    }

    private fun horizontal(row: LinearLayout) = HorizontalScrollView(this).apply {
        isHorizontalScrollBarEnabled = false; addView(row)
    }

    private fun numeric(value: Float) = EditText(this).apply {
        inputType = android.text.InputType.TYPE_CLASS_NUMBER or android.text.InputType.TYPE_NUMBER_FLAG_DECIMAL
        setSingleLine(true); setText(value.toString()); setTextColor(Color.WHITE)
        textSize = 16f
    }

    private fun settingSwitch(text: String, checked: Boolean) = Switch(this).apply {
        this.text = text; isChecked = checked; setTextColor(Color.WHITE)
        setPadding(0, dp(10), 0, dp(10))
    }

    private fun rounded(color: Int, radius: Float) = GradientDrawable().apply {
        setColor(color); cornerRadius = dp(radius.toInt()).toFloat()
    }
    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
    private fun yaw(pose: Pose) = atan2(pose.zAxis[0], pose.zAxis[2])
    private fun yawPose(x: Float, y: Float, z: Float, yaw: Float) = Pose(
        floatArrayOf(x, y, z), floatArrayOf(0f, sin(yaw / 2f), 0f, cos(yaw / 2f)),
    )
    private fun distance(a: Pose, b: Pose): Float {
        val x = a.tx() - b.tx(); val y = a.ty() - b.ty(); val z = a.tz() - b.tz()
        return sqrt(x * x + y * y + z * z)
    }
    private fun horizontalDistance(a: Pose, b: Pose): Float {
        val x = a.tx() - b.tx(); val z = a.tz() - b.tz(); return sqrt(x * x + z * z)
    }
    private fun translationLength(pose: Pose) = sqrt(pose.tx() * pose.tx() + pose.ty() * pose.ty() + pose.tz() * pose.tz())
    private fun format(value: Float) = String.format(java.util.Locale.US, "%.2f", value)

    companion object {
        const val LAYOUT_EXTRA = "com.texiol.crixx.groundar.LAYOUT"
        private const val CAMERA_PERMISSION = 241
    }

    /** Keep new platform classes out of the API-24 lifecycle path. */
    @android.annotation.TargetApi(33)
    private object Api33Back {
        fun register(activity: Activity, action: () -> Unit): () -> Unit {
            val callback = android.window.OnBackInvokedCallback { action() }
            activity.onBackInvokedDispatcher.registerOnBackInvokedCallback(
                android.window.OnBackInvokedDispatcher.PRIORITY_DEFAULT, callback,
            )
            return { activity.onBackInvokedDispatcher.unregisterOnBackInvokedCallback(callback) }
        }
    }
}
