const sql = require('mssql');

const config = {
  server: process.env.DB_SERVER || 'localhost',
  database: process.env.DB_NAME || 'SecureDental',
  user: process.env.DB_USER || 'dental_app',
  password: process.env.DB_PASSWORD || 'dental_app_password',
  pool: {
    max: 10,
    min: 0,
    idleTimeoutMillis: 30000
  },
  options: {
    instanceName: process.env.DB_INSTANCE || undefined,
    encrypt: process.env.DB_ENCRYPT === 'true',
    trustServerCertificate: process.env.DB_TRUST_SERVER_CERTIFICATE !== 'false'
  }
};

if (process.env.DB_PORT) {
  config.port = Number(process.env.DB_PORT);
}

const connectionPool = new sql.ConnectionPool(config);
const poolPromise = connectionPool.connect();

function normalizeSql(sqlText) {
  // Convert numbered placeholders into named SQL Server parameters.
  return sqlText.replace(/\$(\d+)/g, (_, index) => `@p${index}`);
}

function bindParameters(request, params = []) {
  params.forEach((value, index) => {
    request.input(`p${index + 1}`, value);
  });
}

async function runQuery(requestFactory, sqlText, params = []) {
  const request = requestFactory();
  bindParameters(request, params);
  const result = await request.query(normalizeSql(sqlText));

  return {
    rows: result.recordset || [],
    rowsAffected: result.rowsAffected || []
  };
}

const pool = {
  async query(sqlText, params = []) {
    const poolConnection = await poolPromise;
    return runQuery(() => poolConnection.request(), sqlText, params);
  },

  async close() {
    const poolConnection = await poolPromise;
    await poolConnection.close();
  }
};

async function setSessionContext(transaction, key, value) {
  const request = new sql.Request(transaction);
  request.input('value', value || null);
  await request.query(`EXEC sys.sp_set_session_context @key = N'${key}', @value = @value`);
}

async function withActor(user, ipAddress, callback) {
  const poolConnection = await poolPromise;
  const transaction = new sql.Transaction(poolConnection);

  await transaction.begin();

  try {
    // Store the current actor in SQL Server session context for procedures and audit triggers.
    await setSessionContext(transaction, 'app.current_user_id', user?.user_id || '');
    await setSessionContext(transaction, 'app.current_user_role', user?.role || '');
    await setSessionContext(transaction, 'app.encryption_key', process.env.APP_ENCRYPTION_KEY);
    await setSessionContext(transaction, 'app.ip_address', ipAddress || '127.0.0.1');

    const client = {
      query(sqlText, params = []) {
        return runQuery(() => new sql.Request(transaction), sqlText, params);
      }
    };

    const result = await callback(client);
    await transaction.commit();
    return result;
  } catch (error) {
    await transaction.rollback();
    throw error;
  }
}

module.exports = {
  pool,
  withActor
};
