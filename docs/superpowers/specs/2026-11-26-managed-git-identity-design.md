# Managed Git identity
## Goal

Keep the hub and its managed child repositories configured with the intended Git author name and email. A new child repository must not depend on a global Git identity in the pod. Existing children need an automatic repair path.

## Evidence and investigation

The hub's local `user.name` currently contains a literal backslash before the space. The source of that backslash is not yet known. The resolver emits shell-escaped assignments, and the provision pipeline evaluates and forwards them. Existing resolver tests cover names with spaces, but they do not establish what happens across the full DevSpace pipeline boundary. The host global Git configuration could also contain the incorrect value.

`bin/clone-repo` creates a child bare repository without copying the hub's local identity. Provisioning configures the hub's bare repository, not its children.

Before selecting a fix for the mangling, trace the identity from its host source through the actual pipeline to the hub configuration. Reproduce the failure in the appropriate execution context. Do not assume that shell escaping is the cause or strip all backslashes: a backslash can be part of an intended name.

## Design

- Provision preserves the exact intended name and email across the host-to-pod boundary. It retains the existing choice of identity sources and does not derive identity from `gh`.
- At clone time, copy each available `user.name` and `user.email` from the hub's **local bare configuration** into the new child's bare configuration. If a field is absent, leave that field unset in the child. Do not use a global Git value as a substitute.
- Extend workspace repair to copy both hub identity fields into existing managed child bare repositories, replacing their current values. The user confirmed that there are no intentional child-specific identities to preserve. Repair must not change unrelated repositories or global configuration.
- If either hub identity field is missing, the identity repair step must report the problem and leave child identities unchanged. It must not propagate a partial identity.
- Verify the hub identity against the intended host identity before running repair on the live workspace. First fix and verify the provisioning path, then have the user provision the corrected identity in the required execution context. Do not copy the currently observed mangled value to children.
- Repair must identify managed children safely and report invalid or ambiguous child repositories rather than modifying an unrelated Git configuration. Repeated repair with the same hub identity must be safe.

Existing commits are not rewritten. Changes to Git identity affect future commits only.

## Behavioral acceptance

1. A full provision-path test preserves a name with spaces and an email exactly, including at the hub bare configuration. Exercise the boundary that caused the observed failure once it is identified; also cover an intentionally supplied backslash without silently removing it.
2. A new managed child receives both hub-local identity fields. Tests cover each missing field and show that global configuration does not supply it implicitly.
3. Repair updates existing managed children, including children with previous local values. It leaves unrelated repositories alone and is repeatable.
4. A missing hub field prevents identity repair from changing any child. Invalid or ambiguous managed children produce a clear failure or report without altering unrelated repositories.
5. Existing tests continue to establish that provisioning does not derive identity from `gh`.

Use behavioral tests at the appropriate host, pod-inside-nono, or DevSpace boundary. Run each check only in its designated context. Ask the user to run checks that require a host, outside-nono, or vscode context that the agent cannot access.

## User Check-in

The user reviews this spec before implementation planning. Before interface-defining tests are implemented, offer them for user review. After the provision fix is verified in the proper context, the user applies it and confirms the corrected live hub identity before any live child repair.
