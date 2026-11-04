# What is held, what a sale consumes, and what stays unsold

**Status:** Draft, 2026-10-14. The five sale judgments below were resolved 2026-10-15 from shipped Supplier plans. This draft is not implementation authority. It does not authorize M5, M6, Cruise summary Slice 4, a new inventory mode, or a calculation.

**Reads with:** the travel-type requirements reviewed the same day. Shipped Supplier plans remain the authority for facts they already record.

## The question

Before a booking reads supply, each sellable thing needs four answers.

| Question | What it decides |
| --- | --- |
| What is held | The supplier commitment that exists before anyone is sold a place |
| What one sale consumes | The unit a later allocation would count |
| What an unsold unit still costs | Whether an empty place is free, returned, or still owed |
| Where that answer lives | A number the system already keeps, wording on the agreement, or a fact that is not a record yet |

A remaining count is the full availability answer only when an unsold unit costs nothing further. Everywhere else, “short” is the wrong failure.

Shipped inventory modes stay `block`, `allotment`, `on_request`, and `externally_managed`. A pool counts `resource_units` or `traveler_positions`. This note does not add a mode for a courtesy hold, a contingent night, a meal, or an entitlement.

Agreement-reference wording is the supplier’s text. It is not an input to a remaining-capacity figure or an obligation.

Supplier cost and client price stay independent. Who receives a payment is a later routing fact.

## Resolved judgments

These five are decided. Each one restates a shipped plan. None of them starts a calculation.

**A contracted hotel block still costs money below the attrition minimum.** The Hilton walkthrough records a minimum on each contracted night, and a room released after cutoff stays inside that night’s minimum. The shortfall rate and tax are attrition wording. No attrition obligation is calculated, and a night cannot offset another night. A courtesy hold becomes a block only when the hotel commits rooms; the right to reclaim them stays wording. Extra nights are contingent terms with no opening pool until the hotel confirms them as their own inventory.

**A cruise sale consumes a cabin. Guest position is the fare.** A third or fourth guest changes the price and leaves the cabin count as it is. Reaching an option, release, or final-payment deadline does not release inventory and does not post money. Giving cabins back is a separate evidenced capacity disposition. A penalty for holding or dropping cabins stays agreement wording.

**A charter is priced per confirmed vehicle. A per-person transfer is priced per traveler.** Empty seats on a confirmed coach still cost the coach. Passenger capacity is the manifest limit. Another coach is on request until it is confirmed. A per-person shuttle does not leave the agency paying for places nobody took.

**An activity operating minimum and a billable floor are different facts.** Below the Island Sightseeing operating minimum, the supplier decides whether to operate. That minimum is not a guaranteed charge and is not a capacity-pool minimum. A billable floor, where a different agreement has one, means the empty places are still owed.

**A guaranteed meal, an issued ticket, and a concession are not “nothing left to sell.”** An included meal can have a zero client price and a supplier minimum that is still owed. An issued ticket that goes unused is a loss under the venue’s terms. A hotel concession or a cruise tour-conductor credit is earned at a threshold; missing the threshold brings that cost back, and the earned room or cabin is not subtracted from saleable inventory.

## Hotels

| Situation | What is held | What one sale consumes | What an unsold unit still costs | Where that answer lives |
| --- | --- | --- | --- | --- |
| Contracted block | Rooms by night and category | One room night. A person is assigned to that room later. | Down to the attrition minimum, the empty room still costs money. | The block’s opening quantity is a number. The minimum, the shortfall rate, and the tax are attrition wording. The shortfall is not calculated. |
| Courtesy block | Rooms the hotel may reclaim | A room night, once the hotel has committed it | After reclaim, usually nothing. Any penalty is the agreement’s text. | Record committed rooms as a block. The reclaim right stays wording. Courtesy is not its own inventory mode. |
| Allotment | A seasonal allocation | One room night drawn from that allocation | An unused allotment room is this departure’s cost only when the agreement gives it a floor. | Allotment is a shipped inventory mode. A seasonal floor stays wording until the agreement states one. |
| On request | Nothing until the hotel confirms one room | That confirmed room night | Nothing was held, so nothing unsold remains. | On request is a shipped mode. There is no remaining number. |
| Extra nights off the block | A promise to consider nights | Nothing, until a confirmed night exists as its own inventory | No cost until the hotel confirms the night. A confirmed addition is billed on its own. | Additional-night wording. Those nights are not leftover rooms on the contracted stay. |
| Complimentary room | A concession earned at a threshold | An assignment of a room the group earned | If the group misses the threshold, the agency picks up the cost of that room. | The threshold is wording. The room is not subtracted from saleable inventory. |

Guest folios are paid to the hotel. The agency’s group deposit is a different payment. A later refund of that deposit depends on the attrition shortfall. None of those are a remaining room count.

An unmatched share changes who pays the single supplement. It does not change how many rooms the block holds until someone actually takes a second room.

## Cruises

| Situation | What is held | What one sale consumes | What an unsold unit still costs | Where that answer lives |
| --- | --- | --- | --- | --- |
| Cabins by category | Cabins under the group contract | One cabin. Guest position is the fare. | Reaching the release deadline leaves the cabins held. Staff release them later, as its own evidenced capacity disposition. A penalty for holding or dropping them stays agreement wording. | Opening quantity is a number. The deadline is a number. Passing it does not release inventory or post money. |
| Tour conductor credit or amenity | A benefit earned at a threshold | The use of the credit, often the escort’s cabin | Below the threshold the credit is not earned, and that cabin’s cost returns to the agency. | The threshold is agreement wording. The credit is not a cabin subtracted from the group inventory. |
| Payment sent to the line | No inventory | No cabin | The agency may still be owed commission, or may owe the line. | Money routing. It does not change how many cabins are left. |

A third or fourth guest changes the fare. The cabin count changes only when a cabin is added or released.

## Air

| Situation | What is held | What one sale consumes | What an unsold unit still costs | Where that answer lives |
| --- | --- | --- | --- | --- |
| Individual booking | Nothing in the agency’s inventory | The traveler’s own ticket, when it is recorded | No unsold seat belongs to the agency. | A later record. Not a capacity pool. |
| Group seat block | Seats on a flight, later | One seat | The name and ticketing deadlines decide whether unsold seats are released or ticketed and paid. | Later. The consequence belongs to that contract. |
| Group move | Separate tickets toward one arrival window | Each booking on its own | The bookings are not one invoice and not one hold. | Later. |

For the current product, air matters because it places an arrival next to a transfer or an early hotel night.

## Motorcoach and transfers

| Situation | What is held | What one sale consumes | What an unsold unit still costs | Where that answer lives |
| --- | --- | --- | --- | --- |
| Charter | The vehicle, at a fixed price | A seat on the manifest | The empty seat still costs the charter. Cost per traveler at the current enrollment is a forecast. | The contracted rate is per confirmed coach. Seat capacity is the limit, not the cost unit. |
| Per-person shuttle | A headcount the operator will carry | One traveler | An unsold place is not bought. | A different price basis from the charter. |
| Private car | The car for one party | The car | The car is owed with empty seats in it. | The party is not a record yet. The hold is the car. |

Driver lodging, meals, and gratuities follow the charter. They are not divided by the riders who cancel.

## Excursions and activities

| Situation | What is held | What one sale consumes | What an unsold unit still costs | Where that answer lives |
| --- | --- | --- | --- | --- |
| Seats on a dated departure | Seats, with a minimum and a maximum | One traveler place | Below an operating minimum, the supplier may decide whether to run. That empty place is not a bill the agency has already promised. | The Island Sightseeing operating minimum is agreement terms. It is not a capacity-pool minimum and not a guaranteed charge. |
| Billable floor | Seats the agency must pay for even when empty | One traveler place | Each empty place down to the floor is still owed. | A financial minimum, where the agreement has one. It stays a different fact from the operating minimum. |
| Shore excursion | Seats that have to be back before the ship sails | One traveler place | The same two unsold outcomes as above. Missing the ship is a timing constraint, not a third kind of inventory. | The return against all-aboard is a later link to the cruise booking. |

A choice inside the activity, such as a lunch or a difficulty, consumes the same seat. It can change the price.

## Admissions and events

| Situation | What is held | What one sale consumes | What an unsold unit still costs | Where that answer lives |
| --- | --- | --- | --- | --- |
| Before purchase | Nothing, or a temporary hold if the venue gave one | Nothing yet | Nothing is owed. | General service until a plan gives tickets their own rules. |
| Issued ticket or named credential | The ticket | One ticket of a type | An unused issued ticket is usually a loss. Ticket type is the price. | The loss follows the venue’s terms. It is not a remaining-count failure. |

## Meals

| Situation | What is held | What one sale consumes | What an unsold unit still costs | Where that answer lives |
| --- | --- | --- | --- | --- |
| Guaranteed meal | A headcount at a date and time | One guest | The agency pays the minimum when fewer people attend. | The minimum is the cost fact. The client price of an included meal can be zero. The cost still belongs in the package margin. |
| Choice of meals | One commitment per meal that has a minimum | Exactly one choice for that traveler | Each chosen meal keeps its own minimum. A surcharge is the client price of the dearer choice. | The exactly-one rule is a choice. It is not a second inventory. |
| Closeout | The same meal | Nothing new | Attendance is the number who came. The bill is the number the venue charges. | Those two numbers stay separate. Closeout is not a record yet. |

Service charge and tax follow the agreement’s order. They are part of the meal’s cost, not a separate hold.

## Add-ons and entitlements

| Situation | What is held | What one sale consumes | What an unsold unit still costs | Where that answer lives |
| --- | --- | --- | --- | --- |
| Right to use | No seat at a clock time. A right attached to a booking, for a person, a day, or a cabin. | That right, on the price basis the supplier named | Cancelling the booking it depends on cancels the right. A cabin rule that makes every adult buy the same package can leave the right owed. | Eligibility is wording. An entitlement is not a capacity pool. |

Included in the supplier fare, included in the agency package, and bought extra are three sale paths for the same kind of right.

## Insurance, fees, and credits

| Situation | What is held | What one sale consumes | What an unsold unit still costs | Where that answer lives |
| --- | --- | --- | --- | --- |
| Insurance | Nothing | One policy for the travelers it covers | There is no empty unit. The agency’s risk is a missing signed decline, a purchase window that closes, or a trip cost that no longer matches the bookings. | Not capacity. Commission on the policy follows the same commission facts as any other supplier. |
| Agency fee, discount, or credit | Nothing | The financial item on the booking | A discount, credit, or write-off needs a reason and an approver. | A financial item. Not a service and not a pool. |

## Rail

Later. Four purchases can share one trip and stay separate: group seats, a chartered carriage, a pass, and a seat reservation that some operators require on top of a pass.

| Situation | What is held | What one sale consumes | What an unsold unit still costs |
| --- | --- | --- | --- |
| Group seats | Seats in a carriage | One seat | The agency may still pay for unused seats to keep the group terms. |
| Private carriage | The carriage, at a fixed price | A place in that carriage | The empty place still costs the charter. Same shape as a motorcoach. |
| Pass | The right to ride a network for a period | The pass for that traveler | An unused day on the pass is not a seat the agency can resell. |
| Seat reservation on a pass | A seat on a named train | That seat, and it depends on the pass | The reservation without the pass is not a usable place. |

## Rental cars

Later. The hold is a vehicle for a rental period. The travelers in the party do not say how many cars exist. One sale consumes the car for its driver or drivers. An unused day inside the rental period is still the rental. Coverage, drop fees, and mileage are terms on that car.

## Other services

These follow a pattern above until a workflow needs its own rules.

| Service | Pattern it follows |
| --- | --- |
| Tour director or escort | A cost the agency carries. The room or cabin funded by a hotel comp or a cruise credit is the concession row above. Missing the threshold brings that cost back. |
| Local guide | Chartered time, closer to a vehicle charter than to a per-seat sale. A minimum number of hours is a billable floor when the agreement says so. |
| Venue or meeting space | The room, plus a food-and-beverage minimum when the venue requires one. The minimum is a billable floor. |
| Ferry, equipment, parking | Either a held unit with a count, or an individual booking with nothing held ahead. The agreement says which. |

## What a later booking read may assume

A remaining-capacity answer covers the rows whose unsold unit costs nothing further: on request after confirmation, a per-person shuttle, a ticket not yet bought, and a cabin or room Staff have already released through an evidenced capacity disposition.

It does not cover a contracted hotel block, a charter, a guaranteed meal, a billable activity floor, an issued ticket, or a concession that disappears below a threshold. Those need the unsold consequence named before a booking treats “not enough left” as the only reason to stop.

M5 stays unauthorized. This draft records the dynamics. It does not build them.
