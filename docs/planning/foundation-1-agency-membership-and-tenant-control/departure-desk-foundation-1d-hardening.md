# Foundation 1D — command and activation hardening

## Status

Implementation slice on `foundation-1d-command-and-activation-hardening`. Foundation 1A–1C remain the shipped tenant, team, and privileged-operations baseline.

## Purpose

Harden the Foundation 1 command, activation, audit, and invitation-delivery boundaries before Phase 2. This is an integrity slice, not a new foundation program.

## What this slice covers

- Membership-target commands reject a membership that does not belong to the supplied agency.
- Tenant actor authorization runs inside the agency lock and requires a usable administrator membership on that active agency.
- Ordinary team commands accept a user actor only. Privileged system attribution is an explicit opt-in used by recovery-owned nested calls.
- Invitation acceptance and reactivation share a user → agency → membership activation primitive. Acceptance revalidates the presented token after those locks.
- Recovery `reactivate` delegates lock ownership to that primitive. `replace_invitation` and `invite_replacement` keep the agency-first transaction.
- Agency names are stripped and rejected when blank so the database check is not the first failure.
- Team-invitation delivery intents are discarded when the agency is inactive, the intent agency does not own the membership, the subject is missing or not a membership, or the intent has no agency.

## Out of scope

Concurrent last-administrator tests, exhaustive team system tests, an audit-details DSL, and production hosting or email-provider selection.
