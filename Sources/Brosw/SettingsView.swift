import SwiftUI

final class SettingsViewModel: ObservableObject {
    @Published var profiles: [BrowserProfile] = []
    @Published var hiddenIDs: Set<String> = [] {
        didSet {
            guard !isReloading else { return }
            AppSettings.hiddenProfileIDs = hiddenIDs
        }
    }
    @Published var showMenuBarIcon = true {
        didSet {
            guard !isReloading else { return }
            AppSettings.hideMenuBarIcon = !showMenuBarIcon
        }
    }
    @Published var showEmails = true {
        didSet {
            guard !isReloading else { return }
            AppSettings.hideProfileEmails = !showEmails
        }
    }
    @Published var sortOrder = AppSettings.ProfileSortOrder.recentFirst {
        didSet {
            guard !isReloading else { return }
            AppSettings.profileSortOrder = sortOrder
            if sortOrder == .custom, AppSettings.customProfileOrder.isEmpty {
                // 初回は現在の表示順(最近使った順)を初期値にする
                AppSettings.customProfileOrder = profiles.map(\.id)
            }
            reload()
        }
    }

    private var isReloading = false

    /// 表示のたびに現在の設定とプロファイル一覧を読み直す。
    func reload() {
        isReloading = true
        defer { isReloading = false }
        profiles = AppSettings.displayOrder(BrowserProfileStore.loadProfiles())
        hiddenIDs = AppSettings.hiddenProfileIDs
        showMenuBarIcon = !AppSettings.hideMenuBarIcon
        showEmails = !AppSettings.hideProfileEmails
        sortOrder = AppSettings.profileSortOrder
    }

    /// カスタム並び順でプロファイルを上下に動かす
    func move(_ profile: BrowserProfile, by offset: Int) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        let target = index + offset
        guard profiles.indices.contains(target) else { return }
        profiles.swapAt(index, target)
        AppSettings.customProfileOrder = profiles.map(\.id)
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GroupBox(label: Text(L("Menu Bar"))) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(L("Show icon in the menu bar"), isOn: $model.showMenuBarIcon)
                    Text(L("Even when the icon is hidden, launching Brosw again from Spotlight or Finder opens this settings window. You can also open it from the gear button in the picker."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            }

            GroupBox(label: Text(L("Picker"))) {
                Toggle(L("Show account email addresses"), isOn: $model.showEmails)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
            }

            GroupBox(label: Text(L("Profiles Shown in Picker"))) {
                VStack(alignment: .leading, spacing: 2) {
                    Picker(selection: $model.sortOrder) {
                        Text(L("Most recently used first")).tag(AppSettings.ProfileSortOrder.recentFirst)
                        Text(L("Custom")).tag(AppSettings.ProfileSortOrder.custom)
                    } label: {
                        Text(L("Sort order"))
                    }
                    .pickerStyle(.radioGroup)
                    .horizontalRadioGroupLayout()
                    .padding(.bottom, 6)

                    ForEach(model.profiles) { profile in
                        profileRow(profile)
                    }
                    Text(L("If every profile is hidden, all profiles will be shown."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            }

            GroupBox(label: Text(L("Default Browser"))) {
                VStack(alignment: .leading, spacing: 6) {
                    Button(L("Set Chrome as Default Browser")) {
                        DefaultBrowser.requestSetChromeDefault()
                    }
                    .disabled(!Browser.chrome.isInstalled)
                    Text(L("Hands the default browser role back to Chrome. macOS will ask for confirmation."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            }
        }
        .padding(16)
        .frame(width: 400)
    }

    private func profileRow(_ profile: BrowserProfile) -> some View {
        HStack(spacing: 4) {
            Toggle(isOn: isVisibleBinding(profile)) {
                HStack(spacing: 8) {
                    ProfileAvatarView(profile: profile, size: 22)
                    Text(profile.name)
                        .lineLimit(1)
                    if let email = profile.email {
                        Text(email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
            if model.sortOrder == .custom {
                moveButton(profile, offset: -1, symbol: "chevron.up",
                           disabled: profile.id == model.profiles.first?.id)
                moveButton(profile, offset: 1, symbol: "chevron.down",
                           disabled: profile.id == model.profiles.last?.id)
            }
        }
        .padding(.vertical, 2)
    }

    private func moveButton(_ profile: BrowserProfile, offset: Int, symbol: String, disabled: Bool) -> some View {
        Button {
            model.move(profile, by: offset)
        } label: {
            Image(systemName: symbol)
                .font(.caption)
        }
        .buttonStyle(.borderless)
        .disabled(disabled)
    }

    private func isVisibleBinding(_ profile: BrowserProfile) -> Binding<Bool> {
        Binding(
            get: { !model.hiddenIDs.contains(profile.id) },
            set: { visible in
                if visible {
                    model.hiddenIDs.remove(profile.id)
                } else {
                    model.hiddenIDs.insert(profile.id)
                }
            }
        )
    }
}
