# Google Play Data Safety — Stocklet

An inventory of the data the app collects, derived from the code (not from
memory). It is ordered like the Play Console form so it can be transcribed in
one pass: **Play Console → Policy → App content → Data safety**.

> **Keep it alive.** If a change makes the app collect something new, this table
> MUST be updated in the same change. An out-of-date declaration is grounds for
> suspension, not just rejection.
>
> Last reviewed: 2026-09-17, against version 1.1.0+2.

---

## Summary for the form

| Play question | Answer |
|---|---|
| Does the app collect or share any of the required data types? | **Yes** |
| Is all data encrypted in transit? | **Yes** (Firebase always uses TLS) |
| Can users request that their data be deleted? | **Yes**, in the app and on the web |
| Does it collect the advertising ID? | **No** — deliberately removed from the manifest |

**Account deletion.** Play requires both routes and both exist:

- In the app: Settings → Security → Delete account (`eliminarCuenta`, a Cloud Function).
- On the web: the account deletion page at `stocklet.buildlark.com`.

It deletes the Auth account, the user record, the Storage files and — if the
requester is the owner — the whole business tree and its members.

---

## Data collected

None of it is **shared** in Play's sense: everything goes to Firebase (Google)
and RevenueCat, which act as service providers and process on BuildLark's
behalf. Declare everything as **collected**, not as shared.

### Personal info

| Data type | Collected | Required | Purpose | Where it lives |
|---|---|---|---|---|
| Email address | Yes | Required | Account management, sign-in, password recovery | Firebase Auth |
| Name | Yes | Optional | App functionality: identifying each team member | `usuarios/{uid}.nombre` |
| Phone number | Yes | Optional | Functionality: contact details for the profile, the business and **the business's own customers** | `usuarios.celular`, `negocios.tel`, `cliente.telefono` in orders and quotes |
| Other personal info | Yes | Optional | Tax and contact details for the business: tax ID, email and location (text, not GPS) | `negocios.nit`, `.correo`, `.ubicacion` |

> **Mind the customers' phone numbers.** The app stores the name and phone of
> the business's customers (`models/cliente.dart`), who are third parties and do
> not use the app. It has to be declared all the same, and the privacy policy
> must state that the user is responsible for the customer data they enter.

### Financial info

| Data type | Collected | Required | Purpose | Where it lives |
|---|---|---|---|---|
| Purchase history | Yes | Required (if they subscribe) | Managing the Pro subscription | RevenueCat + Google Play Billing |
| Other financial info | Yes | Required | Core functionality: this *is* the business's accounting — sales, expenses, costs, prices and margins | `negocios/{id}/ventas`, `/gastos`, `/productos`, `/insumos` |

> This is the heart of the product. It cannot be marked "optional": without this
> data the app does nothing.

### Photos and videos

| Data type | Collected | Required | Purpose | Where it lives |
|---|---|---|---|---|
| Photos | Yes | Optional | Profile photo and business logo, chosen by the user | Storage: `usuarios/{uid}/foto_perfil`, `negocios/{id}/logo/imagen` |

`image_picker` is used against the gallery, always on an explicit user action.
There is no camera access and no automatic gallery reading.

### Files and docs

| Data type | Collected | Required | Purpose | Where it lives |
|---|---|---|---|---|
| Files and docs | Yes | Optional | PDF catalogues the business uploads to consult and share | Storage: `negocios/{id}/catalogos/` |

### App activity

| Data type | Collected | Required | Purpose | Where it lives |
|---|---|---|---|---|
| App interactions | Yes | Required | Analytics: screens visited, recorded automatically | Firebase Analytics (`FirebaseAnalyticsObserver`) |
| Other user-generated content | Yes | Required | Functionality: recipes, products, supplies, orders, quotes and their notes | Subcollections of `negocios/{id}` |

### App info and performance

| Data type | Collected | Required | Purpose | Where it lives |
|---|---|---|---|---|
| Crash logs | Yes | Required | Error diagnosis | Firebase Crashlytics |
| Diagnostics | Yes | Required | Performance and stability | Crashlytics and Analytics |

### Device or other IDs

| Data type | Collected | Required | Purpose | Where it lives |
|---|---|---|---|---|
| Device or other IDs | Yes | Required | Sending push notifications to the right device; the Analytics instance identifier | `usuarios/{uid}.fcmTokens`, Firebase Analytics |

**This is not the advertising ID.** It was deliberately removed from the
manifest (`com.google.android.gms.permission.AD_ID` with `tools:node="remove"`).
If it is ever re-enabled, come back here and declare it.

---

## Data the app does NOT collect

Getting this right matters too: over-declaring triggers needless reviews.

| Category | Why not |
|---|---|
| Location | There are no location permissions in the manifest. The country is picked by hand from a list. |
| Contacts | Customers are typed in by hand; the address book is never read. |
| Messages | There is no messaging. |
| Audio | Nothing is recorded. |
| Calendar | Order dates are typed in by hand. |
| Health and fitness | Not applicable. |
| Web browsing | Not applicable. |
| Sensitive data (ethnic origin, political or religious beliefs, sexual orientation) | Neither asked for nor inferred. |

---

## Declared permissions and their justification

From the merged manifest of the release `.aab`, version 1.1.0+2:

| Permission | Comes from | What for |
|---|---|---|
| `INTERNET` | Firebase | Everything |
| `ACCESS_NETWORK_STATE` | Firebase | Detecting connectivity |
| `WAKE_LOCK` | Firebase Messaging | Processing notifications |
| `POST_NOTIFICATIONS` | Firebase Messaging | Push on Android 13+ (requested at runtime) |
| `com.android.vending.BILLING` | RevenueCat | The Pro subscription |
| `com.google.android.c2dm.permission.RECEIVE` | Firebase Messaging | Receiving push |
| `READ_GSERVICES` | Google Play Services | Google services |
| `BIND_GET_INSTALL_REFERRER_SERVICE` | Firebase Analytics | Install attribution |

---

## Before submitting the form

- [ ] The privacy policy published at `stocklet.buildlark.com` covers
      **everything** in this inventory, including the business's customer data
      and the user's responsibility for it.
- [ ] The policy URL is set on the Play listing.
- [ ] The account deletion URL is set on the Play listing.
- [ ] If monetisation is still inactive (`SuscripcionService.activa = false`) in
      the version being uploaded, decide whether to declare purchase history now
      or wait until it is switched on.

> This is a technical inventory derived from the code, not legal advice. The
> party signing the declaration to Google is BuildLark S.A.S.
