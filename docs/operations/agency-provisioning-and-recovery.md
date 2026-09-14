# Agency provisioning and recovery

**Status:** Implemented operational guide

**Authority:** [ADR 0005](../adr/0005-agency-identity.md)

Privileged operators create Agencies and change Agency lifecycle through commands that are not exposed as tenant routes. Tenant administrators manage AgencyUsers and Offices through the application.

Run application commands through Docker in development. Do not place passwords in committed files, shell history, process listings, logs, screenshots, tickets, or copied command transcripts.

## Provision an Agency

`agency:provision` creates, atomically:

- one active Agency;
- one active first Office; and
- one active first AgencyUser with administrator access.

The task accepts the first administrator's password through the privileged invocation boundary. The command stores only the digest and prints only non-secret identifiers. It does not create an invitation, global User, AgencyMembership, OfficeAssignment, platform user, or bootstrap token.

Required environment variables:

| Variable | Purpose |
| --- | --- |
| `AGENCY_NAME` | Agency display name. |
| `AGENCY_WORKSPACE_CODE` | Globally unique normalized sign-in code. Immutable after creation. |
| `AGENCY_ADMIN_EMAIL` | First administrator's Agency-scoped email. |
| `AGENCY_ADMIN_FIRST_NAME` | First administrator's first name. |
| `AGENCY_ADMIN_LAST_NAME` | First administrator's last name. |
| `AGENCY_ADMIN_PASSWORD` | Initial password, 12–72 characters. Supply securely. |
| `AGENCY_OPERATOR` | Nonblank system actor identifier recorded in the audit event. |

Optional variables:

| Variable | Default |
| --- | --- |
| `AGENCY_COUNTRY_CODE` | `US` |
| `AGENCY_CURRENCY` | `USD` |
| `AGENCY_TIMEZONE` | `UTC` |
| `AGENCY_OFFICE_NAME` | Agency name |
| `AGENCY_OFFICE_CODE` | `MAIN` |
| `AGENCY_OFFICE_TIMEZONE` | Agency timezone |

Example using an interactive shell so the password is not embedded in a reusable command:

```bash
read -rs AGENCY_ADMIN_PASSWORD
export AGENCY_ADMIN_PASSWORD
export AGENCY_NAME="Horizon Travel"
export AGENCY_WORKSPACE_CODE="horizon"
export AGENCY_ADMIN_EMAIL="admin@example.test"
export AGENCY_ADMIN_FIRST_NAME="Alex"
export AGENCY_ADMIN_LAST_NAME="Morgan"
export AGENCY_OPERATOR="operator:initial-provisioning"
./dev/rails-docker bin/rails agency:provision
unset AGENCY_ADMIN_PASSWORD
```

Use the hosting platform's secret-input mechanism instead of shell export when one is available. The successful task output contains Agency ID, normalized workspace code, Office ID, and administrator ID only.

Provisioning is transactional but not idempotent. A repeated workspace code or same-Agency email fails validation and must not be treated as a retry result. Confirm the first attempt's output or inspect by ID before retrying with different input.

## Change Agency status

Supported lifecycle:

```text
active <-> suspended
active|suspended -> closed
closed is terminal
```

Run:

```bash
AGENCY_ID="<uuid>" \
AGENCY_STATUS="suspended" \
AGENCY_OPERATOR="operator:incident-123" \
./dev/rails-docker bin/rails agency:change_status
```

Suspending or closing an Agency destroys its Session rows. Reactivation does not reactivate suspended or closed AgencyUsers. The command prints the Agency ID and resulting status.

## Recover administrative access

There is no privileged recovery rake task and no supported console shortcut that bypasses the identity contract.

Use the normal mechanisms when possible:

1. An active administrator can invite another administrator or reactivate a suspended administrator through Agency User administration.
2. An active AgencyUser of an active Agency can use Agency-scoped password reset with workspace code and email.
3. An invited AgencyUser can receive a replacement invitation from an active administrator.

If an Agency has no usable administrator, stop and treat recovery as a product and security event. Do not directly update role/status columns, fabricate an audit actor, print a token, or create an undocumented task. Add an explicit, reviewed recovery command with authorization, locking, token/password handling, session invalidation, audit provenance, and tests before using it.

## Verification

After provisioning or lifecycle work:

- confirm the expected Agency, Office, AgencyUser, and AuditEvent by printed identifier;
- confirm no plaintext password or token appeared in application output or logs;
- confirm a suspended or closed Agency cannot authenticate and existing sessions fail closed; and
- record the operator identifier and reason in the appropriate operational record outside the application when required.
