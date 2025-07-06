DragonShield - Software Versioning Strategy

## 1. Philosophy and Core Principles

Our versioning strategy is built on two industry-standard pillars: **Git for history** and **Semantic Versioning (SemVer) for releases**. This approach maximizes automation, clarity, and developer efficiency.

We explicitly **deprecate manual version tracking within source files**. Git is the single source of truth for the history of every line of code.

-   **Development History is handled by Git.**
-   **Release Versioning is handled by SemVer.**

## 2. Applying the Strategy to Every Change

This strategy must be applied for **every logical change** made to the codebase. "Applying the strategy" does not mean editing version numbers in file headers. Instead, for any change that creates or updates files, a developer **must** perform the following three actions:

1.  **Create an Atomic Git Commit:** A commit is the fundamental unit of history. Each commit should represent a single, self-contained logical change. Avoid vague, large commits.
2.  **Write a Descriptive Commit Message:** The commit message is the "history entry" for that specific change. It must clearly explain the *what* and the *why*. This is how we trace the fine-grained evolution of the codebase.
3.  **Update the `CHANGELOG.md`:** If the change is user-facing (a new feature, a bug fix, a performance improvement), a corresponding entry **must** be added to the `[Unreleased]` section of the `CHANGELOG.md` within the same pull request.

This workflow ensures that every modification is documented at the source (the commit) and summarized for release (the changelog), making the history verifiable and complete.

## 3. Release Versioning: Semantic Versioning 2.0.0

All releases will adhere to the **Semantic Versioning (SemVer)** format: `MAJOR.MINOR.PATCH`.

-   `MAJOR` for incompatible API changes.
-   `MINOR` for new, backward-compatible functionality.
-   `PATCH` for backward-compatible bug fixes.

Versions are applied to the entire software artifact at release time via annotated Git tags (e.g., `v1.2.3`).

## 4. Communicating Changes: The `CHANGELOG.md`

The `CHANGELOG.md` file is the official, human-readable history of the project for end-users.

### Maintaining a Clean History
A clean and accurate changelog is mandatory.
-   **Update with Every PR:** Every pull request with a user-facing change must include an update to the `[Unreleased]` section.
-   **Review and Consolidate:** Before a release, the maintainer must review the `[Unreleased]` section to ensure clarity and accuracy. During this review:
    -   Verify that the sequence of changes makes sense.
    -   Consolidate multiple, related entries into a single, more descriptive line item. For example, three small commits fixing one bug should result in one line in the changelog.
    -   Ensure there are no duplicate entries for the same change.

This curation process guarantees that the release notes are clean, concise, and easy for users to understand.

## 5. The Release Workflow

1.  **Prepare for Release:** Ensure the `main` branch is stable.
2.  **Finalize Changelog:** Review, clean, and consolidate the `[Unreleased]` section. Create the new version header (e.g., `## [1.3.0] - 2025-06-30`) and move the curated entries under it.
3.  **Commit Changelog:** Commit the updated file: `git commit -m "docs: Prepare for release v1.3.0"`
4.  **Tag the Version:** Create an annotated Git tag: `git tag -a v1.3.0 -m "Release version 1.3.0"`
5.  **Push to Origin:** Push the commit and the tag: `git push origin main && git push origin v1.3.0`

## 6. Rationale: Why This Is a Better Approach

1.  **Reduces Manual Work & Errors:** Developers focus on code and clear commit messages, not administrative tasks in file headers.
2.  **Eliminates Merge Conflicts:** Removes non-functional merge conflicts from version comments.
3.  **Adopts Industry Standard:** Uses SemVer and Git, which are universally understood.
4.  **Git is the Authority on History:** We leverage the power of `git blame` and `git log` for file-level history.
5.  **Clear Separation of Concerns:** The history of *development* (Git commits) is distinct from the history of *releases* (Changelog and Git tags).
