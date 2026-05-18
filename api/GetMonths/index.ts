import { AzureFunction, Context, HttpRequest } from '@azure/functions';
import { extractUpn } from '../shared/auth';
import { queryMonths } from '../shared/permissionHelper';

/**
 * GET /api/dpp/months
 *
 * Returns the last 13 available month/year entries from
 * vwDIRECT_PKG_PRODS_MONTHS, used to populate the month selector dropdown.
 * Any authenticated user may call this endpoint.
 */
const httpTrigger: AzureFunction = async (
  context: Context,
  req: HttpRequest,
): Promise<void> => {
  try {
    // Ensure the caller is authenticated (UPN extraction will throw if not)
    extractUpn(req.headers as Record<string, string | undefined>);

    const months = await queryMonths();

    context.res = {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ months }),
    };
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Internal server error';
    context.log.error('GetMonths error:', message);
    context.res = {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ error: message }),
    };
  }
};

export default httpTrigger;
