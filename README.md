# Stocklet
Business management app for micro-businesses - sales, inventory, expenses, orders, notes and team roles - built with Flutter + Firebase. Multi-company and multi-language (ES/EN/PT/FR).

## Problem
Small business owners track sales, stock and orders in notebooks or scattered spreadsheets: slow, error-prone and hard to share with a team.

## Solution
A single mobile/PWA app to run the whole operation: register sales and expenses, keep live inventory with low-stock alerts, send quotes and manage orders, with role-based access for owner, partner and employee.


Key features
Multi-company, multi-language (ES/EN/PT/FR)
Sales, expenses and inventory with weighted-average costing and low-stock alerts
Quotes and order management
Role-based access enforced by Firestore security rules
Cloud Functions for low-stock and daily order reminders (push)
Tech stack
Flutter/Dart (Android, iOS, Web/PWA) - Firebase (Auth, Firestore, Storage, Cloud Functions, Messaging, Analytics, Crashlytics) - RevenueCat (subscriptions)


## Architecture highlights
Business isolation and permissions live in Firestore/Storage rules (the real security boundary), with their own test suite.
Inventory integrity via recipe snapshots stored at order creation, so delivery deductions survive later catalog edits.
Status
In production - published by BuildLark S.A.S.

## Demo
Live demo / video: Pending...

Screenshots: Pending...
