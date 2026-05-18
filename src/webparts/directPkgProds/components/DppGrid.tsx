import * as React from 'react';
import styles from './DirectPkgProds.module.css';
import { DppRecord } from '../services/DppApiService';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface IDppGridProps {
  records: DppRecord[];
  sortType: string;
  direction: string;
  loading: boolean;
  onSortChange: (sort: string, direction: string) => void;
}

interface ColDef {
  key: string;
  label: string;
  sortKey: string | null;
  align: 'left' | 'center' | 'right';
  render: (r: DppRecord) => React.ReactNode;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function formatCurrency(value: number | null): string {
  if (value == null) return '';
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 2,
  }).format(value);
}

/** Column definitions — order mirrors the original ASP page. */
const COLUMNS: ColDef[] = [
  {
    key: 'repNum',
    label: 'Rep#',
    sortKey: 'rep',
    align: 'left',
    render: (r) => r.repNum,
  },
  {
    key: 'fundName',
    label: 'Fund',
    sortKey: 'fund',
    align: 'center',
    render: (r) => r.fundName,
  },
  {
    key: 'batch',
    label: 'Type',
    sortKey: 'type',
    align: 'center',
    render: (r) => r.batch,
  },
  {
    key: 'customer',
    label: 'Customer',
    sortKey: 'cust',
    align: 'center',
    render: (r) => r.customer,
  },
  {
    key: 'invest',
    label: 'Invest',
    sortKey: 'inv',
    align: 'right',
    render: (r) => formatCurrency(r.invest),
  },
  {
    key: 'comm',
    label: 'Total',
    sortKey: 'comm',
    align: 'right',
    render: (r) => formatCurrency(r.comm),
  },
  {
    key: 'tradeDate',
    label: 'T-Date',
    sortKey: null, // T-Date sort is intentionally disabled in the original
    align: 'center',
    render: (r) => r.tradeDate,
  },
  {
    key: 'sponAcct',
    label: 'Spon Acct',
    sortKey: 'spon',
    align: 'center',
    render: (r) => r.sponAcct,
  },
  {
    key: 'type',
    label: 'I/T',
    sortKey: null,
    align: 'center',
    render: (r) => r.type,
  },
];

// ---------------------------------------------------------------------------
// SortHeader helper component
// ---------------------------------------------------------------------------

interface ISortHeaderProps {
  col: ColDef;
  currentSortKey: string;
  direction: string;
  onSortChange: (sort: string, direction: string) => void;
}

const SortHeader: React.FC<ISortHeaderProps> = ({
  col,
  currentSortKey,
  direction,
  onSortChange,
}) => {
  if (!col.sortKey) {
    return <th className={`${styles.th} ${styles.thCenter}`}>{col.label}</th>;
  }

  const isActive = currentSortKey === col.sortKey;
  const nextDir = isActive && direction === 'ASC' ? 'DESC' : 'ASC';

  return (
    <th className={`${styles.th} ${styles.thCenter}`}>
      <button
        className={styles.sortBtn}
        type="button"
        onClick={() => onSortChange(col.sortKey as string, 'ASC')}
        title={`Sort by ${col.label} ascending`}
        aria-label={`Sort ${col.label} ascending`}
      >
        ▲
      </button>
      <span
        className={isActive ? styles.sortLabelActive : styles.sortLabel}
        onClick={() => onSortChange(col.sortKey as string, nextDir)}
        role="button"
        tabIndex={0}
        onKeyDown={(e) => {
          if (e.key === 'Enter' || e.key === ' ') {
            onSortChange(col.sortKey as string, nextDir);
          }
        }}
        aria-sort={isActive ? (direction === 'ASC' ? 'ascending' : 'descending') : 'none'}
      >
        {col.label}
      </span>
      <button
        className={styles.sortBtn}
        type="button"
        onClick={() => onSortChange(col.sortKey as string, 'DESC')}
        title={`Sort by ${col.label} descending`}
        aria-label={`Sort ${col.label} descending`}
      >
        ▼
      </button>
    </th>
  );
};

// ---------------------------------------------------------------------------
// Main grid component
// ---------------------------------------------------------------------------

/**
 * Data table — mirrors the original ASP table including:
 *   • Alternating row colours
 *   • Alphabetical section headers when sorted by Customer
 *   • Per-rep subtotal rows when sorted by Rep#
 *   • Grand total row
 */
const DppGrid: React.FC<IDppGridProps> = ({
  records,
  sortType,
  direction,
  loading,
  onSortChange,
}) => {
  if (loading) {
    return (
      <div className={styles.loadingOverlay} role="status" aria-label="Loading records…">
        <div className={styles.spinner} />
      </div>
    );
  }

  if (records.length === 0) {
    return (
      <p className={styles.noRecords}>
        Sorry, no records were found for the selected criteria. Please try your
        search again.
      </p>
    );
  }

  // ---------------------------------------------------------------------------
  // Build rows with injected section-headers and rep-total rows
  // ---------------------------------------------------------------------------

  type GridRow =
    | { kind: 'alpha'; char: string }
    | { kind: 'repTotal'; rep: string; total: number }
    | { kind: 'record'; record: DppRecord; stripe: boolean };

  const rows: GridRow[] = [];
  let grandTotal = 0;
  let lastAlpha = '';
  let lastRep = records.length > 0 ? records[0].repNum : '';
  let repTotal = 0;
  let stripe = false;

  records.forEach((rec, idx) => {
    // --- Alphabetical section dividers (Customer sort only) ---
    if (sortType === 'cust') {
      const firstChar = rec.customer ? rec.customer[0].toUpperCase() : '#';
      if (firstChar !== lastAlpha) {
        rows.push({ kind: 'alpha', char: firstChar });
        lastAlpha = firstChar;
        stripe = false; // reset stripe after section header
      }
    }

    // --- Rep subtotal (Rep sort only) ---
    if (sortType === 'rep') {
      if (idx > 0 && rec.repNum !== lastRep) {
        rows.push({ kind: 'repTotal', rep: lastRep, total: repTotal });
        repTotal = 0;
        stripe = !stripe;
      }
      repTotal += rec.comm ?? 0;
      lastRep = rec.repNum;
    }

    rows.push({ kind: 'record', record: rec, stripe });
    grandTotal += rec.comm ?? 0;
    stripe = !stripe;
  });

  // Final rep subtotal
  if (sortType === 'rep' && records.length > 0) {
    rows.push({ kind: 'repTotal', rep: lastRep, total: repTotal });
  }

  return (
    <div className={styles.tableWrapper}>
      <table className={styles.table} aria-label="Direct Packaged Products">
        <thead>
          <tr>
            {COLUMNS.map((col) => (
              <SortHeader
                key={col.key}
                col={col}
                currentSortKey={sortType}
                direction={direction}
                onSortChange={onSortChange}
              />
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, idx) => {
            if (row.kind === 'alpha') {
              return (
                <tr key={`alpha-${row.char}-${idx}`}>
                  <td
                    colSpan={COLUMNS.length}
                    className={styles.alphaHeader}
                    id={`section-${row.char}`}
                  >
                    <a href="#dpp-top" className={styles.alphaTop}>
                      Top
                    </a>
                    {' '}
                    <strong className={styles.alphaCurrent}>{row.char}</strong>
                  </td>
                </tr>
              );
            }

            if (row.kind === 'repTotal') {
              return (
                <tr key={`reptotal-${row.rep}-${idx}`} className={styles.repTotalRow}>
                  <td className={`${styles.td} ${styles.tdBold}`}>
                    {row.rep} Total:
                  </td>
                  <td className={styles.td} />
                  <td className={styles.td} />
                  <td className={styles.td} />
                  <td className={styles.td} />
                  <td className={`${styles.td} ${styles.tdRight} ${styles.tdBold}`}>
                    {formatCurrency(row.total)}
                  </td>
                  <td className={styles.td} />
                  <td className={styles.td} />
                  <td className={styles.td} />
                </tr>
              );
            }

            // Normal data row
            const { record, stripe: isStripe } = row;
            const rowClass = isStripe ? styles.trStripe : styles.trNormal;
            return (
              <tr key={`rec-${record.id}-${idx}`} className={rowClass}>
                {COLUMNS.map((col) => (
                  <td
                    key={col.key}
                    className={`${styles.td} ${
                      col.align === 'right' ? styles.tdRight : ''
                    } ${col.align === 'center' ? styles.tdCenter : ''}`}
                  >
                    {col.render(record)}
                  </td>
                ))}
              </tr>
            );
          })}

          {/* Grand total row */}
          <tr className={styles.grandTotalRow}>
            <td className={`${styles.td} ${styles.tdBold}`}>Total:</td>
            <td className={styles.td} />
            <td className={styles.td} />
            <td className={styles.td} />
            <td className={styles.td} />
            <td className={`${styles.td} ${styles.tdRight} ${styles.tdBold}`}>
              {formatCurrency(grandTotal)}
            </td>
            <td className={styles.td} />
            <td className={styles.td} />
            <td className={styles.td} />
          </tr>
        </tbody>
      </table>
    </div>
  );
};

export default DppGrid;
