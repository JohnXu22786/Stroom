# Stroom Branch and Version Management

This guide is for all contributors, including external contributors who submit pull requests from personal forks, and for maintainers. Git and GitHub do not prescribe one universal branch naming scheme; this document describes the conventions used in the Stroom repository. Angle-bracketed values are placeholders and do not imply that a branch exists. Pull requests normally target `main`; use another base branch only when an issue or a maintainer specifies it.

## 1. Contributor Workflow

External contributors should usually fork this repository, create a short-lived working branch from the intended pull request base in their fork, and submit a pull request to this repository. Do not push directly to shared branches in the Stroom repository.

Use a lowercase type prefix and a short topic, with words separated by hyphens. The prefix should match the change type and, where possible, the type used in the commit message:

| Branch pattern | Suggested use | Pull request template category |
| --- | --- | --- |
| `feat/<topic>` | New features or user-visible capabilities | Feature |
| `fix/<topic>` | Bug fixes, including urgent fixes | Bug fix |
| `docs/<topic>` | Documentation changes | Documentation |
| `style/<topic>` | Formatting or style changes that do not affect behavior | Chore |
| `refactor/<topic>` | Code restructuring that does not change external behavior | Refactor |
| `perf/<topic>` | Performance improvements | Performance |
| `test/<topic>` | Adding or maintaining tests | Test |
| `ci/<topic>` | Continuous integration configuration | CI/build |
| `cd/<topic>` | Continuous delivery or release automation | CI/build |
| `build/<topic>` | Build system or build dependency changes | CI/build |
| `chore/<topic>` | Other maintenance work | Chore |
| `revert/<topic>` | Reverting an existing change | Category of the reverted change |

Create the working branch from the actual pull request base. Before submitting, confirm that the pull request targets the intended base and explain the purpose of the change. The default base is `main`; use a version branch only when an issue or maintainer specifies it.

## 2. Long-Lived Branches

| Branch pattern | Purpose | Management |
| --- | --- | --- |
| `main` | Default branch and current primary development line. | Changes are merged through pull requests after review and required CI checks. |
| `v<MAJOR>.<MINOR>` | Development and integration line for a minor version series. | Created when work on that series begins and managed by maintainers. |
| `release/<MAJOR>.<MINOR>` | Maintenance line for a supported older version after a newer line takes over `main`. | Created only when ongoing maintenance is needed and managed by maintainers. |

Create version development and maintenance branches only when needed; do not create branches for version series that have not started. Contributors should not create or choose these long-lived branches themselves. An issue or maintainer should specify the target branch.

Record each version line's goals, scope, and acceptance criteria in `docs/roadmap/v<MAJOR>.<MINOR>.md`. Use issues or pull requests to track individual work items. A GitHub milestone is optional; maintainers may use one to group related issues and pull requests and track progress, with a link to the version plan in its description.

## 3. Development and Cross-Version Fixes

- Create a separate working branch from the actual target branch for each change, then merge it through a pull request.
- First merge a fix into the target branch for the affected older version. If a newer development line also needs the fix, forward-port it through a separate pull request from a short-lived working branch. Do not use a long-lived maintenance branch as the source branch for a pull request.
- Do not merge features intended only for a newer version into an older version branch. Adapt incompatible fixes separately and validate them on each target branch.
- Make necessary changes between long-lived branches through pull requests and resolve conflicts early, rather than accumulating a large divergence before a version handoff.
- Do not push directly to `main`, version development branches, or maintenance branches. Do not force-update them or make unplanned cross-version merges.

## 4. Version Handoffs

When a `v<MAJOR>.<MINOR>` development line is ready to take over `main`:

1. Decide whether the previous version series still needs maintenance. If it does, create its `release/<MAJOR>.<MINOR>` branch from the current `main` before the handoff.
2. Complete the final required synchronization from `main` to the development line.
3. After review, CI, and merge validation, merge the development line into `main` through a pull request.
4. `main` then carries the new primary development line. Any maintenance branch that was created continues to receive necessary fixes for its older version.

## 5. Post-Merge Branch Cleanup

This repository has GitHub's automatic deletion of merged pull request branches enabled. After a pull request is merged, GitHub deletes its source branch in this repository. This setting does not delete branches in contributors' forks; fork owners can clean those up themselves. Do not use a long-lived branch as the source of a one-off pull request when it must be kept. Create a separate maintenance branch during a version handoff when needed. Branch protection rules still apply.

## 6. Release Tags

Use the `v` prefix for release tags in the form `v<MAJOR>.<MINOR>.<PATCH>`. The prefix is a common tag naming convention and is not part of the SemVer version string; the version without the prefix follows Semantic Versioning (SemVer). A tag identifies a specific release, unlike a branch that continues to change.

## 7. Repository Settings

- Keep `main` as the default branch.
- Apply appropriate protection rules to `main`, version development branches, and maintenance branches, such as requiring pull requests, review, and CI checks.
- State the target branch, version series, and purpose in each pull request. Meet the target branch's protection requirements before merging.
- Update this guide when the repository's version policy or GitHub branch settings change.
