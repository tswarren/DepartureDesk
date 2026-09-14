# ADR 0005: Agency identity

- Status: Accepted
- Date: 2026-09-13
- Decision owners: DepartureDesk maintainers

## Context

DepartureDesk is being rebuilt from a clean primary schema. The earlier membership model in [ADR 0002](0002-agency-tenancy-and-membership.md) and [ADR 0003](0003-membership-lifecycle-and-invitations.md) is superseded by this decision. Those records are retained for history and are not rewritten.

There is no migration path from the Party and membership schema. Agency identity is the only shipped domain in this slice.

## Decision

`Agency` is the tenant. Sign-in looks up the agency by an immutable, normalized `workspace_code` before email or password lookup. A database trigger rejects a later change to `workspace_code`, `AgencyUser.agency_id`, `Office.agency_id`, or `Office.code`. `params[:agency_id]` never establishes tenancy.

`AgencyUser` belongs to exactly one agency. The same normalized email in two agencies is two accounts, with independent passwords and sessions. Email is stored already stripped and downcased. Uniqueness is `(agency_id, email_address)` on that stored value, and the database requires `email_address = lower(btrim(email_address))`. There is no `citext` column.

Access roles are exactly `administrator`, `staff`, and `viewer`. Application code checks the permission catalog, not role names:

- `view_workspace` and `select_office_context`: administrator, staff, viewer
- `manage_agency_profile`, `manage_offices`, and `manage_agency_users`: administrator only

A descriptive relationship string does not grant access. Do not add Owner, Advisor, or external-collaborator roles.

### Lifecycle

Agency status is `active`, `suspended`, or `closed`. Transitions are `active ↔ suspended`; `active` or `suspended` may become `closed`; `closed` is terminal. Lifecycle changes never cascade-delete. An agency may have zero active offices. `Current.office` is then nil. `ProvisionAgency` still creates the first office. Later commands must not require an active office.

Agency user status is `invited`, `active`, `suspended`, or `closed`. `invited` may become `active` or `closed`; `active ↔ suspended`; `active` or `suspended` may become `closed`; `closed` is terminal. An invited, suspended, or closed user cannot sign in.

Suspending or closing an agency user or agency destroys the affected session rows. The server cannot clear cookies already stored in other browsers. When a browser next presents a stale session cookie, authentication rejects it and clears that presented cookie. Every authenticated request reloads the user and agency and fails closed if either is not active.

Only an active administrator counts. Suspend, close, and demotion of the last active administrator are rejected. Those commands lock the agency, then the affected user, then recheck the active-administrator count before writing.

### Invitations and password recovery

Invitation creates an `AgencyUser` in `invited` for that agency only. It never looks up or attaches a global user. A duplicate email in the same agency is a conflict shown to the inviting administrator and must not reveal that the email exists in another agency.

Store only a token digest. Acceptance requires the current unexpired token, sets the password, moves the user to `active`, clears the digest, and bumps a credential version. Replacement and revocation apply only while the user is `invited`. Replacement issues a new digest and invalidates the previous token. Revocation closes the invited user, clears the digest, and rejects later acceptance.

Password reset is agency-scoped, single-use, and hashed. Only an active agency user of an active agency may request or use it. A token issued before the agency is suspended or closed cannot be used. Every other state, including missing accounts, receives the same generic response and creates no token. A successful password change or reset bumps the credential version and destroys all sessions for that user.

Sign-in and password-reset attempts are rate-limited to 10 per 3 minutes per client IP plus normalized workspace code plus normalized email. Missing workspace, unknown email, bad password, and inactive user or agency all return the same generic failure.

### Office context

`Office` belongs to one agency. Status is `active ↔ inactive`. Inactive offices remain visible and cannot be selected as the current context. Deactivating an office clears it as any user's default and does not delete history. Office code is unique per agency, stored already normalized to uppercase, matches `[A-Z][A-Z0-9]{1,9}`, and is immutable after create. Timezone is a required IANA name.

`Session.office_id` and `AgencyUser.default_office_id` are the only office preferences in this slice. Do not create affiliation rows. `Current.session` is the authentication root. `Current.agency` comes from the session's agency user. `Current.office` resolves, without writing on GET, from a stored session office that belongs to the agency and is active, else the user's default office if that office belongs to the agency and is active, else nil.

An explicit select command may store a current office only when `select_office_context` is allowed and the office is an active office of `Current.agency`. A query parameter never authorizes and never selects an office on GET. Default office uses a composite foreign key `(default_office_id, agency_id)` and must be null or an office of that agency. Changing current office changes no permission.

### Provisioning and isolation

`ProvisionAgency` is privileged and not a tenant route. In one transaction it creates the agency, the first active office, and the first active administrator. It requires an explicit actor identifier and must not invent a platform user. It accepts the first administrator's password through that privileged invocation boundary, stores only the password digest, and never returns or logs the plaintext credential. Do not generate or print a bootstrap password or activation token.

Load records through `Current.agency`. An identifier from another agency returns not found, not forbidden. Tenant records that carry `agency_id` must prove same-agency foreign keys. A session derives its agency through `AgencyUser` and does not store a redundant `agency_id`. Audit catalogs cover `Agency`, `AgencyUser`, and `Office` only. Audit successful administrative commands in the same transaction. Do not audit expected failures as successful activity.

Agency lifecycle changes are privileged commands, not tenant routes. Tenant administrators maintain the profile, offices, and users. They do not suspend or close the agency from the application.

## Consequences

The Party directory, membership invitations, office assignments as access control, and Action Cable identification through membership are not part of this application. Later commercial records must not be loaded from a global user or from `params[:agency_id]`.
