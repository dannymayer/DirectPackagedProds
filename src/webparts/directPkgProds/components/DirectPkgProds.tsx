import * as React from 'react';
import styles from './DirectPkgProds.module.css';
import {
  DppApiService,
  DppMonth,
  DppRecord,
  DppRep,
  DppUser,
} from '../services/DppApiService';
import DppFilters, { FilterState } from './DppFilters';
import DppGrid from './DppGrid';

export interface IDirectPkgProdsProps {
  apiService: DppApiService | undefined;
  isConfigured: boolean;
}

interface State {
  user: DppUser | null;
  months: DppMonth[];
  reps: DppRep[];
  records: DppRecord[];
  filters: FilterState;
  loading: boolean;
  loadingRecords: boolean;
  error: string | null;
}

const DEFAULT_FILTERS: FilterState = {
  myId: undefined,
  repnum: 'all',
  searchType: 'all',
  searchVal: '',
  sort: 'cust',
  direction: 'ASC',
  viewAsAdmin: false,
};

/**
 * Root component for the Direct Packaged Products SharePoint web part.
 *
 * On mount it loads the user identity, available months, and accessible reps
 * in parallel.  Whenever filter/sort state changes it fetches fresh records
 * from the API.  All permission enforcement happens on the server — this
 * component only renders what the API returns.
 */
export default class DirectPkgProds extends React.Component<IDirectPkgProdsProps, State> {
  public constructor(props: IDirectPkgProdsProps) {
    super(props);
    this.state = {
      user: null,
      months: [],
      reps: [],
      records: [],
      filters: { ...DEFAULT_FILTERS },
      loading: true,
      loadingRecords: false,
      error: null,
    };
  }

  public async componentDidMount(): Promise<void> {
    if (!this.props.apiService) {
      this.setState({ loading: false });
      return;
    }

    try {
      const [user, months] = await Promise.all([
        this.props.apiService.getUser(),
        this.props.apiService.getMonths(),
      ]);

      // Default to the most recent month
      const defaultMyId = months.length > 0 ? months[0].myId : undefined;
      const initialFilters: FilterState = { ...DEFAULT_FILTERS, myId: defaultMyId };

      // Load accessible reps (use viewAsAdmin=false initially)
      const reps = await this.props.apiService.getReps(false);

      this.setState({ user, months, reps, filters: initialFilters, loading: false }, () => {
        void this.fetchRecords();
      });
    } catch (err: unknown) {
      this.setState({
        loading: false,
        error: err instanceof Error ? err.message : 'Failed to load user data.',
      });
    }
  }

  private async fetchRecords(): Promise<void> {
    if (!this.props.apiService) return;
    this.setState({ loadingRecords: true });
    try {
      const { filters } = this.state;
      const records = await this.props.apiService.getRecords({
        myId: filters.myId,
        repnum: filters.repnum,
        searchType: filters.searchType !== 'all' ? filters.searchType : undefined,
        searchVal: filters.searchVal || undefined,
        sort: filters.sort,
        direction: filters.direction,
        viewAsAdmin: filters.viewAsAdmin,
      });
      this.setState({ records, loadingRecords: false });
    } catch (err: unknown) {
      this.setState({
        loadingRecords: false,
        error: err instanceof Error ? err.message : 'Failed to load records.',
      });
    }
  }

  private readonly handleFiltersChange = (
    newFilters: Partial<FilterState>,
  ): void => {
    const updated = { ...this.state.filters, ...newFilters };
    const viewAsAdminChanged =
      newFilters.viewAsAdmin !== undefined &&
      newFilters.viewAsAdmin !== this.state.filters.viewAsAdmin;

    if (viewAsAdminChanged && this.props.apiService) {
      const apiService = this.props.apiService;
      this.setState({ filters: updated }, () => {
        apiService
          .getReps(updated.viewAsAdmin)
          .then((reps) => {
            this.setState({ reps, filters: { ...this.state.filters, repnum: 'all' } }, () => {
              void this.fetchRecords();
            });
          })
          .catch((err: unknown) => {
            this.setState({
              error: err instanceof Error ? err.message : 'Failed to load reps.',
            });
          });
      });
    } else {
      this.setState({ filters: updated }, () => {
        void this.fetchRecords();
      });
    }
  };

  private readonly handleExport = (): void => {
    const { records } = this.state;
    if (records.length === 0) return;

    const header = ['Rep#', 'Fund', 'Type', 'Customer', 'Invest', 'Total', 'T-Date', 'Spon Acct', 'I/T'];
    const rows = records.map((r) => [
      r.repNum,
      r.fundName,
      r.batch,
      r.customer,
      r.invest != null ? r.invest.toFixed(2) : '',
      r.comm != null ? r.comm.toFixed(2) : '',
      r.tradeDate,
      r.sponAcct,
      r.type,
    ]);

    const csv = [header, ...rows]
      .map((row) => row.map((v) => `"${String(v).replace(/"/g, '""')}"`).join(','))
      .join('\r\n');

    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `DPP_${this.state.filters.myId ?? 'export'}.csv`;
    link.click();
    URL.revokeObjectURL(url);
  };

  public render(): React.ReactElement {
    const { user, months, reps, records, filters, loading, loadingRecords, error } =
      this.state;

    if (!this.props.isConfigured) {
      return (
        <div className={styles.container}>
          <p className={styles.notice}>
            Please configure the web part — enter the Azure Function App URL in
            the property pane.
          </p>
        </div>
      );
    }

    if (loading) {
      return (
        <div className={styles.container}>
          <div className={styles.spinner} aria-label="Loading…" role="status" />
        </div>
      );
    }

    if (error) {
      return (
        <div className={styles.container}>
          <p className={styles.errorText}>{error}</p>
        </div>
      );
    }

    return (
      <div className={styles.container}>
        <DppFilters
          user={user}
          months={months}
          reps={reps}
          filters={filters}
          loadingRecords={loadingRecords}
          onChange={this.handleFiltersChange}
          onExport={this.handleExport}
        />
        <DppGrid
          records={records}
          sortType={filters.sort}
          direction={filters.direction}
          loading={loadingRecords}
          onSortChange={(sort, direction) =>
            this.handleFiltersChange({ sort, direction })
          }
        />
      </div>
    );
  }
}
