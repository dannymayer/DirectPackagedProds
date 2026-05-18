# DirectPackagedProds

A SharePoint Framework (SPFx) web part that replaces the legacy `DirectPkgProds.asp` page, displaying Direct Packaged Products data from the **WebReps** SQL Server database. Data is served through a secure Azure Functions API backed by Azure AD authentication.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [End User Guide](#end-user-guide)
  - [Accessing the Web Part](#accessing-the-web-part)
  - [Navigating the Page](#navigating-the-page)
  - [Filtering Records](#filtering-records)
  - [Sorting Records](#sorting-records)
  - [Exporting Data](#exporting-data)
  - [Admin View (DPP Admins only)](#admin-view-dpp-admins-only)
- [Permission Tiers](#permission-tiers)
- [Setup & Deployment](#setup--deployment)
- [Local Development](#local-development)
- [API Reference](#api-reference)
- [GitHub Actions](#github-actions)
- [Project Structure](#project-structure)
- [Troubleshooting](#troubleshooting)

---

## Overview

**DirectPackagedProds** shows a filtered, sortable table of direct packaged product transactions — investments, commissions, trade dates, sponsor accounts, and more — for the currently signed-in rep.  It is the modern replacement for the classic ASP page (`DirectPkgProds.asp`) and preserves all original functionality including:

- Per-rep and per-sub-rep filtering
- Month/year period selector (last 13 months)
- Batch-type filters (Trails, Mutuals, Insurance) and free-text search
- Alphabetical section dividers and per-rep subtotals
- Export to CSV / Excel

Authentication is handled entirely by **Azure AD** — users sign in with their existing Microsoft 365 credentials; no separate login is required.

---

## Architecture

```
SharePoint Online
  └── SPFx Web Part (React)
        │  (Bearer token — AAD, via AadHttpClient)
        ▼
  Azure Function App  (Node 18, TypeScript)
        │  (SQL Server over VPN / private endpoint)
        ▼
  SQL Server — WebReps database
        (vwDIRECT_PKG_PRODS, vwDIRECT_PKG_PRODS_ADM,
         vwDIRECT_PKG_PRODS_MONTHS, T_E_Services,
         vwREPALL, T_SUB_RRs, DIRECT_PKG_PRODS_REP_LIST)
```

| Layer | Technology |
|-------|-----------|
| Front-end | SPFx 1.18, React 17, TypeScript |
| Back-end API | Azure Functions v4, Node 18, TypeScript, `mssql` |
| Authentication | Azure AD (Easy Auth on the Function App) |
| Database | SQL Server — WebReps database |
| CI/CD | GitHub Actions (daily data sync, OIDC) |

---

## End User Guide

### Accessing the Web Part

The **Direct Packaged Products** web part is embedded in a SharePoint page. Navigate to the page your SharePoint administrator has set up. You will be signed in automatically using your Microsoft 365 account — no separate login is needed.

> If you see *"Please configure the web part"*, contact your SharePoint administrator — the API URL has not been set yet.

---

### Navigating the Page

When the page loads, the web part:

1. Identifies you via your Azure AD account.
2. Loads available months (last 13 months).
3. Loads the list of RR# numbers you are allowed to filter by.
4. Automatically shows your records for the **most recent available month**.

The page is divided into two areas:

| Area | Description |
|------|-------------|
| **Filter bar** (top) | Controls for period, view mode, rep filter, search, and export |
| **Data table** (below) | Records matching your current filters, with totals |

---

### Filtering Records

All filters are in the bar at the top of the web part. Changes take effect immediately — there is no separate "Apply" button except when using free-text search.

#### Period

Select a **month/year** from the *Period* dropdown to view a different reporting period. Up to 13 months are available.

#### Filter RR#

If you have sub-reps, a *Filter RR#* dropdown appears. Select a specific RR number to narrow results to that rep, or choose **All** to see all your records.

#### Filter by (batch/search type)

Use the *Filter by* dropdown to narrow results by:

| Option | Description |
|--------|-------------|
| Show All | Remove the batch/search filter |
| Trails | Show only Trail-type records (`BATCH = 'TRAILS'`) |
| Mutuals | Show only Mutual-type records (`BATCH = 'MUTUALS'`) |
| Insurance | Show only Insurance-type records (`BATCH = 'INSURANCE'`) |
| Fund | Free-text search on the **Fund** name |
| Customer | Free-text search on the **Customer** name |
| Trade Date | Exact match on the **Trade Date** (format: `YYYY-MM-DD`) |
| Spon Acct | Free-text search on the **Sponsor Account** |

When you select *Fund*, *Customer*, *Trade Date*, or *Spon Acct*, a text input and a **Search** button appear. Type your search term and press **Enter** or click **Search**.

---

### Sorting Records

Click any underlined column heading to toggle the sort order for that column. The active sort column is highlighted. Ascending (▲) and descending (▼) arrow buttons beside each heading let you set the direction explicitly.

| Column | Sort key |
|--------|----------|
| Rep# | By rep number |
| Fund | By fund name |
| Type | By batch type |
| Customer | By customer name (default; also shows A–Z section dividers) |
| Invest | By investment amount |
| Total | By commission/total amount |
| Spon Acct | By sponsor account |

> **T-Date** (Trade Date) and **I/T** columns do not support sorting.

When sorted by **Customer**, alphabetical section dividers are inserted between records. Each section header includes a *Top* link to scroll back to the top of the table.

When sorted by **Rep#**, a subtotal row for each rep is shown immediately below that rep's last record.

A **grand total** row always appears at the bottom of the table.

---

### Exporting Data

Click the **Export to Excel** button to download the currently displayed records as a CSV file. The file is named `DPP_<period>.csv` and can be opened directly in Microsoft Excel.

The export contains these columns:

`Rep#` · `Fund` · `Type` · `Customer` · `Invest` · `Total` · `T-Date` · `Spon Acct` · `I/T`

---

### Admin View (DPP Admins only)

If your account has DPP Admin access, a *View* dropdown appears next to the period selector:

| Option | Description |
|--------|-------------|
| *Your Name* / My Records | Shows only your own records (default) |
| Admin (All Reps) | Shows records for all reps (or your scoped rep group for special admins) |

Switching the view mode reloads both the RR# filter list and the records table.

---

## Permission Tiers

All permission decisions are enforced **server-side** in the Azure Function API. The web part only ever receives data the signed-in user is authorised to view.

| User type | Records shown |
|-----------|---------------|
| Normal rep | Only records where `lasalle_st_ID` = their own ID |
| Rep with sub-reps | Same, plus can filter by any of their RR# numbers |
| DPP Admin (standard) | All records via the admin view (`vwDIRECT_PKG_PRODS_ADM`) |
| Special admin `0KK003` | All records where `lasalle_st_ID LIKE '0KK%'` |
| Special admin `0KAA45` | Records for `0KAA45`, `0KAA53`, `0KAA64` |

User identity is resolved by mapping the signed-in user's **Azure AD UPN** (e.g. `jsmith@company.com`) to a `lasalle_st_ID` in the `T_E_Services` table. See [SETUP.md](SETUP.md) for the required database migration.

---

## Setup & Deployment

Full step-by-step deployment instructions, including database migration, Azure Function App creation, Easy Auth configuration, SPFx packaging, and SharePoint App Catalog deployment, are in **[SETUP.md](SETUP.md)**.

**Quick summary:**

1. Apply the SQL migration (add `UPN` column to `T_E_Services`).
2. Create an Azure Function App (Node 18, Linux) and configure the DB connection strings.
3. Enable App Service Authentication (Easy Auth) with your Azure AD tenant.
4. Build and package the SPFx web part (`npm run ship`).
5. Upload the `.sppkg` to the SharePoint App Catalog and approve the API permission.
6. Add the web part to a SharePoint page and set the **Azure Function App Base URL** in the property pane.

---

## Local Development

### Prerequisites

- Node.js 18 (the SPFx toolchain requires exactly the `18.x` slot)
- npm 8+
- A copy of `api/local.settings.json` (see `api/local.settings.json.example`)
- [Azure Functions Core Tools v4](https://learn.microsoft.com/azure/azure-functions/functions-run-local)

### Running the API locally

```bash
cd api
npm install
# Copy and fill in your local DB connection settings
cp local.settings.json.example local.settings.json
# Start the function host
npm start          # or: func start
```

The API will be available at `http://localhost:7071`.

> **Note:** Easy Auth is not enforced locally. The `extractUpn` helper reads the `x-ms-client-principal-name` header. You can set this manually in your HTTP client (e.g. Postman) or point `api/shared/auth.ts` at a test UPN for development.

### Running the SPFx web part locally

```bash
# From the repo root
npm install
npm run serve       # starts the SPFx workbench
```

Open `https://localhost:4321/temp/workbench.html` in a browser (or the hosted SharePoint workbench). In the web part property pane, set the **Azure Function App Base URL** to `http://localhost:7071`.

### Useful scripts (repo root)

| Command | Description |
|---------|-------------|
| `npm run build` | Bundle (debug) |
| `npm run ship` | Bundle + package for production deployment |
| `npm run serve` | Start local SPFx workbench |
| `npm run lint` | ESLint on `src/` |
| `npm run clean` | Remove build artefacts |

---

## API Reference

All endpoints are HTTP GET. The Function App's Easy Auth layer validates the caller's AAD token before any function code runs.

### `GET /api/dpp/user`

Returns the resolved identity and permission tier for the signed-in user.

**Response**
```jsonc
{
  "lasalleStId": "0KAC23",
  "repName": "Jane Smith",
  "isDppAdmin": false,
  "specialAdminType": null   // "kk003" | "kaa45" | null
}
```

---

### `GET /api/dpp/months`

Returns the last 13 available month/year periods.

**Response**
```jsonc
{
  "months": [
    { "myId": 42, "month": "4", "year": "2025", "label": "4/2025" },
    ...
  ]
}
```

---

### `GET /api/dpp/records`

Returns DPP records for the authenticated user, subject to server-side permission enforcement.

**Query parameters** (all optional)

| Parameter | Type | Description |
|-----------|------|-------------|
| `myId` | integer | Period ID from `/months` — resolves to a month/year filter |
| `repnum` | string | Sub-rep RR# to filter to, or `"all"` |
| `searchType` | string | `trl` \| `mut` \| `ins` \| `fnd` \| `cus` \| `tdt` \| `spn` |
| `searchVal` | string | Free-text value used with `fnd`, `cus`, `tdt`, `spn` |
| `sort` | string | `rep` \| `fund` \| `type` \| `cust` \| `inv` \| `comm` \| `spon` |
| `direction` | string | `ASC` \| `DESC` |
| `viewAsAdmin` | `"true"` | Use the admin view (ignored for non-admin callers) |

**Response**
```jsonc
{
  "records": [
    {
      "id": 1001,
      "repNum": "RR001",
      "fundName": "Acme Growth Fund",
      "batch": "MUTUALS",
      "customer": "Smith, John",
      "invest": 10000.00,
      "comm": 50.00,
      "tradeDate": "2025-03-15",
      "sponAcct": "ACME001",
      "type": "I",
      "month": "3",
      "year": "2025",
      "lasalleStId": "0KAC23",
      "dppAdmin": false
    },
    ...
  ]
}
```

---

### `GET /api/dpp/reps`

Returns the RR# numbers the signed-in user may filter by.

**Query parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `viewAsAdmin` | `"true"` | Return all reps (admin scope) instead of personal sub-reps |

**Response**
```jsonc
{
  "reps": [
    { "repNum": "RR001", "description": "Personal Account", "sharePct": 100 },
    { "repNum": "RR002", "description": "Joint Account", "sharePct": 50 }
  ]
}
```

---

## GitHub Actions

The repository includes a daily scheduled workflow (`sync-dpp-data.yml`) that triggers a data-refresh HTTP function on the Azure Function App. It uses **OIDC federated credentials** — no long-lived secrets are stored in GitHub.

| Secret | Description |
|--------|-------------|
| `AZURE_CLIENT_ID` | Client ID of the service principal |
| `AZURE_TENANT_ID` | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |
| `DPP_SYNC_FUNCTION_URL` | HTTPS URL of the sync HTTP trigger function |

You can also trigger the workflow manually from the **Actions** tab, with an optional *dry run* mode that logs actions without writing data.

See [SETUP.md](SETUP.md#4-github-actions--daily-sync-optional) for how to configure the federated credential.

---

## Project Structure

```
DirectPackagedProds/
├── api/                          ← Azure Functions (Node 18 / TypeScript)
│   ├── GetUser/                  ← GET /api/dpp/user
│   ├── GetMonths/                ← GET /api/dpp/months
│   ├── GetRecords/               ← GET /api/dpp/records
│   ├── GetReps/                  ← GET /api/dpp/reps
│   ├── shared/
│   │   ├── auth.ts               ← Easy Auth UPN extraction
│   │   ├── db.ts                 ← SQL Server connection pool
│   │   └── permissionHelper.ts  ← Permission model + SQL query helpers
│   ├── host.json
│   ├── local.settings.json.example
│   ├── package.json
│   └── tsconfig.json
│
├── src/webparts/directPkgProds/  ← SPFx web part (React / TypeScript)
│   ├── DirectPkgProdsWebPart.ts  ← Entry point, acquires AAD token
│   ├── components/
│   │   ├── DirectPkgProds.tsx    ← Root component, state management
│   │   ├── DppFilters.tsx        ← Month / rep / search filter bar
│   │   ├── DppGrid.tsx           ← Data table with subtotals
│   │   └── DirectPkgProds.module.css
│   └── services/
│       └── DppApiService.ts      ← Typed wrappers for all API endpoints
│
├── config/
│   ├── package-solution.json     ← SPFx solution + API permission requests
│   └── serve.json
│
├── .github/workflows/
│   └── sync-dpp-data.yml         ← Daily data-sync trigger (OIDC)
│
├── DirectPkgProds.asp            ← Original ASP page (reference only)
├── gulpfile.js
├── package.json                  ← SPFx root dependencies
├── tsconfig.json
├── README.md                     ← This file
└── SETUP.md                      ← Full deployment guide
```

---

## Troubleshooting

| Symptom | Likely cause | Resolution |
|---------|-------------|------------|
| *"Please configure the web part"* | Azure Function App URL not set | Open the property pane and enter the Function App URL |
| *"No active rep found for user: …"* | Your AAD UPN is not mapped to a `lasalle_st_ID` | Populate the `UPN` column in `T_E_Services` — see [SETUP.md §1b](SETUP.md#1b-populate-upn-for-existing-reps) |
| Blank filter bar / loading spinner that never resolves | API unreachable or AAD permission not approved | Verify the Function App is running; check SharePoint Admin Center → API access for a pending `user_impersonation` request |
| `403 Forbidden` from the API | Token audience mismatch | Ensure `webApiPermissionRequests` in `config/package-solution.json` uses the exact Application ID URI from Easy Auth |
| Export CSV opens with garbled characters | Encoding issue in Excel | In Excel, use *Data → From Text/CSV* and select UTF-8 encoding |
| Records appear for the wrong rep | UPN fallback matched the wrong account | Explicitly set the `UPN` column in `T_E_Services` for that user instead of relying on username-prefix matching |