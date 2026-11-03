package joel.scripturememory.ui.settings

import android.Manifest
import android.content.Intent
import android.provider.Settings
import android.text.format.DateFormat
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import joel.scripturememory.BuildConfig
import joel.scripturememory.R
import joel.scripturememory.model.AnalyticsEvent
import joel.scripturememory.model.AnalyticsScreen
import joel.scripturememory.model.AppDefaults
import joel.scripturememory.model.BibleVersion
import joel.scripturememory.model.CardAppearance
import joel.scripturememory.model.Catalogue
import joel.scripturememory.model.LearningStore
import joel.scripturememory.model.NewCapUnit
import joel.scripturememory.model.NewCardCap
import joel.scripturememory.model.PackPreferencesStore
import joel.scripturememory.model.SRSQueueBuilder
import joel.scripturememory.model.SRSStore
import joel.scripturememory.model.StudyMode
import joel.scripturememory.system.Analytics
import joel.scripturememory.system.Background
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import joel.scripturememory.system.NotificationManager
import joel.scripturememory.ui.components.AlertAction
import joel.scripturememory.ui.components.AppAlert
import joel.scripturememory.ui.components.AppSheet
import joel.scripturememory.ui.components.GroupedSection
import joel.scripturememory.ui.components.Icon
import joel.scripturememory.ui.components.LargeTitleColumn
import joel.scripturememory.ui.components.ListRow
import joel.scripturememory.ui.components.LocalNavigator
import joel.scripturememory.ui.components.PickerSheet
import joel.scripturememory.ui.components.RowDivider
import joel.scripturememory.ui.components.SegmentedControl
import joel.scripturememory.ui.components.SelectionMark
import joel.scripturememory.ui.components.SheetHeader
import joel.scripturememory.ui.components.Stepper
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.components.TextButton
import joel.scripturememory.ui.components.TimeWheelPicker
import joel.scripturememory.ui.components.ToggleRow
import joel.scripturememory.ui.components.TrackScreen
import joel.scripturememory.ui.components.dimOnPress
import joel.scripturememory.ui.onboarding.LearningSetupScreen
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppMotion
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType
import joel.scripturememory.ui.theme.CardFont
import androidx.compose.ui.unit.sp

private const val hardModeKey = "hardMode"
private val iconRowInset = AppLayout.panelPadding + 36.dp

private fun logSetting(setting: String, value: String) {
    Analytics.log(AnalyticsEvent.SettingChanged(setting, value))
}

private val settlingLogs = mutableMapOf<String, Job>()

private fun logSettingOnceSettled(setting: String, value: String) {
    settlingLogs[setting]?.cancel()
    settlingLogs[setting] = Background.launch {
        delay(settledLogMillis)
        logSetting(setting, value)
    }
}

private const val settledLogMillis = 1500L

private const val privacyPolicyUrl = "https://joelwongjy.github.io/scripture-memory-privacy/"

@Composable
fun SettingsScreen() {
    val defaults = AppDefaults.standard
    val context = LocalContext.current
    val uriHandler = LocalUriHandler.current
    val navigator = LocalNavigator.current

    val studyMode = StudyMode.saved()
    val hardMode = defaults.getBool(hardModeKey) ?: false
    val bibleVersion = BibleVersion.saved()
    val cap = NewCardCap.current()
    val dailyReviewCap = defaults.getInt(NewCardCap.dailyReviewCapKey) ?: NewCardCap.dailyReviewCapDefault
    val reviewsKnown = defaults.getBool(SRSQueueBuilder.NewCardPolicy.reviewsKnownKey)
        ?: SRSQueueBuilder.NewCardPolicy.reviewsKnownDefault
    val cardAppearance = CardAppearance.saved()
    val reminderEnabled = defaults.getBool(NotificationManager.Keys.enabled) ?: false
    val reminderHour = defaults.getInt(NotificationManager.Keys.hour) ?: NotificationManager.defaultHour
    val reminderMinute = defaults.getInt(NotificationManager.Keys.minute) ?: NotificationManager.defaultMinute

    var showResetAlert by rememberSaveable { mutableStateOf(false) }
    var showNotificationsDenied by rememberSaveable { mutableStateOf(false) }
    var showLearningSetup by rememberSaveable { mutableStateOf(false) }
    var showTimePicker by rememberSaveable { mutableStateOf(false) }
    var showsCardsPicker by rememberSaveable { mutableStateOf(false) }

    fun setReminderEnabled(on: Boolean) {
        defaults.putBool(NotificationManager.Keys.enabled, on)
        logSetting("dailyReminder", on.toString())
    }

    fun refuseReminders() {
        setReminderEnabled(false)
        showNotificationsDenied = true
    }

    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) NotificationManager.refreshFromSettings() else refuseReminders()
    }

    fun handleReminderToggle(on: Boolean) {
        setReminderEnabled(on)
        when {
            !on -> NotificationManager.cancelDailyReminder()
            NotificationManager.isAuthorized -> NotificationManager.refreshFromSettings()
            NotificationManager.needsPermissionPrompt -> permission.launch(Manifest.permission.POST_NOTIFICATIONS)
            else -> refuseReminders()
        }
    }

    val ordered = Catalogue.verses(PackPreferencesStore.shared.visible(bibleVersion.packs))
    val currentLearningLabel = when {
        ordered.isEmpty() -> "None"
        else -> LearningStore.shared.current(ordered)?.let { "${it.verse.book} ${it.verse.reference}" } ?: "All learnt"
    }

    TrackScreen(AnalyticsScreen.settings)

    LargeTitleColumn("Settings") {
        GroupedSection(
            title = "Study",
            footer = if (hardMode) {
                "${studyMode.instructions} Hard Mode hides the word blanks."
            } else {
                studyMode.instructions
            },
        ) {
            StudyMode.entries.forEachIndexed { index, mode ->
                if (index > 0) RowDivider()
                ListRow(
                    title = mode.displayName,
                    modifier = Modifier.semantics {
                        selected = mode == studyMode
                        role = Role.RadioButton
                    },
                    onClick = {
                        if (mode != studyMode) {
                            defaults.putString(StudyMode.storageKey, mode.rawValue)
                            logSetting("studyMode", mode.rawValue)
                        }
                    },
                    trailing = { SelectionMark(mode == studyMode) },
                )
            }
            RowDivider()
            ToggleRow("Hard Mode", hardMode, onCheckedChange = {
                defaults.putBool(hardModeKey, it)
                logSetting("hardMode", it.toString())
            })
        }

        GroupedSection(title = "Learning", footer = "Verses before your current verse count as learnt.") {
            ValueRow(
                title = "Current Verse",
                icon = R.drawable.ic_bookmark_fill,
                value = currentLearningLabel,
                trailingIcon = R.drawable.ic_caret_right,
                onClick = { showLearningSetup = true },
            )
        }

        GroupedSection(
            title = "Daily Review",
            footer = "Review Earlier Verses brings verses before your starting point into review, a few at a time. Limits apply across all packs.",
        ) {
            CapRow(
                icon = R.drawable.ic_sparkle,
                title = cap.unit.settingTitle,
                value = cap.amount,
                range = 0..50,
                onValueChange = {
                    defaults.putInt(NewCardCap.amountKey, it)
                    logSettingOnceSettled("newCards", it.toString())
                },
            )
            RowDivider(iconRowInset)
            Row(
                Modifier
                    .fillMaxWidth()
                    .defaultMinSize(minHeight = 52.dp)
                    .padding(horizontal = AppLayout.panelPadding, vertical = 9.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                RowLabel("Count Per", R.drawable.ic_calendar, Modifier.weight(1f))
                SegmentedControl(
                    options = NewCapUnit.entries.map { it.pickerLabel },
                    selected = NewCapUnit.entries.indexOf(cap.unit),
                    onSelect = {
                        val unit = NewCapUnit.entries[it]
                        if (unit != cap.unit) {
                            defaults.putString(NewCardCap.unitKey, unit.rawValue)
                            logSetting("newCardsPer", unit.rawValue)
                        }
                    },
                    modifier = Modifier.width(150.dp),
                )
            }
            RowDivider(iconRowInset)
            CapRow(
                icon = R.drawable.ic_arrow_clockwise,
                title = "Reviews per Day",
                value = dailyReviewCap,
                range = 0..500,
                onValueChange = {
                    defaults.putInt(NewCardCap.dailyReviewCapKey, it)
                    logSettingOnceSettled("reviewsPerDay", it.toString())
                },
            )
            RowDivider(iconRowInset)
            ToggleRow(
                "Review Earlier Verses",
                reviewsKnown,
                onCheckedChange = {
                    defaults.putBool(SRSQueueBuilder.NewCardPolicy.reviewsKnownKey, it)
                    logSetting("reviewEarlierVerses", it.toString())
                },
                leading = { RowIcon(R.drawable.ic_check_circle) },
            )
        }

        GroupedSection(title = "Reminders", footer = "Only on days with verses due.") {
            ToggleRow(
                "Daily Reminder",
                reminderEnabled,
                onCheckedChange = ::handleReminderToggle,
                leading = { RowIcon(R.drawable.ic_bell) },
            )
            AnimatedVisibility(
                visible = reminderEnabled,
                enter = expandVertically(AppMotion.content()) + fadeIn(AppMotion.content()),
                exit = shrinkVertically(AppMotion.content()) + fadeOut(AppMotion.content()),
            ) {
                Column {
                    RowDivider()
                    ListRow(
                        title = "Time",
                        onClick = { showTimePicker = true },
                        trailing = {
                            Box(
                                Modifier
                                    .background(AppTheme.colors.fill, RoundedCornerShape(8.dp))
                                    .padding(horizontal = 10.dp, vertical = 5.dp),
                            ) {
                                Text(reminderTimeLabel(context, reminderHour, reminderMinute), style = AppType.body)
                            }
                        },
                    )
                }
            }
        }

        GroupedSection(title = "Display", footer = "Match Appearance uses dark cards in Dark Mode.") {
            ValueRow(
                title = "Cards",
                icon = R.drawable.ic_cards,
                value = cardAppearance.displayName,
                trailingIcon = R.drawable.ic_caret_up_down,
                onClick = { showsCardsPicker = true },
            )
        }

        GroupedSection(
            title = "Privacy",
            footer = "Sends which screens and features you use, never your verses or personal details.",
        ) {
            ToggleRow(
                "Share Anonymous Usage",
                Analytics.isEnabled,
                onCheckedChange = Analytics::setEnabled,
                leading = { RowIcon(R.drawable.ic_chart_bar) },
            )
        }

        GroupedSection(footer = "Clears all review scheduling. This can't be undone.") {
            Box(
                Modifier
                    .fillMaxWidth()
                    .defaultMinSize(minHeight = 52.dp)
                    .dimOnPress { showResetAlert = true },
                contentAlignment = Alignment.Center,
            ) {
                Text("Reset Review Progress", style = AppType.body, color = AppTheme.colors.red)
            }
        }

        Column {
            GroupedSection(title = "About") {
                ListRow(title = "Version", value = appVersionString)
                RowDivider()
                ListRow(
                    title = "Acknowledgments",
                    showsChevron = true,
                    onClick = { navigator.push("acknowledgments") { AcknowledgmentsScreen() } },
                )
                RowDivider()
                ListRow(
                    title = "Privacy Policy",
                    showsChevron = true,
                    onClick = { runCatching { uriHandler.openUri(privacyPolicyUrl) } },
                )
            }
            Text(
                "Made with God's ❤️ for The Navigators",
                Modifier
                    .fillMaxWidth()
                    .padding(top = 12.dp, bottom = 28.dp),
                style = CardFont.serif(14.sp),
                color = AppTheme.colors.secondaryLabel,
                textAlign = TextAlign.Center,
            )
        }
    }

    if (showsCardsPicker) {
        PickerSheet(
            title = "Cards",
            options = CardAppearance.entries,
            selected = cardAppearance,
            label = { it.displayName },
            onSelect = {
                if (it != cardAppearance) {
                    defaults.putString(CardAppearance.storageKey, it.rawValue)
                    logSetting("cardAppearance", it.rawValue)
                }
            },
            onDismiss = { showsCardsPicker = false },
        )
    }

    if (showTimePicker) {
        AppSheet(onDismiss = { showTimePicker = false }) { sheet ->
            SheetHeader(
                title = "Time",
                trailing = { TextButton("Done", style = AppType.headline, onClick = sheet.dismiss) },
            )
            TimeWheelPicker(
                hour = reminderHour,
                minute = reminderMinute,
                is24Hour = DateFormat.is24HourFormat(context),
                onChange = { hour, minute ->
                    defaults.putInt(NotificationManager.Keys.hour, hour)
                    defaults.putInt(NotificationManager.Keys.minute, minute)
                    NotificationManager.refreshFromSettings()
                },
                modifier = Modifier.padding(top = 4.dp, bottom = 20.dp),
            )
        }
    }

    if (showLearningSetup) {
        AppSheet(onDismiss = { showLearningSetup = false }, fullHeight = true) { sheet ->
            LearningSetupScreen(isOnboarding = false, showsWelcome = false, onComplete = sheet.dismiss)
        }
    }

    if (showNotificationsDenied) {
        AppAlert(
            title = "Notifications Are Off",
            message = "Turn on notifications for Scripture Memory in Settings.",
            actions = listOf(
                AlertAction("Cancel", isCancel = true),
                AlertAction("Open Settings", onClick = {
                    context.startActivity(
                        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                            .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName),
                    )
                }),
            ),
            onDismiss = { showNotificationsDenied = false },
        )
    }

    if (showResetAlert) {
        AppAlert(
            title = "Reset Review Progress?",
            message = "Every card's review schedule will be cleared.",
            actions = listOf(
                AlertAction("Cancel", isCancel = true),
                AlertAction("Reset", isDestructive = true, onClick = { SRSStore.shared.resetAll() }),
            ),
            onDismiss = { showResetAlert = false },
        )
    }
}

private val appVersionString: String
    get() {
        val build = BuildConfig.VERSION_CODE % 100
        return if (build == 0) BuildConfig.VERSION_NAME else "${BuildConfig.VERSION_NAME} ($build)"
    }

private fun reminderTimeLabel(context: android.content.Context, hour: Int, minute: Int): String {
    val time = java.util.Calendar.getInstance().apply {
        set(java.util.Calendar.HOUR_OF_DAY, hour)
        set(java.util.Calendar.MINUTE, minute)
    }.time
    return DateFormat.getTimeFormat(context).format(time)
}

@Composable
private fun RowIcon(icon: Int) {
    Box(Modifier.width(24.dp), contentAlignment = Alignment.Center) {
        Icon(icon, size = 22.dp, tint = AppTheme.colors.accent)
    }
}

@Composable
private fun RowLabel(title: String, icon: Int, modifier: Modifier = Modifier) {
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        RowIcon(icon)
        Text(title, style = AppType.body, color = AppTheme.colors.label)
    }
}

@Composable
private fun ValueRow(title: String, icon: Int, value: String, trailingIcon: Int, onClick: () -> Unit) {
    val colors = AppTheme.colors
    Row(
        Modifier
            .fillMaxWidth()
            .defaultMinSize(minHeight = 52.dp)
            .dimOnPress(onClick = onClick)
            .padding(horizontal = AppLayout.panelPadding, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        RowIcon(icon)
        Spacer(Modifier.width(12.dp))
        Text(title, style = AppType.body, color = colors.label, maxLines = 1)
        Spacer(Modifier.width(8.dp))
        Text(
            value,
            Modifier.weight(1f),
            style = AppType.body,
            color = colors.secondaryLabel,
            maxLines = 1,
            textAlign = TextAlign.End,
        )
        Spacer(Modifier.width(8.dp))
        Icon(trailingIcon, size = 13.dp, tint = colors.tertiaryLabel)
    }
}

@Composable
private fun CapRow(icon: Int, title: String, value: Int, range: IntRange, onValueChange: (Int) -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .defaultMinSize(minHeight = 52.dp)
            .padding(horizontal = AppLayout.panelPadding, vertical = 9.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        RowLabel(title, icon, Modifier.weight(1f))
        Spacer(Modifier.width(8.dp))
        Text(
            "$value",
            Modifier.padding(end = 8.dp).widthIn(min = 16.dp),
            style = AppType.body.copy(fontFeatureSettings = "tnum"),
            color = AppTheme.colors.secondaryLabel,
            textAlign = TextAlign.End,
            maxLines = 1,
        )
        Stepper(value, range, title, onValueChange)
    }
}
