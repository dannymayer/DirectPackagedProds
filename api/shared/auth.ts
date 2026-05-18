/**
 * AAD / Azure App Service "Easy Auth" helpers.
 *
 * When Azure App Service Authentication is enabled on the Function App, every
 * authenticated request includes an `x-ms-client-principal` header that
 * contains a base-64-encoded JSON object with the validated claims.  The
 * function code never has to validate the JWT itself — that is done by the
 * Azure runtime before the function is invoked.
 *
 * Documentation:
 *   https://learn.microsoft.com/en-us/azure/app-service/configure-authentication-user-identities
 */

export interface ClientPrincipalClaim {
  typ: string;
  val: string;
}

export interface ClientPrincipal {
  identityProvider: string;
  userId: string;
  userDetails: string;
  userRoles: string[];
  claims: ClientPrincipalClaim[];
}

/**
 * Ordered list of AAD claim types that may contain the user's UPN / email.
 * The first matching non-empty value is returned.
 */
const UPN_CLAIM_TYPES = [
  'preferred_username',
  'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn',
  'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress',
  'unique_name',
  'upn',
  'email',
];

/**
 * Extracts the authenticated user's UPN from the Easy Auth header.
 *
 * @throws if the header is absent (unauthenticated request) or contains no
 *         recognisable UPN claim.
 */
export function extractUpn(headers: Record<string, string | string[] | undefined>): string {
  const raw = headers['x-ms-client-principal'];
  if (!raw) {
    throw new Error(
      'No x-ms-client-principal header found. ' +
        'Ensure Azure App Service Authentication (Easy Auth) is enabled on the Function App.',
    );
  }

  const headerValue = Array.isArray(raw) ? raw[0] : raw;
  let principal: ClientPrincipal;
  try {
    principal = JSON.parse(Buffer.from(headerValue, 'base64').toString('utf-8')) as ClientPrincipal;
  } catch {
    throw new Error('Failed to decode x-ms-client-principal header.');
  }

  for (const claimType of UPN_CLAIM_TYPES) {
    const claim = principal.claims?.find((c) => c.typ === claimType);
    if (claim?.val) {
      return claim.val.toLowerCase();
    }
  }

  // Final fallback — userDetails is often the email in AAD provider
  if (principal.userDetails) {
    return principal.userDetails.toLowerCase();
  }

  throw new Error('Could not determine UPN from authentication token claims.');
}
