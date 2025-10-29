# Flatplan

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)](https://github.com/YOUR_USERNAME/flatplan/actions)
[![Latest Release](https://img.shields.io/badge/version-v0.1.0-lightgrey.svg)](https://github.com/YOUR_USERNAME/flatplan/releases)

> Your financial planning in "flat" files. Simple, local, and fully under your control.

[HINT: A screenshot is crucial for user engagement. Insert one here as soon as you can.]
``

---

## 💡 What is Flatplan?

**Flatplan** is a desktop personal budgeting application designed for those who value **simplicity, privacy, and full control** over their data.

Unlike most financial apps, Flatplan **does not use cloud services or proprietary databases**. Instead, your entire financial life—plans, categories, and expenses—is stored in **human-readable files (JSON or YAML)** directly in a folder on your computer.

It implements the time-tested **"Plan vs. Fact"** (or "envelope") budgeting method without the bloat of double-entry accounting. It's the perfect solution for developers, tech-savvy users, and anyone who prefers to manage their data like they manage their configs: transparently, and optionally, with Git, Syncthing, or any other tool.

## 🏛️ The "Local-First" Philosophy

Flatplan is built on a few key principles:

1.  **💻 You Own Your Data:** Your financial data lives only on your device in a simple folder. No third-party servers, ever.
2.  **✨ Total Transparency:** By using YAML or JSON, you can view (and even edit) your data in a plain text editor at any time.
3.  **🔄 Sync Freedom:** You decide how to sync your budget folder. Use **Git**, **Syncthing**, **Dropbox**, **Google Drive**, or just copy it to a USB stick. The app doesn't lock you into its own service.
4.  **🔒 Private by Default:** The app requires no registration, does not connect to your bank accounts, and sends no "anonymous" telemetry.

## ✨ Key Features

* **🗂️ File-Based:** All data is stored in human-readable `.json` or `.yaml` files. One period = one file.
* **🧠 Simple Method:** Focuses on **"Plan vs. Fact"**—compare your planned spending against your actuals.
* **🚫 No Accounting:** No double-entry, debits, or credits required. This is budgeting, not accounting.
* **🗓️ Custom Periods:** Set any period length and start date you want (e.g., from the 25th of one month to the 24th of the next).
* **🧾 Categories & Limits:** Create categories with spending limits or list planned itemized expenses.
* **📊 Simple Stats:**
    * Totals: Plan vs. Fact (Income & Expenses).
    * "Heat" indicator for categories (turns red on overspending).
    * Calculates remaining "free-to-spend" money per day until the period ends.
* **📤 Copy Plan:** Easily copy the previous month's plan to avoid starting from scratch.

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

* `template.yaml`: Your budget "master template." It holds your list of categories and recurring income/expenses (e.g., "Rent", "Internet").
* `period-2025-10.yaml`: The data file for October 2025. It's created from your template and holds your **planned** amounts for the month and a column for your **actual** spending.
* `period-2025-11.yaml`: The data file for November 2025.
* ...and so on.

## 🚀 Getting Started

[Your installation instructions will go here.]

1.  **Download** the latest release from the [Releases](https://github.com/YOUR_USERNAME/flatplan/releases) page.
2.  **Run** the application.
3.  **Create** your first `template.yaml` file by adding your budget categories.
4.  **Create** your first period from the template and start planning!

## 🗺️ Roadmap

* [ ] Multi-currency support (vNext)
* [ ] Improved charts and visualizations
* [ ] Your next great idea...

## 🤝 Contributing

We welcome all ideas and pull requests! If you find a bug or have a feature suggestion, please [open an issue](https://github.com/YOUR_USERNAME/flatplan/issues).

## ⚖️ License

This project is distributed under the MIT License. See the `LICENSE` file for details.