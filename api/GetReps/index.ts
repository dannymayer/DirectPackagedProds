import { AzureFunction, Context, HttpRequest } from '@azure/functions';
import { extractUpn } from '../shared/auth';
import { resolveUserPermissions, queryReps } from '../shared/permissionHelper';

/**
 * GET /api/dpp/reps
 *
 * Query parameters:
 *   viewAsAdmin — "true" to return the admin rep list (ignored for non-admins)
 *
 * Returns the list of rep/sub-rep RR# entries the caller is allowed to filter
 * by.  This drives the "Filter RR#s" dropdown in the web part.
 */
const httpTrigger: AzureFunction = async (
  context: Context,
  req: HttpRequest,
): Promise<void> => {
  try {
    const upn = extractUpn(req.headers as Record<string, string | undefined>);
    const perms = await resolveUserPermissions(upn);

    const viewAsAdmin = req.query['viewAsAdmin'] === 'true' && perms.isDppAdmin;
    const reps = await queryReps(perms, viewAsAdmin);

    context.res = {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ reps }),
    };
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Internal server error';
    const status =
      err instanceof Error && err.message.startsWith('No active rep') ? 403 : 500;
    context.log.error('GetReps error:', message);
    context.res = {
      status,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ error: message }),
    };
  }
};

export default httpTrigger;
