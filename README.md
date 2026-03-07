# Flatplan

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Pipeline](https://gitlab.com/flatplan/flatplan/badges/main/pipeline.svg)](https://gitlab.com/flatplan/flatplan/-/pipelines)
[![Latest Release](https://gitlab.com/flatplan/flatplan/-/badges/release.svg)](https://gitlab.com/flatplan/flatplan/-/releases)

> Your financial planning in "flat" files. Simple, local, and fully under your control.

> 💡 A screenshot is crucial for user engagement — add one here as soon as you have a build ready.

---

## 💡 What is Flatplan?

**Flatplan** is a desktop personal budgeting application designed for those who value **simplicity, privacy, and full control** over their data.

Unlike most financial apps, Flatplan **does not use cloud services or proprietary databases**. Instead, your entire financial life—plans, categories, and expenses—is stored in **human-readable YAML files** directly in a folder on your computer.

It implements the time-tested **"Plan vs. Fact"** (or "envelope") budgeting method without the bloat of double-entry accounting. It's the perfect solution for developers, tech-savvy users, and anyone who prefers to manage their data like they manage their configs: transparently, and optionally, with Git, Syncthing, or any other tool.

## 🏛️ The "Local-First" Philosophy

Flatplan is built on a few key principles:

1.  **💻 You Own Your Data:** Your financial data lives only on your device in a simple folder. No third-party servers, ever.
2.  **✨ Total Transparency:** By using YAML, you can view (and even edit) your data in a plain text editor at any time.
3.  **🔄 Sync Freedom:** You decide how to sync your budget folder. Use **Git**, **Syncthing**, **Dropbox**, **Google Drive**, or just copy it to a USB stick. The app doesn't lock you into its own service.
4.  **🔒 Private by Default:** The app requires no registration, does not connect to your bank accounts, and sends no "anonymous" telemetry.

## ✨ Key Features

* **🗂️ File-Based:** All data is stored in human-readable `.yaml` files. One period = one file.
* **🧠 Simple Method:** Focuses on **"Plan vs. Fact"**—compare your planned spending against your actuals.
* **🚫 No Accounting:** No double-entry, debits, or credits required. This is budgeting, not accounting.
* **🗓️ Custom Periods:** Set any period length and start date you want (e.g., from the 25th of one month to the 24th of the next).
* **🧾 Categories & Limits:** Create categories with spending limits or list planned itemized expenses.
* **📊 Simple Stats:**
    * Totals: Plan vs. Fact (Income & Expenses).
    * "Heat" indicator for categories (turns red on overspending).
    * Calculates remaining "free-to-spend" money per day until the period ends.
* **📤 Copy Plan:** Roll over the previous period's plan to a new one — no need to start from scratch.
* **📋 Budget Templates** *(planned)*: Define a reusable master template that seeds every new period automatically.

## 🎯 Who is this for?

* **Developers, sysadmins,** and other tech-savvy users who love keeping configs in text files.
* **Privacy advocates** who don't trust cloud services with their financial data.
* People who like the **method of YNAB** ("envelope budgeting") but dislike its **implementation** (cloud, subscription, bank-linking).
* Users who tried **Ledger/hledger/Beancount** (Plain Text Accounting) but found them too complex (double-entry) for simple personal budgeting.

## ❌ Who is this *NOT* for?

Flatplan is **not** for you if you are looking for:

* Automatic syncing with your bank accounts.
* A cloud-first app with a native mobile client out of the box.
* Complex, double-entry accounting to track assets and liabilities.

## ⚙️ How It Works (Storage Concept)

Flatplan doesn't use a database. Your entire setup lives in a folder you choose:

* `period-2025-10.yaml`: The data file for October 2025. Holds your **planned** amounts for the month and a column for your **actual** spending.
* `period-2025-11.yaml`: The data file for November 2025, rolled over from October's plan.
* ...and so on.

> 🔜 **Planned:** A persistent `template.yaml` — a reusable master template that seeds every new period automatically instead of copying from the previous one.

## 🚀 Getting Started

> 💡 Full installation packages (`.deb`, `.msix`, `.dmg`) will be attached to the first public release.

1.  **Download** the latest release from the [Releases](https://gitlab.com/flatplan/flatplan/-/releases) page.
2.  **Run** the application.
3.  **Create your first period** — the app guides you through a cold-start wizard to add your budget categories.
4.  **Record your planned expenses** and start tracking actuals against them!
5.  At the end of the month, **roll over** to a new period with one click — your categories and plan carry over automatically.

## 🗺️ Roadmap

* [ ] **Budget Templates** — a reusable `template.yaml` that seeds every new period automatically.
* [ ] Multi-currency support
* [ ] Improved charts and visualisations
* [ ] Data export (CSV / PDF)

## 🤝 Contributing

We welcome all ideas and merge requests! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for the full guide.

- 🐛 [Open a Bug Report](https://gitlab.com/flatplan/flatplan/-/issues/new?issuable_template=bug_report)
- 💡 [Request a Feature](https://gitlab.com/flatplan/flatplan/-/issues/new?issuable_template=feature_request)

## ⚖️ License

This project is distributed under the MIT License. See the [`LICENSE`](LICENSE) file for details.
