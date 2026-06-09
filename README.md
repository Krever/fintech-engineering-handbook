# Fintech Engineering Handbook

Welcome to the Fintech Engineering Handbook. This resource aims to describe the most important patterns used in software
engineering, where money is the primary focus of the system. It can be read in full to get a comprehensive understanding
or in parts when dealing with a particular problem.

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

**Principles touched:** No lost data - the wrong representation silently drops precision that can never be recovered.

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

**Principles touched:** No lost data - residuals must be tracked, not dropped. No invented data - rounding must never
mint money that wasn't there.

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

**Principles touched:** No trust - validate currency against the controlled set at the boundary.
No invented data - treating distinct currencies/assets as interchangeable conjures value.

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

**Principles touched:** No lost data - record every relevant timestamp; collapsing them into a single `created_at` loses
information you can't reconstruct later.

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

**Principles touched:** No lost data - keep the amounts (and, for reference rates, a way back to the source). No trust -
there's no canonical rate, so the source should be part of the data.

### Double-entry bookkeeping

Double-entry bookkeeping is a widely used way to store financial transactions as a list of entries in the form of
`(credit account, debit account, amount)` (this is a compact form; the classic representation uses a separate debit
and credit row per movement). It ensures that money always comes from somewhere and always goes to somewhere. External
providers get dedicated accounts too, so money entering/leaving the system is still tracked. Because every entry moves the same amount
out of one account and into another, the books always balance - money is only moved, never created or destroyed.

In this methodology, balance is never stored directly, but derived from the movements of money.

Accounts are labeled as assets, liabilities or equity, so that the **accounting equation**
(`assets = liabilities + equity`) holds and each account has a defined side on which it increases.

A single transaction will usually create multiple movements, e.g. one accounting for the net amount, the other for the
fees.

By convention, posted entries are immutable - corrections are made with new compensating entries, never edits.

**Principles touched:** No invented data - money is only ever moved between accounts, never created or destroyed.

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

**Principles touched:** No trust - invariants are verified, not assumed; even your own code's output gets checked.
