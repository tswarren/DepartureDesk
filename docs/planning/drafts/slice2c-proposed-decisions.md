**Status:** Superseded by [M4D.1 Slice 2C](../m4d1-slice2c-cruise-service-connection.md). Historical decision notes. Not implementation authority.

I would lock the following decisions. One important change from my earlier draft: the rate-category key should follow the stable Client choice option, not the Supplier Resource.

| Decision                   | Recommendation                                                              | Why                                                                   |
| -------------------------- | --------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| “Decide later”             | Create or reuse one `undecided` Service Offer outline                       | Records progress and prevents duplicate services later                |
| New vs existing            | “Existing” means an editable same-Departure `undecided` outline             | Avoids destructively converting arbitrary M4 graphs                   |
| Published offers           | Read-only; require an existing successor workflow or Advanced               | Keeps 2C from becoming a lifecycle slice                              |
| Service granularity        | One Cruise Service per Cruise Arrangement Item                              | Cabin categories are choices, not separate services                   |
| Initial category selection | Preselect all supported typed cabin categories, but require explicit review | Matches the normal cruise contract while remaining deliberate         |
| Later categories           | Never add automatically                                                     | Supplier planning must not silently change Client choices             |
| Choice structure           | One `Cabin category` group, exactly one selection                           | Matches the actual Client decision                                    |
| Source topology            | One `choice_gated` binding per category; each option activates its binding  | Keeps selected Client choice and Supplier support aligned             |
| Rate key identity          | Generate from the stable choice-option UUID                                 | Preserves Client pricing if Supplier support is refreshed or replaced |
| Option price effect        | `NULL`, not zero                                                            | 2C does not know that categories have no price difference             |
| Editing                    | Preserve option and binding identities for retained categories              | M5 selections and later prices need durable references                |
| Category removal           | Block when prices or other downstream records depend on it                  | Avoids leaving unreachable pricing selectors                          |
| Unsupported graphs         | Readable summary plus Advanced link; no partial typed editing               | Prevents lossy reconstruction                                         |
| UI                         | Dedicated summary/editor page, closed by default                            | Avoids repeating the inline-form problems from 2B                     |
| Mutations                  | Separate atomic connect and update commands                                 | Creation/idempotency and graph editing have different risks           |

## Recommended detailed decisions

### 1. What does “Decide later” do?

Use `CreateServiceOfferOutline` to create one `undecided` Service Offer draft.

When Staff returns later, `ConnectCruiseServiceOffer` resolves that same outline instead of creating another offer. If an undecided outline already exists for this Cruise Item, offer to resume it rather than creating a second one.

This gives “Decide later” a durable meaning without fabricating Supplier support.

### 2. Which existing Service Offers can be connected?

The ordinary picker should include only offers that:

* belong to the same Agency and Departure;
* have an editable draft version;
* have `fulfillment_basis: undecided`;
* have no existing source-binding graph;
* have no existing choice topology that would be destroyed.

Existing Client text, terms, or unscoped draft pricing may remain, but the connection preview must disclose them. If choices or source bindings already exist, classify the offer as Advanced.

A Service Offer that already has a supported Cruise connection belongs in the Edit flow, not the Connect-existing picker.

### 3. Should all cabin categories connect automatically?

On first connection:

* show all categories recognized by `DetectCruiseArrangementShape`;
* select them by default;
* require Staff to review the selection before saving;
* permit deliberate deselection.

Afterward, new Supplier categories appear as “Available to add,” never as automatically connected choices.

This balances the ordinary expectation—all blocked categories are intended for sale—with the rule that M3 changes cannot silently rewrite M4.

### 4. What should identify the Client rate category?

Use a key derived from the stable choice option:

```text
cruise_cabin:<service_offer_choice_option_uuid>
```

This is better than deriving it from `SupplierResource` because the key belongs to the Client-pricing graph. Staff may later replace or refresh Supplier support while preserving the same Client choice and price category.

The option retains separate traceability through its activation:

```text
Choice option
├── client_rate_category_key
└── source activation → exact choice-gated Supplier binding
```

The key should be opaque in ordinary UI. Staff see `O1 — Prime Oceanview`, not the UUID-based selector.

### 5. Does an option get a zero price effect?

No. Persist `price_effect_minor_units: NULL`.

Zero would assert that choosing O1 has no incremental price effect. Slice 2C does not know that. Slice 2D will create category-scoped Client base prices using the option’s rate key.

A cabin option can therefore be structurally complete in 2C while pricing remains visibly pending.

### 6. How should edits work?

Do not use destructive replacement for the typed Cruise graph.

Match retained records by their existing stable association:

* option ↔ stable option identity;
* binding ↔ stable Supplier Resource;
* activation ↔ retained option and binding.

For retained categories:

* preserve option ID;
* preserve rate key;
* preserve binding ID when the exact source remains;
* update Client-visible category text only where the typed contract permits.

For an added category, create new records. For a removed category, destroy only its draft option, activation, and binding after checking dependencies.

### 7. What blocks category removal?

Block typed removal when the option or its rate key is referenced by:

* a Service Offer price component;
* a published manifest;
* a Package or later graph that freezes the version;
* any future Client selection record.

In 2C, the most immediate blocker is a price component using that rate key. Explain:

> Remove or retarget the Client price for O1 before removing this cabin choice.

Do not remove the option and leave an unreachable category-scoped price behind.

### 8. How should published connections behave?

Display them read-only.

Do not make 2C automatically create successor Service Offer drafts. If the shipped successor workflow already provides an appropriate action, link to it. Otherwise use Advanced handling and defer typed successor editing.

That keeps 2C focused on Stop E rather than reopening M4D lifecycle semantics.

### 9. Which command surfaces should be locked?

I recommend:

* `ConnectCruiseServiceOffer`

  * Creates a new Service Offer or resolves an eligible undecided outline.
  * Builds the full source/choice graph atomically.
  * Requires idempotency.

* `UpdateCruiseServiceConnection`

  * Adds/removes categories and updates Client-facing fields.
  * Preserves retained identities.
  * Uses optimistic locks.

* `DetectCruiseServiceConnectionShape`

  * Definition-scoped compatibility and exact reconstruction.

* `CompileCruiseServiceConnectionWorkspace`

  * Write-free UI model.

Use `CreateServiceOfferOutline` unchanged for Decide later.

### 10. What should the UI look like?

Use a dedicated Stop E page with two states:

* **Summary:** saved Service, connection status, Client choice sentence, and category cards.
* **Editor:** clearly titled Connect or Edit, with connection mode, Client-facing fields, categories, and a final review sentence.

Do not open the editor by default and do not place it inline among saved cards.

## Resulting locked scenario

For Celebrity:

* One Service Offer: `Celebrity Beyond — 7-Night Eastern Caribbean`
* One choice group: `Cabin category`
* Exactly one option required
* O1 option:

  * retains its stable option ID;
  * carries an option-derived Client rate key;
  * activates the exact O1 Supplier binding;
  * has no invented price effect;
* I1 and other selected categories follow the same shape
* Slice 2D later attaches Client prices to those durable option keys

That is the cleanest boundary: 2C defines what the Client can choose and where fulfillment comes from; 2D defines what those choices cost.
