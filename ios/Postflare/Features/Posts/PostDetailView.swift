import Charts
import SwiftUI

/// One post: content, media, per-account status of its group, metrics, settings, the publishing log and the actions
/// its status allows (retry, cancel, reschedule, resolve, duplicate, delete).
struct PostDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    var postId: String

    @State private var post = Loader<Post>()
    @State private var siblings: [Post] = []
    @State private var metrics: PostMetrics?
    @State private var busy: String?
    @State private var actionError: String?
    @State private var planLimit: PlanLimit?
    @State private var rescheduling = false
    @State private var markingPublished = false
    @State private var publishedURL = ""
    @State private var confirmDelete = false

    var body: some View {
        Group {
            if let p = post.value {
                content(p)
            } else if let error = post.error {
                ContentUnavailableView {
                    Label("Post not available", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { Task { await load() } }.buttonStyle(.glass)
                }
            } else {
                ProgressView().controlSize(.large)
            }
        }
        .navigationTitle(post.value.map { model.account($0.accountId)?.name ?? $0.status.title } ?? String(localized: "Post"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let p = post.value, model.canWrite {
                ToolbarItem(placement: .primaryAction) { moreMenu(p) }
            }
        }
        .task(id: model.dataVersion) { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $rescheduling) {
            if let p = post.value {
                RescheduleSheet(post: p) { date in await perform("schedule") { try await $0.reschedule(p.id, to: date) } }
            }
        }
        .alert("Mark as published", isPresented: $markingPublished) {
            TextField("https://", text: $publishedURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Mark as published") {
                let url = publishedURL.trimmingCharacters(in: .whitespaces)
                Task { await perform("resolve") { try await $0.resolve(postId, published: true, url: url.isEmpty ? nil : url) } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only do this if the post is live on the platform. The link is optional.")
        }
        .confirmationDialog("Delete this post?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await delete() } }
        } message: {
            Text(post.value?.status == .published ? "It is removed from Postflare only, not from the platform." : "This cannot be undone.")
        }
        .alert("Something went wrong", isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(actionError ?? "")
        }
        .planLimitAlert($planLimit)
    }

    // MARK: Content

    @ViewBuilder
    private func content(_ p: Post) -> some View {
        let account = model.account(p.accountId)
        List {
            Section {
                HStack(spacing: 12) {
                    AccountAvatar(account: account, provider: account?.provider ?? "", size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(account?.name ?? String(localized: "Unknown account")).font(.headline)
                        if let handle = account?.handle {
                            Text(handle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        }
                        if let account { Text(model.providerName(account.provider)).font(.caption).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    StatusBadge(status: p.status)
                }
                Label(timeLine(p), systemImage: p.status == .published ? "checkmark.circle" : "calendar")
                    .font(.subheadline)
                if p.attempts > 1 {
                    Label("\(p.attempts) attempts", systemImage: "arrow.clockwise").font(.footnote).foregroundStyle(.secondary)
                }
            }

            if p.status == .needsCheck {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(p.error ?? String(localized: "We couldn't confirm whether the platform accepted the post. Check your profile, then mark it as published or retry."), systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("It is not retried automatically, so it cannot be posted twice by accident.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let error = p.error, p.status == .failed || p.status == .cancelled {
                Section {
                    Label(error, systemImage: "exclamationmark.circle.fill").foregroundStyle(.red)
                }
            }

            actionsSection(p)

            Section("Content") {
                if p.content.isEmpty {
                    Text("No text").italic().foregroundStyle(.secondary)
                } else {
                    Text(p.content).textSelection(.enabled)
                }
                if !p.media.isEmpty { mediaGrid(p.media) }
            }

            if !p.thread.isEmpty {
                Section(String(localized: "Follow-ups")) {
                    ForEach(Array(p.thread.enumerated()), id: \.offset) { i, item in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(i + 1). \(item.content.isEmpty ? String(localized: "Media only") : item.content)")
                            if !item.media.isEmpty { mediaGrid(item.media) }
                        }
                    }
                }
            }

            if siblings.count > 1 { groupSection(p) }

            if p.status == .published { metricsSection() }

            if let campaign = p.campaign, let tracked = campaign.trackedUrl {
                Section("Tracked App Store link") {
                    LabeledContent("Link", value: tracked)
                    LabeledContent("Clicks", value: Fmt.count(campaign.clicks ?? 0))
                    if let d = campaign.downloads { LabeledContent("Downloads", value: Fmt.count(d)) }
                }
            }

            let settings = p.settings.filter { !$0.value.isEmpty }.sorted { $0.key < $1.key }
            if !settings.isEmpty {
                Section("Settings") {
                    ForEach(settings, id: \.key) { k, v in
                        LabeledContent(label(for: k, provider: account?.provider), value: v.display)
                    }
                }
            }

            Section("Publishing log") {
                if let logs = p.logs, !logs.isEmpty {
                    ForEach(logs) { log in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(alignment: .top, spacing: 8) {
                                Circle().fill(log.level == "error" ? Color.red : log.level == "warn" ? Color.orange : Color.secondary)
                                    .frame(width: 7, height: 7)
                                    .padding(.top, 6)
                                Text(log.message)
                                    .font(.subheadline)
                                    .foregroundStyle(log.level == "error" ? Color.red : log.level == "warn" ? Color.orange : Color.primary)
                            }
                            Text(Fmt.date(ms: log.createdAt).formatted(date: .abbreviated, time: .standard))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 15)
                        }
                        .accessibilityElement(children: .combine)
                    }
                } else {
                    Text("No activity yet.").foregroundStyle(.secondary)
                }
            }

            Section {
                Text(p.id).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func mediaGrid(_ ids: [String]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(ids, id: \.self) { MediaThumb(mediaId: $0) }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func actionsSection(_ p: Post) -> some View {
        let canWrite = model.canWrite
        if p.externalUrl != nil || canWrite {
            Section {
                if let url = p.externalUrl.flatMap(URL.init(string:)) {
                    Button { openURL(url) } label: { Label("Open the post", systemImage: "arrow.up.right.square") }
                }
                if canWrite {
                    switch p.status {
                    case .failed, .cancelled:
                        actionButton(p.status == .failed ? "Retry now" : "Publish now", systemImage: "arrow.clockwise", key: "retry") { try await $0.retry(p.id) }
                    case .needsCheck:
                        Button {
                            publishedURL = ""
                            markingPublished = true
                        } label: { Label("Mark as published", systemImage: "checkmark.circle") }
                        actionButton("Retry anyway", systemImage: "arrow.clockwise", key: "resolve") { try await $0.resolve(p.id, published: false, url: nil) }
                    case .scheduled:
                        actionButton("Cancel", systemImage: "slash.circle", key: "cancel", role: .destructive) { try await $0.cancel(p.id) }
                    default:
                        EmptyView()
                    }
                    if p.status.isEditable {
                        Button { rescheduling = true } label: {
                            Label(p.status == .draft ? "Schedule" : "Change schedule", systemImage: "calendar.badge.clock")
                        }
                    }
                }
            } footer: {
                if !canWrite { Text("Your role can view posts but not change them.") }
            }
        }
    }

    private func actionButton(_ title: LocalizedStringKey, systemImage: String, key: String, role: ButtonRole? = nil, _ action: @escaping (APIClient) async throws -> Post) -> some View {
        Button(role: role) {
            Task { await perform(key, action) }
        } label: {
            HStack {
                Label(title, systemImage: systemImage)
                if busy == key { Spacer(); ProgressView() }
            }
        }
        .disabled(busy != nil)
    }

    private func moreMenu(_ p: Post) -> some View {
        Menu {
            Button("Duplicate", systemImage: "plus.square.on.square") { model.compose = ComposeRequest(duplicate: p) }
            if let url = p.externalUrl.flatMap(URL.init(string:)) {
                ShareLink(item: url) { Label("Share link", systemImage: "square.and.arrow.up") }
            }
            if p.status != .publishing {
                Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
            }
        } label: {
            Label("More", systemImage: "ellipsis")
        }
    }

    private func groupSection(_ p: Post) -> some View {
        Section {
            ForEach(siblings) { s in
                if s.id == p.id {
                    siblingRow(s, current: true)
                } else {
                    NavigationLink(value: Route.post(id: s.id)) { siblingRow(s, current: false) }
                }
            }
        } header: {
            Text("Accounts")
        } footer: {
            Text("Posted together: one post per account.")
        }
    }

    private func siblingRow(_ s: Post, current: Bool) -> some View {
        let a = model.account(s.accountId)
        return HStack(spacing: 10) {
            AccountAvatar(account: a, provider: a?.provider ?? "", size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(a?.name ?? s.accountId).font(.subheadline)
                Text(current ? String(localized: "This post") : a.map { model.providerName($0.provider) } ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StatusBadge(status: s.status)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func metricsSection() -> some View {
        Section {
            if let m = metrics?.metrics {
                let rows: [(LocalizedStringKey, Double?)] = [("Views", m.views ?? m.impressions ?? m.reach), ("Likes", m.likes), ("Comments", m.comments), ("Shares", m.shares ?? m.reposts), ("Saves", m.saves), ("Clicks", m.clicks)]
                let shown = rows.filter { $0.1 != nil }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(Array(shown.enumerated()), id: \.offset) { _, row in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Fmt.compact(row.1 ?? 0)).font(.system(.title3, design: .rounded).weight(.bold)).monospacedDigit()
                            Text(row.0).font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.vertical, 4)
                if let rate = m.exposure.flatMap({ $0 > 0 ? m.engagements / $0 : nil }) {
                    LabeledContent("Engagement rate", value: Fmt.percent(rate))
                }
                if let snaps = metrics?.snapshots, snaps.count > 1 {
                    Chart(snaps, id: \.capturedAt) { s in
                        LineMark(x: .value("Time", Fmt.date(ms: s.capturedAt)), y: .value("Views", s.metrics.exposure ?? 0))
                            .foregroundStyle(Color.brand)
                            .interpolationMethod(.monotone)
                        PointMark(x: .value("Time", Fmt.date(ms: s.capturedAt)), y: .value("Views", s.metrics.exposure ?? 0))
                            .foregroundStyle(Color.brand)
                    }
                    .frame(height: 120)
                    .accessibilityLabel(Text("Views over time"))
                }
                if let at = metrics?.metricsAt {
                    Text("Collected \(Fmt.relative(ms: at))").font(.caption).foregroundStyle(.secondary)
                }
            } else if let next = metrics?.metricsNextAt {
                Text("First numbers \(Fmt.relative(ms: next)).").foregroundStyle(.secondary)
            } else {
                Text("No numbers yet.").foregroundStyle(.secondary)
            }
        } header: {
            Text("Performance")
        }
    }

    // MARK: Helpers

    private func timeLine(_ p: Post) -> String {
        switch p.status {
        case .published: String(localized: "Published \(Fmt.when(p.date))")
        case .draft: String(localized: "Draft · created \(Fmt.when(Fmt.date(ms: p.createdAt)))")
        case .scheduled: String(localized: "Scheduled for \(Fmt.when(p.date))")
        default: Fmt.when(p.date)
        }
    }

    private func label(for key: String, provider: String?) -> String {
        provider.flatMap { model.provider($0) }?.settingsFields.first { $0.key == key }?.label ?? key
    }

    private func load() async {
        guard let client = model.client else { return }
        post.use(cacheKey: ResponseCache.key("post", postId))
        await post.load { try await client.post(postId) }
        guard let p = post.value else { return }
        model.loadMedia(p.media + p.thread.flatMap(\.media))
        var q = APIClient.PostQuery()
        q.groupId = p.groupId
        q.limit = 100
        if let group = try? await client.posts(q) { siblings = group.sorted { (model.account($0.accountId)?.name ?? "") < (model.account($1.accountId)?.name ?? "") } }
        if p.status == .published { metrics = try? await client.postMetrics(p.id) }
    }

    private func perform(_ key: String, _ action: (APIClient) async throws -> Post) async {
        guard let client = model.client else { return }
        busy = key
        defer { busy = nil }
        do {
            let updated = try await action(client)
            var merged = updated
            merged.logs = updated.logs ?? post.value?.logs
            post.set(merged)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            model.dataChanged()
        } catch let APIError.planLimit(limit) {
            planLimit = limit
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            actionError = model.handle(error)
        }
    }

    private func delete() async {
        guard let client = model.client else { return }
        do {
            try await client.deletePost(postId)
            model.dataChanged()
            dismiss()
        } catch {
            actionError = model.handle(error)
        }
    }
}

/// Date picker for a new schedule, or "Save as draft".
struct RescheduleSheet: View {
    @Environment(\.dismiss) private var dismiss
    var post: Post
    var save: (Date?) async -> Void
    @State private var date: Date
    @State private var working = false

    init(post: Post, save: @escaping (Date?) async -> Void) {
        self.post = post
        self.save = save
        let current = post.scheduledAt.map(Fmt.date(ms:)) ?? .now.addingTimeInterval(3600)
        _date = State(initialValue: max(current, .now.addingTimeInterval(5 * 60)))
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Publish at", selection: $date, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                if post.status != .draft {
                    Button("Save as draft instead", systemImage: "doc.text") { Task { await run(nil) } }
                }
            }
            .navigationTitle(post.status == .draft ? "Schedule" : "Change schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await run(date) } }.disabled(working)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func run(_ d: Date?) async {
        working = true
        await save(d)
        working = false
        dismiss()
    }
}
