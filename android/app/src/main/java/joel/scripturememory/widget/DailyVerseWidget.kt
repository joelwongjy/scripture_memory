package joel.scripturememory.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.res.Configuration
import android.graphics.RectF
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.widget.RemoteViews
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.remember
import androidx.compose.ui.unit.dp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.AndroidRemoteViews
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.semantics.contentDescription
import androidx.glance.semantics.semantics
import joel.scripturememory.R
import joel.scripturememory.system.Background
import joel.scripturememory.system.DeepLink

private typealias Render = (WidgetRenderer, Boolean) -> WidgetCard

private val WidgetBridge.Snapshot.displayedVerse: WidgetVerse?
    get() = featuredVerse ?: VerseLibrary.firstVerse

class ScriptureVerseWidget : GlanceAppWidget(errorUiLayout = R.layout.widget_loading) {
    override val sizeMode = SizeMode.Single
    override val stateDefinition = null

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(id)
        provideContent {
            LiveWidget(appWidgetId) { snapshot, verse, options ->
                CanvasWidget(
                    options = options,
                    description = verse?.let { "${it.title}, ${it.fullReference}. ${it.verse} ${it.packName}" }
                        ?: "Open the app to set the verse you're learning.",
                    open = verse?.deepLinkUri,
                    render = { renderer, dark -> renderer.verse(snapshot, verse, dark) },
                )
            }
        }
    }
}

class ScriptureProgressWidget : GlanceAppWidget(errorUiLayout = R.layout.widget_loading) {
    override val sizeMode = SizeMode.Single
    override val stateDefinition = null

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val appWidgetId = GlanceAppWidgetManager(context).getAppWidgetId(id)
        provideContent {
            LiveWidget(appWidgetId) { snapshot, verse, options ->
                CanvasWidget(
                    options = options,
                    description = buildString {
                        append("Up next")
                        verse?.let { append(", ${it.title}, ${it.fullReference}") }
                        append(". ${snapshot.streak} day streak, ${snapshot.dueToday} due today, ")
                        append("${snapshot.learned} learned.")
                    },
                    open = verse?.deepLinkUri,
                    render = { renderer, dark -> renderer.progress(snapshot, verse, dark) },
                )
            }
        }
    }
}

@Composable
private fun LiveWidget(
    appWidgetId: Int,
    content: @Composable (WidgetBridge.Snapshot, WidgetVerse?, Bundle) -> Unit,
) {
    val context = LocalContext.current
    val revision = WidgetBridge.revision.intValue
    val snapshot = remember(revision) { WidgetBridge.current() }
    val verse = remember(revision) { snapshot.displayedVerse }
    val options = remember(revision) { AppWidgetManager.getInstance(context).getAppWidgetOptions(appWidgetId) }
    key(revision) { content(snapshot, verse, options) }
}

@Composable
private fun CanvasWidget(options: Bundle, description: String, open: Uri?, render: Render) {
    val context = LocalContext.current
    val fallback = LocalSize.current
    val configuration = context.resources.configuration
    val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, fallback.width.value.toInt())
    val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, fallback.height.value.toInt())
    val maxWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, minWidth)
    val maxHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, minHeight)
    val isLandscape = configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
    val rotates = configuration.smallestScreenWidthDp >= tabletWidthDp

    val face = remember(minWidth, minHeight, maxWidth, maxHeight, isLandscape, rotates) {
        val portrait by lazy { widgetFace(context, minWidth, maxHeight, description, render) }
        val landscape by lazy { widgetFace(context, maxWidth, minHeight, description, render) }
        when {
            rotates -> WidgetFace(
                RemoteViews(landscape.views, portrait.views),
                if (isLandscape) landscape.cta else portrait.cta,
                if (isLandscape) minHeight else maxHeight,
            )
            isLandscape -> landscape
            else -> portrait
        }
    }
    val radius = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        GlanceModifier.cornerRadius(android.R.dimen.system_app_widget_background_radius)
    } else {
        GlanceModifier.cornerRadius(16.dp)
    }
    Box(
        GlanceModifier.fillMaxSize().appWidgetBackground().then(radius),
        contentAlignment = Alignment.BottomStart,
    ) {
        AndroidRemoteViews(face.views, GlanceModifier.fillMaxSize())
        val base = GlanceModifier.fillMaxSize().semantics { contentDescription = description }
        Box(
            if (open == null) base else base.clickable(
                onClick = actionStartActivity(DeepLink.intent(context, open)),
                rippleOverride = R.drawable.widget_no_ripple,
            ),
        ) {}
        face.cta?.let { cta ->
            Box(
                GlanceModifier
                    .fillMaxWidth()
                    .height((face.heightDp - cta.top + ctaReach).dp)
                    .semantics { contentDescription = "Review" }
                    .clickable(
                        onClick = actionStartActivity(DeepLink.intent(context, DeepLink.review)),
                        rippleOverride = R.drawable.widget_no_ripple,
                    ),
            ) {}
        }
    }
}

private const val tabletWidthDp = 600
private const val ctaReach = 6f

private class WidgetFace(val views: RemoteViews, val cta: RectF?, val heightDp: Int)

private fun widgetFace(context: Context, widthDp: Int, heightDp: Int, description: String, render: Render): WidgetFace {
    val renderer = WidgetRenderer(context, widthDp.toFloat(), heightDp.toFloat())
    val isNight = context.resources.configuration.uiMode and
        Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
    val current = render(renderer, isNight)
    val views = RemoteViews(context.packageName, R.layout.widget_canvas)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val other = render(renderer, !isNight)
        val day = if (isNight) other else current
        val night = if (isNight) current else other
        views.setIcon(
            R.id.widget_canvas,
            "setImageIcon",
            Icon.createWithBitmap(day.bitmap.asShared()),
            Icon.createWithBitmap(night.bitmap.asShared()),
        )
    } else {
        views.setImageViewBitmap(R.id.widget_canvas, current.bitmap)
    }
    views.setContentDescription(R.id.widget_canvas, description)
    return WidgetFace(views, current.cta, heightDp)
}

class ScriptureVerseWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = ScriptureVerseWidget()

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        Background.launch { WidgetBridge.scheduleMidnightRefresh() }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        Background.launch { WidgetBridge.reload() }
    }
}

class ScriptureProgressWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = ScriptureProgressWidget()

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        Background.launch { WidgetBridge.scheduleMidnightRefresh() }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        Background.launch { WidgetBridge.reload() }
    }
}
