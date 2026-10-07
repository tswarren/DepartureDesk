# Cruise activation review

**Status:** Shipped 2026-10-06. Authority for confirming displayed Cruise inventory and contracted rates during activation. Not authority for Hotel, Transportation, Activity, inventory-mode changes, unpriced on-request categories, or document storage.

**Amends:** [ADR 0012](../../adr/0012-arrangement-activation-reservations-and-confirmations.md) for this Cruise confirmation path, [ADR 0010](../../adr/0010-supplier-capacity-ledger-and-projection.md) for opening-evidence date and note origins, and the activation boundary in [Cruise contracted-rate readiness](cruise-contracted-rate-readiness.md).

## Outcome

Staff save sailing details, cabin inventory, and contracted rates. **Confirm and activate group** shows those facts together, takes Supplier proof once, and records the contract reviews and numeric opening authority in the same transaction as activation.

The records stay separate. Staff do not perform separate confirmation actions to create them. An existing current contract review or existing opening evidence is kept. A review whose fingerprint no longer matches the displayed terms is stamped again from this confirmation.

## What activation records

The acknowledgement authorizes those records. The command validates it. A direct POST without it writes nothing.

| Fact | Activation |
| --- | --- |
| Contracted rates | The same structural validation as contract review, without forecast assumptions. A passing contracted definition is stamped. A working definition that fails that validation stays a blocker. |
| Numeric opening inventory | Opening authority for each displayed positive quantity that does not already have it, using the supplied proof. |
| Supplier confirmation | A new exact-version confirmation, or reuse of a compatible one. |
| Cruise agreement | Unchanged. The confirmed group number and contract date are still required first. |
| Forecast | Optional. |

Missing or invalid substantive facts stay blockers: no usable contracted rate, invalid components, no numeric quantity, or no confirmed group number and contract date.

## Supplier proof

Proof type is required for new proof. “Other” requires its description. Proof date, channel, and notes are optional. A blank date is stored blank and is not copied from the activation timestamp. A blank Supplier reference does not require an absence explanation. When a reference is present, it is stored as a `group_number` issued by the contracting Supplier. The confirmed group number prefills that reference on the first visit. A cleared reference stays cleared after a validation or duplicate-review interruption.

This relaxation is a policy of the Cruise activation command. It is not a request parameter. Generic activation, reservation confirmation, and Hotel, Transportation, and Activity confirmation stay strict. A relaxed confirmation may be reused only by this Cruise command for that same exact version.

## Opening authority

Supplier confirmation proof types and capacity evidence kinds are the same six values, including “Other.” The mapping is that identity. Every offered proof type can establish opening authority. An unmapped kind is invalid proof and does not force administrator override.

The Supplier confirmation remains the original proof, including an “Other” description. Opening authority records the mapped kind and keeps that confirmation as its context.

A supplied proof date is a Staff-supplied evidence date. When the proof date is blank, the agreement contract date may be stored only with origin `agreement_contract_date`. History must show that origin. Supplier reference or notes are Supplier wording. When both are blank, “Confirmed during activation of this version” is stored with origin `activation_attestation`. History must show that origin.

Administrator override remains the alternative when that proof should not establish numeric opening authority. It is limited to `override_supplier_planning_terms`, names the pool, and cannot bypass a missing quantity, a missing contracted rate, or an unconfirmed agreement.

## Overview

Cabin inventory is complete when every numeric category has a positive opening quantity. Supplier rates are complete when every cabin passes the structural validation, whether or not it is already contract-reviewed. Review & activate is ready when this form can confirm the displayed facts. A structurally incomplete contracted rate keeps the overview and the activation review on “Needs attention.”

## Command

One command locks the exact version, checks idempotent replay before draft-only validation, then records the reviews, the opening authority, and the activation. The fingerprint is the submitted version, lock versions, acknowledgement, confirmation choice, proof fields, and override map. It does not include a recalculated list of definitions that currently need review. Duplicate review, a stale version, invalid proof, or activation failure rolls back every stamp, authority, override, and audit.
