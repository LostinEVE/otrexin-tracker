# OTRExin Tracker (Rails)

OTRExin Tracker is a Ruby on Rails web and mobile-friendly app for owner-operators and small trucking businesses.

It helps track:
- Invoices
- Expenses
- Fuel logs and MPG
- Mileage and cost/revenue per mile
- Maintenance records
- Tax payments and estimator
- Customer analysis
- Profit and Loss reports

The app also supports:
- Company profile settings used on invoice headers
- Exporting expense, maintenance, and P&L reports as CSV
- Emailing invoices directly from the app
- Print/Save PDF invoice and report workflows

## Tech Stack

- Ruby 4.0+
- Rails 8.1+
- SQLite (default)
- Propshaft + Importmap

## Local Setup

1. Install dependencies:

```powershell
bundle install
```

2. Create and migrate the database:

```powershell
ruby bin/rails db:create db:migrate
```

3. Start the app:

```powershell
ruby bin/rails server
```

4. Open in browser:

http://localhost:3000

Note for Windows:
- Use ruby bin/rails ... commands if bin/rails alone does not run correctly.

## First-Time App Walkthrough

After booting the app:

1. Open Company page and fill in company details.
2. Create an invoice.
3. Open the invoice and test Print/Save PDF.
4. Use Email Invoice to send from the app.
5. Add expenses, maintenance, fuel, and mileage records.
6. Open P&L for period reporting and CSV export.

## Main Sections

- Dashboard: top-level business stats
- Invoices: create, view, print, email
- Expenses: categorized expenses with CSV export
- Fuel Log: fill-up history, per-fill MPG, overall MPG
- Mileage: miles and revenue per trip, RPM and CPM stats
- Maintenance: service history with CSV export
- Customers: customer-level revenue and payment performance
- Taxes: estimator and payment history tracking
- P&L: date-range report with CSV export for bank/tax use

## Emailing Invoices

Invoice email is sent through Action Mailer.

To use real email delivery, configure SMTP in environment config.

Example settings to add in development or production environment files:

```ruby
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
	address: ENV["SMTP_ADDRESS"],
	port: ENV.fetch("SMTP_PORT", 587).to_i,
	user_name: ENV["SMTP_USERNAME"],
	password: ENV["SMTP_PASSWORD"],
	authentication: :plain,
	enable_starttls_auto: true
}
```

Set environment variables before starting the app.

If SMTP is not configured, emails are written to `tmp/mails` instead of being sent.

### Local real email quick setup

1. Copy `.env.example` to `.env` and fill your SMTP credentials.
2. Install gems (adds `dotenv-rails`):

```bash
bundle install
```

3. Restart Rails server.
4. Send a test email:

```bash
ruby bin/rails "mail:test[your-email@example.com]"
```

If the test succeeds, invoice emails will go out through SMTP instead of being written to `tmp/mails`.

## Buy Me a Coffee (PayPal)

You can add an optional PayPal tip link to support development.

1. In PayPal, create a personal payment link (for example your PayPal.Me URL).
2. Set this environment variable:

```powershell
$env:PAYPAL_BUY_ME_COFFEE_URL="https://www.paypal.com/your-tip-link"
```

3. Restart the app and open Buy Me a Coffee from the top navigation.

For Render, add `PAYPAL_BUY_ME_COFFEE_URL` in the service environment variables.

## Report Exports

Supported exports:
- Expense report CSV
- Maintenance report CSV
- Profit and Loss CSV

Recommended workflow for banks/taxes:
1. Filter by date range.
2. Export CSV for records.
3. Use Print/Save PDF from browser for a printable statement.

## Git Workflow

If creating a new remote repository:

```powershell
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/otrexin-tracker.git
git push -u origin main
```

If origin already exists:

```powershell
git remote set-url origin https://github.com/YOUR_USERNAME/otrexin-tracker.git
git push -u origin main
```

## Useful Commands

```powershell
ruby bin/rails routes
ruby bin/rails db:migrate
ruby bin/rails test
```

## Troubleshooting

### cannot load such file -- csv

Install dependencies again:

```powershell
bundle install
```

Then restart server:

```powershell
ruby bin/rails server
```

### Server does not start on Windows

Use:

```powershell
ruby bin/rails server
```

## Deploy to Render

This app is configured to run on Render with PostgreSQL in production.

### 1. Create a Render PostgreSQL database

In Render dashboard:
- New > PostgreSQL
- Name it (for example `otrexin-db`)

### 2. Create the Render Web Service

In Render dashboard:
- New > Web Service
- Connect your GitHub repo
- Runtime: Ruby

Use these commands:

- Build Command:

```bash
bundle install && bundle exec rails assets:precompile && bundle exec rails db:migrate
```

- Start Command:

```bash
bundle exec puma -C config/puma.rb
```

### 3. Set environment variables

Required:
- `RAILS_MASTER_KEY` = value from your local `config/master.key`
- `DATABASE_URL` = Render PostgreSQL internal URL (usually auto-set if linked)
- `APP_HOST` = your Render domain (example `otrexin-tracker.onrender.com`)

Required for invoice email (Outlook / Microsoft 365):
- `SMTP_ADDRESS` = `smtp.office365.com`
- `SMTP_PORT` = `587`
- `SMTP_USERNAME` = your full Outlook email address
- `SMTP_PASSWORD` = your Outlook password or app password
- `SMTP_AUTHENTICATION` = `login`
- `SMTP_ENABLE_STARTTLS_AUTO` = `true`

> **Note:** The local `.env` file is NOT used on Render. You must enter these values directly in the Render dashboard under your service's Environment tab. After saving, Render will redeploy automatically.

### 4. Deploy

Trigger deploy after setting env vars.

## Migrate Data From Old Cloud App

Yes, you can move data from your old app into this Rails app.

### Supported import format

One JSON file, either:
- direct object with arrays, or
- wrapped object under `data`

The importer supports common key names from your previous app.

### Import task

Task file:
- `lib/tasks/import_legacy_data.rake`

Usage locally:

```powershell
ruby bin/rails "data:import_legacy_json[C:/path/to/legacy-export.json]"
```

Reset existing data before import:

```powershell
$env:RESET="true"
ruby bin/rails "data:import_legacy_json[C:/path/to/legacy-export.json]"
```

Usage on Render shell:

```bash
bundle exec rails "data:import_legacy_json[/tmp/legacy-export.json]"
```

### Import expense CSV from old app

If you exported expense report CSV (columns like `Truck,Date,Category,Vendor,Amount,Notes`), use:

```powershell
$env:IMPORT_USER_EMAIL="your-login-email@example.com"
ruby bin/rails "data:import_expenses_csv[C:/Users/you/Documents/expenses_by_truck.csv]"
```

Notes:
- Section rows like `Truck Name - EXPENSES` are skipped automatically.
- Truck name is appended into expense notes because the new expense model has no separate truck field.

### What gets imported

- Invoices
- Expenses
- Fuel logs
- Mileage trips
- Maintenance records
- Tax payments
- Company profile/settings

### Push to GitHub fails with URL error 400

You are likely using a placeholder URL.
Set the correct remote URL with your real GitHub username.

## License

Private/Internal use unless otherwise specified by repository owner.
