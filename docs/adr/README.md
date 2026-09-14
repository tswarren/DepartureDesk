# Architecture decision records

ADRs preserve decisions and their history. Superseded ADRs remain here rather than moving to the general documentation archive.

| ADR | Status | Governs |
| --- | --- | --- |
| [0001](0001-money-and-currency.md) | Accepted | Money values, minor-unit persistence, currency, parsing, and conversion boundaries. |
| [0002](0002-agency-tenancy-and-membership.md) | Superseded by 0005 | Previous global User and agency-membership tenancy. |
| [0003](0003-membership-lifecycle-and-invitations.md) | Superseded by 0005 | Previous membership invitation and lifecycle model. |
| [0004](0004-human-readable-references.md) | Accepted | Internal UUID identity and domain-qualified human references. |
| [0005](0005-agency-identity.md) | Accepted and implemented | Agency-scoped AgencyUser identity, authentication, Office context, and permissions. |
| [0006](0006-separate-identity-domains.md) | Accepted product boundary; implementation deferred | Separate Agency User, Client, Supplier, and Traveler identity contexts. |

An accepted ADR governs only its stated boundary. It does not place every described future model into implementation scope.
