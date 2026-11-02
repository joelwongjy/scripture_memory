package joel.scripturememory.ui.theme

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color

@Immutable
data class AppColors(
    val isDark: Boolean,
    val background: Color,
    val panel: Color,
    val panelRaised: Color,
    val chrome: Color,
    val label: Color,
    val secondaryLabel: Color,
    val tertiaryLabel: Color,
    val separator: Color,
    val fill: Color,
    val accent: Color,
    val onAccent: Color,
    val accentSoft: Color,
    val green: Color,
    val orange: Color,
    val red: Color,
    val yellow: Color,
    val purple: Color,
    val scrim: Color,
    val shadow: Color,
)

val LightColors = AppColors(
    isDark = false,
    background = Color(0xFFF3F2EE),
    panel = Color(0xFFFFFFFD),
    panelRaised = Color(0xFFFFFFFF),
    chrome = Color(0xF7FAF9F6),
    label = Color(0xFF191917),
    secondaryLabel = Color(0xFF6E6D68),
    tertiaryLabel = Color(0xFFA9A8A2),
    separator = Color(0x1F1E1D18),
    fill = Color(0x0F1E1D18),
    accent = Color(0xFF0A7AF0),
    onAccent = Color(0xFFFFFFFF),
    accentSoft = Color(0x1A0A7AF0),
    green = Color(0xFF2FA85A),
    orange = Color(0xFFF28A1E),
    red = Color(0xFFE5413A),
    yellow = Color(0xFFEBB10C),
    purple = Color(0xFF8E5BD9),
    scrim = Color(0x66000000),
    shadow = Color(0x24000000),
)

val DarkColors = AppColors(
    isDark = true,
    background = Color(0xFF0F0F0E),
    panel = Color(0xFF1C1C1A),
    panelRaised = Color(0xFF262624),
    chrome = Color(0xF2161615),
    label = Color(0xFFF4F3EF),
    secondaryLabel = Color(0xFFA2A19B),
    tertiaryLabel = Color(0xFF686762),
    separator = Color(0x2EF4F3EF),
    fill = Color(0x1AF4F3EF),
    accent = Color(0xFF3B9BFF),
    onAccent = Color(0xFFFFFFFF),
    accentSoft = Color(0x263B9BFF),
    green = Color(0xFF45C777),
    orange = Color(0xFFFF9F3D),
    red = Color(0xFFFF5F58),
    yellow = Color(0xFFF7C52E),
    purple = Color(0xFFAF85EE),
    scrim = Color(0x99000000),
    shadow = Color(0x66000000),
)

object PouchInk {
    private fun pick(dark: Boolean, l: Int, d: Int) = Color(if (dark) d else l)

    fun paper(dark: Boolean) = pick(dark, 0xFFF6F5F2.toInt(), 0xFF2E2D2B.toInt())
    fun paperBack(dark: Boolean) = pick(dark, 0xFFECEBE7.toInt(), 0xFF252423.toInt())
    fun paperEdge(dark: Boolean) = pick(dark, 0xFFE3E3E3.toInt(), 0xFF3C3B39.toInt())
    fun title(dark: Boolean) = pick(dark, 0xFF545454.toInt(), 0xFFBDBDB8.toInt())
    fun body(dark: Boolean) = pick(dark, 0xFF242424.toInt(), 0xFFE6E6E0.toInt())
    fun caption(dark: Boolean) = pick(dark, 0xFF4D4D4D.toInt(), 0xFF9E9E99.toInt())
    fun green(dark: Boolean) = pick(dark, 0xFF1F8C5E.toInt(), 0xFF5CC78F.toInt())
    fun mint(dark: Boolean) = pick(dark, 0xFFCCE8DB.toInt(), 0xFF294D3D.toInt())
    fun edgeLine(dark: Boolean) = if (dark) Color(0x1AFFFFFF) else Color(0x1A000000)
}
