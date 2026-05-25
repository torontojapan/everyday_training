import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct FriendsView: View {
    @Environment(FriendsStore.self) private var friendsStore
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingAdd = false
    @State private var isShowingSignIn = false

    var body: some View {
        Group {
            if let profile = friendsStore.profile {
                signedInBody(profile: profile)
            } else {
                signedOutBody
            }
        }
        .background(Palette.background)
        .navigationTitle("友達")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await friendsStore.refresh()
        }
        .sheet(isPresented: $isShowingAdd) {
            NavigationStack {
                FriendAddView()
                    .environment(friendsStore)
            }
        }
        .sheet(isPresented: $isShowingSignIn) {
            FriendsSignInSheet(isPresented: $isShowingSignIn)
                .environment(friendsStore)
        }
    }

    // MARK: - Signed out

    private var signedOutBody: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Palette.primary)
                    .padding(.top, 40)
                Text("友達と連続記録を分かち合う")
                    .font(Typography.title)
                    .multilineTextAlignment(.center)
                Text("サインインすると、連続記録と今日のメニュー (種目名のみ) を友達と共有できます。体重・体調などのプライベートな記録は共有されません。")
                    .font(Typography.body)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                PrimaryButton("サインインして始める", systemImage: "person.crop.circle.badge.checkmark") {
                    isShowingSignIn = true
                }
                .padding(.top, 12)
                .accessibilityIdentifier("friends-signin-button")

                Text("※ Apple ID ベースのサインインを将来 CloudKit で実装予定。現在はデモ用のローカルプロフィールを作成します。")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 8)
            }
            .padding(20)
        }
    }

    // MARK: - Signed in

    private func signedInBody(profile: FriendProfile) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                profileHeader(profile)

                if !friendsStore.requests.isEmpty {
                    requestsSection
                }

                friendsSection

                Button(role: .destructive) {
                    Task { await friendsStore.signOut() }
                } label: {
                    Label("サインアウト", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(Typography.caption)
                }
                .padding(.top, 20)
            }
            .padding(20)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingAdd = true
                } label: {
                    Image(systemName: "person.crop.circle.badge.plus")
                }
                .accessibilityLabel("友達を追加")
                .accessibilityIdentifier("friend-add-button")
            }
        }
    }

    private func profileHeader(_ profile: FriendProfile) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                avatar(tier: profile.decorationTier)
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.displayName)
                        .font(Typography.title)
                        .foregroundStyle(Palette.textPrimary)
                    Text("@\(profile.username)")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                    Text("🔥 \(profile.currentStreak) 日連続")
                        .font(Typography.headline)
                        .foregroundStyle(Palette.primaryDeep)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("あなたの友達コード")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                HStack {
                    Text(profile.friendCode)
                        .font(.system(size: 28, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Palette.primaryDeep)
                    Spacer()
                    ShareLink(item: shareText(for: profile)) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18))
                            .foregroundStyle(Palette.primaryDeep)
                    }
                }
                if let qr = qrImage(text: profile.friendCode) {
                    HStack {
                        Spacer()
                        Image(uiImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 140, height: 140)
                            .padding(8)
                            .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        Spacer()
                    }
                }
            }
            .padding(16)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("申請が届いています (\(friendsStore.requests.count))")
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
            ForEach(friendsStore.requests) { request in
                requestRow(request)
            }
        }
    }

    private func requestRow(_ request: FriendRequest) -> some View {
        HStack(spacing: 12) {
            avatar(tier: request.fromProfile.decorationTier, small: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(request.fromProfile.displayName)
                    .font(Typography.body)
                    .foregroundStyle(Palette.textPrimary)
                Text("@\(request.fromProfile.username) · 🔥 \(request.fromProfile.currentStreak) 日連続")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            Button("承認") {
                Task { await friendsStore.accept(request) }
            }
            .font(Typography.caption)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Palette.primary, in: Capsule())
            .foregroundStyle(.white)
            Button {
                Task { await friendsStore.decline(request) }
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(Palette.textSecondary)
            }
            .accessibilityLabel("拒否")
        }
        .padding(12)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("友達 (\(friendsStore.friends.count))")
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
            if friendsStore.friends.isEmpty {
                EmptyStateView(message: "友達コードでつながろう。右上の + から追加できます。")
            } else {
                ForEach(friendsStore.friends) { friend in
                    friendCard(friend)
                }
            }
        }
    }

    private func friendCard(_ friend: FriendProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                avatar(tier: friend.decorationTier)
                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.displayName)
                        .font(Typography.headline)
                        .foregroundStyle(Palette.textPrimary)
                    Text("@\(friend.username)")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("🔥 \(friend.currentStreak)")
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(Palette.primaryDeep)
                    Text("累計 \(friend.totalAchievedDays)日")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            HStack(spacing: 6) {
                if friend.todayAchieved {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(Palette.success)
                    Text("今日:")
                        .font(Typography.caption).foregroundStyle(Palette.textSecondary)
                    if let cat = friend.todayCategoryName {
                        Text(cat)
                            .font(Typography.caption)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Palette.chipBackground, in: Capsule())
                            .foregroundStyle(Palette.primaryDeep)
                    }
                    Text(friend.todayExerciseNames.joined(separator: " / "))
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(2)
                } else {
                    Image(systemName: "hourglass").foregroundStyle(Palette.textSecondary)
                    Text("今日はまだ未達成").font(Typography.caption).foregroundStyle(Palette.textSecondary)
                }
                Spacer()
            }
            HStack(spacing: 10) {
                ForEach(CheerKind.allCases, id: \.self) { kind in
                    Button {
                        Task { await friendsStore.cheer(kind, to: friend.friendCode) }
                    } label: {
                        Text("\(kind.emoji) \(kind.label)")
                            .font(Typography.caption)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Palette.chipBackground, in: Capsule())
                            .foregroundStyle(Palette.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
        .padding(14)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contextMenu {
            Button(role: .destructive) {
                Task { await friendsStore.remove(friend) }
            } label: {
                Label("友達を解除", systemImage: "person.crop.circle.badge.minus")
            }
        }
    }

    private func avatar(tier: Int, small: Bool = false) -> some View {
        let size: CGFloat = small ? 36 : 56
        return ZStack {
            Circle()
                .fill(tierColor(tier).opacity(0.25))
                .frame(width: size, height: size)
            Text("🐱")
                .font(.system(size: small ? 22 : 32))
        }
    }

    private func tierColor(_ tier: Int) -> Color {
        switch tier {
        case 1: return Palette.primary
        case 2: return Palette.settingsAccent
        case 3: return Color(red: 0.90, green: 0.60, blue: 0.20)
        case 4: return Color(red: 1.00, green: 0.82, blue: 0.30)
        default: return Palette.textSecondary
        }
    }

    private func qrImage(text: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(Data(text.utf8), forKey: "inputMessage")
        filter.correctionLevel = "H"
        guard let output = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 8, y: 8)
        let scaled = output.transformed(by: transform)
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    private func shareText(for profile: FriendProfile) -> String {
        "GOエクササイズで一緒に運動しよう！\n友達コード: \(profile.friendCode)\n@\(profile.username) (🔥 \(profile.currentStreak)日連続)"
    }
}

// MARK: - Sign in sheet

struct FriendsSignInSheet: View {
    @Binding var isPresented: Bool
    @Environment(FriendsStore.self) private var friendsStore
    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var username = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("表示名") {
                    TextField("例: ジュン", text: $displayName)
                }
                Section("ユーザー名 (検索用)") {
                    TextField("例: jun88", text: $username)
                        .textInputAutocapitalization(.never)
                    Text("半角英数字推奨。後から変更できます。")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("作成して始める")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                    }
                    .disabled(displayName.isEmpty || username.isEmpty || isSubmitting)
                }
            }
            .navigationTitle("プロフィール作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") {
                        isPresented = false
                        dismiss()
                    }
                }
            }
        }
    }

    private func submit() async {
        isSubmitting = true
        await friendsStore.signIn(displayName: displayName, username: username)
        isSubmitting = false
        isPresented = false
        dismiss()
    }
}
