______________________________________________________________________

## name: git-commit description: Guidelines on commit granularity, branch awareness, commit messages, and safety before proposing commits.

# Git commit

Read this when deciding whether to create a git commit during a task.

## Goal

Keep work recoverable without creating noisy or unrelated commits.

## Branch Awareness

- Check the current branch before committing (`git branch --show-current`).
- Avoid committing directly to `main` unless explicitly requested.
- Use `git switch -c <branch-name>` when creating a new topic branch (avoid `git checkout`).

## Suggest a commit when

Suggest a commit when:

- one logical unit of work is complete
- the diff is becoming too large to review comfortably
- a risky operation is next
- a long task is pausing or switching context
- the user explicitly asks

Do not create a commit without user approval.

## Do not propose a commit when

Do not propose a commit when:

- the edit is still incomplete
- the tree is broken and the user did not ask for a WIP commit
- unrelated user changes are mixed in
- the commit would include files outside the task scope
- the diff has not been reviewed with `git status` and `git diff`

If unrelated changes are present, report them and ask how to proceed.

## Granularity

Use one commit for one reviewable intent.

Split before committing when:

- refactoring and behaviour changes are mixed
- unrelated changes were made for different reasons
- formatter or linter changes touched files outside the task scope
- the reviewer could not describe the commit in one sentence

Do not split into tiny commits for trivial edits unless the user asks.

## Commit message

Follow the repository convention if one exists (see `.agents/skills/pr-workflow/SKILL.md`).

If no convention is found, use:

- English
- imperative mood
- short summary, preferably under 72 characters
- no trailing period

Use a type prefix only when the repository already uses one.
Do NOT include issue numbers (e.g., `(#24)` or `#24`) in the commit summary.


Examples:

- `feat: add sequencer event scheduler`
- `refactor: extract filter coefficients`
- `docs: update git commit guidance`

## Reporting changes for commits

When preparing a commit, state what changes were made:

- Summary of changes made and their rationale
- `git status` and files staged or intended to be staged
- Relevant `git diff` or `git diff --stat`
- Proposed commit message
