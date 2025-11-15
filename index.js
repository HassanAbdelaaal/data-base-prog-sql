const express = require('express');
const bodyParser = require('body-parser');
const { sql, connectDB } = require('./db');
const open = require('open');

const app = express();
const PORT = 3000;

// Middleware
app.use(express.static('public'));
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Get all movies
app.get('/api/movies', async (req, res) => {
    try {
        const result = await sql.query`SELECT * FROM UserMovies ORDER BY dateAdded DESC`;
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Add a movie
app.post('/api/movies', async (req, res) => {
    try {
        const { userName, movieName, genre, rating } = req.body;
        
        await sql.query`
            INSERT INTO UserMovies (userName, movieName, genre, rating)
            VALUES (${userName}, ${movieName}, ${genre}, ${rating})
        `;
        
        res.json({ success: true, message: 'Movie added successfully!' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Delete a movie
app.delete('/api/movies/:id', async (req, res) => {
    try {
        const { id } = req.params;
        await sql.query`DELETE FROM UserMovies WHERE id = ${id}`;
        res.json({ success: true, message: 'Movie deleted successfully!' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Start server
async function startServer() {
    // Connect to database first
    const connected = await connectDB();
    
    if (!connected) {
        console.error('❌ Failed to connect to database. Please check your configuration.');
        process.exit(1);
    }
    
    // Start the server
    app.listen(PORT, () => {
        console.log(`🚀 Server running at http://localhost:${PORT}`);
        console.log('📊 Database connected successfully');
        console.log('🌐 Opening browser...');
        
        
    });
}

startServer();
