package com.texiol.crixx.groundar

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.view.View

/** Screen-space aiming aid. Only the separate plane mesh describes detected ground. */
internal class GroundTargetView(context: Context) : View(context) {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val bounds = RectF()
    private val density = resources.displayMetrics.density
    private var active = true
    private var tracking = false
    private var surfaceFound = false
    private var ready = false

    init {
        isClickable = false
        importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
    }

    fun update(active: Boolean, tracking: Boolean, surfaceFound: Boolean, ready: Boolean) {
        if (this.active == active && this.tracking == tracking &&
            this.surfaceFound == surfaceFound && this.ready == ready) return
        this.active = active
        this.tracking = tracking
        this.surfaceFound = surfaceFound
        this.ready = ready
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        if (!active) return
        val x = width / 2f
        val y = height / 2f
        val radius = 23f * density
        bounds.set(x - radius, y - radius, x + radius, y + radius)
        paint.style = Paint.Style.STROKE
        paint.strokeCap = Paint.Cap.ROUND
        paint.strokeWidth = 5f * density
        paint.color = 0x66000000
        for (angle in 0..3) canvas.drawArc(bounds, angle * 90f + 12f, 66f, false, paint)
        paint.strokeWidth = 2f * density
        paint.color = when {
            !tracking -> 0xFFC9D3D7.toInt()
            ready -> 0xFF78E7BA.toInt()
            surfaceFound -> 0xFFFFCF78.toInt()
            else -> Color.WHITE
        }
        for (angle in 0..3) canvas.drawArc(bounds, angle * 90f + 12f, 66f, false, paint)
        paint.style = Paint.Style.FILL
        canvas.drawCircle(x, y, 2.5f * density, paint)
    }
}
