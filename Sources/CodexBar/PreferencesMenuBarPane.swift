import CodexBarCore
import SwiftUI

@MainActor
struct MenuBarPane: View {
    private static let maxOverviewProviders = SettingsStore.mergedOverviewProviderLimit

    @State private var isOverviewProviderPopoverPresented = false
    @Bindable var settings: SettingsStore
    @Bindable var store: UsageStore

    static func overviewProviderLimitText(limit: Int = Self.maxOverviewProviders) -> String {
        L("overview_choose_providers", String(limit))
    }

    static func layoutEditorEnabled(for style: MenuBarIconStyle) -> Bool {
        style == .iconAndPercent
    }

    static func layoutFooterText(for style: MenuBarIconStyle) -> String {
        self.layoutEditorEnabled(for: style)
            ? L("menu_bar_layout_footer")
            : L("menu_bar_layout_footer_requires_icon_and_percent", MenuBarIconStyle.iconAndPercent.label)
    }

    static func progressGlyphLabel(for glyphs: MenuBarProgressGlyphSet) -> String {
        switch glyphs {
        case .blocks: L("menu_bar_progress_glyphs_blocks")
        case .circles: L("menu_bar_progress_glyphs_circles")
        case .squares: L("menu_bar_progress_glyphs_squares")
        case .thin: L("menu_bar_progress_glyphs_thin")
        }
    }

    static func progressCompanionLabel(for companion: MenuBarProgressCompanion) -> String {
        switch companion {
        case .none: L("menu_bar_progress_companion_none")
        case .percent: L("menu_bar_progress_companion_percent")
        case .time: L("menu_bar_progress_companion_time")
        case .percentAndTime: L("menu_bar_progress_companion_percent_and_time")
        }
    }

    /// Fixed preview lanes: a 5h session at 74% remaining and a 7d weekly lane at 20% remaining.
    private static let progressPreviewSession = RateWindow(
        usedPercent: 26, windowMinutes: 300, resetsAt: nil, resetDescription: nil)
    private static let progressPreviewWeekly = RateWindow(
        usedPercent: 80, windowMinutes: 10080, resetsAt: nil, resetDescription: nil)

    /// Stepper range mirrors the write-side clamp in `SettingsStore.menuBarProgressWidth`.
    private static let progressWidthRange = 4...20

    var body: some View {
        let paceColorSubtitle = L(
            "Green pace indicator when behind pace, red when ahead of pace (risk of running out early)")
            + "\n" + L("menu_bar_layout_title") + ": " + [
                L("menu_bar_layout_token_session_pace"),
                L("menu_bar_layout_token_weekly_pace"),
                L("menu_bar_layout_token_auto_pace"),
                L("menu_bar_layout_token_spend_pace"),
            ].joined(separator: ", ")

        Form {
            Section {
                SettingsMenuPicker(
                    selection: self.$settings.menuBarIconStyle,
                    options: MenuBarSettingsMenuOptions.iconStyles,
                    label: { Text(L("menu_bar_style_title")) },
                    optionLabel: { style in
                        Text(style.label)
                    })

                SettingsMenuPicker(
                    selection: self.$settings.menuBarDisplayMode,
                    options: MenuBarSettingsMenuOptions.displayModes,
                    label: {
                        SettingsRowLabel(
                            L("display_mode_title"),
                            subtitle: self.settings.menuBarDisplayMode.description)
                    },
                    optionLabel: { mode in
                        Text(mode.label)
                    })
                    .disabled(!Self.layoutEditorEnabled(for: self.settings.menuBarIconStyle))

                Toggle(isOn: self.$settings.menuBarHighContrastOnInactiveDisplays) {
                    SettingsRowLabel(
                        L("menu_bar_inactive_display_contrast_title"),
                        subtitle: "\(MenuBarIconStyle.iconAndPercent.label): "
                            + L("menu_bar_inactive_display_contrast_subtitle"))
                }
                .disabled(!Self.layoutEditorEnabled(for: self.settings.menuBarIconStyle))

                Toggle(isOn: self.$settings.menuBarColorPace) {
                    SettingsRowLabel(
                        L("Color Pace Indicator"),
                        subtitle: paceColorSubtitle)
                }
                .disabled(self.settings.menuBarIconStyle != .iconAndPercent)

                SettingsMenuPicker(
                    selection: self.$settings.menuBarPaceReservePositive,
                    options: [false, true],
                    label: { Text(L("Pace sign")) },
                    optionLabel: { reservePositive in
                        Text(reservePositive ? L("Reserve is +") : L("Ahead of pace is +"))
                    })
                    .disabled(self.settings.menuBarIconStyle != .iconAndPercent)

                Toggle(isOn: self.$settings.menuBarColorByProvider) {
                    Text(L("Color by provider"))
                }
            } header: {
                Text(L("section_icon"))
            }

            if self.settings.menuBarDisplayMode == .progressBar {
                Section {
                    SettingsMenuPicker(
                        selection: self.$settings.menuBarProgressGlyphs,
                        options: MenuBarProgressGlyphSet.allCases,
                        label: { Text(L("menu_bar_progress_glyphs_title")) },
                        optionLabel: { glyphs in
                            Text(MenuBarPane.progressGlyphLabel(for: glyphs))
                        })

                    self.progressWidthRow

                    SettingsMenuPicker(
                        selection: self.$settings.menuBarProgressCompanion,
                        options: MenuBarProgressCompanion.allCases,
                        label: { Text(L("menu_bar_progress_companion_title")) },
                        optionLabel: { companion in
                            Text(MenuBarPane.progressCompanionLabel(for: companion))
                        })

                    Toggle(isOn: self.$settings.menuBarProgressShowsWeekly) {
                        SettingsRowLabel(
                            L("menu_bar_progress_shows_weekly_title"),
                            subtitle: L("menu_bar_progress_shows_weekly_subtitle"))
                    }

                    LabeledContent {
                        Text(self.progressPreviewText)
                            .monospaced()
                            .lineLimit(1)
                    } label: {
                        SettingsRowLabel(L("menu_bar_progress_preview"))
                    }
                } header: {
                    Text(L("menu_bar_progress_title"))
                } footer: {
                    SettingsSectionFooter(L("menu_bar_progress_subtitle"))
                }
            }

            Section {
                MenuBarLayoutEditor(settings: self.settings, store: self.store)
                    .disabled(!Self.layoutEditorEnabled(for: self.settings.menuBarIconStyle))
            } header: {
                Text(L("menu_bar_layout_title"))
            } footer: {
                SettingsSectionFooter(Self.layoutFooterText(for: self.settings.menuBarIconStyle))
            }

            Section {
                Toggle(isOn: self.$settings.mergeIcons) {
                    SettingsRowLabel(L("merge_icons_title"), subtitle: L("merge_icons_subtitle"))
                }

                SettingsMenuPicker(
                    selection: Binding(
                        get: { self.mergedIconPresentation.effectiveStyle },
                        set: { self.settings.mergedIconDisplayStyle = $0 }),
                    options: MenuBarSettingsMenuOptions.mergedIconStyles,
                    label: {
                        SettingsRowLabel(L("merged_icon_style_title"), subtitle: L("merged_icon_style_subtitle"))
                    },
                    optionLabel: { style in
                        Text(style.label)
                    })
                    .disabled(!self.mergedIconPresentation.canStack)

                if let pair = self.mergedIconPresentation.stackedProviders {
                    self.stackedRowProviderPicker(
                        title: L("merge_icon_stacked_top_provider_title"),
                        selection: Binding(
                            get: { self.mergedIconPresentation.topSelection },
                            set: { self.settings.mergeIconStackedTopProvider = $0 }),
                        excluding: self.mergedIconPresentation.bottomSelection,
                        automaticProvider: pair.top)
                    self.stackedRowProviderPicker(
                        title: L("merge_icon_stacked_bottom_provider_title"),
                        selection: Binding(
                            get: { self.mergedIconPresentation.bottomSelection },
                            set: { self.settings.mergeIconStackedBottomProvider = $0 }),
                        excluding: self.mergedIconPresentation.topSelection,
                        automaticProvider: pair.bottom)
                }

                SettingsMenuPicker(
                    selection: self.$settings.switcherRowsOption,
                    options: MenuBarSettingsMenuOptions.switcherRows,
                    label: { SettingsRowLabel(L("switcher_rows_title")) },
                    optionLabel: { option in
                        Text(option.label)
                    })
                    .disabled(!self.settings.mergeIcons)

                UnifiedIconSourcePicker(selection: self.$settings.unifiedIconSource)
                    .disabled(!self.settings.mergeIcons || self.mergedIconPresentation.effectiveStyle == .stacked)

                self.overviewProviderRow
                    .disabled(!self.settings.mergeIcons)
                Toggle(isOn: self.$settings.mergedOverviewAllAccounts) {
                    SettingsRowLabel(
                        L("Show all accounts in Overview"),
                        subtitle: L(
                            "Expand cached account usage. The six-provider limit still applies."))
                }
                .disabled(!self.settings.mergeIcons)
            } header: {
                Text(L("section_combined_icon"))
            }

            Section {
                Toggle(isOn: self.$settings.randomBlinkEnabled) {
                    SettingsRowLabel(L("surprise_me_title"), subtitle: L("surprise_me_subtitle"))
                }
                // Brand icons (including stacked rows, which require them) never draw blink frames.
                .disabled(self.settings.menuBarShowsBrandIconWithPercent)
            } header: {
                Text(L("section_animation"))
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .scrollContentBackground(.hidden)
        .onAppear {
            self.reconcileOverviewSelection()
        }
        .onChange(of: self.settings.mergeIcons) { _, isEnabled in
            guard isEnabled else {
                self.isOverviewProviderPopoverPresented = false
                return
            }
            self.reconcileOverviewSelection()
        }
        .onChange(of: self.activeProvidersInOrder) { _, _ in
            if self.activeProvidersInOrder.isEmpty {
                self.isOverviewProviderPopoverPresented = false
            }
            self.reconcileOverviewSelection()
        }
    }

    private var overviewProviderRow: some View {
        LabeledContent {
            if self.settings.mergeIcons, !self.activeProvidersInOrder.isEmpty {
                Button(L("configure")) {
                    self.isOverviewProviderPopoverPresented = true
                }
                .popover(isPresented: self.$isOverviewProviderPopoverPresented, arrowEdge: .bottom) {
                    self.overviewProviderPopover
                }
            }
        } label: {
            SettingsRowLabel(L("overview_tab_providers_title"), subtitle: self.overviewProviderSubtitle)
        }
    }

    private var progressWidthRow: some View {
        LabeledContent {
            HStack(spacing: 8) {
                Text("\(self.progressWidth)")
                    .monospacedDigit()
                    .frame(width: 28)
                Stepper(value: self.progressWidthBinding, in: Self.progressWidthRange) {
                    EmptyView()
                }
                .labelsHidden()
            }
        } label: {
            SettingsRowLabel(
                L("menu_bar_progress_width_title"),
                subtitle: L("menu_bar_progress_width_subtitle"))
        }
    }

    private var overviewProviderSubtitle: String {
        if !self.settings.mergeIcons {
            L("overview_enable_merge_icons_hint")
        } else if self.activeProvidersInOrder.isEmpty {
            L("overview_no_providers_hint")
        } else {
            self.overviewProviderSelectionSummary
        }
    }

    private var overviewProviderPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Self.overviewProviderLimitText())
                .font(.headline)
            Text(L("overview_rows_follow_order"))
                .font(.footnote)
                .foregroundStyle(.tertiary)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(self.activeProvidersInOrder, id: \.self) { provider in
                        Toggle(
                            isOn: Binding(
                                get: { self.overviewSelectedProviders.contains(provider) },
                                set: { shouldSelect in
                                    self.setOverviewProviderSelection(provider: provider, isSelected: shouldSelect)
                                })) {
                            Text(self.providerDisplayName(provider))
                                .font(.body)
                        }
                        .toggleStyle(.checkbox)
                        .disabled(
                            !self.overviewSelectedProviders.contains(provider) &&
                                self.overviewSelectedProviders.count >= Self.maxOverviewProviders)
                    }
                }
            }
            .frame(maxHeight: 220)
        }
        .padding(12)
        .frame(width: 280)
    }

    private var activeProvidersInOrder: [ProviderInstanceID] {
        self.store.enabledProvidersForDisplay()
    }

    private var mergedIconPresentation: MergedIconPresentation {
        self.settings.mergedIconPresentation(activeProviders: self.store.enabledFirstPartyProvidersForDisplay())
    }

    /// Stepper value, clamped on read so a hand-edited default cannot land outside the stepper range.
    private var progressWidth: Int {
        max(
            Self.progressWidthRange.lowerBound,
            min(Self.progressWidthRange.upperBound, self.settings.menuBarProgressWidth))
    }

    private var progressWidthBinding: Binding<Int> {
        Binding(
            get: { self.progressWidth },
            set: { self.settings.menuBarProgressWidth = $0 })
    }

    /// Live preview of the composed progress line, mirroring the status item's rendering inputs
    /// (`StatusItemController.menuBarDisplayText`), including the shared "show used" quota semantics.
    private var progressPreviewText: String {
        let options = MenuBarProgressTextOptions(
            width: self.progressWidth,
            glyphs: self.settings.menuBarProgressGlyphs,
            companion: self.settings.menuBarProgressCompanion,
            showUsed: self.settings.usageBarsShowUsed,
            weeklyWindow: self.settings.menuBarProgressShowsWeekly ? Self.progressPreviewWeekly : nil)
        return MenuBarProgressText.text(session: Self.progressPreviewSession, options: options) ?? ""
    }

    private func stackedRowProviderPicker(
        title: String,
        selection: Binding<UsageProvider?>,
        excluding: UsageProvider?,
        automaticProvider: UsageProvider) -> some View
    {
        SettingsMenuPicker(
            selection: selection,
            options: [nil] + self.mergedIconPresentation.eligibleProviders.filter { $0 != excluding },
            label: { Text(title) },
            optionLabel: { provider in
                Text(provider.map(self.providerDisplayName)
                    ?? "\(L("Automatic")) (\(self.providerDisplayName(automaticProvider)))")
            })
    }

    private var overviewSelectedProviders: [ProviderInstanceID] {
        self.settings.resolvedMergedOverviewProviders(
            activeProviders: self.activeProvidersInOrder,
            maxVisibleProviders: Self.maxOverviewProviders)
    }

    private var overviewProviderSelectionSummary: String {
        let selectedNames = self.overviewSelectedProviders.map(self.providerDisplayName)
        guard !selectedNames.isEmpty else { return L("overview_no_providers_selected") }
        return selectedNames.joined(separator: ", ")
    }

    private func providerDisplayName(_ instanceID: ProviderInstanceID) -> String {
        if let provider = instanceID.firstPartyProvider { return self.providerDisplayName(provider) }
        return UserProviderPluginRegistry.plugin(for: instanceID)?.manifest.name ?? instanceID.rawValue
    }

    private func providerDisplayName(_ provider: UsageProvider) -> String {
        ProviderDescriptorRegistry.descriptor(for: provider).metadata.displayName
    }

    private func setOverviewProviderSelection(provider: ProviderInstanceID, isSelected: Bool) {
        _ = self.settings.setMergedOverviewProviderSelection(
            provider: provider,
            isSelected: isSelected,
            activeProviders: self.activeProvidersInOrder,
            maxVisibleProviders: Self.maxOverviewProviders)
    }

    private func reconcileOverviewSelection() {
        _ = self.settings.reconcileMergedOverviewSelectedProviders(
            activeProviders: self.activeProvidersInOrder,
            maxVisibleProviders: Self.maxOverviewProviders)
    }
}
