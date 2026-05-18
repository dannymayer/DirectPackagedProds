import { AzureFunction, Context, HttpRequest } from '@azure/functions';
import { extractUpn } from '../shared/auth';
import {
  resolveUserPermissions,
  queryRecords,
  queryMonthById,
} from '../shared/permissionHelper';

/**
 * GET /api/dpp/records
 *
 * Query parameters (all optional):
 *   myId         — integer; resolves to the month/year pair for filtering
 *   repnum       — sub-rep RR# to filter to (or "all")
 *   searchType   — trl | mut | ins | fnd | cus | tdt | spn
 *   searchVal    — free-text value used with fnd / cus / tdt / spn
 *   sort         — rep | fund | type | cust | inv | comm | spon
 *   direction    — ASC | DESC
 *   viewAsAdmin  — "true" to use admin view (ignored for non-admins)
 *
 * Permission enforcement is entirely server-side.  The base WHERE clause and
 * table name are determined by the authenticated user's permission tier — not
 * by any query parameter.
 */
const httpTrigger: AzureFunction = async (
  context: Context,
  req: HttpRequest,
): Promise<void> => {
  try {
    const upn = extractUpn(req.headers as Record<string, string | undefined>);
    const perms = await resolveUserPermissions(upn);

    // Resolve month/year from myId if supplied
    let month: string | undefined;
    let year: string | undefined;
    const myIdRaw = req.query['myId'];
    if (myIdRaw) {
      const myId = parseInt(myIdRaw, 10);
      if (!isNaN(myId)) {
        const resolved = await queryMonthById(myId);
        if (resolved) {
          month = resolved.month;
          year = resolved.year;
        }
      }
    }

    // viewAsAdmin is only honoured when the user is actually a DPP Admin
    const viewAsAdmin = req.query['viewAsAdmin'] === 'true' && perms.isDppAdmin;

    const records = await queryRecords(perms, {
      month,
      year,
      repnum: req.query['repnum'],
      searchType: req.query['searchType'],
      searchVal: req.query['searchVal'],
      sortType: req.query['sort'],
      direction: req.query['direction'],
      viewAsAdmin,
    });

    context.res = {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ records }),
    };
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Internal server error';
    const status =
      err instanceof Error && err.message.startsWith('No active rep') ? 403 : 500;
    context.log.error('GetRecords error:', message);
    context.res = {
      status,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ error: message }),
    };
  }
};

export default httpTrigger;
