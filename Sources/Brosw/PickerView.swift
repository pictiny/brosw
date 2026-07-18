import SwiftUI

final class PickerViewModel: ObservableObject {
    @Published var urls: [URL] = []
    @Published var profiles: [ChromeProfile] = []
    @Published var selectedIndex: Int = 0
    @Published var showEmails = true

    var onChoose: ((Int) -> Void)?
    var onCancel: (() -> Void)?
    var onOpenSettings: (() -> Void)?
}

struct PickerView: View {
    @ObservedObject var model: PickerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            Divider()
            VStack(spacing: 2) {
                ForEach(Array(model.profiles.enumerated()), id: \.element.id) { index, profile in
                    ProfileRow(
                        profile: profile,
                        index: index,
                        isSelected: index == model.selectedIndex,
                        showEmail: model.showEmails
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { model.onChoose?(index) }
                    .onHover { hovering in
                        if hovering { model.selectedIndex = index }
                    }
                }
            }
            .padding(6)
            Divider()
            HStack {
                Text(L("1-9 to select · Esc to cancel · ⌘C to copy"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 8)
                Button {
                    model.onOpenSettings?()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(L("Open Settings"))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .frame(width: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var header: some View {
        let first = model.urls.first
        let isFile = first?.isFileURL ?? false
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: isFile ? "doc" : "link")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                // file URL は host を持たないのでファイル名を見出しにする
                Text((isFile ? first?.lastPathComponent : first?.host) ?? "")
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                if model.urls.count > 1 {
                    Text(String(format: L("+%d more"), model.urls.count - 1))
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.2), in: Capsule())
                }
            }
            // file URL はパーセントエンコード済み absoluteString よりパスの方が読みやすい
            Text((isFile ? first?.path : first?.absoluteString) ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

private struct ProfileRow: View {
    let profile: ChromeProfile
    let index: Int
    let isSelected: Bool
    let showEmail: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(index < 9 ? "\(index + 1)" : "")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 12)
            ProfileAvatarView(profile: profile, size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(profile.name)
                    .font(.body)
                    .lineLimit(1)
                if showEmail, let email = profile.email {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(
            isSelected ? Color.accentColor.opacity(0.18) : .clear,
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
    }

}

struct ProfileAvatarView: View {
    let profile: ChromeProfile
    let size: CGFloat

    var body: some View {
        if let image = profile.avatar {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            ZStack {
                Circle().fill(profile.fillColor.map(Color.init(nsColor:)) ?? fallbackColor)
                Text(profile.initial)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(profile.strokeColor.map(Color.init(nsColor:)) ?? .white)
            }
            .frame(width: size, height: size)
        }
    }

    /// Chrome がプロファイルカラーを持たない場合の予備(ディレクトリ名のハッシュで固定色)
    private var fallbackColor: Color {
        let palette: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo, .red]
        var hash = 0
        for scalar in profile.directory.unicodeScalars {
            hash = (hash &* 31 &+ Int(scalar.value)) & 0x7FFF_FFFF
        }
        return palette[hash % palette.count]
    }
}
