# Direct Packaged Products — SharePoint Web Part Setup Guide

This document describes all steps needed to deploy the new SharePoint web part
and its supporting Azure Functions API.

---

## Architecture overview

```
SharePoint Online
  └── SPFx Web Part (React)
        │  (Bearer token — AAD)
        ▼
  Azure Function App  (Node 18, TypeScript)
        │  (SQL Server over VPN / private endpoint)
        ▼
  SQL Server — WebReps database
        (vwDIRECT_PKG_PRODS, vwDIRECT_PKG_PRODS_ADM,
         vwDIRECT_PKG_PRODS_MONTHS, T_E_Services,
         vwREPALL, T_SUB_RRs, DIRECT_PKG_PRODS_REP_LIST)
```

---

## 1. Database migration

### 1a. Add `UPN` column to `T_E_Services`

The web part uses Azure AD UPNs (e.g. `dmayer@lasallest.com`) to identify
users.  The Function App maps UPNs to `lasalle_st_ID` via `T_E_Services`.

```sql
ALTER TABLE T_E_Services
ADD UPN NVARCHAR(254) NULL;

-- Add an index for fast lookup
CREATE NONCLUSTERED INDEX IX_TES_UPN ON T_E_Services (UPN);
```

### 1b. Populate `UPN` for existing reps

For reps whose Windows username equals their `lasalle_st_ID` (the majority),
the Function App falls back to username-prefix matching automatically.  For
reps with alias mappings (previously hardcoded in the ASP page), populate the
`UPN` column explicitly:

```sql
-- Examples of the previously hardcoded aliases
UPDATE T_E_Services SET UPN = 'mcampbell@lasallest.com'   WHERE lasalle_st_ID = '0KAC23';
UPDATE T_E_Services SET UPN = 'jbulava@lasallest.com'     WHERE lasalle_st_ID = '0KAC23';
UPDATE T_E_Services SET UPN = 'n.kholdebarin@lasallest.com' WHERE lasalle_st_ID = '0KAC88';
UPDATE T_E_Services SET UPN = 'dmayer@lasallest.com'      WHERE lasalle_st_ID = '0KAC88';
UPDATE T_E_Services SET UPN = 'fmonte@lasallest.com'      WHERE lasalle_st_ID = '0KA056';
-- Add all remaining users here, or bulk-import from Azure AD.
```

---

## 2. Azure Function App

### 2a. Create the Function App

- **Runtime**: Node 18
- **OS**: Linux
- **Hosting plan**: Consumption or Premium (Premium recommended for VPN access)
- **Region**: Match your SharePoint tenant region

```bash
az functionapp create \
  --resource-group <rg> \
  --name dpp-functions \
  --storage-account <sa> \
  --consumption-plan-location <location> \
  --runtime node \
  --runtime-version 18 \
  --functions-version 4
```

### 2b. Configure App Settings (environment variables)

```bash
az functionapp config appsettings set \
  --resource-group <rg> \
  --name dpp-functions \
  --settings \
    DB_SERVER="your-sql.database.windows.net" \
    DB_NAME="WebReps" \
    DB_USER="<service-account>" \
    DB_PASSWORD="<password>" \
    DB_ENCRYPT="true" \
    DB_TRUST_CERT="false"
```

> **Recommendation**: Use an Azure Key Vault reference instead of plain-text
> passwords — replace `DB_PASSWORD` with
> `@Microsoft.KeyVault(SecretUri=https://...)`

### 2c. Enable App Service Authentication (Easy Auth)

In Azure portal → Function App → Authentication:
1. Add provider: **Microsoft**
2. Choose your AAD tenant
3. Set **Unauthenticated requests** to `HTTP 401`
4. Note the **Application (client) ID** — you need it in step 3c.

### 2d. Network connectivity to SQL Server

If the SQL Server is on-premise or in a private VNet, configure one of:
- **VNet Integration** (Function App → Networking)
- **Hybrid Connections**

---

## 3. SPFx Web Part

### 3a. Build and package

```bash
npm install
npm run ship        # Runs gulp bundle --ship && gulp package-solution --ship
```

The output is in `sharepoint/solution/direct-packaged-products.sppkg`.

### 3b. Update `config/package-solution.json`

Replace the placeholder resource URI with the actual Function App URI:

```json
"webApiPermissionRequests": [
  {
    "resource": "https://dpp-functions.azurewebsites.net",
    "scope": "user_impersonation"
  }
]
```

> The `resource` value must exactly match the **Application ID URI** of the
> AAD app registration created by Easy Auth (step 2c).

### 3c. Deploy to SharePoint App Catalog

1. Upload `direct-packaged-products.sppkg` to the tenant App Catalog.
2. In the SharePoint Admin Center → API access, **approve** the
   `user_impersonation` request for `dpp-functions`.
3. Add the web part to any SharePoint page.

### 3d. Configure the web part property

Open the property pane and set **Azure Function App Base URL** to the Function
App URL, e.g. `https://dpp-functions.azurewebsites.net`.

---

## 4. GitHub Actions — daily sync (optional)

The sync workflow is only required if you maintain a SharePoint List cache or a
staging table.  If the Function App queries the SQL Server directly on every
request, skip this section.

### 4a. Secrets required

| Secret | Description |
|--------|-------------|
| `AZURE_CLIENT_ID` | Client ID of the service principal |
| `AZURE_TENANT_ID` | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |
| `DPP_SYNC_FUNCTION_URL` | HTTPS URL of the sync HTTP trigger function |

### 4b. Federated credential (OIDC)

```bash
az ad app federated-credential create \
  --id <app-id> \
  --parameters '{
    "name": "github-dpp-sync",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:dannymayer/DirectPackagedProds:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

---

## 5. Permission model reference

| User type | Records shown |
|-----------|---------------|
| Normal rep | Only `lasalle_st_ID = <their own ID>` |
| Rep with sub-reps | Same + can filter by any of their RR# numbers |
| DPP Admin (standard) | All records via `vwDIRECT_PKG_PRODS_ADM` |
| Special admin `0KK003` | All records where `lasalle_st_ID LIKE '0KK%'` |
| Special admin `0KAA45` | Records for `0KAA45`, `0KAA53`, `0KAA64` |

Permission decisions are made **entirely server-side** in `api/shared/permissionHelper.ts`.
The web part never receives data for reps the authenticated user is not
authorised to view.

---

## 6. Project structure

```
DirectPackagedProds/
├── api/                          ← Azure Functions (Node/TypeScript)
│   ├── GetUser/                  ← GET /api/dpp/user
│   ├── GetMonths/                ← GET /api/dpp/months
│   ├── GetRecords/               ← GET /api/dpp/records
│   ├── GetReps/                  ← GET /api/dpp/reps
│   ├── shared/
│   │   ├── auth.ts               ← Easy Auth UPN extraction
│   │   ├── db.ts                 ← SQL Server connection pool
│   │   └── permissionHelper.ts  ← 3-tier permission + SQL query helpers
│   ├── host.json
│   ├── local.settings.json.example
│   ├── package.json
│   └── tsconfig.json
│
├── src/webparts/directPkgProds/  ← SPFx web part (React/TypeScript)
│   ├── DirectPkgProdsWebPart.ts  ← Entry point, acquires AAD token
│   ├── DirectPkgProdsWebPart.manifest.json
│   ├── components/
│   │   ├── DirectPkgProds.tsx    ← Root component, state management
│   │   ├── DppFilters.tsx        ← Month/rep/search filter bar
│   │   ├── DppGrid.tsx           ← Data table with subtotals
│   │   └── DirectPkgProds.module.css
│   └── services/
│       └── DppApiService.ts      ← Typed wrappers for all API endpoints
│
├── config/
│   ├── package-solution.json     ← SPFx solution + API permissions
│   └── serve.json
│
├── .github/workflows/
│   └── sync-dpp-data.yml         ← Daily data-sync trigger
│
├── DirectPkgProds.asp            ← Original ASP page (reference only)
├── gulpfile.js
├── package.json                  ← SPFx root dependencies
├── tsconfig.json
└── SETUP.md                      ← This file
```
