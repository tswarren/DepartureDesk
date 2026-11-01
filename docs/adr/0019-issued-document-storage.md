# ADR 0019: Issued document storage

- Status: Accepted 2026-11-01. Decision log entry D-67.
- Date: 2026-11-01
- Decision owners: DepartureDesk maintainers
- Amends: `AGENTS.md`, which forbade Active Storage tables while they were unused.
- Specification: DOC-11, DOC-12, DOC-13, DOC-14, DOC-21, DOC-24, DOC-51; later CLT-17, CLT-18, CLT-20 and SUP-05
- Charter: [first-slice charter](../planning/first-slice/first-slice-charter.md), step 10 (D13) and Slice 1b reissue (D17)

## Context

Slice 1 issues confirmations, invoices and receipts as PDFs. Each issued document is kept as an immutable version with its exact rendered content (DOC-11). Reissuing creates a linked next version and keeps the earlier one as superseded (DOC-12). Receipts are payment evidence and are never overwritten (DOC-14). Staff and resellers download documents they may send (DOC-21, DOC-24).

Two questions follow:

1. **Store the rendered file, or render it again on every download?** Rendering on demand reproduces the original only if the template, fonts, renderer version and every input stay fixed forever. A template fix or a Chromium upgrade would silently change a document the client already holds.
2. **Where do the bytes live?** The application will soon need file storage beyond generated PDFs: passport images uploaded by staff and resellers (CLT-17, CLT-18), supplier quotes and agreements (SUP-05), and the agency logo (DOC-51). A Postgres byte column fits small generated files but not those.

## Decision

### Render once, at issue

- An issued document is rendered once, when it is issued, and the resulting PDF is stored. Every later download serves those stored bytes.
- Drafts and previews may render on demand. A preview is never stored as an issued version.
- Rendering is server-side HTML to PDF with headless Chromium. Whether it is invoked through the Chromium command line or a library is decided in the step 10 pull request. Production images must include Chromium, not only the development image.

### Files live in Active Storage

- Active Storage is installed and used. Its tables are framework-owned and may differ from the application's identifier and tenancy conventions. They are generated so attachments can reference the application's UUID primary keys.
- Services: local disk in development and test. The production service, with server-side encryption, is chosen before any real agency data or passport image is stored.

### An application-owned version table holds the guarantees

Each issued document is a row in an application-owned `document_versions` table. Active Storage holds only the bytes.

| Column or rule | Purpose |
| --- | --- |
| `agency_id` with same-agency foreign keys to the subject (booking, Client Trip or payment) | Tenancy, as for every other record |
| Document type and version number | DOC-11, DOC-12 |
| `supersedes_id` and a required reissue reason | DOC-12 |
| Issued at, issued by, template version and renderer version | Explains how the file was produced |
| SHA-256 of the PDF bytes | Integrity check on every download |
| `has_one_attached` PDF | The bytes |

- Version rows are append-only and never updated. Superseding is a new row pointing at the earlier one through `supersedes_id`; whether a version is superseded is derived from that link, not stored on the earlier row.
- Resending a version records a delivery and creates no new version (DOC-13).
- The attachment of a document version is never replaced, detached or purged. Model code refuses it, and a database trigger refuses deleting `active_storage_attachments` rows whose `record_type` is the document version class. Blob metadata updates from Active Storage analysis remain allowed.
- Other attachments follow their own rules. A passport image, for example, must be deletable (CLT-20).

### Issuing order

1. Render the PDF and compute its SHA-256.
2. Upload it as a blob with `ActiveStorage::Blob.create_and_upload!`.
3. In one transaction, create the document version row, attach the blob and write the audit event.
4. If the transaction fails, purge the uploaded blob.
5. A periodic job purges unattached blobs older than a set age. It never touches an attached blob.

This order means a committed version always has its file. A failure can leave only an unattached blob, which the job removes.

### Downloads go through the application

- Active Storage's own routes are turned off (`config.active_storage.draw_routes = false`). No file is reachable through a framework URL.
- Every download goes through an application controller that loads the document version through `Current.agency`, applies the user's permissions and, for reseller users, the reseller scope from [ADR 0017](0017-user-types-permissions-and-reseller-users.md). Anything outside scope returns not found.
- The controller checks the stored SHA-256 before sending the file. A mismatch is an error, never a silent download.
- Later, for large files, the controller may redirect to a short-lived service URL after authorizing the request.

### Not authorized by this ADR

Email delivery, passport images, supplier document uploads and the agency logo. Each uses this storage when a charter step places it in scope, with its own retention and deletion rules.

## Consequences

### Positive

- One storage mechanism for generated documents now and uploads later.
- Issued documents are exact and verifiable: what the client received is what the system serves.
- Tenancy, permissions and reseller scope stay in application tables and controllers, not in framework URLs.

### Costs

- File storage and the database commit separately, so the issuing order and the cleanup job are required, not optional.
- Backups must cover file storage as well as the database.
- Production images carry Chromium.
- Active Storage's tables sit outside the same-agency foreign key rules; tenancy depends on always going through `document_versions`.

## Alternatives rejected

### Render on every download

Rejected. It cannot guarantee the exact content DOC-11 requires, and receipts are payment evidence (DOC-14).

### PDF bytes in a Postgres column

Rejected, though it is simpler for Slice 1. It gives atomic commits and normal tenancy, but it doesn't fit passport images or supplier uploads, so a second storage mechanism would follow soon.

### Active Storage with its default routes

Rejected. Signed framework URLs work for anyone who holds them, which bypasses reseller scope and, later, passport permissions.

## Implementation boundary

Implemented in charter Slice 1 step 10 (D13) and used for reissue in Slice 1b (D17).
