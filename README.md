# Stocklet

Business management app for micro-businesses — sales, inventory, expenses, orders, notes and team roles — built with Flutter + Firebase. Multi-company and multi-language (ES/EN/PT/FR).

[![CI](https://github.com/BuildLark-Devs/stocklet/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/BuildLark-Devs/stocklet/actions/workflows/ci.yml)

**[Try it →](https://stocklet.buildlark.com)**

## Problem

Small business owners track sales, stock and orders in notebooks or scattered spreadsheets: slow, error-prone and hard to share with a team.

## Solution

A single mobile/PWA app to run the whole operation: register sales and expenses, keep live inventory with low-stock alerts, send quotes and manage orders, with role-based access for owner, partner and employee.

## Key features

- Multi-company, multi-language (ES/EN/PT/FR)
- Sales, expenses and inventory with weighted-average costing and low-stock alerts
- Quotes and order management
- Role-based access enforced by Firestore security rules
- Cloud Functions for low-stock and daily order reminders (push)

## Tech stack

Flutter/Dart (Android, iOS, Web/PWA) · Firebase (Auth, Firestore, Storage, Cloud Functions, Messaging, Analytics, Crashlytics) · RevenueCat (subscriptions)

## Architecture highlights

- Business isolation and permissions live in Firestore/Storage rules — the real security boundary — with their own test suite of 46 access cases.
- Inventory integrity via recipe snapshots stored at order creation, so delivery deductions survive later catalog edits.

## Status

Pre-launch. The app is feature-complete and the web build runs at
[stocklet.buildlark.com](https://stocklet.buildlark.com). The Google Play
release is waiting on the Play organization account for BuildLark S.A.S., which
requires a D-U-N-S number.

## Demo

Live web app: [stocklet.buildlark.com](https://stocklet.buildlark.com)

Video and screenshots: pending.

## Documentation

- [CONTRIBUTING.md](CONTRIBUTING.md) — branch and pull request flow, the required checks
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) — local setup, emulators, deployment
- [docs/data-safety.md](docs/data-safety.md) — data inventory for the Play Data Safety form
- [docs/play-listing.md](docs/play-listing.md) — Play Store listing copy and screenshot script

## Contributing

`main` is protected: changes land through a pull request that passes CI. The
flow, the two required checks and what must never be committed are in
[CONTRIBUTING.md](CONTRIBUTING.md).

---

© BuildLark S.A.S. All rights reserved. This source is published for reference;
it is not licensed for reuse or redistribution.
