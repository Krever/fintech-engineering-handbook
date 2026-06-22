# Fintech Engineering Handbook

Welcome to the Fintech Engineering Handbook. This resource aims to describe the most important patterns used in software
engineering, where money is the primary focus of the system. It can be read in full to get a comprehensive understanding
or in parts when dealing with a particular problem.

### Fow whom?

- **People joining fintech** - to get familiar with the domain and the patterns that make money systems trustworthy.
- **People already in fintech** - as a reference to reach for when facing a particular problem, and a shared vocabulary
  to point colleagues at.
- **People outside fintech** - to understand how building for money differs from what they're used to, and why.

It's meant as a living document and contributions are welcomed.

## Principles

Everything you will read below is a way to adhere to the three principles:

1. **No invented data** - Money can't be created out of nowhere, hence we can't tolerate duplicates or arbitrary balance
   updates.
2. **No lost data** - Everything that happens to money has to be tracked and persisted: no precision losses,
   at-least-once
   deliveries, event-sourcing, audit trails, immutability.
3. **No trust** - Neither towards external providers, internal components nor the world. Failing on broken assumptions,
   verifying webhooks, verifying data across different sources.

## Guidelines

### Precision handling

Money representation is one of the most fundamental decisions in financial systems. There are four primary ways to do
it:

1. Floating-point precision - Using built-in float or double types. This can create unpredictable precision losses and
   is almost never a good idea. But it's the fastest and most memory efficient, and requires no additional libraries or
   data structures.
2. Arbitrary precision - Types like Java's `BigDecimal` let you control the precision of a computation precisely. This
   way the code is predictable and we get to decide where and how rounding happens. It fits intermediate work like FX or
   pricing math, where many operations chain together.
3. Minor-units precision - For most fiat currencies it's ok to keep only a fixed precision, the same that is used in the
   connected central banking system. The number of digits is described by ISO 4217 (don't assume it's always 2, it's
   not!). In practice this means storing the amount as an integer in its smallest unit - €12.34 becomes `1234`. This
   approach is usually good enough for fiat currencies but doesn't work for crypto.
4. Rational numbers - when no precision loss is acceptable, we can use rational numbers. This is the most powerful
   approach but comes with its own caveats. First, it's slower than the alternatives. Second, it cannot be converted to
   other formats without losing precision. Third, it usually requires a custom datatype or a library.

Selecting one or the other depends on the class of the system and its responsibilities. There is no rule of thumb here,
other than not using floating points. These representations are not mutually exclusive either - how you store an amount
and how you compute with it are separate decisions, and a system often combines them, e.g. integer storage with
`BigDecimal` for intermediate computation.

**Principles touched:**

- **No lost data** - the wrong representation silently drops precision that can never be recovered.

### Rounding strategies

1. Rounding is inevitable and it should be done explicitly. Any division, currency conversion, fee, interest or rate
   application, or move between precisions might require rounding.
2. Different rounding strategies have different implications. Sometimes you have to be conservative (e.g. not to spend
   what you don't have) and round down. Sometimes you might care about statistical effects and use half-even. This is
   usually a business decision, not a technical one - deciding who gets the fraction might have legal/tax implications.
3. Round as seldom as possible. The longer you keep full precision, the more options you have to make the right decision
   in the right context. Rounding should usually happen on boundaries, e.g. before numbers are persisted or before they
   are shown to the user.
4. Rounding breaks sums. If a number is split into parts and rounding is applied, the sum of the parts might no longer
   equal the original number. Depending on the context, this might require explicit handling - e.g. explicit rounding
   account.

**Principles touched:**

- **No lost data** - residuals must be tracked, not dropped.
- **No invented data** - rounding must never mint money that wasn't there.

### Currency handling

Money can't be represented as a number alone - it comes paired with a currency. There are a few nuances when it comes
to handling currencies.

1. Packing currency and amount into a `Money` newtype (struct, class, record etc.) minimizes the chance of errors.
2. No cross-currency arithmetic is allowed. Your system should prohibit adding two amounts in different currencies.
   Conversion should happen very explicitly with a strictly controlled rate.
3. Use a controlled currency set: a custom config entry, JDK database, dedicated service. Never accept arbitrary
   currency codes, validate at the boundaries of the system.
4. Currency codes are unique and usable as identifiers only for fiat. For crypto currencies you will have to use a more
   complicated approach like `(network, contract address)` or similar.
5. Currencies come with metadata: symbol, precision, name, etc. You will usually need those details for display purposes
   but rarely for business logic.
6. Pegged, bridged and wrapped crypto currencies are not equivalent to the underlying ones.

**Principles touched:**

- **No trust** - validate currency against the controlled set at the boundary.
- **No invented data** - treating distinct currencies/assets as interchangeable conjures value.

### Value time vs booking time vs settlement time

Transactions will usually have at least two, sometimes three timestamps associated:

1. Value time - time when transaction occurred
2. Booking time - time when transaction was recorded in the system.

Those two timestamps will almost always diverge. When booking time > value time, we have a backdated transaction.
Technically, almost all transactions are backdated, but this term is most impactful when booking and value time fall
under different reporting periods, e.g. days, months, years.

When booking time < value time, we have a forward-dated transaction. This is less frequent but can happen e.g. with
scheduled or future-dated payments - a standing order recorded today but effective next week.

Additionally, some transactions might have a third timestamp: settlement time. This is the time when money was actually
transferred or materialized. Usually settlement time is expressed as T+X, where X is the number of days after which
settlement happens, e.g. T+2 means settlement happens 2 days after value.

Example: A card payment happened at T1 (value time), you recorded it at T2 (booking time), but the payment provider
transferred money to your account at T3 (settlement time).

Business and business-consumed reports usually care about value or settlement time while
booking time is useful for traceability.

**Principles touched:**

- **No lost data** - record every relevant timestamp; collapsing them into a single `created_at` loses information you
  can't reconstruct later.

### FX Rates

FX (Forex, foreign exchange currency market) rates allow us to convert money between currencies.

1. A rate is always directional. The EUR/USD rate is not the same thing as the inverted USD/EUR rate. On an exchange,
   buying and selling are two different orders at different prices (the bid/ask spread), so the two directions don't
   simply invert.
2. The time of the rate is critical. While you can technically use a rate from any point in time, the most commonly used
   are:
    - Current-time rate - e.g. to calculate current holdings or the value of a transaction as if it happened right now.
    - Value-date rate - e.g. to calculate change in value or a tax amount.
3. Two kinds of rate matter for conversion:
    1. A transactional rate is the rate a real conversion happened at. You don't store it directly - it falls out of the
       original and result amounts.
    2. A reference rate (mid-market or central bank) is one used for valuation and equivalence -
       what holdings are worth right now, or a tax base at the value date - and is not a price anyone actually trades
       at.
4. There is no such thing as a canonical rate. Rates come from markets and vary between venues or calculation methods.
   The closest to canonical are central bank rates, which can be used only as a reference rate and even there we can
   have alternative sources which are just as valid.

**Principles touched:**

- **No lost data** - keep the amounts (and, for reference rates, a way back to the source).
- **No trust** - there's no canonical rate, so the source should be part of the data.

### Double-entry bookkeeping

Double-entry bookkeeping is a widely used way to store financial transactions as a list of entries in the form of
`(credit account, debit account, amount)` (this is a compact form; the classic representation uses a separate debit
and credit row per movement). It ensures that money always comes from somewhere and always goes to somewhere. External
providers get dedicated accounts too, so money entering/leaving the system is still tracked. Because every entry moves
the same amount
out of one account and into another, the books always balance - money is only moved, never created or destroyed.

In this methodology, balance is never stored directly, but derived from the movements of money.

Accounts are labeled as assets, liabilities or equity, so that the **accounting equation**
(`assets = liabilities + equity`) holds and each account has a defined side on which it increases.

A single transaction will usually create multiple movements, e.g. one accounting for the net amount, the other for the
fees.

By convention, posted entries are immutable - corrections are made with new compensating entries, never edits.

**Principles touched:**

- **No invented data** - money is only ever moved between accounts, never created or destroyed.

### Invariants

In any system there exist special properties that must always hold - we call them invariants. One such invariant is
the accounting equation mentioned above. Your business stakeholders might define many such conditions that then have to
be enforced.

There are 3 primary ways to enforce invariants:

1. **By construction** - make sure that the system allows creating only valid objects, so invalid states are
   unrepresentable. This can be done through a variety of techniques: factory methods (smart constructors), type-level
   programming (e.g. refined types), database constraints.
2. **Runtime checks** - check that invariants hold when executing logic. This can be assertions in production code or
   tests - property-based testing shines here (e.g. "for any sequence of postings, the books balance").
3. **Post-factum** - analyse the data persisted by the system looking for any violations, e.g. reconciliation jobs or
   nightly checks that ledger balances still satisfy the accounting equation.

What's important: those methods are complementary and you will usually use all of them side by side to achieve the
desired level of trust. By construction is the strongest but cannot express everything (especially cross-aggregate or
cross-system invariants), runtime checks catch violations at the point of occurrence, and post-factum is the only one
that catches bugs that already shipped - but catches them late.

**Principles touched:**

- **No trust** - invariants are verified, not assumed; even your own code's output gets checked.

### Funds reservation

In most cases your transactions will require interaction with the external world. For example, you might need to
run compliance checks before allowing a user to withdraw funds, or you need to register the withdrawal in an external
system.

In such cases you also have to avoid race conditions - spending the same money twice, or discovering "insufficient
balance" only after the external world interaction already happened.

To address this, systems implement funds reservation (also known as hold-and-release), where funds are first reserved
for a particular transaction before the external interaction starts. Once it completes, the reservation is settled and
the transaction proceeds; if anything goes wrong, the reservation is released and the funds return to the available
balance.

This pattern introduces a distinction between two balances: the **total balance** (everything the user owns, including
reserved funds) and the **available balance** (`available = total - reserved`). Balance checks and new reservations are
made against the available balance, which is what prevents the same funds from backing two transactions.

A few practical notes:

1. The final amount is not always known upfront - fees or rates may differ from the estimate. In that case you reserve
   the estimated amount, settle the actual one and release the remainder.
2. A reservation that's never settled nor released locks user funds, so every flow that creates one must guarantee it
   eventually resolves it. An explicit expiry/timeout can serve as a safety net, but it's optional - you can rely on
   internal system discipline instead. Notably, the failure mode is conservative: an orphaned reservation locks money,
   it never loses or creates it.

**Principles touched:**

- **No invented data** - the same funds can never back two transactions; a reservation makes this explicit instead of
  relying on a racy balance check.

### Handling overdrafts

An overdraft happens when an account balance goes negative. Overdrafts come in two kinds:

1. Intentional - an overdraft is a credit product the business explicitly offers, with limits and interest. This is a
   business feature, not an anomaly, and is mostly out of scope here. This will most likely be modeled as a separate
   overdraft account (liability for the user, receivable for the operator) with a positive balance.
2. Unintentional - the balance goes negative even though policy forbids it.

Unintentional overdrafts happen even in correct systems, because the external world doesn't ask for permission: a
settlement comes in higher than the reserved estimate or a reversal lands after the funds already left. Funds
reservation reduces the window for overdrafts but cannot eliminate it.

**Forbidden is not the same as unrepresentable**. It's tempting to encode
"balance is never negative" at the type or storage level as an unsigned integer or a `CHECK (balance >= 0)` constraint.
But when we are forced to accept a negative balance, a system that cannot represent it will either crash mid-flow,
silently
clamp the balance to zero (inventing money), or do something similarly wrong.

Put differently, "balance >= 0" is just an invariant and the usual toolbox applies: enforce it at runtime when
authorizing transactions, detect violations post-factum with monitoring and reconciliation - but don't force it by
construction. When an overdraft is detected, it's a signal to investigate but not necessarily a bug.

When an overdraft does happen, we have to book it and recover explicitly, e.g. by netting it against future deposits,
requesting repayment, or writing it off - as an explicit compensating entry to an expense/loss account, never by
editing the balance.

**Principles touched:**

- **No invented data** - clamping a negative balance to zero mints money.
- **No trust** - the external world can force an overdraft no matter what your checks say.

### Audits and audit trails

Financial systems are subject to regulatory scrutiny in the form of various audits. Some of the things that might be
verified during an audit:

* are company funds not commingled with user funds or used for company expenses?
* are all revenues registered, reported and explainable? E.g. can you pinpoint the transactions that contributed to a
  particular revenue stream in a particular period?
* is the information provided to the external world (e.g. users or the tax office) matching reality? E.g. does the
  company hold as much in assets as it owes its users?
* are the funds protected against external threats? (e.g. who can access the funds and how)

To answer those and many other questions, financial systems have to keep track of not only the current state but the
full history of how that state came to be. This history is the **audit trail**: a record of everything that happened,
detailed enough that any balance, report or decision can be explained and reproduced from it.

A useful audit trail captures, for every change: what happened, when (see value time vs booking time), who or what
triggered it (a user, an operator, an automated job), and why (a reference to the order, instruction or incident that
caused it). Money movements are the obvious subject, but manual interventions, configuration changes (fee schedules,
rate sources, limits) and permission changes need trails too.

**Principles touched:**

- **No lost data** - current state alone can't answer an audit's questions; only the full history can.

#### Event sourcing

Event sourcing is probably the most principled and systemic approach to building an audit trail. In ES, instead of
storing current state with a log next to it, you
store only the events and derive state from them. The double-entry ledger is an example of this pattern applied to
money -
balance is never stored, it is calculated from the stored entries. With this approach the trail is a primary
artifact
and cannot drift away from reality.

A few practical notes:

1. You don't need full event sourcing everywhere. The ledger already covers money; for surrounding domains a
   conventional model with a reliable change log may be enough.
2. Derived state (balances, projections) can be cached or snapshotted for performance.
3. Building the projections is work intensive, and you might need a lot of them. You cannot effectively query your
   primary data set (events) for anything, so you need to build dedicated or generic projections to look into your data.
4. Events live for years, so plan for schema evolution: today's code must still read events written long ago.

In other words: event sourcing is a very good solution when an audit trail is required, but it comes with a very high
price in terms of system complexity.

**Principles touched:**

- **No lost data** - when state is derived from events, the trail can't drift out of sync with reality because it *is*
  the source of truth.

#### Immutability

An audit trail that can be edited proves nothing, hence records can never be updated or deleted. Our log must be
append-only, and every correction should be a new record (see below).

Immutability is an invariant, and the usual toolbox applies:

1. By construction - append-only tables, revoking `UPDATE`/`DELETE` at the database-permission level.
2. Runtime checks - the application layer exposes no mutating operations on posted records.
3. Post-factum - tamper evidence: checksums or hash chains over the records, periodically verified, so that any
   after-the-fact modification is detectable.

When building a real system bugs are unavoidable and might require you to fix the event log/audit trail. In those cases
it's sometimes easier to update the trail in place instead of keeping it strictly immutable. To balance those two
worlds it's important to understand your reporting schedule and obligations - usually data has to be kept in stone only
once it has been reported, e.g. when the financial statement has been shared at the end of the month. Until then you
might still be able to modify your data in place, if you detect the problem and fix it before it leaves your system.

**Principles touched:**

- **No trust** - an editable history proves nothing; immutability and tamper evidence make the trail trustworthy to an
  outsider, including yourself investigating an incident.

#### Reversals and corrections

Mistakes still happen, for example a wrong amount gets posted or a transaction lands on the wrong account. Immutability
means fixing forward - post a new compensating entry and link it to the
record it corrects, in both directions.

1. A **reversal** negates the original in full, as if it never happened economically - but it stays visible in the
   history, together with the original.
2. A **correction** (adjustment) books the difference between what was recorded and what should have been, or reverses
   and re-posts with the right values.
3. Corrections often land in a different reporting period than the original (see value time vs booking time) - the
   linkage is what lets reports attribute them correctly and distinguish real activity from cleanup.

The last point is particularly important - when posting corrections/reversals you will need to decide whether to
backdate the event
(specify a value time in the past) or not. Here a lot depends on the reporting schedule again - usually you won't be
allowed to backdate anything to an already closed period, because it was already reported to the external world.

**Principles touched:**

- **No invented data** - mistakes are fixed by posting linked compensating entries, never by editing or deleting what
  was already recorded.

#### Immutability vs GDPR

GDPR's right to erasure appears to contradict an immutable ledger. In practice it's quite easy to make it a non-problem:

1. Financial records are largely exempt - legal retention obligations (accounting law, AML, typically 5-10 years) take
   precedence over erasure requests for transactional data. You don't delete postings in that timeframe.
2. The exemption covers what you are obliged to keep, not everything you'd like to keep. Separate personal data from
   financial data so that the immutable ledger references users only by opaque internal identifiers, while PII (names,
   addresses, documents) lives in a separate, mutable store that can be redacted or erased independently.
3. Where personal data must be embedded in immutable records (e.g. event payloads), **crypto-shredding** works: encrypt
   each user's personal fields with a per-user key and erase by deleting the key. Erasure becomes a key deletion, not a
   rewrite of history.

**Principles touched:**

- **No lost data** - separating PII from financial data lets you honor erasure without losing the financial history
  you're obliged to keep.

## External world

Interacting with the external world - whether in the form of 3rd party providers (payments, KYC, AML, banks,
custodians, etc.) or internal services - is unavoidable. Our job is to build a system that stays correct regardless of
how unreliable those dependencies become.

### Idempotency

In a distributed system it's impossible to guarantee exactly-once delivery - any call can be interrupted and we won't
know whether it reached the other side or not. To make sure a message is delivered, we have to retry every such call.
But in doing so we risk delivering it more than once, hence its processing needs to be idempotent - the same message
delivered twice must trigger the processing only once.

1. Idempotency keys vs business-derived idempotency (e.g. deduplicating on the payload). An explicit key is usually the
   simpler and better solution - deriving it from the data is fragile, e.g. it's hard to tell whether two transactions
   with the same amount are a duplicate or two genuine operations. When using idempotency keys make sure they are scoped
   to a particular operation and client.
2. Idempotency on errors - when a call failed the first time, should a retry re-raise the stored error or re-trigger the
   processing? It's usually simpler and easier to reason about when we treat the error as the idempotent result and
   replay it. The client can always retry with a new key. A lot depends on the nature of errors - permanent ones (e.g.
   validation) should be replayed as-is while temporary ones (e.g. network failure) might be reprocessed.
3. Validating the payload for a repeated key - it's good practice to ensure a repeated call carries the same payload as
   the original. In practice this gets costly and buys only a little extra confidence, at the cost of a more complex
   implementation and less flexibility (the caller might change the request for a good reason).
4. Building reliable idempotency at scale can be a complex endeavour - make sure to dedicate enough effort to it. Not
   only might you need to deduplicate billions of requests,
   but you also have to get the behavior right under concurrent access (e.g. two duplicate calls arriving in the same
   millisecond). Your idempotency barrier has to be atomic.
5. You might be tempted to rely on an idempotency time window - e.g. dedupe only within 24h. This significantly
   simplifies the implementation (otherwise the data volume grows forever) but at the cost of correctness. Make this
   tradeoff only if you absolutely have to,
   because it will haunt you later.
6. It's good practice to test for retries. One of the better approaches is to bake a generic middleware into your
   integration or system tests that automatically repeats every call.
7. Make sure you handle out-of-order retries. Your system needs to stay idempotent even if it already moved to a new
   state - e.g. keep putting the funds on hold idempotent even if they were already released.

Idempotency matters on both sides - when you make calls and when you receive them. Keep it in mind every time you
consume or expose an operation.

**Principles touched:**

- **No invented data** - retries are unavoidable, so processing must collapse duplicate deliveries into a single effect
  instead of moving money twice.

### Handling webhooks

Webhooks are the most common way to receive signals from external systems, but processing them safely is not trivial.
While we focus here on webhooks (HTTP endpoints you expose, called by an external system with a payload defined by that
system) many of the points apply to other transport methods as well.

1. Don't assume ordering of events - messages can arrive out of order or carry stale data, so the last webhook you
   received is not necessarily the latest truth. Don't blindly overwrite your state with whatever just arrived;
   reconcile
   it against what you already know (e.g. by querying the API for the current state).
2. Don't assume validity of data - webhooks might come from a secondary part of the issuer's system and carry stale or
   improperly transformed data. A good practice is to ignore the content of the webhook and use it only as a trigger to
   query the API for the authoritative state. Beware that the API can be eventually consistent and lag behind the
   webhook, so a query right after the trigger may still return the old state - be ready to retry.
3. Don't assume delivery - webhooks will get lost sooner or later, regardless of how strong a re-delivery policy the
   issuer promises. You have to be prepared to handle a missing webhook, which usually means an independent process that
   fixes the completeness of your data. See reconciliation.
4. Don't assume single delivery - the same webhook will be delivered more than once. Processing must be idempotent. See
   idempotency.
5. Acknowledge fast, process asynchronously - return a 2xx as soon as you've durably stored the raw event, and do the
   real
   work asynchronously. If you process inline and are slow, the issuer can time out and retry, multiplying your load.
6. Persist the raw payload - store what you received verbatim before acting on it. It will not only make processing more
   reliable but will also act as your audit trail of what the provider actually said. It also lets you reprocess the
   message after a bug without asking the provider to resend.
7. Verify the caller - the usual mechanism is for the issuer to attach a signature of the payload, generated with an
   asymmetric key whose public half is published, so you can verify the message really came from them. One caveat:
   verify the signature over the *raw bytes* you received, not a re-serialized payload (re-serialization changes bytes
   and breaks the signature). Even with this, prefer not to trust the content (see point 2).

There is a recurring theme here: don't trust the webhook. Treat it as a hint that *something*
happened, not as a reliable, ordered, authentic statement of *what* happened.

**Principles touched:**

- **No trust** - a webhook is an unauthenticated, unordered, possibly-lost, possibly-duplicated hint; verify the source
  and confirm the actual state against the API.
- **No lost data** - persist the raw event and back delivery up with reconciliation so a dropped webhook doesn't mean a
  dropped fact.

### Consuming APIs

Sooner or later you will have to call someone else's API, e.g. a payment provider, a custodian, a blockchain node or a
KYC vendor. You don't control its code, its quality or its uptime, so the safe default is to assume it will misbehave
and to build defensively around it.

1. Don't trust the schema. The response will not always match the contract you were given - fields can go missing, types
   can change, nulls can appear where they shouldn't. Validate the important pieces at the boundary and fail loudly on
   anything you didn't expect, so malformed data cannot leak into the system. At the same time, never validate the
   pieces you don't need, as it might cause unnecessary outages when a third party breaks its contract. And they will.
2. Be ready for all kinds of weirdness and imperfect engineering. Everything you consider a questionable engineering
   practice will rear its head given enough time: tokens passed in URLs, lost precision, HTTP codes that don't mean what
   they should (a `200` carrying an error body), inconsistent pagination, custom date formats - all of this is normal
   when integrating with the outside world. Don't get frustrated by it; treat it as the job rather than the exception.
3. All calls will fail at some point. Design the system so that it can handle a lack of response. Retries and timeouts
   are necessary protection.
4. Circuit breakers are usually optional. They are mostly a courtesy toward an overloaded server, paid for by you with
   added complexity on the client side. It's reasonable to expect the server to handle its own load and drop requests it
   can't serve. That being said, a circuit breaker also protects your latency and finite resources (threads,
   connections, etc.), so employ one when it's really needed.
5. Mind the quotas. Rate limits and usage quotas are easy to forget but can be a source of nasty weekend outages. It's
   good to do a bit of napkin math up front (expected call volume against the provider's limits) so you find out before
   it causes a problem.
6. Store every request and response. It might sound excessive, but it can be a lifesaver during an investigation when an
   external API starts returning something it never should. Persist what you sent and what came back, in a structured,
   queryable form (e.g. a Redshift table). This will also be your audit trail and evidence when the provider's behavior
   is disputed, and your material for reprocessing after a bug.
7. Aim for provider redundancy for the most critical parts. You can never fully trust the provider, so when the stakes
   are highest, consider using more than one for the same purpose. This can mean validating the data against multiple
   sources (e.g. two blockchain nodes) or having a backup bank partner, crypto custodian or KYC vendor. This approach is
   extremely expensive (development, fees and complexity-wise) but might be necessary to achieve the desired level of
   reliability.
8. Don't expect too much from the testing environment. If a provider gives you testing/sandbox access, that's already a
   good sign. Those environments are fine for basic scenarios but will usually diverge very significantly from the
   production setup. Be prepared to test in production (e.g. through canary releases and controlled usage with small
   impact).

**Principles touched:**

- **No trust** - the provider's code, schema and uptime are all outside your control, so verify facts against
  independent sources and validate everything at the boundary.
- **No lost data** - persisting every request and response keeps a record you can reconcile against and reprocess from.

### Reconciliation

Any system that relies on external data is prone to data drift - a situation where one system doesn't match the other.
For example, you might miss a webhook, or a transaction might be posted to the ledger but not reflected in the external
provider's system. In all such cases we need reconciliation: a process that aligns the two systems. While we say "two",
in practice it can be more than that, e.g. ledger, payment processor and the bank, but this doesn't change anything in
how to approach the problem.

1. Cadence - depending on the exact context and constraints, reconciliation might be done hourly, daily, monthly or even
   yearly.
2. Nature of drift - data can be missing (which is an easy case) or different (e.g. the same transaction with different
   amounts, which is much more complicated to solve). Timing also matters a lot: if settlements happen at T+3, records
   will stay unreconciled for 3 days - that logic should be incorporated into the process so that we don't alert on
   those cases.
3. Matching algorithm - knowing what to compare between the two systems is the hard part. Usually you want to persist
   the external provider id within your system so that matching is straightforward. If this is not the case, heuristic
   algorithms enter the game (e.g. matching by amount and time).
4. One-to-many - in some cases you will have to reconcile multiple records on one side with one on the other, e.g.
   a single settlement transfer might cover a couple of transactions.
5. Aligning is not trivial - it goes without saying we can't simply overwrite the data to make the reconciliation happy.
   Each discrepancy found should be understood and fixed through first-class support, e.g. a correction record,
   reprocessing of webhook data etc.

**Principles touched:**

- **No trust** - reconciliation is how we verify across independent sources instead of believing any single one is
  right.
- **No lost data** - it's the safety net that catches the dropped fact - the missing webhook, the unsettled transfer -
  before it disappears for good.