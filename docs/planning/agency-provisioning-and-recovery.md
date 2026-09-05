# Agency provisioning and recovery

Privileged operators create agencies, change lifecycle status, and recover
administrative access through Rails commands. There is no platform
administration web UI. These commands are not part of ordinary agency
administration.

Authorization is operational, not application-role based. Only operators who
are allowed to run deployment or production-console commands may execute them.
Never put passwords, invitation tokens, or mail credentials in arguments,
environment dumps, logs, or command output.

Use the Docker wrapper in development:

```bash
./dev/rails-docker bin/rails agency:provision
./dev/rails-docker bin/rails agency:change_status
./dev/rails-docker bin/rails agency:recover_administrator
```

## Provision an agency

Creates an active agency, an invited administrator membership, provisioning and
invitation audit events, and then enqueues the invitation email. The membership
is never silently activated. The generated password digest is unguessable and
is never printed.

Required environment:

| Variable | Purpose |
| --- | --- |
| `AGENCY_PROVISIONING_KEY` | Caller-supplied idempotency key. Only its digest is stored. |
| `AGENCY_OPERATOR` | System actor identifier for the operator or deployment principal. |
| `AGENCY_NAME` | Display name. |
| `AGENCY_ADMIN_EMAIL` | First administrator email. |
| `AGENCY_ADMIN_FIRST_NAME` | First name. |
| `AGENCY_ADMIN_LAST_NAME` | Last name. |

Optional environment:

| Variable | Default |
| --- | --- |
| `AGENCY_LEGAL_NAME` | none |
| `AGENCY_COUNTRY_CODE` | `US` |
| `AGENCY_TIMEZONE` | `UTC` |
| `AGENCY_CURRENCY` | `USD` |
| `AGENCY_ADMIN_PREFERRED_NAME` | none |

Example:

```bash
AGENCY_PROVISIONING_KEY="harbor-travel-2026-09-05" \
AGENCY_OPERATOR="ops:alex.mariner" \
AGENCY_NAME="Harbor Travel" \
AGENCY_LEGAL_NAME="Harbor Travel LLC" \
AGENCY_COUNTRY_CODE="US" \
AGENCY_TIMEZONE="America/New_York" \
AGENCY_CURRENCY="USD" \
AGENCY_ADMIN_EMAIL="alex.mariner@example.com" \
AGENCY_ADMIN_FIRST_NAME="Alex" \
AGENCY_ADMIN_LAST_NAME="Mariner" \
./dev/rails-docker bin/rails agency:provision
```

Successful output contains the agency ID, agency name, membership ID, whether
the request was reused, and the next action. It never contains a token or
password.

### Idempotency

The command stores `idempotency_key_digest` and `intent_digest` (a digest of
the normalized inputs). The raw key is not retained.

- Same key and same intent: return the existing agency and membership. Do not
  send another invitation.
- Same key and different intent: explicit conflict. No additional tenant is
  created.
- New key and the same business inputs: explicit conflict. This is not silent
  reuse.
- An email that already has an active membership: generic operator conflict.
  The command does not attach that user or disclose the other agency.

If the provisioning transaction fails, no completed request row remains.

### Inspecting the result

```bash
./dev/rails-docker bin/rails runner '
  agency = Agency.find("AGENCY_ID")
  puts [agency.id, agency.name, agency.status].join(" ")
  agency.agency_memberships.find_each do |membership|
    puts [membership.id, membership.role, membership.status, membership.user_id].join(" ")
  end
  agency.audit_events.order(:created_at).each do |event|
    puts [event.id, event.action, event.actor_kind, event.actor_identifier].join(" ")
  end
'
```

The invited administrator accepts the email link, sets a password, and lands on
the dashboard. Do not set or print a password for them.

## Change agency status

Allowed transitions:

```text
active → suspended → active
active → closed
suspended → closed
```

`closed` is terminal. Closure does not delete agency, membership, user, or
audit data. Reactivating an agency does not reactivate suspended memberships.

Required environment: `AGENCY_ID`, `AGENCY_STATUS`, `AGENCY_REASON`,
`AGENCY_OPERATOR`.

```bash
AGENCY_ID="..." \
AGENCY_STATUS="suspended" \
AGENCY_REASON="Contract review" \
AGENCY_OPERATOR="ops:alex.mariner" \
./dev/rails-docker bin/rails agency:change_status
```

After suspend or close, sessions are destroyed only for users whose **active**
membership is on that agency. Foundation 1 session revalidation remains the
fail-closed backstop.

## Recover an administrator

The agency must already be active. Recovery does not reopen a suspended or
closed agency. It does not bypass the one-active-membership rule.

Required environment: `AGENCY_ID`, `AGENCY_REASON`, `AGENCY_OPERATOR`,
`AGENCY_RECOVERY_MODE`.

Modes:

| Mode | Additional input | Effect |
| --- | --- | --- |
| `replace_invitation` | `AGENCY_MEMBERSHIP_ID` | Replace an invited or revoked administrator invitation. |
| `reactivate` | `AGENCY_MEMBERSHIP_ID` | Reactivate a suspended administrator. |
| `invite_replacement` | `AGENCY_ADMIN_EMAIL`, `AGENCY_ADMIN_FIRST_NAME`, `AGENCY_ADMIN_LAST_NAME`, optional preferred name | Invite a replacement administrator. |

```bash
AGENCY_ID="..." \
AGENCY_RECOVERY_MODE="replace_invitation" \
AGENCY_MEMBERSHIP_ID="..." \
AGENCY_REASON="Expired first-admin invitation" \
AGENCY_OPERATOR="ops:alex.mariner" \
./dev/rails-docker bin/rails agency:recover_administrator
```

Each success writes `team.administrator_recovery_started` plus the matching
team completion action. Failures write no success audit. Sessions are destroyed
only when a nested command changes credentials or revokes access; replacing an
invitation or inviting a new address does not sign anyone in.

## Failed or expired invitations

If invitation mail is not delivered after a committed provision or invite, do
not roll back the agency. Use `replace_invitation` (or the tenant-facing
replace action when an administrator can still sign in). The earlier link
becomes invalid.

If acceptance fails, the invitation version is unchanged and the same link
remains usable until it expires, is replaced, or is revoked.

## Compensation boundaries

- Do not delete a provisioned agency to “undo” a mistake. Suspend or close it
  with a reason.
- Do not rewrite audit events.
- Do not reuse a provisioning key for a different agency.
- Do not activate a membership from the console to skip invitation acceptance.
- A mail-delivery failure after commit is recovered by replacing the
  invitation, not by deleting the membership.
