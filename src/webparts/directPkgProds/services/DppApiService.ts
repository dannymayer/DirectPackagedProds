import { AadHttpClient, HttpClientResponse } from '@microsoft/sp-http';

// ---------------------------------------------------------------------------
// Shared DTOs (must match the API response shapes)
// ---------------------------------------------------------------------------

export interface DppUser {
  lasalleStId: string;
  repName: string;
  isDppAdmin: boolean;
  specialAdminType: 'kk003' | 'kaa45' | null;
}

export interface DppMonth {
  myId: number;
  month: string;
  year: string;
  label: string;
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

export interface DppRep {
  repNum: string;
  description: string;
  sharePct: number;
}

export interface RecordQueryParams {
  myId?: number;
  repnum?: string;
  searchType?: string;
  searchVal?: string;
  sort?: string;
  direction?: string;
  viewAsAdmin?: boolean;
}

// ---------------------------------------------------------------------------
// Service class
// ---------------------------------------------------------------------------

/**
 * Wraps all HTTP calls to the Azure Functions API.
 *
 * Every request is made via AadHttpClient which automatically attaches the
 * user's AAD access token in the Authorization header.  The Function App's
 * Easy Auth layer validates the token before any function code runs.
 */
export class DppApiService {
  constructor(
    private readonly apiBaseUrl: string,
    private readonly aadClient: AadHttpClient,
  ) {}

  private async getJson<T>(path: string): Promise<T> {
    const url = `${this.apiBaseUrl}/api/${path}`;
    const response: HttpClientResponse = await this.aadClient.get(
      url,
      AadHttpClient.configurations.v1,
    );

    if (!response.ok) {
      const text = await response.text();
      throw new Error(`API error ${response.status} from ${path}: ${text}`);
    }

    return (await response.json()) as T;
  }

  /** Resolves the current user's rep identity and admin tier. */
  public getUser(): Promise<DppUser> {
    return this.getJson<DppUser>('dpp/user');
  }

  /** Returns the last 13 available month/year pairs. */
  public async getMonths(): Promise<DppMonth[]> {
    const data = await this.getJson<{ months: DppMonth[] }>('dpp/months');
    return data.months;
  }

  /** Returns filtered/sorted DPP records for the authenticated user. */
  public async getRecords(params: RecordQueryParams): Promise<DppRecord[]> {
    const qs = new URLSearchParams();
    if (params.myId != null) qs.set('myId', String(params.myId));
    if (params.repnum)    qs.set('repnum', params.repnum);
    if (params.searchType) qs.set('searchType', params.searchType);
    if (params.searchVal)  qs.set('searchVal', params.searchVal);
    if (params.sort)       qs.set('sort', params.sort);
    if (params.direction)  qs.set('direction', params.direction);
    if (params.viewAsAdmin) qs.set('viewAsAdmin', 'true');

    const data = await this.getJson<{ records: DppRecord[] }>(
      `dpp/records?${qs.toString()}`,
    );
    return data.records;
  }

  /** Returns the rep/sub-rep RR# list the user may filter by. */
  public async getReps(viewAsAdmin?: boolean): Promise<DppRep[]> {
    const qs = new URLSearchParams();
    if (viewAsAdmin) qs.set('viewAsAdmin', 'true');
    const data = await this.getJson<{ reps: DppRep[] }>(
      `dpp/reps?${qs.toString()}`,
    );
    return data.reps;
  }
}
