# fintech-engineering-handbook

Welcome to the Fintech Engineering Handbook. This resource aims to describe the most important patterns used in software
engineering, where money is the primary focus of the system. It can be read in full to get a comprehensive understanding
or in parts when dealing with a particular problem.

It's meant as a living document and contributions are welcomed.

## Principles

Everything you will read below is a way to adhere to the three principles:

1. No invented data - Money can't be created out of nowhere, hence we can't tolerate duplicates or arbitrary balance
   updates.
2. No lost data - Everything that happens to money has to be tracked and persisted: no precision losses, at-least-once
   deliveries, event-sourcing, audit trails, immutability.
3. No trust - Neither towards external providers, internal components nor the world. Failing on broken assumptions,
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
