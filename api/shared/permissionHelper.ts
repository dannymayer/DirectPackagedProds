/**
 * Permission helper — the heart of the access-control model.
 *
 * Three permission tiers mirror the original ASP page logic:
 *
 *   1. Normal rep     → sees only rows where lasalle_st_ID = their own ID
 *   2. DPP Admin      → sees all rows via the admin view (vwDIRECT_PKG_PRODS_ADM)
 *   3. Special admins → scoped subsets:
 *        • 0KK003 (Tim Meisenheimer) → lasalle_st_ID LIKE '0KK%'
 *        • 0KAA45 (Pete Kearney)     → lasalle_st_ID IN ('0KAA45','0KAA53','0KAA64')
 *
 * Database prerequisite:
 *   The T_E_Services table must have a UPN column populated with the user's
 *   Azure AD UPN (e.g. john.doe@company.com).  As a fallback, the code also
 *   tries matching the username portion of the UPN against lasalle_st_ID,
 *   which works for reps whose Windows username equals their lasalle_st_ID.
 *   See SETUP.md for the migration script.
 */

import * as sql from 'mssql';
import { getPool } from './db';

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

export interface UserPermissions {
  /** e.g. "0KAC23" */
  lasalleStId: string;
  repName: string;
  isDppAdmin: boolean;
  /** Non-null only for the two hardcoded special-admin IDs */
  specialAdminType: 'kk003' | 'kaa45' | null;
}

export interface RecordQueryParams {
  /** myID value from vwDIRECT_PKG_PRODS_MONTHS — used to resolve month/year */
  myId?: number;
  /** Pre-resolved month string, e.g. "3" */
  month?: string;
  /** Pre-resolved year string, e.g. "2024" */
  year?: string;
  /** Selected sub-rep RR# or "all" */
  repnum?: string;
  /** One of the search-type keys: trl | mut | ins | fnd | cus | tdt | spn */
  searchType?: string;
  /** Free-text search value (user-supplied; parameterised before use) */
  searchVal?: string;
  /** Sort column key: rep | fund | type | cust | inv | comm | spon */
  sortType?: string;
  /** "ASC" or "DESC" */
  direction?: string;
  /** True when an admin explicitly chooses the admin (all-rep) view */
  viewAsAdmin?: boolean;
}

export interface DppRecord {
  id: number;
  repNum: string;
  fundName: string;
  batch: string;
  customer: string;
  invest: number | null;
  comm: number | null;
  tradeDate: string;
  sponAcct: string;
  type: string;
  month: string;
  year: string;
  lasalleStId: string;
  dppAdmin: boolean;
}

// ---------------------------------------------------------------------------
// resolveUserPermissions
// ---------------------------------------------------------------------------

/**
 * Maps an AAD UPN to a lasalle_st_ID and determines the user's admin tier.
 *
 * Lookup order:
 *   1. tes.UPN  (exact match, case-insensitive)
 *   2. tes.lasalle_st_ID  where the username prefix of the UPN matches
 *      (covers reps whose Windows username equals their lasalle_st_ID)
 */
export async function resolveUserPermissions(upn: string): Promise<UserPermissions> {
  const pool = await getPool();

  // Username prefix, e.g. "dmayer" from "dmayer@lasallest.com"
  const usernamePrefix = upn.includes('@') ? upn.split('@')[0] : upn;

  const result = await pool
    .request()
    .input('upn', sql.NVarChar(254), upn)
    .input('usernamePrefix', sql.NVarChar(100), usernamePrefix)
    .query<{ lasalle_st_ID: string; DPP_ADMIN: boolean | number; LASL_NAME: string }>(`
      SELECT TOP 1
        tes.lasalle_st_ID,
        vr.DPP_ADMIN,
        vr.LASL_NAME
      FROM T_E_Services tes
      INNER JOIN vwREPALL vr ON tes.ID = vr.ID
      WHERE vr.LASL_ACTIVCODE = 'Active'
        AND (
          LOWER(tes.UPN) = @upn
          OR LOWER(tes.lasalle_st_ID) = LOWER(@usernamePrefix)
        )
    `);

  if (result.recordset.length === 0) {
    throw new Error(`No active rep found for user: ${upn}`);
  }

  const row = result.recordset[0];
  const lasalleStId: string = row.lasalle_st_ID;
  const isDppAdmin = row.DPP_ADMIN === true || row.DPP_ADMIN === 1;

  let specialAdminType: UserPermissions['specialAdminType'] = null;
  if (isDppAdmin) {
    if (lasalleStId === '0KK003') specialAdminType = 'kk003';
    else if (lasalleStId === '0KAA45') specialAdminType = 'kaa45';
  }

  return {
    lasalleStId,
    repName: row.LASL_NAME || '',
    isDppAdmin,
    specialAdminType,
  };
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

const ALLOWED_SORT_TYPES = new Set(['rep', 'fund', 'type', 'cust', 'inv', 'comm', 'spon']);
const ALLOWED_SEARCH_TYPES = new Set(['trl', 'mut', 'ins', 'fnd', 'cus', 'tdt', 'spn']);

function buildOrderBy(sortType?: string, direction?: string): string {
  const safeSort = ALLOWED_SORT_TYPES.has(sortType ?? '') ? sortType : 'cust';
  const safeDir = direction?.toUpperCase() === 'DESC' ? 'DESC' : 'ASC';
  switch (safeSort) {
    case 'rep':  return `ORDER BY REPNUM ${safeDir}, CUSTOMER ${safeDir}`;
    case 'fund': return `ORDER BY FUND_NAME ${safeDir}, CUSTOMER ${safeDir}`;
    case 'type': return `ORDER BY BATCH ${safeDir}`;
    case 'cust': return `ORDER BY CUSTOMER ${safeDir}`;
    case 'inv':  return `ORDER BY INVEST ${safeDir}, CUSTOMER ${safeDir}`;
    case 'comm': return `ORDER BY COMM ${safeDir}, CUSTOMER ${safeDir}`;
    case 'spon': return `ORDER BY SPON_ACCT ${safeDir}, CUSTOMER ${safeDir}`;
    default:     return 'ORDER BY CUSTOMER ASC';
  }
}

// ---------------------------------------------------------------------------
// queryRecords — main data endpoint
// ---------------------------------------------------------------------------

/**
 * Fetches DPP records for the given user under the given filter/sort params.
 *
 * Security notes:
 *   • Table name and base WHERE clause are selected by server-side permission
 *     logic and are never derived from user-supplied input.
 *   • All user-supplied filter values (repnum, searchVal, month, year) are
 *     passed as named parameters to prevent SQL injection.
 *   • Sort column and direction are whitelist-validated before interpolation.
 */
export async function queryRecords(
  perms: UserPermissions,
  params: RecordQueryParams,
): Promise<DppRecord[]> {
  const pool = await getPool();
  const request = pool.request();
  const viewAsAdmin = !!params.viewAsAdmin && perms.isDppAdmin;

  // --- Base table + WHERE (permission-driven, not user input) ---
  let tableName: string;
  let baseWhere: string;

  if (viewAsAdmin) {
    switch (perms.specialAdminType) {
      case 'kk003':
        // Tim Meisenheimer: all reps whose ID starts with "0KK"
        tableName = 'vwDIRECT_PKG_PRODS';
        baseWhere = "lasalle_st_ID LIKE '0KK%'";
        break;
      case 'kaa45':
        // Pete Kearney: explicit rep list
        tableName = 'vwDIRECT_PKG_PRODS';
        baseWhere = "lasalle_st_ID IN ('0KAA45', '0KAA53', '0KAA64')";
        break;
      default:
        // Standard DPP Admin — full admin view
        tableName = 'vwDIRECT_PKG_PRODS_ADM';
        baseWhere = '1=1';
    }
  } else {
    tableName = 'vwDIRECT_PKG_PRODS';
    request.input('baseRepId', sql.NVarChar(50), perms.lasalleStId);
    baseWhere = 'lasalle_st_ID = @baseRepId';
  }

  // --- Sub-rep (repnum) filter — user-supplied, parameterised ---
  let repnumClause = '';
  if (params.repnum && params.repnum.toLowerCase() !== 'all') {
    request.input('repnum', sql.NVarChar(20), params.repnum);
    repnumClause = ' AND REPNUM = @repnum';
  }

  // --- Month / Year filter — resolved server-side, parameterised ---
  let monthClause = '';
  if (params.month && params.year) {
    request.input('filterMonth', sql.NVarChar(2), params.month);
    request.input('filterYear', sql.NVarChar(4), params.year);
    monthClause = ' AND MONTH = @filterMonth AND YEAR = @filterYear';
  }

  // --- Text search filter — user-supplied values are parameterised ---
  let searchClause = '';
  const safeSearchType = ALLOWED_SEARCH_TYPES.has(params.searchType ?? '')
    ? params.searchType
    : null;

  if (safeSearchType) {
    switch (safeSearchType) {
      // Batch-type filters use static literals — no user input involved
      case 'trl': searchClause = " AND BATCH = 'TRAILS'"; break;
      case 'mut': searchClause = " AND BATCH = 'MUTUALS'"; break;
      case 'ins': searchClause = " AND BATCH = 'INSURANCE'"; break;
      // Free-text filters: wildcard added here, value is parameterised
      case 'fnd':
        request.input('searchVal', sql.NVarChar(200), `%${params.searchVal ?? ''}%`);
        searchClause = ' AND FUND_NAME LIKE @searchVal';
        break;
      case 'cus':
        request.input('searchVal', sql.NVarChar(200), `%${params.searchVal ?? ''}%`);
        searchClause = ' AND CUSTOMER LIKE @searchVal';
        break;
      case 'tdt':
        request.input('searchVal', sql.NVarChar(20), params.searchVal ?? '');
        searchClause = ' AND TRADE_DATE = @searchVal';
        break;
      case 'spn':
        request.input('searchVal', sql.NVarChar(200), `%${params.searchVal ?? ''}%`);
        searchClause = ' AND SPON_ACCT LIKE @searchVal';
        break;
    }
  }

  const orderBy = buildOrderBy(params.sortType, params.direction);

  const querySql = `
    SELECT
      ID, REPNUM, FUND_NAME, BATCH, CUSTOMER,
      INVEST, COMM, TRADE_DATE, SPON_ACCT,
      TYPE, MONTH, YEAR, lasalle_st_ID, DPP_ADMIN
    FROM ${tableName}
    WHERE (${baseWhere})${repnumClause}${monthClause}${searchClause}
    ${orderBy}
  `;

  type RawRow = {
    ID: number; REPNUM: string; FUND_NAME: string; BATCH: string;
    CUSTOMER: string; INVEST: number | null; COMM: number | null;
    TRADE_DATE: Date | string; SPON_ACCT: string; TYPE: string;
    MONTH: string; YEAR: string; lasalle_st_ID: string; DPP_ADMIN: boolean | number;
  };

  const result = await request.query<RawRow>(querySql);

  return result.recordset.map((r) => ({
    id: r.ID,
    repNum: r.REPNUM ?? '',
    fundName: r.FUND_NAME ?? '',
    batch: r.BATCH ?? '',
    customer: r.CUSTOMER ?? '',
    invest: r.INVEST ?? null,
    comm: r.COMM ?? null,
    tradeDate: r.TRADE_DATE ? String(r.TRADE_DATE).split('T')[0] : '',
    sponAcct: r.SPON_ACCT ?? '',
    type: r.TYPE ?? '',
    month: r.MONTH ?? '',
    year: r.YEAR ?? '',
    lasalleStId: r.lasalle_st_ID ?? '',
    dppAdmin: r.DPP_ADMIN === true || r.DPP_ADMIN === 1,
  }));
}

// ---------------------------------------------------------------------------
// queryMonths
// ---------------------------------------------------------------------------

export interface DppMonth {
  myId: number;
  month: string;
  year: string;
  label: string;
}

export async function queryMonths(): Promise<DppMonth[]> {
  const pool = await getPool();
  const result = await pool
    .request()
    .query<{ myID: number; MONTH: string; YEAR: string }>(`
      SELECT TOP 13 myID, MONTH, YEAR
      FROM vwDIRECT_PKG_PRODS_MONTHS
      WHERE MONTH > 0
      ORDER BY YEAR DESC, MONTH DESC
    `);

  return result.recordset.map((r) => ({
    myId: r.myID,
    month: r.MONTH,
    year: r.YEAR,
    label: `${r.MONTH}/${r.YEAR}`,
  }));
}

export async function queryMonthById(myId: number): Promise<{ month: string; year: string } | null> {
  const pool = await getPool();
  const result = await pool
    .request()
    .input('myId', sql.Int, myId)
    .query<{ MONTH: string; YEAR: string }>(
      'SELECT MONTH, YEAR FROM vwDIRECT_PKG_PRODS_MONTHS WHERE myID = @myId',
    );

  return result.recordset.length > 0
    ? { month: result.recordset[0].MONTH, year: result.recordset[0].YEAR }
    : null;
}

// ---------------------------------------------------------------------------
// queryReps
// ---------------------------------------------------------------------------

export interface DppRep {
  repNum: string;
  description: string;
  sharePct: number;
}

/**
 * Returns the list of rep/sub-rep numbers the current user is allowed to
 * filter by.  The SQL differs per permission tier (mirrors the original
 * SelectRep() VBScript subroutine).
 */
export async function queryReps(
  perms: UserPermissions,
  viewAsAdmin: boolean,
): Promise<DppRep[]> {
  const pool = await getPool();
  const request = pool.request();
  let repsSql: string;

  if (viewAsAdmin && perms.isDppAdmin && perms.specialAdminType === null) {
    // Standard admin: pull from DIRECT_PKG_PRODS_REP_LIST (all reps)
    request.input('adminId', sql.NVarChar(50), perms.lasalleStId);
    repsSql = `
      SELECT
        tes.lasalle_st_ID,
        dpl.[Rep Number]  AS repNum,
        'ADMIN'           AS description,
        dpl.Percentage    AS sharePct
      FROM T_E_Services tes
      INNER JOIN vwREPALL vr  ON tes.ID = vr.ID
      INNER JOIN DIRECT_PKG_PRODS_REP_LIST dpl ON vr.LASL_REP_NO = dpl.[Rep Code]
      WHERE vr.DPP_ADMIN = 1
        AND tes.lasalle_st_ID = @adminId
      ORDER BY dpl.[Rep Number]
    `;
  } else if (viewAsAdmin && perms.specialAdminType === 'kk003') {
    // 0KK003: sub-reps for any rep whose ID starts with "0KK"
    repsSql = `
      SELECT
        tes.lasalle_st_ID,
        sr.SHARED_REP_NO AS repNum,
        sr.Description   AS description,
        sr.Share_Pcnt    AS sharePct
      FROM T_E_Services tes
      INNER JOIN vwREPALL vr ON tes.ID = vr.ID
      INNER JOIN T_SUB_RRs sr ON vr.ID = sr.ID
      WHERE tes.lasalle_st_ID LIKE '0KK%'
        AND vr.LASL_ACTIVCODE = 'active'
        AND sr.Share_Pcnt > 0
        AND sr.Description NOT LIKE 'Direct'
      ORDER BY sr.SHARED_REP_NO
    `;
  } else if (viewAsAdmin && perms.specialAdminType === 'kaa45') {
    // 0KAA45: explicit rep group
    repsSql = `
      SELECT
        tes.lasalle_st_ID,
        sr.SHARED_REP_NO AS repNum,
        sr.Description   AS description,
        sr.Share_Pcnt    AS sharePct
      FROM T_E_Services tes
      INNER JOIN vwREPALL vr ON tes.ID = vr.ID
      INNER JOIN T_SUB_RRs sr ON vr.ID = sr.ID
      WHERE tes.lasalle_st_ID IN ('0KAA45', '0KAA53', '0KAA64')
        AND vr.LASL_ACTIVCODE = 'active'
        AND sr.Share_Pcnt > 0
        AND sr.Description NOT LIKE 'Direct'
      ORDER BY sr.SHARED_REP_NO
    `;
  } else {
    // Normal rep: their own sub-reps from T_SUB_RRs
    request.input('repId', sql.NVarChar(50), perms.lasalleStId);
    repsSql = `
      SELECT
        tes.lasalle_st_ID,
        sr.SHARED_REP_NO AS repNum,
        sr.Description   AS description,
        sr.Share_Pcnt    AS sharePct
      FROM T_E_Services tes
      INNER JOIN vwREPALL vr ON tes.ID = vr.ID
      INNER JOIN T_SUB_RRs sr ON vr.ID = sr.ID
      WHERE tes.lasalle_st_ID = @repId
        AND vr.LASL_ACTIVCODE = 'active'
        AND sr.Share_Pcnt > 0
        AND sr.Description NOT LIKE 'Direct'
      ORDER BY sr.SHARED_REP_NO
    `;
  }

  const result = await request.query<{
    repNum: string;
    description: string;
    sharePct: number;
  }>(repsSql);

  return result.recordset.map((r) => ({
    repNum: r.repNum,
    description: r.description,
    // Display fractional splits faithfully (matches original VBScript Select Case)
    sharePct: r.sharePct === 13 ? 13.333 : r.sharePct === 33 ? 33.333 : r.sharePct,
  }));
}
