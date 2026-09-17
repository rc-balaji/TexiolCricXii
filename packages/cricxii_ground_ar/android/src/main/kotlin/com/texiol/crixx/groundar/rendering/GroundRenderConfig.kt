package com.texiol.crixx.groundar.rendering

/** Metres throughout. Wide guides are a configurable local practice aid, not a Wide decision. */
data class GroundRenderConfig(
    val lengthMetres: Float = GroundDimensions.PITCH_LENGTH,
    val wideGuides: Boolean = false,
    val guideHalfWidthMetres: Float = 0.9f,
    val runUpMetres: Float = 0f,
    val showCreases: Boolean = true,
    val showStumps: Boolean = true,
    val locked: Boolean = false,
)

/** Exact imperial-to-SI conversions from MCC Laws 6, 7 and 8 (adult pitch). */
object GroundDimensions {
    const val PITCH_LENGTH = 20.1168f // 22 yards, middle stump to middle stump.
    const val PITCH_WIDTH = 3.048f // 10 feet; not the bowling-crease width.
    const val STUMP_HEIGHT = 0.7112f // 28 inches above the ground.
    const val WICKET_WIDTH = 0.2286f // 9 inches, outside edge to outside edge.
    const val POPPING_DISTANCE = 1.2192f // 4 feet, back edge to back edge.
    const val RETURN_HALF_WIDTH = 1.3208f // 4 feet 4 inches, inside edge.
    const val BOWLING_LENGTH = 2.6416f // 8 feet 8 inches.
    const val POPPING_LENGTH = 3.6576f // Minimum 6 feet each side of centre.
    const val RETURN_LENGTH = 2.4384f // Minimum 8 feet behind the popping crease.
    const val PAINT_WIDTH = 0.045f // Presentation width; the legal edge stays exact.
    const val STUMP_RADIUS = 0.018f // 36 mm diameter, within MCC limits.
}
