package joel.scripturememory.ui.settings

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import joel.scripturememory.R
import joel.scripturememory.ui.components.GroupedSection
import joel.scripturememory.ui.components.InlineScreen
import joel.scripturememory.ui.components.ListRow
import joel.scripturememory.ui.components.LocalBottomBarPadding
import joel.scripturememory.ui.components.LocalNavigator
import joel.scripturememory.ui.components.RowDivider
import joel.scripturememory.ui.components.Text
import joel.scripturememory.ui.components.readableColumn
import joel.scripturememory.ui.theme.AppLayout
import joel.scripturememory.ui.theme.AppTheme
import joel.scripturememory.ui.theme.AppType

private const val ofl = "SIL Open Font License 1.1"

private class License(
    val name: String,
    val licenseName: String,
    val copyright: String,
    val text: Int,
)

private val fonts = listOf(
    License(
        "Inter",
        ofl,
        "Copyright 2016 The Inter Project Authors (https://github.com/rsms/inter)",
        R.raw.license_ofl,
    ),
    License(
        "Belleza",
        ofl,
        "Copyright 2012 The Belleza Project Authors (https://github.com/etunni/belleza)",
        R.raw.license_ofl,
    ),
    License(
        "Quattrocento Sans",
        ofl,
        "Copyright (c) 2011, Pablo Impallari (www.impallari.com|impallari@gmail.com), " +
            "Copyright (c) 2011, Igino Marini. (www.ikern.com|mail@iginomarini.com), " +
            "Copyright (c) 2011, Brenda Gallo. (gbrenda1987@gmail.com), " +
            "with Reserved Font Name Quattrocento Sans.",
        R.raw.license_ofl,
    ),
    License(
        "Tinos",
        ofl,
        "Copyright 2026 The Tinos Project Authors (https://github.com/googlefonts/tinos)",
        R.raw.license_ofl,
    ),
)

private val phosphor = License("Phosphor Icons", "MIT License", "Copyright (c) 2023 Phosphor Icons", R.raw.license_phosphor)

@Composable
fun AcknowledgmentsScreen() {
    val navigator = LocalNavigator.current
    InlineScreen("Acknowledgments", onBack = navigator::pop) {
        Column(
            Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(top = 16.dp, bottom = LocalBottomBarPadding.current + 24.dp),
        ) {
            Column(Modifier.readableColumn().padding(horizontal = AppLayout.screenMargin)) {
                TextSection(
                    "Scripture",
                    "Scripture quotations taken from The Holy Bible, New International Version® NIV®. Copyright © 1973, 1978, 1984, 2011 by Biblica, Inc.® All rights reserved worldwide.",
                )
                Spacer(Modifier.height(24.dp))
                TextSection(
                    "Topical Memory System",
                    "Verse selections are based on The Navigators' Topical Memory System®. This app is independent and is not affiliated with, endorsed by, or sponsored by The Navigators.",
                )
                Spacer(Modifier.height(24.dp))
                GroupedSection(title = "Fonts") {
                    fonts.forEachIndexed { index, font ->
                        if (index > 0) RowDivider()
                        LicenseRow(font)
                    }
                }
                Spacer(Modifier.height(24.dp))
                GroupedSection(title = "Icons") { LicenseRow(phosphor) }
            }
        }
    }
}

@Composable
private fun TextSection(title: String, text: String) {
    GroupedSection(title = title) {
        Text(
            text,
            Modifier.padding(horizontal = AppLayout.panelPadding, vertical = 12.dp),
            style = AppType.body,
            color = AppTheme.colors.label,
        )
    }
}

@Composable
private fun LicenseRow(license: License) {
    val navigator = LocalNavigator.current
    ListRow(
        title = license.name,
        subtitle = license.licenseName,
        showsChevron = true,
        onClick = { navigator.push("license-${license.name}") { LicenseScreen(license) } },
    )
}

@Composable
private fun LicenseScreen(license: License) {
    val navigator = LocalNavigator.current
    val context = LocalContext.current
    val text = remember(license.text) {
        context.resources.openRawResource(license.text).bufferedReader().use { it.readText() }
    }
    InlineScreen(license.name, onBack = navigator::pop) {
        Box(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
            Column(
                Modifier
                    .readableColumn()
                    .padding(horizontal = AppLayout.screenMargin + 4.dp)
                    .padding(top = 16.dp, bottom = LocalBottomBarPadding.current + 24.dp),
            ) {
                Text(license.copyright, style = AppType.subheadline, color = AppTheme.colors.label)
                Spacer(Modifier.height(16.dp))
                Text(text, style = AppType.footnote, color = AppTheme.colors.secondaryLabel)
            }
        }
    }
}
