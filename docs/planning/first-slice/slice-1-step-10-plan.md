# Slice 1 step 10: Confirmation, invoice and receipt PDFs

**Status:** Accepted 2026-11-10, after step 9 merged (#284, #285), with **D-100** logged; built 2026-11-10. Questions 1, 7 and 13 settled with the user 2026-11-10. Not implementation authority beyond the [first-slice charter](first-slice-charter.md) build step 10 and the decision log entries it cites.

Charter build step 10 issues the confirmation, invoice and receipt as PDFs. It closes **D13**:

> Staff issue a confirmation, invoice and receipt. PDFs are stored as immutable versions and show no dates of birth.

It covers:
- **Workflow step 15, documents:** DOC-01, DOC-03, DOC-11, DOC-21 and DOC-24. DOC-12, reissue, is Slice 1b (D17).
- **Storage:** [ADR 0019](../../adr/0019-issued-document-storage.md) (D-67), which this step implements: render once at issue, an application-owned version table, Active Storage for the bytes, downloads only through the application.
- **What documents show:** the agency profile, inclusion flags and footers already shipped in step 1 (SET-04 to SET-07), and the optional logo (DOC-51).

It uses screens S-35 (Documents) and R-04 (the reseller's confirmation download).

Already shipped:
- **References:** the `confirmation`, `invoice` and `receipt` reference namespaces (CNF, INV, RCP). Invoice and receipt numbers are gapless (REF-05).
- **Receipts:** a `Receipt` record is issued with its RCP number when an agency payment is recorded (step 8a, CMN-55). It holds the payer, amount, date, method and what was applied, and its page says its PDF arrives with documents.
- **Agency profile:** the profile fields, `agency_document_inclusions` for the confirmation, invoice, receipt and statement families, both footers with their limited Markdown, and the logo. `Agency#document_profile_blockers` already lists what SET-04 requires.
- **Active Storage:** installed, with its framework routes off (`draw_routes = false`), and used for the logo, arrangement documents and acceptance evidence.
- **Chromium:** in the development image for system tests. There is no production image yet; the platform is still open in [production readiness](../../operations/production-readiness.md).

## Questions settled for this plan (2026-11-10)

Each recommendation stays inside the cited rules except question 13, which brings DOC-09 into scope and so is proposed below as **D-100**.

| # | Question | Recommendation |
| --- | --- | --- |
| 1 | **When a document is issued.** | **By an explicit action, never automatically.** "Issue confirmation" and "Issue invoice" on a confirmed booking; "Issue receipt PDF" on an agency receipt. Each renders the PDF once and stores it (ADR 0019). A draft, discarded or cancelled booking can't be issued a confirmation or invoice: the invoice covers the client charge and its installments (DOC-01), which exist only once confirmed. |
| 2 | **Numbers.** | The confirmation takes the next **CNF** number and the invoice the next **INV** number, both at issue; INV stays gapless because the number is drawn in the issuing transaction (REF-05). The receipt PDF **keeps its receipt's RCP number**, issued with the payment in step 8a; it draws no new number. Every version is version 1 in Slice 1, shown without a suffix. |
| 3 | **Issuing twice.** | **Refused in Slice 1.** Each booking has at most one confirmation and one invoice, and each receipt one PDF, enforced by a unique index. A second issue is a reissue (DOC-12), which is Slice 1b (D17): the refusal says the document is already issued and reissue isn't built yet. The table already carries `supersedes_id` and a reason column, null for now, so Slice 1b adds no migration for the link. |
| 4 | **What each document shows (DOC-01, DOC-03, DOC-51).** | One fixed layout per type.<br>• **Every document:** the agency's profile fields as its family's inclusion flags allow, the logo when set, the family's footer (confirmation footer for the confirmation; financial-document footer for the invoice and receipt), the document number and issue date, and the responsible client (the payer for a receipt, CMN-56).<br>• **Confirmation:** "Booked through [reseller]" when a reseller owns the booking (question 13), the booking and trip references, the Departure's name and dates, each traveler by name, each service by its label with who is in it, the total price, and the accepted client terms version.<br>• **Invoice:** the same "Booked through" line, the charge lines with the total, the installments with due dates, what was paid at issue and what is still due, labelled by route (paid to the agency, or to a named supplier, CMN-53).<br>• **Receipt:** what the receipt record holds (CMN-55): payer, amount, date paid, collector and route, method and reference, and the amounts applied.<br>**Never shown (DOC-03, CLT-36):** dates of birth, passport details, supplier references, emergency contacts, supplier cost, commission or margin. Supplier names appear only where a payment was made to a supplier. |
| 5 | **The snapshot (DOC-11).** | Each version stores, beside its PDF, a `snapshot` (jsonb) of exactly the values it displays, built from recorded data in one place per type. The template renders only from the snapshot, so what is stored is what was shown, and later profile, footer or price changes never touch it (SC-DOC-03). The snapshot builders are the only code that reads the records, and their tests check that no date of birth or cost field is ever copied in. |
| 6 | **Renderer (ADR 0019).** | **Chromium's command line**, with no new gem: render the template to an HTML file, run `chromium --headless --no-sandbox --print-to-pdf --no-pdf-header-footer` on it with a timeout, and read the PDF back.<br>• Fonts and styles are inline in the template; no network access while rendering.<br>• The renderer version (from `chromium --version`) and a template version constant are stored on the version row.<br>• **Correction (build):** the invoice's gapless number must exist before its PDF can show it, so rendering and the upload happen inside the issuing transaction, after the number is drawn; a failed transaction purges the blob. Recorded as ADR 0019's 2026-11-10 amendment. |
| 7 | **Who issues and downloads (ACC-30, DOC-21, DOC-24).** | **Staff:** every staff user issues and downloads all three (ACC-30: issue and send documents is baseline). One new baseline action, `issue_documents`.<br>**Reseller:** the reseller that owns the booking issues and downloads that booking's **confirmation only** (R-04; DOC-24). Its invoice and receipt are hidden from it, as screen R-04 says. One new reseller action, `reseller_issue_confirmation`. An invoice or receipt route is not found for a reseller. |
| 8 | **Manual delivery (DOC-21).** | Anyone who may download a version may record a manual delivery: method (own email, printed, in person), recipient and date. An append-only `document_deliveries` row, marked manual, listed under the version. Sending email from DepartureDesk is out of scope (charter). |
| 9 | **Refusals before issuing.** | Issuing is refused, with its reason, when the agency profile lacks its display name or contact email (SET-04), or when the booking isn't confirmed (question 1). |
| 10 | **Storage guarantees (ADR 0019).** | • `document_versions`: agency, document type, number, subject (a booking or a receipt) with same-agency keys, issued at and by, template and renderer versions, SHA-256 of the PDF, snapshot, `supersedes_id` and reissue reason (unused in Slice 1), and the attached PDF.<br>• Rows are append-only: a trigger refuses update and delete. A second trigger refuses deleting their `active_storage_attachments` rows.<br>• Issuing order: render, hash, upload the blob, then one transaction for the row, the attachment and the audit event; purge the blob if the transaction fails.<br>• A daily job on a new `documents` queue purges unattached blobs older than a day; it never touches an attached one.<br>• Every download goes through one controller that loads the version through `Current.agency` (or the reseller scope), checks the SHA-256 and sends the PDF inline under a sandboxing Content-Security-Policy.<br>• `DocumentVersion` joins the audit subject catalog, with `document_version.issued` and `document_version.delivery_recorded` (AGENTS.md invariant 15). |
| 11 | **Where it shows (S-35, R-04).** | A **Documents** panel on the booking Summary lists the confirmation and invoice with Issue or Download, each version's number, issue date and who issued it, its deliveries, and "Record delivery". The receipt page gets the same panel for its PDF. The reseller's booking Summary shows the confirmation part only. |
| 12 | **Production image.** | There is none yet. The production readiness checklist gains a line: the image includes Chromium and the fonts the templates use, and a renderer smoke test runs at release. The development image gains `poppler-utils`, so tests can read the text of a PDF with `pdftotext`. |
| 13 | **"Booked through" (DOC-09).** The charter doesn't cite it. | **Added (D-100, settled 2026-11-10).** The confirmation and invoice of a booking a reseller owns at issue carry the line "Booked through [reseller name]". The line follows the owner at issue, so a reassigned booking's later documents name the new owner, and documents already issued are unchanged (DOC-11). A receipt covers a payer's payment across a Departure, not one booking, so it carries no line. Recipient defaults (DOC-07, DOC-08) stay out of scope, since nothing is sent from the app. |

## Proposed decision log entry

> | D-100 | 2026-11-10 | Amend the first-slice charter for build step 10: bring DOC-09 into scope. The booking confirmation and invoice of a booking owned by a reseller when the document is issued carry "Booked through [reseller name]"; a receipt carries no such line. Recipient defaults (DOC-07, DOC-08) stay out of scope. | DOC-09, DOC-11 |

Once it is logged, the build's first commit applies it to the charter (workflow step 15's rule list), the pending entries' "Already logged" row, the snapshot's decision log row and the planning index.

## Not in this step

- Reissue and superseded versions (DOC-12, D17, Slice 1b), and receipt corrected copies (DOC-14).
- Sending email (DOC-15 to DOC-20), reminders, statements, proposals, itineraries and the other catalog documents.
- Recipient defaults for reseller-owned bookings (DOC-07, DOC-08).
- Previews before issuing.

## Tests

- **D13**, against the Alpha fixture with BK-101 paid (`bookings: :paid`):
  1. Staff issue BK-101's confirmation, invoice and receipt.
  2. Each is a stored version with its number (CNF, INV, the payment's RCP), its PDF and SHA-256.
  3. The PDF text shows the travelers' names and no date of birth; no cost or commission.
  4. BK-105's confirmation, issued by the reseller, reads "Booked through Coral Coast Travel"; BK-101's has no such line (D-100).
  5. Changing the footer after issue leaves the stored PDF and snapshot unchanged (SC-DOC-03).
  6. PostgreSQL refuses updating or deleting a version and deleting its attachment.
- **Commands:** issuing twice is refused; a draft booking can't be issued; SET-04 blockers refuse; a failed transaction leaves no attached blob and the job purges it; invoice numbers stay gapless.
- **Authorization:** another agency's version is not found; a reseller issues and downloads only its own booking's confirmation, and its invoice and receipt are not found; a SHA-256 mismatch is an error.
- **D15** gains the reseller's confirmation download (R-04).
- **UI:** S-35 and R-04 reflow at 375px; query counts for the booking Summary with documents.

## Build order

One pull request, citing DOC-01, DOC-03, DOC-09 (D-100), DOC-11, DOC-21, DOC-24, SET-04 to SET-07 and D13:
1. Migration: `document_versions`, `document_deliveries`, the triggers; models; audit catalog.
2. Snapshot builders and templates for the three types; the renderer.
3. `IssueDocument` and `RecordDocumentDelivery`; the cleanup job.
4. S-35 on the booking Summary and the receipt page; R-04.
5. D13, the D15 addition, docs (current state, shipped vocabulary, ADR 0019's implementation note, production readiness, planning index).
