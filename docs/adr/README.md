# Architecture decision records

ADRs preserve decisions and their history. Superseded ADRs remain here rather than moving to the general documentation archive.

| ADR | Status | Governs |
| --- | --- | --- |
| [0001](0001-money-and-currency.md) | Accepted | Money values, minor-unit persistence, currency, parsing, and conversion boundaries. |
| [0002](0002-agency-tenancy-and-membership.md) | Superseded by 0005 | Previous global User and agency-membership tenancy. |
| [0003](0003-membership-lifecycle-and-invitations.md) | Superseded by 0005 | Previous membership invitation and lifecycle model. |
| [0004](0004-human-readable-references.md) | Accepted | Internal UUID identity and domain-qualified human references, including Client, Supplier, and Departure namespaces. |
| [0005](0005-agency-identity.md) | Accepted and implemented | Agency-scoped AgencyUser identity, authentication, Office context, and permissions. |
| [0006](0006-separate-identity-domains.md) | Accepted product boundary; implementation deferred | Separate Agency User, Client, Supplier, and Traveler identity contexts. |
| [0007](0007-departure-operational-root.md) | Accepted | Departure as dated operational root; Travel Program deferred. |
| [0008](0008-supplier-arrangement-version-topology.md) | Accepted; M3A draft topology implemented; activation and successor behavior deferred | Stable Arrangement and child identities with immutable activated versions and per-version definitions. |
| [0009](0009-supplier-contracting-and-service-provider-roles.md) | Accepted; M3A Supplier-role behavior implemented; later dependency extensions deferred | Contracting Supplier, computed Service Provider, Arrangement contact, and Supplier-inactivation roles. |
| [0010](0010-supplier-capacity-ledger-and-projection.md) | Accepted; implemented by shipped M3B | Stable Capacity Pool identity, immutable Supplier-capacity events, scheduled effectiveness, reconciliation, and rebuildable projections. |
| [0011](0011-supplier-cost-definitions-and-forecast-evaluation.md) | Accepted; implemented by shipped M3C | Exact-version Supplier cost sources, staged definitions, constrained components, planning assumptions, and deterministic forecast evaluation. |
| [0012](0012-arrangement-activation-reservations-and-confirmations.md) | Accepted; M3D is the implementing slice (shipped with M3D; requires shipped M3D.0) | Arrangement activation manifests, successor copying, Reservation history, confirmation evidence, and confirmation-triggered commitment openings. |
| [0013](0013-supplier-operational-commitments-deadlines-exposure-and-ending.md) | Accepted; implemented by shipped M3E (M3E.1–M3E.7b) | Source-shaped commitment openings and dispositions, Deposit Requirements, Deadlines, planning milestones, exposure, Needs attention, and Arrangement ending. |
| [0014](0014-client-offers-publication-and-supply-compatibility.md) | Accepted. M4A–M4C are shipped; M4D is Accepted; not implementation authority for M4E | Client Service Offer and Package identity, publication, Supplier-source compatibility, Sales enabled versus computed eligibility, and M5 Charge-posting handoff. [M4A](../planning/m4a-service-definitions-and-sources.md), [M4B](../planning/m4b-client-pricing-and-anonymous-preview.md), and [M4C](../planning/m4c-packages-choices-and-client-terms.md) are shipped. [M4D](../planning/m4d-publication-and-live-feasibility.md) is Accepted. Do not implement M4E until that slice's accepted plan names the work. |

An accepted ADR governs only its stated boundary. It does not place every described future model into implementation scope.
