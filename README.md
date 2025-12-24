# Kashr - Catch Your Cash

A personal finance app with a focus on privacy and open source.

Kashr, derived from the German word *'Kescher'* (pronounced *Késcher* like cash-er), means landing net. It's open like open source software, but your privacy and data? They won't slip through! Plus, it's perfect for catching where your money goes. Oh, and it sounds like "cash" - pure coincidence, of course. :p

**Status**: EARLY ACCESS

## TL;DR Features

- **Business Model**: No paywalls*, no ads, no data sales. Open source software. Fully optional: pay if you like it and to keep us going.
- **Account Management** - Multi-account support with various types and sync options (well, currently only comdirect support)
- **Transactions** - Comprehensive transaction tracking with tagging and search
- **Transfers** - Money transfer tracking between accounts
- **Savings Goals** - Goal setting and progress tracking
- **Bank Integration** - Comdirect API integration for automatic sync
- **Analytics** - Dashboard, charts, and financial summaries
- **Backup & Restore** - Local and cloud (Nextcloud) backup support
- **Security** - Biometric auth and encryption of backups
- **UX** - Themes, quick entry, responsive design

*There will be no paywalls on the software itself, but some 3rd party features may require payment, e.g. your bank may charge for their API or a PSD2 provider may raise charges for their account aggregation.

## Data Privacy

- **You own your data**
- **No data is sold** (we don't even have or want it!)
- **All data stays on your device** by default.
- You can store (optionally encrypted) backups in any of the supported backends (e.g. Nextcloud/WebDAV).
- We provide a dockerized decryption tool independent of the app, see [ENCRYPTION_README.md](ENCRYPTION_README.md).

## Trustful Business Model: Good Software, Not Data!

- **You're the customer**, not the product.
- We **build great software**, not data mining tools.
- No paywalls or ads. We rather spent our time improving our software.
- All software is open source, so you can see exactly what it does.
- It's free as in freedom and - fully optional - you can pay us to keep us going.

## Limitations of v1

- See [ROADMAP.md](ROADMAP.md)
- No automatic recurring transactions, yet
- No debt tracking, yet
- Multi-currency support is prepared but not implemented and not really planned. Currently, only EUR is supported.
- Bank sync only supports comdirect. Support of other data ingest methods prepared, but NOT implemented.
  - more banks or PSD2 if project has traction (vote for your bank if it has an API for private customers by raising a ticket)
  - we'll be able to implement CSV import or maybe can support other formats as well
- no automatic tests, yet - Early Stage, use at own risk
- Cannot execute transactions via the app (not planned, it is a pure analytical app)
- known bugs: see issue tracker

## Core Features

### Account Management

- Multiple account types (Checking, Savings, Cash, Investment, Credit Card)
- Manual and automatic (Comdirect) account sync
- Balance tracking with current and projected balances
- Show/hide accounts

### Transactions (Turnovers)

- Income and expense tracking
- Search, filter, and sort transactions
- Batch tagging for multiple transactions
- Tag-based categorization with custom colors
- Smart tag suggestions based on counterpart and purpose (learns over time)
- Transaction matching with imported bank data

### Transfers

- Track money transfers between accounts
- Transfer confirmation workflow
- Automatic validation and review flagging

### Savings Goals

- Create savings goals linked to transaction tags
- Track progress toward savings targets
- Virtual booking adjustments
- Savings can span multiple accounts

### Bank Integration

- **Comdirect API Integration:**
  - OAuth2-based authentication with 2FA support
  - Automatic account discovery
  - Transaction import and sync
  - Balance updates from bank
- **Other banks**
  - This project is open to contributions
  - Not all banks provide an enduser API
  - Professional account aggregators might be supported in the future but will introduce a paywall as their services will not be free-of-charge.

### Analytics & Reporting

- Financial dashboard with period navigation (monthly/yearly)
- Cashflow summary (income vs. expenses)
- Tag-based spending and income breakdowns
- Transfer summaries
- Visual charts and trends over time
- Pending and unallocated transaction indicators

### Backup & Restore

- **Local Backups:**
  - Encrypted database backups with password protection
  - Backup creation, listing, and restoration
- **Cloud Backups (Nextcloud):**
  - WebDAV integration for cloud storage
  - Upload and download backups

### Security

- Biometric authentication (fingerprint/face ID)
- Encrypted backups (AES encryption)
- Secure credential storage

### User Experience

- Light and dark theme modes
- Quick entry mode for rapid data input
- Full-text search and Recent search history
