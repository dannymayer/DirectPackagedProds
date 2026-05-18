import { AzureFunction, Context, HttpRequest } from '@azure/functions';
import { extractUpn } from '../shared/auth';
import { resolveUserPermissions } from '../shared/permissionHelper';

/**
 * GET /api/dpp/user
 *
 * Returns the authenticated user's rep identity and admin tier.
 * The SPFx web part calls this on load to determine which controls to render.
 */
const httpTrigger: AzureFunction = async (
  context: Context,
  req: HttpRequest,
): Promise<void> => {
  try {
    const upn = extractUpn(req.headers as Record<string, string | undefined>);
    const perms = await resolveUserPermissions(upn);

    context.res = {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        lasalleStId: perms.lasalleStId,
        repName: perms.repName,
        isDppAdmin: perms.isDppAdmin,
        specialAdminType: perms.specialAdminType,
      }),
    };
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Internal server error';
    const status =
      err instanceof Error && err.message.startsWith('No active rep') ? 403 : 500;
    context.log.error('GetUser error:', message);
    context.res = {
      status,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ error: message }),
    };
  }
};

export default httpTrigger;
