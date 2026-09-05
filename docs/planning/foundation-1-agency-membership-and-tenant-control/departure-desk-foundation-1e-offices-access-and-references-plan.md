# Foundation 1E — offices, access, and reference policy

## Status

Implementation slice on `foundation-1e-offices-access-and-reference-policy`. Depends on Foundation 1D.

## Purpose

Introduce agency-owned offices, explicit office access, and session-backed current-office context without making `Office` a tenant or adding a numbering engine.

## Locked decisions

- Agency remains the tenant. Every later office-owned row still has a direct `agency_id` and must enforce matching `(office_id, agency_id)` with a composite foreign key.
- Staff operate only in offices with an active assignment. Administrators may use every active office without an assignment per office; they still have one default assignment when any active office exists.
- Office access is not a role.
- Office codes are stripped, uppercased, then validated as `\A[A-Z][A-Z0-9]{1,9}\z`; immutable after create; unique per agency. Backfill/provision use `MAIN`, `MAIN2`, `MAIN3`, and abort rather than truncate.
- Each office has its own IANA timezone, initially copied from the agency.
- `Current.office` is side-effect-free. Order: valid stored `session.office_id`, else the active accessible default, else the sole accessible office, else `nil`. Persist only on login, invitation acceptance, and `SelectCurrentOffice`. Deactivation and revocation clear matching sessions after commit.
- Dashboard, agency profile, and team remain agency-wide in this slice.
- Provisioning creates agency, `MAIN` office, invited administrator, default assignment, then audits and delivery intent, in one transaction.
- New and replacement invitations through `InviteTeamMember` submit a complete intended office set plus one default. Omitted assignments are revoked. `ReplaceInvitation` only rotates the token and fails if the current set is illegal.
- Accepting or reactivating staff requires an active assignment to an active office. Administrators may activate without an assignment only when the agency has no active office.
- Deactivating an office clears defaults targeting it, does not revoke those assignments, and nominates another default only when exactly one accessible active office remains. Reactivation does not restore prior defaults.
- ADR 0004 is accepted. No universal sequence table.

See [ADR 0002](../../adr/0002-agency-tenancy-and-membership.md) and [ADR 0004](../../adr/0004-human-readable-references.md).
