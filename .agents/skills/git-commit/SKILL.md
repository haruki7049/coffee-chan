______________________________________________________________________

## name: git-commit description: Repository commit conventions and strict prohibition on proposing or executing git commits and pushes.

# Git Commit Policy & Conventions

Read this to understand the commit policy and message conventions for `coffee-chan`.

## Strict Prohibition: Never Propose or Execute Commits or Pushes

- **Do NOT execute `git commit` or `git push`**: AI agents must never create commits or push changes to remote.
- **Do NOT propose or prompt for commits or pushes**: AI agents must never suggest committing or pushing changes, nor ask for confirmation to commit or push (e.g., do NOT ask for permission or confirmation to commit/push).
- **Do NOT include unprompted commit message proposals**: Do NOT append proposed commit messages or commit/push suggestion sections at the end of a response unless the user explicitly asks for commit message suggestions.
- **End turns with verification reporting**: Work concludes upon completing edits and presenting the verification report in the format defined in `verify` (`Changed`, `Verified`, `Not verified`, `Risk`).
- **Committing and pushing are strictly human actions**: All committing, pushing, and history management are performed exclusively by the human maintainer.

## Commit Message Conventions (Reference Only)

When the user explicitly asks the agent to formulate a commit message or when checking commit conventions:

Follow the repository convention (see `.agents/skills/pr-workflow/SKILL.md`):

- Use Conventional Commits style prefixes (`feat:`, `fix:`, `build:`, `refactor:`, `docs:`, `test:`).
- English, imperative mood, short summary, under 72 characters, no trailing period.
- **Do NOT include issue numbers (e.g., `(#24)` or `#24`) in the commit summary.** Issue linkage must be done exclusively in the PR Description using explicit issue-closing keywords (e.g. `Closes #24`).

Examples:

- `feat: add sequencer event scheduler`
- `refactor: extract filter coefficients`
- `docs: update git commit guidance`
