package joel.scripturememory.ui.packs

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import joel.scripturememory.model.Pack
import joel.scripturememory.model.VerseNumbering

internal fun colorFromHex(hex: String): Color? {
    val digits = hex.trim().removePrefix("#")
    if (digits.length != 6) return null
    val value = digits.toLongOrNull(16) ?: return null
    return Color(0xFF000000 or value)
}

private fun Color.hsv(): FloatArray =
    FloatArray(3).also { android.graphics.Color.colorToHSV(toArgb(), it) }

private fun hsvColor(hue: Float, saturation: Float, value: Float): Color =
    Color(android.graphics.Color.HSVToColor(floatArrayOf(hue, saturation, value)))

internal fun Color.darkened(amount: Float): Color {
    val c = hsv()
    return hsvColor(c[0], c[1], c[2] * (1 - amount))
}

internal fun Color.lightened(amount: Float): Color {
    val t = amount.coerceIn(0f, 1f)
    return Color(red + (1 - red) * t, green + (1 - green) * t, blue + (1 - blue) * t)
}

internal val Color.muted: Color
    get() {
        val c = hsv()
        return hsvColor(c[0], c[1] * 0.55f, c[2] * 0.7f)
    }

internal val Color.hueDegrees: Float get() = hsv()[0]

val Pack.fieldColor: Color get() = colorFromHex(color) ?: Color(0xFF8E8E93)

val Pack.fieldIsLight: Boolean
    get() {
        val c = fieldColor
        return 0.299f * c.red + 0.587f * c.green + 0.114f * c.blue > 0.85f
    }

val Pack.inkColor: Color
    get() = if (fieldIsLight) Color(0.72f, 0.16f, 0.11f) else Color.White

val Pack.tint: Color get() = if (fieldIsLight) inkColor else fieldColor

val Pack.shortName: String
    get() {
        if (name.startsWith("DEP") || name.startsWith("TMS 180")) {
            for (separator in listOf(": ", " · ")) {
                val at = name.indexOf(separator)
                if (at >= 0) return name.substring(at + separator.length)
            }
        }
        return name
    }

val Pack.seriesCode: String?
    get() = if (shortName == name) null else VerseNumbering.packCode(name)
