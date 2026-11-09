# Background jobs

Moved from [AGENTS.md](../../AGENTS.md), which points here. Active Job, Solid Queue and the scheduled sweeps. These rules are binding when a task touches this area.

- Use Active Job with Solid Queue.
- Jobs must be idempotent or guarded by durable idempotency keys when duplicate execution would cause harm.
- Pass record identifiers, not full Active Record objects or sensitive payloads.
- Re-load and authorize/scoped records inside the job. Never depend on `Current`.
- Define retry/discard behavior intentionally for supplier APIs, mail delivery, and financial workflows.
- Never rely on an in-memory job adapter for behavior that must survive a process restart.
- The second scheduled job is the supplier amounts sweep (`PostDueSupplierAmountsJob`, queue `supplier_money`): it enqueues one child per confirmed arrangement with schedule lines, which posts as the system (`supplier_money.post_amounts_due`); posting is idempotent through the one-amount-per-shell-per-line index. The first scheduled domain job is the M2B departed sweep. It reads the primary database and enqueues into the separate queue database with no spanning transaction. Delivery is at least once. Child jobs call `MarkDepartureDeparted` with `actor_kind: :system` and identifier `departures.mark_departed` only. Retry deadlock, serialization failure, and lock wait timeout at most five times, then fail visibly. Do not write a domain `AuditEvent` for job infrastructure failures. Queue name: `departures`.
