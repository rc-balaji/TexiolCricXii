package com.texiol.crixx.groundar

import org.json.JSONObject

/** Settings only. Never serialize a world pose, anchor, or camera image. */
internal data class GroundLayout(
    val lengthMetres: Float = 20.1168f,
    val wideGuides: Boolean = false,
    val wideOffsetMetres: Float = .9f,
    val runUpMetres: Float = 0f,
    val showCreases: Boolean = true,
    val showStumps: Boolean = true,
    val locked: Boolean = false,
) {
    fun asMap(): Map<String, Any> = mapOf(
        "version" to 1,
        "lengthMetres" to lengthMetres.toDouble(),
        "wideGuides" to wideGuides,
        "wideOffsetMetres" to wideOffsetMetres.toDouble(),
        "runUpMetres" to runUpMetres.toDouble(),
        "showCreases" to showCreases,
        "showStumps" to showStumps,
        "locked" to locked,
    )

    fun toJson(): String = JSONObject(asMap()).toString()

    companion object {
        fun fromMap(map: Map<*, *>?): GroundLayout {
            fun number(key: String, default: Float, low: Float, high: Float): Float {
                val value = (map?.get(key) as? Number)?.toFloat() ?: default
                return if (value.isFinite()) value.coerceIn(low, high) else default
            }
            fun flag(key: String, default: Boolean) = map?.get(key) as? Boolean ?: default
            return GroundLayout(
                lengthMetres = number("lengthMetres", 20.1168f, 4f, 40f),
                wideGuides = flag("wideGuides", false),
                wideOffsetMetres = number("wideOffsetMetres", .9f, .3f, 1.3f),
                runUpMetres = number("runUpMetres", 0f, 0f, 20f),
                showCreases = flag("showCreases", true),
                showStumps = flag("showStumps", true),
                locked = flag("locked", false),
            )
        }

        fun fromJson(raw: String?): GroundLayout = try {
            val json = JSONObject(raw ?: "{}")
            fromMap(json.keys().asSequence().associateWith { json.get(it) })
        } catch (_: Exception) {
            GroundLayout()
        }
    }
}
