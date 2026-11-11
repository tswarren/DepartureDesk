# Authentication and tenancy

Moved from [AGENTS.md](../../AGENTS.md), which points here. Sessions, tenancy, invitations, permissions, offices, audit and Action Cable. These rules are binding when a task touches this area.

- Authentication uses `AgencyUser`, `Session`, bcrypt, and a signed permanent session cookie.
- Tenant context is the session's agency user. `Current.session` is the authentication root. `Current.agency` comes from that user. Never establish tenancy from `params[:agency_id]`, headers, or extra cookies.
- `Current.office` is subordinate context. It is resolved, without writing the session, from a valid stored `office_id`, else the user's active default office, else nil. Never authorize from `params[:office_id]`, and do not persist or clear a session office selection on GET.
- Login and every authenticated request fail closed when the user or agency is not active. Do not reveal whether the workspace, email, password, user, or agency failed.
- Successful authentication redirects through the named root route; keep `root_url` available unless authentication behavior is intentionally changed.
- Do not expose whether an email address exists during password-reset flows.
- Never log plaintext passwords, tokens, payment credentials, or other sensitive information.
- The current seed credential is development-only and must not be printed.
- Agency Admin capabilities are catalog checks on the agency user, not a property on a global user.
- Agency Admins may edit the current agency profile, offices, traveler types, agency users and their permissions. They may not create agencies or change agency lifecycle status from a tenant route.
- An Agency Admin invites `agency_admin` or `staff` users. A `reseller` user is invited from its relationship's page (S-04) by an Agency Admin or staff with Reseller relationships, to one active relationship (Slice 1 step 9b; ACC-13).
- A reseller session is served only from the `Reseller::` namespace under `/reseller`. The guard in `Authentication` sends it home from every staff controller unless the controller declares `allow_reseller_access` (sign-out, the password page); `ResellerArea` refuses a staff session in the namespace. Reseller reads go through `ResellerScope`, never `Current.agency` alone, so a record outside it is not found.
- Invitation acceptance is the documented invitee exception: the invitee is the audit actor and is not yet an Agency Admin until acceptance commits.
- Last-Agency-Admin mutations lock agency, then the affected user, then recheck.
- Agency provisioning and lifecycle are privileged commands (`ProvisionAgency`, `ChangeAgencyStatus`), not tenant-facing routes. System audit events require `actor_identifier` and must not invent a platform user. Command output may print identifiers only—never passwords or invitation tokens.
- Audit subjects are narrowly typed: an `Agency` subject must equal the event agency; any other subject must belong to it. Unknown subject types raise.
- An office belongs to exactly one agency. Office access is not a permission. Do not create affiliation rows. Human-readable office codes never authorize.
- Later office-owned records must carry a direct `agency_id` and enforce matching `(office_id, agency_id)` with a composite foreign key. Do not infer tenant ownership only through `office_id`.
- `AuditEvent::ACTIONS` and subject types are closed catalogs. Extend both in the same change that first writes a new supported action or subject. `AuditEvent#details` is not a document-version or snapshot store.
- Administrative mutations write append-only `AuditEvent` records in the same transaction. Audit events reject update and destroy in the application and in PostgreSQL.
- Business records must be loaded through `Current.agency`. Do not use a tenant `default_scope`.
- Action Cable identifies `current_agency_user` and `current_agency` from the session. It must not copy request `Current` onto a long-lived connection and must not persist `Current.office` on the connection.
- Jobs that need office scope accept an office identifier, reload the office through the agency, and re-check that it is an active office of that agency. Office context is not authorization.
