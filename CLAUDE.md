# otrexin-tracker — project rules

## What this is
Settlement accounting for a leased owner-operator at Kaplan Trucking.
Pay structure: 76% of gross linehaul, 100% of fuel surcharge, accessorials at
mixed rates stated per line. These numbers file taxes and support chargeback
disputes. Wrong numbers have financial and legal consequences.

## Money
- Money is `BigDecimal`. Never Float. Use `.to_d`, never `.to_f`.
- New money columns: `precision: 12, scale: 2, null: false` with a default.
- Money assertions are exact: `assert_equal 3_686.00.to_d, x`. Never
  `assert_in_delta` on money. If a money test needs a tolerance, the code is wrong.

## Test integrity — non-negotiable
Tests encode what the settlement PDF says. Code is what's allowed to be wrong.

1. A failing test means fix `app/`. That is the default and near-always correct.
2. You may NOT: change an expected value, loosen an assertion, add `skip`,
   delete or narrow a test, stub the unit under test, or rescue an exception the
   code shouldn't raise.
3. If you believe a test is genuinely wrong, STOP. State the assertion, what the
   code produces, and quote the line of the settlement PDF that proves the test
   wrong. Wait for approval. "The code does X so the test should expect X" is not
   evidence.
4. Never change files under `test/` in the same commit as files under `app/`.
5. Files in `test/fixtures/files/` are hand-verified against real statements.
   Read-only. Never regenerate them.
6. Do not write a test by running new code and asserting its output. Derive
   expected values from the statement by hand.

## Existing code
`SettlementStatementParser` splits `extract` (PDF gem) from `parse` (pure text)
so parsing is testable without committing financial documents. Preserve that
split. The parser reconciles against the statement's own printed
Total Deductions and refuses to import when it doesn't balance. Never weaken
that gate. Never add a plug or rounding line to force a balance.

## Workflow
- Tests before implementation for parser, importer, and ledger math.
- Run `bin/rails test` and paste real output. Never claim green without it.
- `bin/rubocop -f github` must pass; CI runs it along with brakeman.
- Small commits, one concern each. No new gems without asking.

## Out of scope — flag, never decide
Section 179, depreciation elections, per-diem treatment, entity structure.
The app may reserve for tax. It may not advise on tax.
