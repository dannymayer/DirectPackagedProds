import * as React from 'react';
import styles from './DirectPkgProds.module.css';
import { DppMonth, DppRep, DppUser } from '../services/DppApiService';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface FilterState {
  myId: number | undefined;
  repnum: string;
  searchType: string;
  searchVal: string;
  sort: string;
  direction: string;
  viewAsAdmin: boolean;
}

export interface IDppFiltersProps {
  user: DppUser | null;
  months: DppMonth[];
  reps: DppRep[];
  filters: FilterState;
  loadingRecords: boolean;
  onChange: (newFilters: Partial<FilterState>) => void;
  onExport: () => void;
}

// ---------------------------------------------------------------------------
// Search types that require a free-text input
// ---------------------------------------------------------------------------
const TEXT_SEARCH_TYPES = new Set(['fnd', 'cus', 'tdt', 'spn']);

/**
 * Filter bar — mirrors the controls at the top of the original ASP page:
 *   • Month/year dropdown
 *   • Admin-view toggle (DPP Admins only)
 *   • Rep selector (admins or reps with sub-reps)
 *   • Sub-rep / RR# filter
 *   • Batch-type filter + free-text search
 *   • Export to Excel
 */
const DppFilters: React.FC<IDppFiltersProps> = ({
  user,
  months,
  reps,
  filters,
  loadingRecords,
  onChange,
  onExport,
}) => {
  const needsText = TEXT_SEARCH_TYPES.has(filters.searchType);

  const handleSearchTypeChange = (
    e: React.ChangeEvent<HTMLSelectElement>,
  ): void => {
    const newType = e.target.value;
    onChange({
      searchType: newType,
      // Clear the text value when switching to a non-text filter
      searchVal: TEXT_SEARCH_TYPES.has(newType) ? filters.searchVal : '',
    });
  };

  const handleSearchSubmit = (e: React.FormEvent): void => {
    e.preventDefault();
    onChange({});
  };

  return (
    <div className={styles.filtersBar}>
      {/* ---- Month selector ---- */}
      <label className={styles.filterLabel} htmlFor="dpp-month">
        Period:
      </label>
      <select
        id="dpp-month"
        className={styles.select}
        value={filters.myId ?? ''}
        disabled={loadingRecords}
        onChange={(e) =>
          onChange({ myId: e.target.value ? parseInt(e.target.value, 10) : undefined })
        }
      >
        {months.map((m) => (
          <option key={m.myId} value={m.myId}>
            {m.label}
          </option>
        ))}
      </select>

      {/* ---- Admin-view toggle (DPP Admins only) ---- */}
      {user?.isDppAdmin && (
        <>
          <span className={styles.separator} />
          <label className={styles.filterLabel} htmlFor="dpp-admin-view">
            View:
          </label>
          <select
            id="dpp-admin-view"
            className={styles.select}
            value={filters.viewAsAdmin ? 'admin' : 'rep'}
            disabled={loadingRecords}
            onChange={(e) => onChange({ viewAsAdmin: e.target.value === 'admin' })}
          >
            <option value="rep">{user.repName || 'My Records'}</option>
            <option value="admin">Admin (All Reps)</option>
          </select>
        </>
      )}

      {/* ---- Sub-rep / RR# filter (only shown when reps list is non-trivial) ---- */}
      {reps.length > 0 && (
        <>
          <span className={styles.separator} />
          <label className={styles.filterLabel} htmlFor="dpp-repnum">
            Filter RR#:
          </label>
          <select
            id="dpp-repnum"
            className={styles.select}
            value={filters.repnum}
            disabled={loadingRecords}
            onChange={(e) => onChange({ repnum: e.target.value })}
          >
            <option value="all">All</option>
            {reps.map((r) => (
              <option key={r.repNum} value={r.repNum}>
                {r.repNum} ({r.description} / {r.sharePct}%)
              </option>
            ))}
          </select>
        </>
      )}

      {/* ---- Batch / search type + text input ---- */}
      <span className={styles.separator} />
      <label className={styles.filterLabel} htmlFor="dpp-search-type">
        Filter by:
      </label>
      <form
        className={styles.searchForm}
        onSubmit={handleSearchSubmit}
        aria-label="Search filters"
      >
        <select
          id="dpp-search-type"
          className={styles.select}
          value={filters.searchType}
          disabled={loadingRecords}
          onChange={handleSearchTypeChange}
        >
          <option value="all">Show All</option>
          <option value="trl">Trails</option>
          <option value="mut">Mutuals</option>
          <option value="ins">Insurance</option>
          <option value="fnd">Fund</option>
          <option value="cus">Customer</option>
          <option value="tdt">Trade Date</option>
          <option value="spn">Spon Acct</option>
        </select>

        {needsText && (
          <>
            <input
              className={styles.textInput}
              type="text"
              aria-label="Search value"
              value={filters.searchVal}
              disabled={loadingRecords}
              onChange={(e) => onChange({ searchVal: e.target.value })}
              onKeyDown={(e) => {
                if (e.key === 'Enter') onChange({});
              }}
            />
            <button
              className={styles.button}
              type="submit"
              disabled={loadingRecords}
            >
              Search
            </button>
          </>
        )}
      </form>

      {/* ---- Export ---- */}
      <span className={styles.separator} />
      <button
        className={styles.button}
        type="button"
        disabled={loadingRecords}
        onClick={onExport}
      >
        Export to Excel
      </button>
    </div>
  );
};

export default DppFilters;
