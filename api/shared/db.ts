/**
 * SQL Server connection pool singleton.
 *
 * Configuration is driven entirely by environment variables so no credentials
 * are ever committed to source control.  See local.settings.json.example for
 * the full list of variables required.
 */
import * as sql from 'mssql';

const poolConfig: sql.config = {
  server: process.env['DB_SERVER'] as string,
  database: process.env['DB_NAME'] || 'WebReps',
  user: process.env['DB_USER'],
  password: process.env['DB_PASSWORD'],
  options: {
    encrypt: process.env['DB_ENCRYPT'] !== 'false',
    trustServerCertificate: process.env['DB_TRUST_CERT'] === 'true',
    enableArithAbort: true,
  },
  pool: {
    max: 10,
    min: 0,
    idleTimeoutMillis: 30_000,
  },
  requestTimeout: 30_000,
  connectionTimeout: 15_000,
};

let pool: sql.ConnectionPool | null = null;

/**
 * Returns (or lazily creates) the shared connection pool.
 * Safe to call on every request — the pool is reused across warm invocations.
 */
export async function getPool(): Promise<sql.ConnectionPool> {
  if (!pool || !pool.connected) {
    pool = await new sql.ConnectionPool(poolConfig).connect();
  }
  return pool;
}
