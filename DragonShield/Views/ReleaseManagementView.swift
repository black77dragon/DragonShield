// DragonShield/Views/ReleaseManagementView.swift
// Guided Release & Branch Management workflow (v1.0)

import SwiftUI
import Combine
import Foundation

#if os(macOS)
import AppKit
#endif

private enum Surface {
    static var secondary: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(.secondarySystemBackground)
        #endif
    }

    static var tertiary: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(.tertiarySystemBackground)
        #endif
    }
}

private enum StatusLevel: String {
    case ok
    case info
    case warning
    case error
    case running
    case idle

    var color: Color {
        switch self {
        case .ok: return Color.green
        case .info: return Color.blue
        case .warning: return Color.orange
        case .error: return Color.red
        case .running: return Color.blue
        case .idle: return Color.secondary
        }
    }

    var label: String {
        switch self {
        case .ok: return "OK"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .running: return "RUNNING"
        case .idle: return "IDLE"
        }
    }
}

private enum ReleasePrepStep: Int, CaseIterable {
    case checkStatus
    case createBranch
    case captureChanges
    case commitChanges
    case pushBranch
    case openPR
    case mergePR
    case deleteBranch
    case setRelease
    case createTag
    case syncChangelog
    case reviewFinish

    var spineTitle: String {
        switch self {
        case .checkStatus: return "Check Status"
        case .createBranch: return "Create Branch"
        case .captureChanges: return "Capture Local Changes"
        case .commitChanges: return "Commit Changes"
        case .pushBranch: return "Push Branch"
        case .openPR: return "Open PR"
        case .mergePR: return "Merge (Squash)"
        case .deleteBranch: return "Delete Branch"
        case .setRelease: return "Set Release Number"
        case .createTag: return "Create Tag (Annotated)"
        case .syncChangelog: return "Sync Changelog"
        case .reviewFinish: return "Review & Finish"
        }
    }

    var headerTitle: String {
        spineTitle
    }

    var headerDetail: String {
        switch self {
        case .checkStatus:
            return "Confirm the repo is ready and resolve any local changes."
        case .createBranch:
            return "Create and switch to a new feature branch."
        case .captureChanges:
            return "Stage your local changes so they can be committed."
        case .commitChanges:
            return "Save your local work with a short message."
        case .pushBranch:
            return "Upload the branch so GitHub can see it."
        case .openPR:
            return "Create a pull request from your branch to main."
        case .mergePR:
            return "Merge with squash after checks pass."
        case .deleteBranch:
            return "Remove the merged branch from local and remote."
        case .setRelease:
            return "Write the new release number into the VERSION file."
        case .createTag:
            return "Create the release tag after VERSION is set."
        case .syncChangelog:
            return "Rebuild CHANGELOG.md and the archive from new_features.md."
        case .reviewFinish:
            return "Quick final review of the release artifacts."
        }
    }

    var typicalTime: String {
        switch self {
        case .checkStatus: return "1 minute"
        case .createBranch: return "1 minute"
        case .captureChanges: return "1-2 minutes"
        case .commitChanges: return "2 minutes"
        case .pushBranch: return "1 minute"
        case .openPR: return "2 minutes"
        case .mergePR: return "1-5 minutes"
        case .deleteBranch: return "1 minute"
        case .setRelease: return "1 minute"
        case .createTag: return "1 minute"
        case .syncChangelog: return "1-2 minutes"
        case .reviewFinish: return "2 minutes"
        }
    }
}

private enum SpineStatus {
    case notStarted
    case active
    case completed
    case blocked
    case warning

    var symbol: String {
        switch self {
        case .notStarted: return "○"
        case .active: return "●"
        case .completed: return "✓"
        case .blocked: return "!"
        case .warning: return "!"
        }
    }

    var symbolColor: Color {
        switch self {
        case .notStarted: return .secondary
        case .active: return .accentColor
        case .completed: return .green
        case .blocked: return .red
        case .warning: return .orange
        }
    }

    var textColor: Color {
        switch self {
        case .blocked: return .red
        case .warning: return .orange
        case .notStarted: return .secondary
        case .active, .completed: return .primary
        }
    }
}

private struct ReleaseSystemStatus {
    var repoRoot: URL?
    var repoPath: String = "Not found"
    var originURL: String = "-"
    var currentBranch: String = "-"
    var upstreamBranch: String = "-"
    var defaultBaseBranch: String = "main"
    var isClean: Bool = false
    var uncommittedCount: Int = 0
    var untrackedCount: Int = 0
    var version: String = ""
    var latestTag: String = ""
    var versionMatchesTag: Bool = false
    var gitVersion: String = ""
    var pythonVersion: String = ""
    var changelogScriptPath: String = ""
    var githubTokenPresent: Bool = false
    var githubTokenSource: String = "Missing"
    var lastError: String? = nil
    var repoOverridePath: String = ""
    var repoOverrideValid: Bool = false

    static let empty = ReleaseSystemStatus()
}

private struct PullRequestInfo {
    let number: Int
    let url: String
    let headSha: String
    let state: String
    let mergeable: Bool?
    let mergeableState: String?
}

private struct ChecksSummary {
    let state: String
    let description: String
}

private struct ProcessSpineItem: Identifiable {
    let id: String
    let title: String
    let status: SpineStatus
    let isSelectable: Bool
    let help: String?
    let step: ReleasePrepStep
}

private final class ReleaseManagementModel: ObservableObject {
    @Published var releaseStep: ReleasePrepStep = .checkStatus

    @Published var systemStatus: ReleaseSystemStatus = .empty
    @Published var statusMessage: String = "Idle"
    @Published var statusLevel: StatusLevel = .idle
    @Published var isRunning: Bool = false

    @Published var newVersion: String = ""
    @Published var branchName: String = ""
    @Published var commitMessage: String = ""
    @Published var prTitle: String = ""
    @Published var prBody: String = ""
    @Published var includeUntracked: Bool = true
    @Published var stageMessage: String = ""

    @Published var includeGitHubData: Bool = true
    @Published var dryRun: Bool = false

    @Published var lastOutput: String = ""
    @Published var lastError: String = ""
    @Published var lastSyncAt: Date?
    @Published var lastTagAt: Date?
    @Published var repoRootOverride: String = UserDefaults.standard.string(forKey: "release.repoRootOverride") ?? ""
    @Published var githubTokenInput: String = ""
    @Published var githubTokenSaved: Bool = false
    @Published var isNewRelease: Bool = true
    @Published var dirtyWorkspaceAcknowledged: Bool = false

    @Published var versionWritten: Bool = false
    @Published var tagCreated: Bool = false
    @Published var changelogSynced: Bool = false

    @Published var branchCreated: Bool = false
    @Published var changesCaptured: Bool = false
    @Published var changesCommitted: Bool = false
    @Published var branchPushed: Bool = false
    @Published var prInfo: PullRequestInfo?
    @Published var checksSummary: ChecksSummary?
    @Published var prMerged: Bool = false
    @Published var branchDeleted: Bool = false
}

struct ReleaseManagementRootView: View {
    @StateObject private var model = ReleaseManagementModel()

    var body: some View {
        Group {
            #if os(macOS)
            HStack(spacing: 0) {
                workflowSidebar
                    .frame(width: 260)
                    .background(Surface.tertiary)
                Divider()
                workflowDetail
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            #else
            workflowDetail
            #endif
        }
        .navigationTitle("Release Management")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            refreshStatus()
        }
    }

    private var workflowSidebar: some View {
        ScrollView {
            ReleaseWorkflowSidebarView(model: model, onSelect: selectSpineItem)
                .padding(12)
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private var workflowDetail: some View {
        ReleaseWorkflowDetailView(model: model,
                                  onAdvanceRelease: advanceReleaseStep,
                                  onRefreshStatus: refreshStatus,
                                  onApplyRepoRoot: applyRepoRootOverride,
                                  onSaveGitHubToken: saveGitHubToken,
                                  onClearGitHubToken: clearGitHubToken,
                                  onCaptureChanges: captureChanges,
                                  onCreateBranch: createBranch,
                                  onCommitChanges: commitChanges,
                                  onPushBranch: pushBranch,
                                  onWriteVersion: writeVersion,
                                  onCreateTag: createTag,
                                  onSyncChangelog: syncChangelog,
                                  onCreatePR: createPullRequest,
                                  onRefreshChecks: refreshPullRequestChecks,
                                  onMergePR: mergePullRequest,
                                  onDeleteBranch: deleteBranch)
    }
}

private struct ReleaseWorkflowSidebarView: View {
    @ObservedObject var model: ReleaseManagementModel
    let onSelect: (ProcessSpineItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(spineSections) { section in
                VStack(alignment: .leading, spacing: 6) {
                    Text(section.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(section.items) { item in
                        Button {
                            onSelect(item)
                        } label: {
                            HStack(spacing: 8) {
                                Text(item.status.symbol)
                                    .foregroundStyle(item.status.symbolColor)
                                    .frame(width: 16, alignment: .leading)
                                Text(item.title)
                                    .foregroundStyle(item.status.textColor)
                                    .font(.subheadline)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(!item.isSelectable)
                        .help(item.help ?? "")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var spineSections: [ProcessSpineSection] {
        [
            ProcessSpineSection(id: "release", title: "Release Workflow", items: releaseItems),
        ]
    }

    private var releaseItems: [ProcessSpineItem] {
        let currentIndex = model.releaseStep.rawValue
        return ReleasePrepStep.allCases.map { step in
            let status = releaseStepStatus(step)
            let isSelectable = step.rawValue <= currentIndex
            return ProcessSpineItem(
                id: "release_\(step.rawValue)",
                title: step.spineTitle,
                status: status,
                isSelectable: isSelectable,
                help: status == .blocked ? releaseBlockedReason(step) : nil,
                step: step
            )
        }
    }

    private func releaseStepStatus(_ step: ReleasePrepStep) -> SpineStatus {
        if model.releaseStep == step { return .active }
        if step.rawValue < model.releaseStep.rawValue { return .completed }
        if !canSelectReleaseStep(step) { return .blocked }
        return .notStarted
    }

    private func canSelectReleaseStep(_ step: ReleasePrepStep) -> Bool {
        let prereqs = model.systemStatus.repoRoot != nil
            && !model.systemStatus.gitVersion.isEmpty
            && !model.systemStatus.pythonVersion.isEmpty
            && !model.systemStatus.changelogScriptPath.isEmpty
        switch step {
        case .checkStatus,
             .createBranch,
             .captureChanges,
             .commitChanges,
             .pushBranch,
             .openPR,
             .mergePR,
             .deleteBranch,
             .setRelease:
            return prereqs
        case .createTag:
            return prereqs && model.systemStatus.isClean && !model.systemStatus.version.isEmpty
        case .syncChangelog:
            return prereqs && (model.tagCreated || model.systemStatus.versionMatchesTag)
        case .reviewFinish:
            return model.changelogSynced
        }
    }

    private func releaseBlockedReason(_ step: ReleasePrepStep) -> String {
        let prereqsMet = model.systemStatus.repoRoot != nil
            && !model.systemStatus.gitVersion.isEmpty
            && !model.systemStatus.pythonVersion.isEmpty
            && !model.systemStatus.changelogScriptPath.isEmpty
        switch step {
        case .checkStatus,
             .createBranch,
             .captureChanges,
             .commitChanges,
             .pushBranch,
             .openPR,
             .mergePR,
             .deleteBranch,
             .setRelease:
            return prereqsMet ? "" : "Resolve the red issues in system status before continuing."
        case .createTag:
            if model.systemStatus.version.isEmpty { return "VERSION must be set before tagging." }
            return "Working tree must be clean before tagging."
        case .syncChangelog:
            return "Create the release tag first so items map correctly."
        case .reviewFinish:
            return "Run the changelog sync before final review."
        }
    }
}

private struct ProcessSpineSection: Identifiable {
    let id: String
    let title: String
    let items: [ProcessSpineItem]
}

private struct ReleaseWorkflowDetailView: View {
    @ObservedObject var model: ReleaseManagementModel
    let onAdvanceRelease: () -> Void
    let onRefreshStatus: () -> Void
    let onApplyRepoRoot: () -> Void
    let onSaveGitHubToken: () -> Void
    let onClearGitHubToken: () -> Void
    let onCaptureChanges: () -> Void
    let onCreateBranch: () -> Void
    let onCommitChanges: () -> Void
    let onPushBranch: () -> Void
    let onWriteVersion: () -> Void
    let onCreateTag: () -> Void
    let onSyncChangelog: () -> Void
    let onCreatePR: () -> Void
    let onRefreshChecks: () -> Void
    let onMergePR: () -> Void
    let onDeleteBranch: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(currentSectionTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        StepHeaderView(title: currentHeaderTitle, detail: currentHeaderDetail)
                    }
                    Spacer()
                }
                ReleaseActionStatusView(level: model.statusLevel,
                                        message: model.statusMessage,
                                        isRunning: model.isRunning,
                                        lastError: model.lastError)
                ScrollView {
                    currentStepContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(DSLayout.spaceM)
            Divider()
            ReleaseSystemStateBar(level: model.statusLevel, message: model.statusMessage)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var currentHeaderTitle: String {
        model.releaseStep.headerTitle
    }

    private var currentSectionTitle: String {
        "Release Workflow"
    }

    private var currentHeaderDetail: String {
        let index = model.releaseStep.rawValue + 1
        let total = ReleasePrepStep.allCases.count
        let time = model.releaseStep.typicalTime
        return "Step \(index) of \(total) - Typical time: \(time)"
    }

    private var releasePrereqsMet: Bool {
        let status = model.systemStatus
        return status.repoRoot != nil
            && !status.gitVersion.isEmpty
            && !status.pythonVersion.isEmpty
            && !status.changelogScriptPath.isEmpty
    }

    private var canContinueCheckStatus: Bool {
        if model.systemStatus.isClean { return releasePrereqsMet }
        return releasePrereqsMet && model.dirtyWorkspaceAcknowledged
    }

    private var needsBranchSteps: Bool {
        let status = model.systemStatus
        if status.repoRoot == nil { return false }
        if !status.isClean { return true }
        return model.branchCreated
            || model.changesCaptured
            || model.changesCommitted
            || model.branchPushed
            || model.prInfo != nil
            || model.prMerged
            || model.branchDeleted
    }

    private var canAdvanceReleaseStep: Bool {
        switch model.releaseStep {
        case .checkStatus:
            return canContinueCheckStatus
        case .createBranch:
            return !needsBranchSteps || model.branchCreated
        case .captureChanges:
            return !needsBranchSteps || model.changesCaptured
        case .commitChanges:
            return !needsBranchSteps || model.changesCommitted
        case .pushBranch:
            return !needsBranchSteps || model.branchPushed
        case .openPR:
            return !needsBranchSteps || model.prInfo != nil
        case .mergePR:
            return !needsBranchSteps || model.prMerged
        case .deleteBranch:
            return !needsBranchSteps || model.branchDeleted
        case .setRelease:
            if model.isNewRelease {
                return model.versionWritten
            }
            return model.systemStatus.versionMatchesTag && !model.systemStatus.version.isEmpty
        case .createTag:
            return model.tagCreated || model.systemStatus.versionMatchesTag
        case .syncChangelog:
            return model.changelogSynced
        case .reviewFinish:
            return model.changelogSynced
        }
    }

    private var releaseBlockerText: String {
        if !releasePrereqsMet {
            return "Resolve the red issues above to continue."
        }
        if model.releaseStep == .checkStatus, !model.systemStatus.isClean, !model.dirtyWorkspaceAcknowledged {
            return "Confirm the dirty workspace or capture changes before continuing."
        }
        if needsBranchSteps {
            switch model.releaseStep {
            case .createBranch:
                return "Create the feature branch before continuing."
            case .captureChanges:
                return "Stage your local changes before continuing."
            case .commitChanges:
                return "Commit your changes before continuing."
            case .pushBranch:
                return "Push the branch before continuing."
            case .openPR:
                return model.systemStatus.githubTokenPresent ? "Create the pull request before continuing." : "Add a GitHub token before creating a PR."
            case .mergePR:
                return "Merge the PR before continuing."
            case .deleteBranch:
                return "Delete the branch before continuing."
            default:
                break
            }
        }
        if model.releaseStep == .setRelease {
            if model.isNewRelease && !model.versionWritten {
                return "Write the VERSION file before continuing."
            }
            if !model.isNewRelease && !model.systemStatus.versionMatchesTag {
                return "VERSION must match the latest tag before continuing."
            }
        }
        if model.releaseStep == .createTag, !model.tagCreated {
            return "Create the release tag before continuing."
        }
        if model.releaseStep == .syncChangelog, !model.changelogSynced {
            return "Run the sync script before continuing."
        }
        return "Resolve the required items before continuing."
    }

    private var statusIssues: [StatusIssue] {
        var issues: [StatusIssue] = []
        let status = model.systemStatus

        if status.repoRoot == nil {
            let fix = "Set a Repo Path override below (full path to the repo), or launch the app from the repo folder."
            issues.append(StatusIssue(level: .error, title: "Repository not found", detail: "Git could not locate the repo root.", fix: fix))
        }
        if !status.repoOverridePath.isEmpty, !status.repoOverrideValid {
            let level: StatusLevel = status.repoRoot == nil ? .error : .warning
            issues.append(StatusIssue(level: level, title: "Repo path override invalid", detail: status.repoOverridePath, fix: "Check the path and try again."))
        }
        if status.gitVersion.isEmpty {
            issues.append(StatusIssue(level: .error, title: "Git not available", detail: "git is missing or not on PATH.", fix: "Install Git (Xcode Command Line Tools) and restart the app."))
        }
        if status.pythonVersion.isEmpty {
            issues.append(StatusIssue(level: .error, title: "Python 3 not available", detail: "python3 is missing or not on PATH.", fix: "Install Python 3 and restart the app."))
        }
        if status.changelogScriptPath.isEmpty {
            issues.append(StatusIssue(level: .error, title: "Sync script not found", detail: "scripts/sync_changelog.py was not found.", fix: "Ensure you are using a local repo checkout with the scripts/ folder."))
        }
        if status.repoRoot != nil, !status.isClean {
            let level: StatusLevel = .warning
            let fix = needsBranchSteps
                ? "Continue to the branch steps to capture and merge these updates before tagging."
                : "Use the branch steps below to capture your local changes into a feature branch."
            issues.append(StatusIssue(level: level, title: "Workspace is dirty", detail: "Uncommitted or untracked changes detected.", fix: fix))
        }
        if status.version.isEmpty {
            issues.append(StatusIssue(level: .warning, title: "VERSION is empty", detail: "No release number is set.", fix: "Enter a release number and write VERSION."))
        }
        if status.latestTag.isEmpty {
            issues.append(StatusIssue(level: .warning, title: "No release tags found", detail: "Git has no vX.Y.Z tags.", fix: "Create the first release tag after writing VERSION."))
        }
        if !status.version.isEmpty, !status.latestTag.isEmpty, !status.versionMatchesTag {
            let level: StatusLevel = model.isNewRelease ? .info : .warning
            let fix = model.isNewRelease
                ? "This is expected for a new release. Create the new tag v\(status.version)."
                : "Update VERSION to match the latest tag."
            issues.append(StatusIssue(level: level, title: "VERSION does not match latest tag", detail: "\(status.version) vs \(status.latestTag)", fix: fix))
        }
        if status.originURL == "-" {
            issues.append(StatusIssue(level: .warning, title: "Origin remote missing", detail: "No origin remote was found.", fix: "Add an origin remote in git before pushing a branch."))
        }
        if model.includeGitHubData && !status.githubTokenPresent {
            issues.append(StatusIssue(level: .warning, title: "GitHub token missing", detail: "Release notes from GitHub will be skipped.", fix: "Set GITHUB_TOKEN in your environment or use the token field."))
        }
        if !status.githubTokenPresent, needsBranchSteps {
            issues.append(StatusIssue(level: .error, title: "GitHub token required for PRs", detail: "PR creation and merge require a token.", fix: "Add a token in the GitHub token field."))
        }

        return issues
    }

    @ViewBuilder
    private var currentStepContent: some View {
        switch model.releaseStep {
        case .checkStatus:
            releaseCheckStatusView
        case .createBranch:
            branchCreateView
        case .captureChanges:
            branchCaptureChangesView
        case .commitChanges:
            branchCommitView
        case .pushBranch:
            branchPushView
        case .openPR:
            branchOpenPRView
        case .mergePR:
            branchMergeView
        case .deleteBranch:
            branchDeleteView
        case .setRelease:
            releaseSetNumberView
        case .createTag:
            releaseCreateTagView
        case .syncChangelog:
            releaseSyncChangelogView
        case .reviewFinish:
            releaseReviewFinishView
        }
    }

    private var releaseCheckStatusView: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceM) {
            workflowInfoCard(title: "What this does", lines: [
                "Shows the current version, latest tag, and workspace cleanliness.",
                "A clean workspace means there are no unsaved code changes.",
                "If it is dirty, you can resolve it right here before tagging."
            ])
            ResolveIssuesCard(issues: statusIssues)
            ReleaseIntentCard(isNewRelease: $model.isNewRelease,
                              version: $model.newVersion,
                              currentVersion: model.systemStatus.version,
                              latestTag: model.systemStatus.latestTag,
                              isRunning: model.isRunning,
                              onWrite: onWriteVersion)
            if model.systemStatus.repoRoot != nil && !model.systemStatus.isClean {
                DirtyWorkspaceResolveCard(branchName: $model.branchName,
                                          commitMessage: $model.commitMessage,
                                          includeUntracked: $model.includeUntracked,
                                          acknowledged: $model.dirtyWorkspaceAcknowledged,
                                          isRunning: model.isRunning,
                                          canCreateBranch: model.systemStatus.repoRoot != nil && !model.systemStatus.gitVersion.isEmpty,
                                          canStage: model.systemStatus.repoRoot != nil && !model.systemStatus.gitVersion.isEmpty,
                                          canCommit: model.systemStatus.repoRoot != nil && !model.systemStatus.gitVersion.isEmpty,
                                          canPush: model.systemStatus.originURL != "-" && model.systemStatus.repoRoot != nil && !model.systemStatus.gitVersion.isEmpty,
                                          branchCreated: model.branchCreated,
                                          changesCaptured: model.changesCaptured,
                                          changesCommitted: model.changesCommitted,
                                          branchPushed: model.branchPushed,
                                          onCreateBranch: onCreateBranch,
                                          onStage: onCaptureChanges,
                                          onCommit: onCommitChanges,
                                          onPush: onPushBranch)
            }
            RepoOverrideCard(path: $model.repoRootOverride, isValid: model.systemStatus.repoOverrideValid, onApply: onApplyRepoRoot)
            GitHubTokenCard(token: $model.githubTokenInput,
                            source: model.systemStatus.githubTokenSource,
                            isPresent: model.systemStatus.githubTokenPresent,
                            isRunning: model.isRunning,
                            onSave: onSaveGitHubToken,
                            onClear: onClearGitHubToken)
            SystemStatusCard(status: model.systemStatus)
            HStack {
                Button("Refresh Status") {
                    onRefreshStatus()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isRunning)
                Spacer()
                Button("Continue") {
                    onAdvanceRelease()
                }
                .buttonStyle(.bordered)
                .disabled(model.isRunning || !canAdvanceReleaseStep)
            }
            if !canAdvanceReleaseStep {
                BlockerHint(text: releaseBlockerText)
            }
        }
    }

    private var releaseSetNumberView: some View {
        let canWriteVersion = model.systemStatus.repoRoot != nil
        return VStack(alignment: .leading, spacing: DSLayout.spaceM) {
            workflowInfoCard(title: "What this does", lines: [
                "You choose the new release number (example: 1.40.0).",
                "The app writes it into the VERSION file.",
                "This number must match the tag you create next.",
                "Format: X.Y.Z (numbers only). Do not include a leading \"v\"."
            ])
            card {
                Text("Release number")
                    .font(.headline)
                TextField("Example: 1.40.0", text: $model.newVersion)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Write VERSION") {
                        onWriteVersion()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isRunning || !canWriteVersion)
                    Spacer()
                    Button("Continue") {
                        onAdvanceRelease()
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isRunning || !canAdvanceReleaseStep)
                }
                if model.isNewRelease && !model.versionWritten {
                    BlockerHint(text: "Write the VERSION file before continuing.")
                }
                if !model.isNewRelease && !model.systemStatus.versionMatchesTag {
                    BlockerHint(text: "You marked \"no new release\". VERSION must match the latest tag to continue.")
                }
                if !canWriteVersion {
                    BlockerHint(text: "Repo root not found. Set the repo path override and refresh.")
                }
            }
        }
    }

    private var releaseCreateTagView: some View {
        let canTag = model.systemStatus.isClean && !model.systemStatus.version.isEmpty
        return VStack(alignment: .leading, spacing: DSLayout.spaceM) {
            workflowInfoCard(title: "What this does", lines: [
                "Creates an annotated git tag like v1.40.0.",
                "The tag is created as: v + VERSION.",
                "Annotated tags store a message and timestamp for traceability.",
                "Tagging is blocked if VERSION is missing or the workspace is dirty."
            ])
            card {
                StatusPill(level: canTag ? .ok : .warning, text: canTag ? "READY TO TAG" : "BLOCKED")
                Text("Current VERSION: \(model.systemStatus.version.isEmpty ? "-" : model.systemStatus.version)")
                    .font(.subheadline)
                Text("Latest tag: \(model.systemStatus.latestTag.isEmpty ? "-" : model.systemStatus.latestTag)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !model.systemStatus.version.isEmpty {
                    Text("Next tag: v\(model.systemStatus.version)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("Create Annotated Tag") {
                        onCreateTag()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canTag || model.isRunning)
                    Spacer()
                    Button("Continue") {
                        onAdvanceRelease()
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isRunning || !(model.tagCreated || model.systemStatus.versionMatchesTag))
                }
                if !(model.tagCreated || model.systemStatus.versionMatchesTag) {
                    BlockerHint(text: "Create the release tag before continuing.")
                }
                if !model.systemStatus.isClean {
                    BlockerHint(text: "Workspace is still dirty. Resolve it in Check Status before tagging.")
                }
            }
        }
    }

    private var releaseSyncChangelogView: some View {
        let canSync = !model.systemStatus.changelogScriptPath.isEmpty && !model.systemStatus.pythonVersion.isEmpty
        return VStack(alignment: .leading, spacing: DSLayout.spaceM) {
            workflowInfoCard(title: "What this does", lines: [
                "Rebuilds CHANGELOG.md from new_features.md and git tags.",
                "Includes GitHub release notes if a token is available.",
                "Dry run shows output without writing files."
            ])
            card {
                Toggle("Include GitHub release data (best effort)", isOn: $model.includeGitHubData)
                    .toggleStyle(.switch)
                Toggle("Dry run (preview only)", isOn: $model.dryRun)
                    .toggleStyle(.switch)
                HStack {
                    Button("Run Sync Script") {
                        onSyncChangelog()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isRunning || !canSync)
                    Spacer()
                    Button("Continue") {
                        onAdvanceRelease()
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isRunning || !model.changelogSynced)
                }
                if !model.changelogSynced {
                    BlockerHint(text: "Run the sync script before continuing.")
                }
                if !canSync {
                    BlockerHint(text: "Python and the sync script must be available before running.")
                }
                if !model.lastOutput.isEmpty {
                    Text("Output:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(model.lastOutput)
                        .font(.caption)
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Surface.tertiary))
                }
            }
        }
    }

    private var releaseReviewFinishView: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceM) {
            workflowInfoCard(title: "Final review", lines: [
                "Confirm the tag, VERSION, and changelog match.",
                "You are now ready to publish the GitHub release."
            ])
            card {
                Text("VERSION: \(model.systemStatus.version.isEmpty ? "-" : model.systemStatus.version)")
                    .font(.subheadline)
                Text("Latest tag: \(model.systemStatus.latestTag.isEmpty ? "-" : model.systemStatus.latestTag)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Changelog: CHANGELOG.md")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    #if os(macOS)
                    Button("Open CHANGELOG.md") {
                        openFile(named: "CHANGELOG.md", in: model.systemStatus.repoRoot)
                    }
                    .buttonStyle(.bordered)
                    #endif
                    Spacer()
                    Button("Finish") {
                        onAdvanceRelease()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isRunning || !model.changelogSynced)
                }
            }
        }
    }

    private var branchCreateView: some View {
        let canCreateBranch = model.systemStatus.repoRoot != nil && !model.systemStatus.gitVersion.isEmpty
        let branchRequired = needsBranchSteps
        return VStack(alignment: .leading, spacing: DSLayout.spaceM) {
            workflowInfoCard(title: "What this does", lines: [
                "Creates a new branch and switches to it.",
                "Example: feature/ds-123-short-description."
            ])
            card {
                if !branchRequired {
                    StatusPill(level: .info, text: "OPTIONAL")
                    Text("No local changes detected. You can skip creating a branch and continue.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                TextField("Branch name", text: $model.branchName)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Create & Switch Branch") {
                        onCreateBranch()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.branchName.isEmpty || model.isRunning || !canCreateBranch)
                    Spacer()
                    Button("Continue") {
                        onAdvanceRelease()
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isRunning || !canAdvanceReleaseStep)
                }
                if branchRequired && !model.branchCreated {
                    BlockerHint(text: "Create the branch before continuing.")
                }
                if !canCreateBranch {
                    BlockerHint(text: "Git and repo must be available before creating a branch.")
                }
            }
        }
    }

    private var branchCaptureChangesView: some View {
        let canStage = model.systemStatus.repoRoot != nil && !model.systemStatus.gitVersion.isEmpty
        let branchRequired = needsBranchSteps
        return VStack(alignment: .leading, spacing: DSLayout.spaceM) {
            workflowInfoCard(title: "What this does", lines: [
                "Stages your local changes so they can be committed.",
                "If you include untracked files, new files are added too.",
                "This step is how you gather all local changes into the feature branch."
            ])
            card {
                if !branchRequired {
                    StatusPill(level: .info, text: "OPTIONAL")
                    Text("No local changes detected. You can continue without staging.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Toggle("Include untracked files", isOn: $model.includeUntracked)
                    .toggleStyle(.switch)
                HStack {
                    Button("Stage Changes") {
                        onCaptureChanges()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isRunning || !canStage)
                    Spacer()
                    Button("Continue") {
                        onAdvanceRelease()
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isRunning || !canAdvanceReleaseStep)
                }
                if branchRequired && !model.changesCaptured {
                    BlockerHint(text: "Stage your changes before continuing.")
                }
                if !model.stageMessage.isEmpty {
                    Text(model.stageMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !canStage {
                    BlockerHint(text: "Git and repo must be available before staging changes.")
                }
            }
        }
    }

    private var branchCommitView: some View {
        let canCommit = model.systemStatus.repoRoot != nil && !model.systemStatus.gitVersion.isEmpty
        let branchRequired = needsBranchSteps
        return VStack(alignment: .leading, spacing: DSLayout.spaceM) {
            workflowInfoCard(title: "What this does", lines: [
                "Commits the changes you staged in the previous step.",
                "This is like taking a snapshot of your work."
            ])
            card {
                if !branchRequired {
                    StatusPill(level: .info, text: "OPTIONAL")
                    Text("No local changes detected. You can continue without committing.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                TextField("Commit message", text: $model.commitMessage)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Commit Staged Changes") {
                        onCommitChanges()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.commitMessage.isEmpty || model.isRunning || !canCommit || !model.changesCaptured)
                    Spacer()
                    Button("Continue") {
                        onAdvanceRelease()
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isRunning || !canAdvanceReleaseStep)
                }
                if branchRequired && !model.changesCommitted {
                    BlockerHint(text: "Commit your changes before continuing.")
                }
                if branchRequired && !model.changesCaptured {
                    BlockerHint(text: "Stage changes before committing.")
                }
                if !canCommit {
                    BlockerHint(text: "Git and repo must be available before committing.")
                }
            }
        }
    }

    private var branchPushView: some View {
        let canPush = model.systemStatus.repoRoot != nil && !model.systemStatus.gitVersion.isEmpty && model.systemStatus.originURL != "-"
        let branchRequired = needsBranchSteps
        return VStack(alignment: .leading, spacing: DSLayout.spaceM) {
            workflowInfoCard(title: "What this does", lines: [
                "Uploads your branch to GitHub so a PR can be created.",
                "This sets the remote tracking branch automatically."
            ])
            card {
                if !branchRequired {
                    StatusPill(level: .info, text: "OPTIONAL")
                    Text("No local changes detected. You can continue without pushing.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("Push Branch") {
                        onPushBranch()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isRunning || !canPush)
                    Spacer()
                    Button("Continue") {
                        onAdvanceRelease()
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isRunning || !canAdvanceReleaseStep)
                }
                if branchRequired && !model.branchPushed {
                    BlockerHint(text: "Push the branch before continuing.")
                }
                if branchRequired && !canPush {
                    BlockerHint(text: "Origin remote is missing or git is unavailable.")
                }
            }
        }
    }

    private var branchOpenPRView: some View {
        let canOpenPR = model.systemStatus.githubTokenPresent && model.branchPushed
        let branchRequired = needsBranchSteps
        return VStack(alignment: .leading, spacing: DSLayout.spaceM) {
            workflowInfoCard(title: "What this does", lines: [
                "Creates a pull request from your branch to the main branch.",
                "A pull request is a request to merge your work into main."
            ])
            card {
                if !branchRequired {
                    StatusPill(level: .info, text: "OPTIONAL")
                    Text("No local changes detected. You can continue without opening a PR.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                TextField("PR title", text: $model.prTitle)
                    .textFieldStyle(.roundedBorder)
                TextEditor(text: $model.prBody)
                    .frame(minHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                HStack {
                    Button("Create PR") {
                        onCreatePR()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.prTitle.isEmpty || model.isRunning || !canOpenPR)
                    Spacer()
                    Button("Continue") {
                        onAdvanceRelease()
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isRunning || !canAdvanceReleaseStep)
                }
                if branchRequired && model.prInfo == nil {
                    BlockerHint(text: "Create the pull request before continuing.")
                }
                if branchRequired && !canOpenPR {
                    BlockerHint(text: model.systemStatus.githubTokenPresent ? "Push the branch before creating a PR." : "Set GITHUB_TOKEN before creating a PR.")
                }
                if let prInfo = model.prInfo {
                    Text("PR created: #\(prInfo.number)")
                        .font(.subheadline)
                    Text(prInfo.url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var branchMergeView: some View {
        let checksState = model.checksSummary?.state ?? "unknown"
        let checksOk = checksState == "success"
        let branchRequired = needsBranchSteps
        return VStack(alignment: .leading, spacing: DSLayout.spaceM) {
            workflowInfoCard(title: "What this does", lines: [
                "Merges the PR using squash (one clean commit on main).",
                "If checks fail, the merge will be blocked."
            ])
            card {
                if !branchRequired {
                    StatusPill(level: .info, text: "OPTIONAL")
                    Text("No local changes detected. You can continue without merging.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                StatusPill(level: checksOk ? .ok : .warning, text: "CHECKS: \(checksState.uppercased())")
                if let summary = model.checksSummary {
                    Text(summary.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("Refresh Checks") {
                        onRefreshChecks()
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isRunning)
                    Button("Merge (Squash)") {
                        onMergePR()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!checksOk)
                    Spacer()
                    Button("Continue") {
                        onAdvanceRelease()
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isRunning || !canAdvanceReleaseStep)
                }
                if branchRequired && !model.prMerged {
                    BlockerHint(text: checksOk ? "Merge the PR before continuing." : "Checks must pass before you can merge.")
                }
                if model.prMerged {
                    Text("Merged successfully.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var branchDeleteView: some View {
        let branchRequired = needsBranchSteps
        return VStack(alignment: .leading, spacing: DSLayout.spaceM) {
            workflowInfoCard(title: "What this does", lines: [
                "Deletes the branch after it has been merged.",
                "Keeps the repository clean and tidy."
            ])
            card {
                if !branchRequired {
                    StatusPill(level: .info, text: "OPTIONAL")
                    Text("No local changes detected. You can continue without deleting a branch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("Delete Remote Branch") {
                        onDeleteBranch()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isRunning)
                    Spacer()
                    Button("Continue") {
                        onAdvanceRelease()
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isRunning || !canAdvanceReleaseStep)
                }
                if branchRequired && !model.branchDeleted {
                    BlockerHint(text: "Delete the branch before continuing.")
                }
                if model.branchDeleted {
                    Text("Branch deleted.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func workflowInfoCard(title: String, lines: [String]) -> some View {
        card {
            Text(title)
                .font(.headline)
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceS, content: content)
            .padding(DSLayout.spaceM)
            .background(RoundedRectangle(cornerRadius: DSLayout.radiusL).fill(Surface.secondary))
    }

    private func openFile(named file: String, in root: URL?) {
        #if os(macOS)
        guard let root else { return }
        let url = root.appendingPathComponent(file)
        NSWorkspace.shared.open(url)
        #else
        _ = file
        #endif
    }
}

private struct StepHeaderView: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.title2)
                .bold()
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct StatusPill: View {
    let level: StatusLevel
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(level.color.opacity(0.15))
            .foregroundStyle(level.color)
            .clipShape(Capsule())
    }
}

private struct ReleaseSystemStateBar: View {
    let level: StatusLevel
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(level.color)
                .frame(width: 8, height: 8)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Surface.tertiary)
    }
}

private struct ReleaseActionStatusView: View {
    let level: StatusLevel
    let message: String
    let isRunning: Bool
    let lastError: String

    var body: some View {
        HStack(spacing: 8) {
            if isRunning {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Image(systemName: levelSymbol)
                    .foregroundStyle(level.color)
            }
            Text(message.isEmpty ? "Idle" : message)
                .font(.caption)
                .foregroundStyle(.secondary)
            if !lastError.isEmpty {
                Text("• \(lastError)")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: DSLayout.radiusM).fill(Surface.tertiary))
    }

    private var levelSymbol: String {
        switch level {
        case .ok: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        case .running: return "clock.arrow.2.circlepath"
        case .idle: return "circle"
        }
    }
}

private struct StatusIssue: Identifiable {
    let id = UUID()
    let level: StatusLevel
    let title: String
    let detail: String
    let fix: String
}

private struct ResolveIssuesCard: View {
    let issues: [StatusIssue]

    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceS) {
            Text("Resolve these items")
                .font(.headline)
            if issues.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                    Text("All prerequisites are green. You can continue.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(Array(issues.enumerated()), id: \.element.id) { index, issue in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(issue.title)
                                .font(.subheadline)
                                .foregroundStyle(issue.level.color)
                            Spacer()
                            StatusPill(level: issue.level, text: issue.level.label)
                        }
                        if !issue.detail.isEmpty {
                            Text(issue.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("Fix: \(issue.fix)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(DSLayout.spaceS)
                    .background(RoundedRectangle(cornerRadius: DSLayout.radiusM).fill(Surface.tertiary))
                }
            }
        }
        .padding(DSLayout.spaceM)
        .background(RoundedRectangle(cornerRadius: DSLayout.radiusL).fill(Surface.secondary))
    }
}

private struct ReleaseIntentCard: View {
    @Binding var isNewRelease: Bool
    @Binding var version: String
    let currentVersion: String
    let latestTag: String
    let isRunning: Bool
    let onWrite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceS) {
            Text("Release intent")
                .font(.headline)
            Toggle("I am preparing a NEW release tag", isOn: $isNewRelease)
                .toggleStyle(.switch)
            if isNewRelease {
                Text("Set the next release number. The tag will be created as v + VERSION.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Format: X.Y.Z (numbers only). Do not include a leading \"v\".")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !latestTag.isEmpty {
                    Text("Latest tag is \(latestTag). The next tag should be v\(version.isEmpty ? "X.Y.Z" : version).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    TextField("Example: 4.8.2", text: $version)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                    Button("Write VERSION") {
                        onWrite()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning || version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Spacer()
                }
            } else {
                Text("No new release. VERSION should match the latest tag exactly (without the leading \"v\").")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !currentVersion.isEmpty || !latestTag.isEmpty {
                Text("Current VERSION: \(currentVersion.isEmpty ? "-" : currentVersion) • Latest tag: \(latestTag.isEmpty ? "-" : latestTag)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DSLayout.spaceM)
        .background(RoundedRectangle(cornerRadius: DSLayout.radiusL).fill(Surface.secondary))
    }
}

private struct DirtyWorkspaceResolveCard: View {
    @Binding var branchName: String
    @Binding var commitMessage: String
    @Binding var includeUntracked: Bool
    @Binding var acknowledged: Bool
    let isRunning: Bool
    let canCreateBranch: Bool
    let canStage: Bool
    let canCommit: Bool
    let canPush: Bool
    let branchCreated: Bool
    let changesCaptured: Bool
    let changesCommitted: Bool
    let branchPushed: Bool
    let onCreateBranch: () -> Void
    let onStage: () -> Void
    let onCommit: () -> Void
    let onPush: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceS) {
            Text("Resolve dirty workspace here")
                .font(.headline)
            Text("This will move your local changes into a feature branch without leaving this workflow.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Feature branch name (e.g., feature/ds-123-short-desc)", text: $branchName)
                .textFieldStyle(.roundedBorder)
            HStack(spacing: 8) {
                Button("Create Branch") {
                    onCreateBranch()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunning || branchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !canCreateBranch)
                StatusPill(level: branchCreated ? .ok : .warning, text: branchCreated ? "BRANCH READY" : "NOT CREATED")
                Spacer()
            }
            Toggle("Include untracked files", isOn: $includeUntracked)
                .toggleStyle(.switch)
            HStack(spacing: 8) {
                Button("Stage Changes") {
                    onStage()
                }
                .buttonStyle(.bordered)
                .disabled(isRunning || !canStage || !branchCreated)
                StatusPill(level: changesCaptured ? .ok : .warning, text: changesCaptured ? "STAGED" : "NOT STAGED")
                Spacer()
            }
            TextField("Commit message", text: $commitMessage)
                .textFieldStyle(.roundedBorder)
            HStack(spacing: 8) {
                Button("Commit") {
                    onCommit()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunning || !canCommit || !changesCaptured || commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                StatusPill(level: changesCommitted ? .ok : .warning, text: changesCommitted ? "COMMITTED" : "NOT COMMITTED")
                Spacer()
            }
            HStack(spacing: 8) {
                Button("Push (optional)") {
                    onPush()
                }
                .buttonStyle(.bordered)
                .disabled(isRunning || !canPush || !changesCommitted)
                StatusPill(level: branchPushed ? .ok : .info, text: branchPushed ? "PUSHED" : "NOT PUSHED")
                Spacer()
            }
            Toggle("I confirm these changes will be part of the feature branch and the release", isOn: $acknowledged)
                .toggleStyle(.switch)
        }
        .padding(DSLayout.spaceM)
        .background(RoundedRectangle(cornerRadius: DSLayout.radiusL).fill(Surface.secondary))
    }
}

private struct BlockerHint: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.orange)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: DSLayout.radiusM).fill(Surface.tertiary))
    }
}

private struct RepoOverrideCard: View {
    @Binding var path: String
    let isValid: Bool
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceS) {
            Text("Repo path override (optional)")
                .font(.headline)
            Text("Use this if the app cannot find the repo automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Example: /Users/you/Projects/DragonShield/DragonShield", text: $path)
                .textFieldStyle(.roundedBorder)
            HStack(spacing: 8) {
                Button("Apply Repo Path") {
                    onApply()
                }
                .buttonStyle(.borderedProminent)
                StatusPill(level: isValid || path.isEmpty ? .ok : .warning,
                           text: path.isEmpty ? "NOT SET" : (isValid ? "VALID" : "INVALID"))
                Spacer()
            }
        }
        .padding(DSLayout.spaceM)
        .background(RoundedRectangle(cornerRadius: DSLayout.radiusL).fill(Surface.secondary))
    }
}

private struct GitHubTokenCard: View {
    @Binding var token: String
    let source: String
    let isPresent: Bool
    let isRunning: Bool
    let onSave: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceS) {
            Text("GitHub token (secure)")
                .font(.headline)
            Text("Optional for release notes; required for PR creation and merge.")
                .font(.caption)
                .foregroundStyle(.secondary)
            SecureField("Paste token (not shown)", text: $token)
                .textFieldStyle(.roundedBorder)
            HStack(spacing: 8) {
                Button("Save to Keychain") {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRunning)
                Button("Clear") {
                    onClear()
                }
                .buttonStyle(.bordered)
                .disabled(isRunning)
                StatusPill(level: isPresent ? .ok : .warning, text: isPresent ? "PRESENT (\(source))" : "MISSING")
                Spacer()
            }
        }
        .padding(DSLayout.spaceM)
        .background(RoundedRectangle(cornerRadius: DSLayout.radiusL).fill(Surface.secondary))
    }
}

private struct StatusRow: View {
    let label: String
    let value: String
    let level: StatusLevel

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .leading)
            Text(value)
                .font(.caption)
            Spacer()
            Circle()
                .fill(level.color)
                .frame(width: 8, height: 8)
        }
    }
}

private struct SystemStatusCard: View {
    let status: ReleaseSystemStatus

    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spaceS) {
            Text("System status")
                .font(.headline)
            VStack(spacing: 6) {
                StatusRow(label: "Repo path", value: status.repoPath, level: status.repoRoot == nil ? .error : .ok)
                let overrideLabel = status.repoOverridePath.isEmpty ? "-" : status.repoOverridePath
                let overrideLevel: StatusLevel = status.repoOverridePath.isEmpty ? .info : (status.repoOverrideValid ? .ok : .warning)
                StatusRow(label: "Repo override", value: overrideLabel, level: overrideLevel)
                StatusRow(label: "Origin", value: status.originURL, level: status.originURL == "-" ? .warning : .ok)
                StatusRow(label: "Branch", value: status.currentBranch, level: status.currentBranch == "-" ? .warning : .ok)
                StatusRow(label: "Upstream", value: status.upstreamBranch, level: status.upstreamBranch == "-" ? .warning : .ok)
                StatusRow(label: "Default base", value: status.defaultBaseBranch, level: .info)
                let cleanLevel: StatusLevel = status.isClean ? .ok : .warning
                StatusRow(label: "Workspace", value: status.isClean ? "Clean" : "Dirty", level: cleanLevel)
                StatusRow(label: "VERSION", value: status.version.isEmpty ? "-" : status.version, level: status.version.isEmpty ? .warning : .ok)
                let tagLevel: StatusLevel = status.latestTag.isEmpty ? .warning : .ok
                StatusRow(label: "Latest tag", value: status.latestTag.isEmpty ? "-" : status.latestTag, level: tagLevel)
                let matchLevel: StatusLevel = status.versionMatchesTag ? .ok : .warning
                StatusRow(label: "Version match", value: status.versionMatchesTag ? "Yes" : "No", level: matchLevel)
                StatusRow(label: "Git", value: status.gitVersion.isEmpty ? "Missing" : status.gitVersion, level: status.gitVersion.isEmpty ? .error : .ok)
                StatusRow(label: "Python", value: status.pythonVersion.isEmpty ? "Missing" : status.pythonVersion, level: status.pythonVersion.isEmpty ? .error : .ok)
                StatusRow(label: "Sync script", value: status.changelogScriptPath.isEmpty ? "Not found" : "Found", level: status.changelogScriptPath.isEmpty ? .error : .ok)
                let tokenLevel: StatusLevel = status.githubTokenPresent ? .ok : .warning
                let tokenValue = status.githubTokenPresent ? "Present (\(status.githubTokenSource))" : "Missing"
                StatusRow(label: "GitHub token", value: tokenValue, level: tokenLevel)
                if let error = status.lastError, !error.isEmpty {
                    StatusRow(label: "Last error", value: error, level: .error)
                }
            }
        }
        .padding(DSLayout.spaceM)
        .background(RoundedRectangle(cornerRadius: DSLayout.radiusL).fill(Surface.secondary))
    }
}

// MARK: - Actions

extension ReleaseManagementRootView {
    private func selectSpineItem(_ item: ProcessSpineItem) {
        model.releaseStep = item.step
    }

    private func advanceReleaseStep() {
        guard model.releaseStep.rawValue + 1 < ReleasePrepStep.allCases.count else { return }
        model.releaseStep = ReleasePrepStep(rawValue: model.releaseStep.rawValue + 1) ?? model.releaseStep
    }


    private func refreshStatus() {
        runAction(message: "Refreshing status...") {
            let status = buildSystemStatus()
            DispatchQueue.main.async {
                model.systemStatus = status
                if model.newVersion.isEmpty {
                    model.newVersion = status.version
                }
                if !model.newVersion.isEmpty {
                    model.versionWritten = (model.newVersion == status.version)
                }
                if status.isClean {
                    model.dirtyWorkspaceAcknowledged = false
                }
            }
        }
    }

    private func applyRepoRootOverride() {
        let trimmed = model.repoRootOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        model.repoRootOverride = trimmed
        UserDefaults.standard.set(trimmed, forKey: "release.repoRootOverride")
        refreshStatus()
    }

    private func saveGitHubToken() {
        let trimmed = model.githubTokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        model.githubTokenInput = trimmed
        _ = KeychainService.set(trimmed, account: "github_token")
        model.githubTokenSaved = true
        refreshStatus()
    }

    private func clearGitHubToken() {
        KeychainService.delete(account: "github_token")
        model.githubTokenInput = ""
        model.githubTokenSaved = false
        refreshStatus()
    }

    private func captureChanges() {
        runAction(message: "Staging changes...") {
            guard let root = model.systemStatus.repoRoot else {
                throw ReleaseActionError("Repo root not found. Set the repo path override and refresh.")
            }
            let statusOutput = (try? runGit(["status", "--porcelain"], root: root)) ?? ""
            let lines = statusOutput.split(separator: "\n").map(String.init)
            guard !lines.isEmpty else {
                throw ReleaseActionError("No local changes found to stage.")
            }
            let args = model.includeUntracked ? ["add", "-A"] : ["add", "-u"]
            _ = try runGit(args, root: root)
            DispatchQueue.main.async {
                model.changesCaptured = true
                model.changesCommitted = false
                model.stageMessage = "Staged \(lines.count) file(s)."
            }
        }
    }

    private func writeVersion() {
        var version = model.newVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        if version.lowercased().hasPrefix("v") {
            version.removeFirst()
            version = version.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !version.isEmpty else { return }
        runAction(message: "Writing VERSION...") {
            guard let root = model.systemStatus.repoRoot else {
                throw ReleaseActionError("Repo root not found. Set the repo path override and try again.")
            }
            let path = root.appendingPathComponent("VERSION")
            do {
                try version.appending("\n").write(to: path, atomically: true, encoding: .utf8)
            } catch {
                throw ReleaseActionError("Could not write VERSION. Check file permissions and repo path.")
            }
            let updated = buildSystemStatus()
            DispatchQueue.main.async {
                model.newVersion = version
                model.versionWritten = true
                model.systemStatus = updated
            }
        }
    }

    private func createTag() {
        runAction(message: "Creating tag...") {
            let version = model.systemStatus.version
            guard !version.isEmpty else {
                throw ReleaseActionError("VERSION is empty.")
            }
            guard model.systemStatus.isClean else {
                throw ReleaseActionError("Workspace is not clean. Commit or stash changes first.")
            }
            _ = try runGit(["tag", "-a", "v\(version)", "-m", "Release \(version)"], root: model.systemStatus.repoRoot)
            let updated = buildSystemStatus()
            DispatchQueue.main.async {
                model.tagCreated = true
                model.lastTagAt = Date()
                model.systemStatus = updated
            }
        }
    }

    private func syncChangelog() {
        runAction(message: "Running changelog sync...") {
            guard let script = resolveChangelogSyncScript() else {
                throw ReleaseActionError("sync_changelog.py not found.")
            }
            var args = [script.path]
            if !model.includeGitHubData { args.append("--no-github") }
            if model.dryRun { args.append("--dry-run") }
            let output = try runProcess(executable: "/usr/bin/python3", args: args, root: script.deletingLastPathComponent())
            let updated = buildSystemStatus()
            DispatchQueue.main.async {
                model.lastOutput = output
                model.lastSyncAt = Date()
                model.changelogSynced = true
                model.systemStatus = updated
            }
        }
    }

    private func createBranch() {
        let branch = model.branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !branch.isEmpty else { return }
        runAction(message: "Creating branch...") {
            guard model.systemStatus.repoRoot != nil else {
                throw ReleaseActionError("Repo root not found. Set the repo path override and refresh.")
            }
            _ = try runGit(["checkout", "-b", branch], root: model.systemStatus.repoRoot)
            let updated = buildSystemStatus()
            DispatchQueue.main.async {
                model.branchCreated = true
                model.changesCaptured = false
                model.changesCommitted = false
                model.branchPushed = false
                model.prInfo = nil
                model.prMerged = false
                model.branchDeleted = false
                model.stageMessage = ""
                model.systemStatus = updated
            }
        }
    }

    private func commitChanges() {
        let message = model.commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }
        runAction(message: "Committing changes...") {
            guard model.systemStatus.repoRoot != nil else {
                throw ReleaseActionError("Repo root not found. Set the repo path override and refresh.")
            }
            guard model.changesCaptured else {
                throw ReleaseActionError("No staged changes found. Use 'Capture Local Changes' first.")
            }
            _ = try runGit(["commit", "-m", message], root: model.systemStatus.repoRoot)
            let updated = buildSystemStatus()
            DispatchQueue.main.async {
                model.changesCommitted = true
                model.changesCaptured = false
                model.systemStatus = updated
            }
        }
    }

    private func pushBranch() {
        let branch = model.branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !branch.isEmpty else { return }
        runAction(message: "Pushing branch...") {
            guard model.systemStatus.originURL != "-" else {
                throw ReleaseActionError("Origin remote not found. Add an origin remote before pushing.")
            }
            _ = try runGit(["push", "-u", "origin", branch], root: model.systemStatus.repoRoot)
            let updated = buildSystemStatus()
            DispatchQueue.main.async {
                model.branchPushed = true
                model.systemStatus = updated
            }
        }
    }

    private func createPullRequest() {
        runAction(message: "Creating pull request...") {
            let repo = try resolveGitHubRepo()
            let branch = model.branchName.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = model.prTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !branch.isEmpty else { throw ReleaseActionError("Branch name is empty.") }
            guard !title.isEmpty else { throw ReleaseActionError("PR title is empty.") }
            let base = model.systemStatus.defaultBaseBranch
            let body = [
                "title": title,
                "head": branch,
                "base": base,
                "body": model.prBody
            ]
            let payload = try JSONSerialization.data(withJSONObject: body, options: [])
            let data = try runGitHubRequest(method: "POST", path: "/repos/\(repo.owner)/\(repo.name)/pulls", body: payload)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw ReleaseActionError("Failed to parse PR response.")
            }
            let number = json["number"] as? Int ?? 0
            let url = json["html_url"] as? String ?? ""
            let head = (json["head"] as? [String: Any])?["sha"] as? String ?? ""
            let state = json["state"] as? String ?? ""
            let mergeable = json["mergeable"] as? Bool
            let mergeableState = json["mergeable_state"] as? String
            let checks = try fetchChecksSummary(owner: repo.owner, repo: repo.name, headSha: head)
            DispatchQueue.main.async {
                model.prInfo = PullRequestInfo(number: number, url: url, headSha: head, state: state, mergeable: mergeable, mergeableState: mergeableState)
                model.checksSummary = checks
            }
        }
    }

    private func refreshPullRequestChecks() {
        runAction(message: "Refreshing checks...") {
            guard let pr = model.prInfo else { throw ReleaseActionError("PR not found.") }
            let repo = try resolveGitHubRepo()
            let summary = try fetchChecksSummary(owner: repo.owner, repo: repo.name, headSha: pr.headSha)
            DispatchQueue.main.async {
                model.checksSummary = summary
            }
        }
    }

    private func mergePullRequest() {
        runAction(message: "Merging PR (squash)...") {
            guard let pr = model.prInfo else { throw ReleaseActionError("PR not found.") }
            let repo = try resolveGitHubRepo()
            let checks = model.checksSummary?.state ?? "unknown"
            guard checks == "success" else { throw ReleaseActionError("Checks not green. Merge blocked.") }
            let payload = try JSONSerialization.data(withJSONObject: ["merge_method": "squash"], options: [])
            _ = try runGitHubRequest(method: "PUT", path: "/repos/\(repo.owner)/\(repo.name)/pulls/\(pr.number)/merge", body: payload)
            DispatchQueue.main.async {
                model.prMerged = true
            }
        }
    }

    private func deleteBranch() {
        let branch = model.branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !branch.isEmpty else { return }
        runAction(message: "Deleting branch...") {
            _ = try runGit(["push", "origin", "--delete", branch], root: model.systemStatus.repoRoot)
            let updated = buildSystemStatus()
            DispatchQueue.main.async {
                model.branchDeleted = true
                model.systemStatus = updated
            }
        }
    }
}

// MARK: - Helpers

private struct ReleaseActionError: Error, LocalizedError, CustomStringConvertible {
    let message: String
    init(_ message: String) { self.message = message }
    var description: String { message }
    var errorDescription: String? { message }
}

private struct GitHubRepo {
    let owner: String
    let name: String
}

extension ReleaseManagementRootView {
    private func runAction(message: String, work: @escaping () throws -> Void) {
        guard !model.isRunning else { return }
        model.isRunning = true
        model.statusMessage = message
        model.statusLevel = .running
        model.lastError = ""
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try work()
                DispatchQueue.main.async {
                    model.statusMessage = "Done."
                    model.statusLevel = .ok
                    model.isRunning = false
                }
            } catch {
                let description = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                DispatchQueue.main.async {
                    model.statusMessage = "Failed: \(description)"
                    model.statusLevel = .error
                    model.lastError = description
                    model.isRunning = false
                }
            }
        }
    }

    private func buildSystemStatus() -> ReleaseSystemStatus {
        var status = ReleaseSystemStatus.empty
        do {
            let override = model.repoRootOverride.trimmingCharacters(in: .whitespacesAndNewlines)
            if !override.isEmpty {
                status.repoOverridePath = override
                let fm = FileManager.default
                if fm.fileExists(atPath: override) {
                    if let rootResult = try? runProcess(
                        executable: "/usr/bin/env",
                        args: ["git", "-C", override, "rev-parse", "--show-toplevel"],
                        root: nil
                    ) {
                        let rootPath = rootResult.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !rootPath.isEmpty {
                            status.repoRoot = URL(fileURLWithPath: rootPath)
                            status.repoPath = rootPath
                            status.repoOverrideValid = true
                        }
                    }
                }
            }

            if status.repoRoot == nil {
                let rootResult = try runGit(["rev-parse", "--show-toplevel"], root: nil)
                let rootPath = rootResult.trimmingCharacters(in: .whitespacesAndNewlines)
                if !rootPath.isEmpty {
                    status.repoRoot = URL(fileURLWithPath: rootPath)
                    status.repoPath = rootPath
                }
            }

            if let root = status.repoRoot {
                status.currentBranch = (try? runGit(["rev-parse", "--abbrev-ref", "HEAD"], root: root)) ?? "-"
                status.upstreamBranch = (try? runGit(["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"], root: root)) ?? "-"
                let statusOutput = (try? runGit(["status", "--porcelain"], root: root)) ?? ""
                let lines = statusOutput.split(separator: "\n").map(String.init)
                let untracked = lines.filter { $0.hasPrefix("??") }.count
                let uncommitted = lines.filter { !$0.hasPrefix("??") && !$0.isEmpty }.count
                status.untrackedCount = untracked
                status.uncommittedCount = uncommitted
                status.isClean = lines.isEmpty
                let versionPath = root.appendingPathComponent("VERSION")
                if let version = try? String(contentsOf: versionPath, encoding: .utf8) {
                    status.version = version.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                let latestTag = (try? runGit(["describe", "--tags", "--abbrev=0", "--match", "v*"], root: root)) ?? ""
                status.latestTag = latestTag
                if !status.version.isEmpty && !latestTag.isEmpty {
                    status.versionMatchesTag = ("v\(status.version)" == latestTag)
                }

                let origin = (try? runGit(["remote", "get-url", "origin"], root: root)) ?? "-"
                status.originURL = origin

                let base = (try? runGit(["symbolic-ref", "refs/remotes/origin/HEAD"], root: root)) ?? "refs/remotes/origin/main"
                status.defaultBaseBranch = base.replacingOccurrences(of: "refs/remotes/origin/", with: "")
            }
        } catch {
            status.lastError = error.localizedDescription
        }

        status.gitVersion = (try? runProcess(executable: "/usr/bin/env", args: ["git", "--version"], root: status.repoRoot)) ?? ""
        status.pythonVersion = (try? runProcess(executable: "/usr/bin/env", args: ["python3", "--version"], root: status.repoRoot)) ?? ""
        status.changelogScriptPath = resolveChangelogSyncScript()?.path ?? ""
        let tokenInfo = resolveGitHubToken()
        status.githubTokenPresent = !(tokenInfo.token?.isEmpty ?? true)
        status.githubTokenSource = status.githubTokenPresent ? tokenInfo.source : "Missing"

        return status
    }

    private func runGit(_ args: [String], root: URL?) throws -> String {
        try runProcess(executable: "/usr/bin/env", args: ["git"] + args, root: root)
    }

    private func runProcess(executable: String, args: [String], root: URL?) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        if let root {
            process.currentDirectoryURL = root
        }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if process.terminationStatus != 0 {
            throw ReleaseActionError(output.isEmpty ? "Command failed: \(args.joined(separator: " "))" : output)
        }
        return output
    }

    private func resolveChangelogSyncScript() -> URL? {
        let fm = FileManager.default
        var candidates: [URL] = []
        let env = ProcessInfo.processInfo.environment
        if let override = env["DS_CHANGELOG_SYNC_SCRIPT"], !override.isEmpty {
            candidates.append(URL(fileURLWithPath: override))
        }
        let repoOverride = model.repoRootOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        if !repoOverride.isEmpty {
            candidates.append(URL(fileURLWithPath: repoOverride).appendingPathComponent("scripts/sync_changelog.py"))
        }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        candidates.append(cwd.appendingPathComponent("scripts/sync_changelog.py"))
        let moduleDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let parent = moduleDir.deletingLastPathComponent()
        let grandParent = parent.deletingLastPathComponent()
        candidates.append(moduleDir.appendingPathComponent("scripts/sync_changelog.py"))
        candidates.append(parent.appendingPathComponent("scripts/sync_changelog.py"))
        candidates.append(grandParent.appendingPathComponent("scripts/sync_changelog.py"))
        for candidate in candidates where fm.fileExists(atPath: candidate.path) {
            return candidate
        }
        return nil
    }

    private func resolveGitHubRepo() throws -> GitHubRepo {
        let origin = model.systemStatus.originURL
        guard origin != "-" else { throw ReleaseActionError("Origin remote not found.") }
        let cleaned = origin
            .replacingOccurrences(of: "git@github.com:", with: "")
            .replacingOccurrences(of: "https://github.com/", with: "")
            .replacingOccurrences(of: ".git", with: "")
        let parts = cleaned.split(separator: "/")
        guard parts.count >= 2 else { throw ReleaseActionError("Could not parse origin URL.") }
        return GitHubRepo(owner: String(parts[0]), name: String(parts[1]))
    }

    private func resolveGitHubToken() -> (token: String?, source: String) {
        let input = model.githubTokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !input.isEmpty { return (input, "App Field") }
        if let keychain = KeychainService.get(account: "github_token"), !keychain.isEmpty {
            return (keychain, "Keychain")
        }
        let env = ProcessInfo.processInfo.environment["GITHUB_TOKEN"] ?? ""
        if !env.isEmpty { return (env, "Environment") }
        return (nil, "Missing")
    }

    private func fetchChecksSummary(owner: String, repo: String, headSha: String) throws -> ChecksSummary {
        let data = try runGitHubRequest(
            method: "GET",
            path: "/repos/\(owner)/\(repo)/commits/\(headSha)/status",
            body: nil
        )
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ReleaseActionError("Failed to parse checks response.")
        }
        let state = (json["state"] as? String) ?? "unknown"
        let statuses = json["statuses"] as? [[String: Any]] ?? []
        let contexts = statuses.compactMap { $0["context"] as? String }
        let description = contexts.isEmpty ? "No checks reported yet." : "Checks: " + contexts.joined(separator: ", ")
        return ChecksSummary(state: state, description: description)
    }

    private func runGitHubRequest(method: String, path: String, body: Data?) throws -> Data {
        let tokenInfo = resolveGitHubToken()
        let token = tokenInfo.token ?? ""
        guard !token.isEmpty else { throw ReleaseActionError("GitHub token is missing. Add it in Release Management or set GITHUB_TOKEN.") }
        guard let url = URL(string: "https://api.github.com\(path)") else {
            throw ReleaseActionError("Invalid GitHub URL.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = body
        }
        let semaphore = DispatchSemaphore(value: 0)
        var responseData: Data?
        var responseError: Error?
        var statusCode: Int = 0
        URLSession.shared.dataTask(with: request) { data, response, error in
            responseData = data
            responseError = error
            statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            semaphore.signal()
        }.resume()
        semaphore.wait()
        if let responseError {
            throw responseError
        }
        guard (200..<300).contains(statusCode) else {
            let bodyText = responseData.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
            throw ReleaseActionError("GitHub error \(statusCode): \(bodyText)")
        }
        return responseData ?? Data()
    }
}
