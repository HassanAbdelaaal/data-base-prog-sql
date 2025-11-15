const sql = require('mssql');

const config = {
    user: 'sa',
    password: 'McCool091005',
    server: 'localhost',
    port: 1433,
    database: 'DB_Prog',  // Changed from 'MoviesDB' to 'DB_Prog'
    options: {
        encrypt: true,
        trustServerCertificate: true,
        enableArithAbort: true
    },
    pool: {
        max: 10,
        min: 0,
        idleTimeoutMillis: 30000
    }
};

async function connectDB() {
    try {
        await sql.connect(config);
        console.log('✅ Connected to SQL Server');
        return true;
    } catch (err) {
        console.error('❌ Database connection failed:', err);
        console.error('Error details:', err.message);
        return false;
    }
}

module.exports = { sql, connectDB };