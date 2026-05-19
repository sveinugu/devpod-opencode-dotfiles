# GitHub App integration for opencode agents

Date: 2026-05-19
Status: Proposed design for agent-initiated integration
Scope: Agent-initiated GitHub App operations now; webhook-driven automation explicitly deferred

## 1. Context summary

- The local opencode setup is intentionally subagent-driven, with a Maestro coordinating specialized subagents, so any GitHub integration should be usable from agent workflows without forcing a new orchestration model.
- Skill priority in this repo is pragmatic-programmer first, then karpathy-guidelines, then superpowers, which favors reversible design, explicit contracts, and small surgical additions over a large framework.
- Repo guidance emphasizes tests as behavior-level exploration tools rather than low-level unit-test-first bureaucracy, so the integration should define end-to-end verification steps that match user-visible outcomes.
- The recent review record praised the current process/docs scope as surgical, but flagged weak validation and path ambiguity; this design should therefore prefer explicit paths, clear activation/install notes, and verifiable non-placeholder checks.
- The review also noted that workflow files under `.config/opencode/.github/` are templates rather than active GitHub Actions, which reinforces the decision to keep this first GitHub App integration agent-initiated instead of introducing hidden automation.

## 2. Problem statement

opencode agents need a safe, auditable way to perform GitHub actions as a GitHub App installation without relying on a personal access token. The first version should let an agent deliberately request GitHub access for tasks such as reading PR metadata, commenting on PRs, or creating PRs, while keeping credential handling local, explicit, and easy to revoke.

Out of scope for this design:

- webhook listeners
- background automation triggered by GitHub events
- long-running token broker services
- generalized multi-provider forge support

## 3. Approaches considered

### Approach A — Agent-invoked helper scripts with local token minting (**recommended**)

Agents call small local helper scripts that:

1. generate a GitHub App JWT from a locally stored private key
2. exchange that JWT for an installation access token
3. optionally resolve installation IDs and wrap a few common GitHub operations

The agent then uses `gh` or `curl` with the short-lived installation token.

**Pros**

- Smallest reversible change set
- Clear security boundary: key stays local, token is short-lived
- Easy to debug from a terminal
- Works well with explicit, agent-initiated actions
- Keeps webhook automation as future work without blocking it

**Cons**

- Some UX rough edges remain at the script layer
- Installation selection and error reporting need careful scripting
- More direct shell usage by agents than a richer integrated tool would require

### Approach B — Local opencode plugin exposing GitHub App commands

Create an opencode plugin that centralizes JWT minting, installation-token exchange, and a narrow set of GitHub commands.

**Pros**

- Better ergonomics for agents
- Centralized policy and logging hooks
- Easier future expansion into a stable internal interface

**Cons**

- More opencode-specific implementation complexity up front
- Harder to validate incrementally than plain scripts
- Larger surface area before real usage patterns are proven

### Approach C — Separate local or remote GitHub App bridge service

Run a dedicated service that handles GitHub App auth and exposes a local API for agents.

**Pros**

- Strong isolation and clear future path to webhook automation
- Easier to add caching, auditing, and multi-agent coordination later

**Cons**

- Overbuilt for the current need
- Adds deployment, lifecycle, and secret-management burden immediately
- Harder rollback story than simple local scripts

## 4. Recommendation

Use **Approach A** first: **agent-invoked helper scripts with local token minting**.

This is the best fit for the current constraints:

- agent-initiated actions are explicitly in scope now
- webhook automation is explicitly deferred
- the repo prefers pragmatic, reversible, narrowly scoped changes
- the authentication contract can be made explicit without committing to a plugin or service prematurely

The design should still preserve an upgrade seam: the scripts become the reference behavior that could later be wrapped by an opencode plugin or a small broker service if usage grows.

## 5. Design overview

### 5.1 Architecture

The integration consists of four layers:

1. **Configuration layer**
   - Stores non-secret metadata such as GitHub App ID, optional default installation owner, and private-key path.
   - Pulls sensitive values from environment variables or local file paths outside repo-tracked content where possible.

2. **Authentication helper layer**
   - Creates a JWT signed with the GitHub App private key.
   - Exchanges the JWT for a short-lived installation token using GitHub's REST API.
   - Optionally resolves the correct installation ID from an owner/repo pair.

3. **Action helper layer**
   - Provides thin wrappers for common operations an agent may need first, such as:
     - print installation token for a child process
     - get PR metadata
     - create PR comment
     - create PR
   - Keeps wrappers intentionally narrow and composable.

4. **Agent usage contract**
   - Agents explicitly invoke helpers when a task requires GitHub access.
   - No background automation, no implicit polling, and no webhook listener in this phase.

### 5.2 Data flow

1. Agent decides it needs GitHub access for an explicit user-approved task.
2. Agent invokes a helper script with repo/owner context.
3. Helper reads configured App ID and private key path.
4. Helper generates a short-lived JWT.
5. Helper calls GitHub to resolve installation context if needed.
6. Helper exchanges JWT for an installation access token.
7. Helper either:
   - prints the token for one-time use by `gh`/`curl`, or
   - performs a narrow action and returns structured output.
8. Token expires naturally; no persistent session is required.

### 5.3 Why this boundary is correct now

- It keeps secrets local and avoids embedding long-lived credentials in agent prompts.
- It keeps the first delivery understandable without reading opencode internals.
- It supports manual debugging with ordinary command-line tooling.
- It limits blast radius if the design changes later.

## 6. Components

### 6.1 Config contract

Recommended config inputs:

- `GITHUB_APP_ID` — numeric App ID
- `GITHUB_APP_PRIVATE_KEY_FILE` — absolute path to PEM private key
- `GITHUB_APP_INSTALLATION_ID` — optional fixed installation ID for single-installation setups
- `GITHUB_APP_DEFAULT_OWNER` — optional default org/user for installation lookup
- `GITHUB_API_URL` — optional, defaults to `https://api.github.com`

These may be sourced from shell environment or a local machine-specific config file that is not committed with secrets.

### 6.2 Helper scripts

Suggested helper responsibilities:

- `github-app-jwt` — output a signed JWT
- `github-app-token` — output an installation token, resolving installation if needed
- `github-app-api` — convenience wrapper for authenticated REST calls
- `github-app-pr-comment` — add a PR comment from explicit repo + PR number input
- `github-app-pr-create` — create a PR from explicit base/head/title/body input

These should emit machine-readable errors where practical and avoid writing secrets to logs.

### 6.3 Optional `gh` integration

If `gh` is available, the simplest pattern is:

- mint installation token with helper
- pass token as `GH_TOKEN` for a single command invocation
- avoid storing auth state globally in `gh auth login`

This keeps token use ephemeral and reduces accidental credential persistence.

## 7. File plan

This phase is only a design, but the expected implementation file set should look like this.

### 7.1 Repo-tracked files

- `docs/superpowers/specs/2026-05-19-github-app-integration-design.md`
- `.config/opencode/README.md` or a nearby ops doc section describing setup and activation
- `.config/opencode/bin/github-app/github-app-jwt`
- `.config/opencode/bin/github-app/github-app-token`
- `.config/opencode/bin/github-app/github-app-api`
- `.config/opencode/bin/github-app/github-app-pr-comment`
- `.config/opencode/bin/github-app/github-app-pr-create`
- `.config/opencode/opencode.jsonc` updates only if a non-secret command alias or permission rule is needed

### 7.2 Example runtime paths under `~/.config/opencode`

- `~/.config/opencode/bin/github-app/github-app-jwt`
- `~/.config/opencode/bin/github-app/github-app-token`
- `~/.config/opencode/bin/github-app/github-app-api`
- `~/.config/opencode/bin/github-app/github-app-pr-comment`
- `~/.config/opencode/bin/github-app/github-app-pr-create`
- `~/.config/opencode/credentials/github-app/private-key.pem`
- `~/.config/opencode/env/github-app.env`

### 7.3 Files intentionally not added in this phase

- webhook receiver services
- GitHub Actions workflows that auto-trigger from app events
- a persistent local daemon

## 8. Local testing strategy

The first implementation should be tested locally in behavior-focused steps.

### 8.1 Prerequisites

- A GitHub App created with only the minimum required permissions
- A private key downloaded locally
- Installation of the App on a test repository or sandbox org
- `curl` available
- Optional: `gh` available for convenience checks

### 8.2 Local test cases

1. **JWT generation succeeds**
   - Run the JWT helper with a valid private key.
   - Verify it outputs a token-shaped value and exits successfully.

2. **Installation token exchange succeeds**
   - Run the token helper with a known installation.
   - Verify returned token can call `GET /installation/repositories` or similar low-risk endpoint.

3. **Installation resolution works**
   - Omit fixed installation ID and provide owner/repo context.
   - Verify helper selects the expected installation.

4. **PR read succeeds**
   - Fetch metadata for a known pull request.
   - Verify the response includes expected fields.

5. **PR comment write succeeds**
   - Post a comment to a sandbox PR.
   - Verify the comment appears and contains the exact payload.

6. **PR create succeeds**
   - Create a PR in a sandbox repository from an already-pushed branch.
   - Verify title/body/base/head match requested values.

7. **Permission failure is clear**
   - Attempt an action without the required App permission.
   - Verify the helper returns an actionable, non-secret error.

8. **Missing key path fails safely**
   - Point to a nonexistent PEM file.
   - Verify helper exits nonzero and does not emit misleading auth output.

### 8.3 Verification commands

Representative manual verification flow:

1. `github-app-jwt` returns success and non-empty output
2. `github-app-token --owner <owner> --repo <repo>` returns success and non-empty output
3. `GH_TOKEN=$(github-app-token --owner <owner> --repo <repo>) gh pr view <number> --repo <owner>/<repo> --json number,title`
4. `GH_TOKEN=$(github-app-token --owner <owner> --repo <repo>) gh pr comment <number> --repo <owner>/<repo> --body "test comment"`

The exact command names may change during implementation, but the verification contract should stay at this behavioral level.

## 9. Success criteria

The first implementation is successful when all of the following are true:

1. An opencode agent can explicitly obtain a GitHub App installation token without using a PAT.
2. The private key is read from a local file path and is never committed to the repo.
3. The token is short-lived and used ephemerally for one command or one action.
4. An agent can read PR metadata from a sandbox repository.
5. An agent can add a PR comment in a sandbox repository.
6. An agent can create a PR in a sandbox repository.
7. Failures for missing config, invalid key, bad installation, or insufficient permissions are understandable and actionable.
8. No webhook receiver or background automation is required for the above workflow.

## 10. Security considerations

### 10.1 Secret handling

- Never commit the GitHub App private key.
- Prefer a file path such as `~/.config/opencode/credentials/github-app/private-key.pem` with restrictive file permissions.
- Avoid printing PEM contents, JWTs, or installation tokens in normal logs.
- If debugging token flow, require an explicit opt-in debug mode that still redacts secrets by default.

### 10.2 Permission minimization

- Grant the GitHub App only the repo permissions needed for the initial tasks.
- Prefer installing the App only on test repositories first.
- Separate sandbox and production installations where feasible.

### 10.3 Token lifecycle

- Use GitHub's short-lived installation tokens only.
- Do not cache tokens longer than necessary in files.
- Prefer environment-variable handoff to child commands over persistent credential stores.

### 10.4 Agent safety

- Keep actions explicit and user-task-driven.
- Require repo/PR identifiers as explicit inputs for mutating actions.
- Make destructive or broad operations out of scope for the first version.

## 11. Rollout plan

### Phase 1 — local sandbox trial

- Create helper scripts
- Validate auth flow against a sandbox repository
- Confirm read/comment/create PR flows
- Document setup and verification steps

### Phase 2 — limited real use

- Use the helpers only for explicitly requested GitHub tasks
- Observe repeated friction points and missing abstractions
- Decide whether scripts remain sufficient or justify a plugin wrapper

### Future phase — webhook-driven automation

Only after the agent-initiated workflow is reliable:

- evaluate event ingestion design
- define approval boundaries for automatic actions
- consider a plugin or service boundary if persistent orchestration is required

## 12. Rollback plan

Rollback should be cheap:

1. Remove helper scripts from the agent workflow.
2. Remove any command aliases or config references pointing to them.
3. Revoke or uninstall the GitHub App installation if needed.
4. Delete local private-key material from `~/.config/opencode/credentials/github-app/`.
5. Fall back to manual GitHub actions until a revised design is approved.

Because this phase avoids background services and webhooks, rollback is mainly a matter of removing scripts and revoking credentials.

## 13. Risks and mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Incorrect installation selected | Actions hit wrong repo/org | Require explicit owner/repo inputs and log resolved installation ID without exposing secrets |
| Secrets exposed in logs | Credential compromise | Redact sensitive output; avoid `set -x`; keep tokens ephemeral |
| App permissions too broad | Excess write authority | Start with minimum permissions on sandbox repos only |
| Script UX too clumsy for agents | Operational friction | Keep wrappers narrow and evolve to plugin only after real usage proves need |
| Future webhook design forced by early choices | Rework later | Keep auth and action helpers composable and stateless |

## 14. Test plan summary

The implementation plan should include behavior-level tests or verification steps for:

- valid JWT generation
- valid installation token exchange
- installation lookup by owner/repo
- PR read
- PR comment write
- PR creation
- clear failures for missing key, missing config, bad installation, and insufficient permissions

Where automated tests are added, prefer thin black-box tests around helper behavior over low-level crypto implementation tests.

## 15. Open future work intentionally deferred

- Webhook receiver for GitHub events
- Automatic PR triage or comment bots
- Background syncing of GitHub state into agent sessions
- Token broker daemon
- Rich opencode plugin abstraction over the script layer

These remain future work until the agent-initiated path proves useful and stable.
