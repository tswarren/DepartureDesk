# Product Specification

**Status:** Accepted product authority. The master copy is the Google Doc; this folder holds a read-only snapshot.

| File | Purpose |
| --- | --- |
| [`product-specification.md`](product-specification.md) | Markdown export of every tab of the [DepartureDesk Product Specification](https://docs.google.com/document/d/1qdqOTMWcSWClAojGeB8NsYYunzJlTDcmgXp_S1Se-CQ/edit), including its decision log (D-01 to D-67) and the advisers' questions appendix. Do not edit it. |
| [`pending-decision-log-entries.md`](pending-decision-log-entries.md) | Decision log entries proposed by the [first-slice charter](../planning/first-slice/first-slice-charter.md) that are not yet in the Google Doc. |

## How the specification is organized

Each area has Context, Rules, Tables, Scenarios and Open questions. Rule IDs use an area prefix and a two-digit number (`BKG-39`). Scenario IDs use `SC-` plus the prefix (`SC-BKG-07`). Decision log entries are `D-nn`. Numbers are never reused.

| Prefix | Area |
| --- | --- |
| OVR | Product overview |
| ACC | Users and access |
| SET | Agency setup |
| REF | References |
| SUP | Suppliers and arrangements |
| INV | Inventory |
| CLT | Clients and travelers |
| BKG | Bookings and packages |
| DEP | Departures |
| SMN | Supplier money |
| CMN | Client money |
| FIN | Profitability, currency, tax, and closeout |
| OPS | Operations |
| DOC | Documents and communications |
| RPT | Reporting and boundaries |
| D | Decision log |

Rule status is one of Agreed, Detail, Proposed, Open, Review, Deferred or Retired. **Agreed does not mean in scope.** Only a rule cited by the active slice charter is in scope; see the [planning index](../planning/README.md).

## Changing a rule

The spec changes before the code does.

1. Edit the rule in its area of the Google Doc, and add a decision log entry naming the rule ID. If the change adds scope to the active slice, the entry must name the charter.
2. Search the Google Doc for the rule ID and update anything that cites it.
3. Re-export the Google Doc as Markdown (all tabs) and replace `product-specification.md`, keeping the header comment and updating its dates.
4. Commit the snapshot in the same pull request as the code that depends on the change, or in an earlier one.

Pull requests cite the rule IDs they implement. If code and the snapshot disagree, the snapshot wins. If the snapshot and the Google Doc disagree, re-export.

## Relationship to older documents

The specification replaces the [MVP requirements](../planning/departure-desk-mvp.md), the [Commercial Domain Decision Register](../planning/commercial-domain-decision-register.md) and the [roadmap](../planning/roadmap.md) as product authority. Those documents are Superseded and kept for history. Accepted ADRs still govern the technical decisions they record, unless a later ADR or decision log entry supersedes them.
