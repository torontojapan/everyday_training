import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

enum FriendSortOrder: String, CaseIterable, Identifiable {
    case streakDesc        // 連続日数の多い順
    case todayFirst        // 今日達成済みを先頭に
    case recentlyUpdated   // 最終更新が新しい順

    var id: String { rawValue }

    var label: String {
        switch self {
        case .streakDesc: return "連続日数順"
        case .todayFirst: return "今日達成順"
        case .recentlyUpdated: return "更新順"
        }
    }
}

struct FriendsView: View {
    @Environment(FriendsStore.self) private var friendsStore
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingAdd = false
    @State private var isShowingSignIn = false
    @State private var sortOrder: FriendSortOrder = .streakDesc
    @State private var detailFriend: FriendProfile?
    @State private var cheerToast: String?
    @State private var cheerToastToken: UUID?
    @State private var pendingRemovalFriend: FriendProfile?
    @State private var isShowingMyQR = false
    @State private var cheerTarget: FriendProfile?
    /// Phase 7.0: 友達画面に「リスト / 公園」切替セグメント追加。
    @State private var displayMode: DisplayMode = .park
    private let hapticFeedback: any HapticFeedbackProviding = HapticFeedback()

    enum DisplayMode: String, CaseIterable { case park, list }

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
            // --mock-open-* はスクショ / デモ専用の自動オープン。Release では無効化し、
            // 本番でデモ動線が勝手に開かないようにする (debug 引数は Release で無効)。
            #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            if args.contains("--mock-open-friend-detail") {
                // open the highest-streak friend so screenshots show a rich profile
                let best = FriendSorter.sort(friendsStore.friends, by: .streakDesc).first
                detailFriend = best
            }
            if args.contains("--mock-open-friend-add") {
                isShowingAdd = true
            }
            #endif
        }
        .overlay(alignment: .bottom) {
            // toast を下部に移動。上部は Dynamic Island / Navigation Bar
            // と被るため、下部 safe area の少し上の方が衝突しにくい。
            if let cheerToast {
                Text(cheerToast)
                    .font(Typography.caption)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.bottom, 24)
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .accessibilityIdentifier("friend-cheer-toast")
            }
        }
        .animation(.easeOut(duration: 0.25), value: cheerToast)
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
        .sheet(item: $detailFriend) { friend in
            FriendDetailView(friend: friend)
                .environment(friendsStore)
        }
        .confirmationDialog(
            pendingRemovalFriend.map { "\($0.displayName) を友達から外しますか？" } ?? "",
            isPresented: Binding(
                get: { pendingRemovalFriend != nil },
                set: { if !$0 { pendingRemovalFriend = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingRemovalFriend
        ) { friend in
            Button("友達を解除", role: .destructive) {
                Task { await friendsStore.remove(friend) }
                pendingRemovalFriend = nil
            }
            Button("キャンセル", role: .cancel) {
                pendingRemovalFriend = nil
            }
        } message: { _ in
            Text("再度つながるには友達コードで申請が必要です。")
        }
        .sheet(item: $cheerTarget) { friend in
            CheerPickerSheet(friend: friend) { kind in
                cheerTarget = nil
                Task { await sendCheer(kind, to: friend) }
            }
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
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

                // サインイン前でもアプリを友達に紹介できる導線。
                shareAppCard
                    .padding(.top, 24)
            }
            .padding(20)
        }
    }

    /// 「このアプリを友達にシェア」セクション。SwiftUI 標準の `ShareLink` で
    /// LINE / メッセージ / Twitter / メール などの share sheet を呼び出す。
    /// 共有先 URL とメッセージは [[AppSharingConfig]] に集約 (App Store URL
    /// が決まったら 1 箇所差し替えるだけ)。
    private var shareAppCard: some View {
        ShareLink(
            item: AppSharingConfig.shareURL,
            subject: Text(AppSharingConfig.shareSubject),
            message: Text(AppSharingConfig.shareMessage)
        ) {
            HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.up.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Palette.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("このアプリを友達にシェア")
                        .font(Typography.body)
                        .foregroundStyle(Palette.textPrimary)
                    Text("インストール用リンクが LINE / メッセージなどで送れます")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("share-app-button")
        .accessibilityLabel("このアプリを友達にシェア")
    }

    // MARK: - Signed in

    private func signedInBody(profile: FriendProfile) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                profileHeader(profile)

                // アプリ自体を友達に紹介する導線 (友達コードの共有とは別物)。
                // 友達コード = 既にアプリを入れている人を friend に追加するためのコード。
                // shareAppCard = まだアプリを入れていない人に install 用 URL を投げるため。
                // ユーザー要望でプロフィール直下に固定配置 (招待動線をファーストビューに)。
                shareAppCard

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
        .refreshable {
            await friendsStore.refresh()
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

    /// UI test 用 ID。profileHeader 全体を 1 つの accessibility container として
    /// まとめ、shareAppCard との物理的隣接 (= 「直下」要件) を frame 比較で
    /// 検証できるようにする (Codex round3)。
    private static let profileSectionAccessibilityID = "friends-profile-section"

    private func profileHeader(_ profile: FriendProfile) -> some View {
        // 自分のアイコンは UserCatPreferences の breed を反映 (Phase 6.7)。
        let myBreed = UserCatPreferences.shared.myCat
        return VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(myBreed.tintColor.opacity(0.30))
                        .frame(width: 56, height: 56)
                    Image(myBreed.avatarAssetName)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(1.05)
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                }
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

            // 友達コード行は常時表示、QR は折り畳み (デフォルト閉)。
            // 以前は QR まで含めて画面の 60% を占有していたが、これで
            // 友達リストがファーストビューに入る。
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("あなたの友達コード")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textSecondary)
                        Text(profile.friendCode)
                            .font(.system(size: 24, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Palette.primaryDeep)
                    }
                    Spacer()
                    ShareLink(item: shareText(for: profile)) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.primaryDeep)
                            .frame(width: 44, height: 44)
                            .background(Palette.chipBackground, in: Circle())
                    }
                    .accessibilityLabel("友達コードを共有")
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isShowingMyQR.toggle() }
                    } label: {
                        Image(systemName: isShowingMyQR ? "qrcode.viewfinder" : "qrcode")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.primaryDeep)
                            .frame(width: 44, height: 44)
                            .background(Palette.chipBackground, in: Circle())
                    }
                    .accessibilityLabel(isShowingMyQR ? "QR コードを隠す" : "QR コードを表示")
                    .accessibilityIdentifier("toggle-my-qr")
                }
                if isShowingMyQR, let qr = qrImage(text: profile.friendCode) {
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
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(14)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(Self.profileSectionAccessibilityID)
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
            FriendAvatarView(friend: request.fromProfile, size: 36, showsDecorationBorder: true)
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
            HStack {
                Text("友達 (\(friendsStore.friends.count))")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                if !friendsStore.friends.isEmpty {
                    // Phase 7.0 公園 / リスト切替
                    Picker("表示", selection: $displayMode) {
                        Image(systemName: "square.grid.2x2").tag(DisplayMode.park)
                        Image(systemName: "list.bullet").tag(DisplayMode.list)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 90)
                    .accessibilityIdentifier("friends-display-mode")
                }
                if !friendsStore.friends.isEmpty {
                    // 「ランキング」をテキストつき chip に。アイコンだけだと
                    // 何が起きるか分かりにくいので、視認性を優先。
                    NavigationLink {
                        WeeklyRankingView()
                            .environment(friendsStore)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trophy.fill")
                            Text("順位を見る")
                        }
                        .font(Typography.caption)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Palette.settingsAccent.opacity(0.18), in: Capsule())
                        .foregroundStyle(Palette.settingsAccent)
                    }
                    .accessibilityLabel("週間ランキング")
                    .accessibilityIdentifier("weekly-ranking-link")
                    sortMenu
                }
            }
            if friendsStore.friends.isEmpty {
                EmptyStateView(message: "友達コードでつながろう。右上の + から追加できます。")
            } else if displayMode == .park {
                FriendsParkView(friends: sortedFriends) { friend in
                    detailFriend = friend
                    hapticFeedback.tap()
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                ForEach(sortedFriends) { friend in
                    friendCard(friend)
                }
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("並び順", selection: $sortOrder) {
                ForEach(FriendSortOrder.allCases) { order in
                    Text(order.label).tag(order)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                Text(sortOrder.label)
            }
            .font(Typography.caption)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Palette.chipBackground, in: Capsule())
            .foregroundStyle(Palette.textPrimary)
        }
        .accessibilityIdentifier("friend-sort-menu")
    }

    private var sortedFriends: [FriendProfile] {
        FriendSorter.sort(friendsStore.friends, by: sortOrder)
    }

    private func friendCard(_ friend: FriendProfile) -> some View {
        // カードは「装飾 + 名前 + 連続 + 今日達成 + 更新」に絞る。
        Button {
            detailFriend = friend
            hapticFeedback.tap()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    FriendAvatarView(friend: friend, size: 56, showsDecorationBorder: true)
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
                            .monospacedDigit()
                        Text("累計 \(friend.totalAchievedDays)日")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }

                HStack(spacing: 8) {
                    if friend.todayAchieved {
                        Label("今日達成", systemImage: "checkmark.seal.fill")
                            .font(Typography.caption)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Palette.success.opacity(0.15), in: Capsule())
                            .foregroundStyle(Palette.success)
                        if let cat = friend.todayCategoryName {
                            Text(cat)
                                .font(Typography.caption)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Palette.chipBackground, in: Capsule())
                                .foregroundStyle(Palette.primaryDeep)
                        }
                    } else {
                        Label("今日はまだ未達成", systemImage: "hourglass")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Spacer()
                    Text(relativeUpdated(friend.lastUpdated))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)
                }

                // クイック応援: 主要 emoji を 1 タップで送信できる。
                // 「..」は CheerPickerSheet を開いて 4 種から選ぶ既存導線を残す。
                // 2 タップ必要だった応援を、1 タップで完了するショートカット。
                HStack(spacing: 6) {
                    ForEach([CheerKind.fight, .great, .clap, .fire], id: \.self) { kind in
                        Button {
                            Task { await sendCheer(kind, to: friend) }
                        } label: {
                            Text(kind.emoji)
                                .font(.system(size: 20))
                                .frame(minWidth: 44, minHeight: 44)
                                .background(Palette.primary.opacity(0.10), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(friend.displayName) に \(kind.label) を送る")
                        .accessibilityIdentifier("quick-cheer-\(kind.rawValue)-\(friend.friendCode)")
                    }
                    Spacer()
                    Button {
                        cheerTarget = friend
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .heavy))
                            .frame(minWidth: 44, minHeight: 44)
                            .background(Palette.chipBackground, in: Circle())
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(friend.displayName) への応援を選んで送る")
                    .accessibilityIdentifier("open-cheer-sheet-\(friend.friendCode)")
                }
            }
            .padding(14)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary.opacity(0.5))
                    .padding(.top, 14).padding(.trailing, 12)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("friend-card-\(friend.friendCode)")
        .accessibilityHint("タップで詳細を表示")
        .contextMenu {
            Button { detailFriend = friend } label: {
                Label("詳細を見る", systemImage: "person.crop.circle.fill")
            }
            Button(role: .destructive) {
                // 即実行ではなく confirmation dialog 経由に変える。
                // 誤タップで「友達解除」が起きると Undo できない。
                pendingRemovalFriend = friend
            } label: {
                Label("友達を解除", systemImage: "person.crop.circle.badge.minus")
            }
        }
    }

    private func sendCheer(_ kind: CheerKind, to friend: FriendProfile) async {
        hapticFeedback.success()
        await friendsStore.cheer(kind, to: friend.friendCode)
        let token = UUID()
        cheerToastToken = token
        cheerToast = "\(kind.emoji) \(friend.displayName) に \(kind.label) を送りました"
        try? await Task.sleep(for: .seconds(2.0))
        // Only clear the toast if no newer cheer has replaced ours. Using a
        // token avoids the substring race (two friends with overlapping
        // displayName like "あき" / "あきら" would otherwise dismiss each
        // other's toasts).
        if cheerToastToken == token {
            cheerToast = nil
            cheerToastToken = nil
        }
    }

    private var todayWeekdayIndex: Int {
        let wd = Calendar.mondayFirst.component(.weekday, from: Date())
        return (wd + 5) % 7
    }

    private func relativeUpdated(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.unitsStyle = .short
        return "更新 \(formatter.localizedString(for: date, relativeTo: Date()))"
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

// MARK: - Cheer picker sheet

struct CheerPickerSheet: View {
    let friend: FriendProfile
    let onSend: (CheerKind) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("\(friend.displayName) に応援を送る")
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
                .padding(.top, 24)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(CheerKind.allCases, id: \.self) { kind in
                    Button {
                        onSend(kind)
                    } label: {
                        VStack(spacing: 4) {
                            Text(kind.emoji).font(.system(size: 28))
                            Text(kind.label)
                                .font(Typography.body)
                                .foregroundStyle(Palette.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Palette.chipBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(PressableScaleButtonStyle())
                    .accessibilityIdentifier("cheer-sheet-\(kind.rawValue)")
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
        .background(Palette.background)
    }
}

// MARK: - Friend sorting

enum FriendSorter {
    static func sort(_ friends: [FriendProfile], by order: FriendSortOrder) -> [FriendProfile] {
        switch order {
        case .streakDesc:
            return friends.sorted { lhs, rhs in
                if lhs.currentStreak != rhs.currentStreak {
                    return lhs.currentStreak > rhs.currentStreak
                }
                return lhs.totalAchievedDays > rhs.totalAchievedDays
            }
        case .todayFirst:
            return friends.sorted { lhs, rhs in
                if lhs.todayAchieved != rhs.todayAchieved {
                    return lhs.todayAchieved && !rhs.todayAchieved
                }
                return lhs.currentStreak > rhs.currentStreak
            }
        case .recentlyUpdated:
            return friends.sorted { $0.lastUpdated > $1.lastUpdated }
        }
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
                    .disabled(
                        displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        isSubmitting
                    )
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
