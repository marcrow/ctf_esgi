// server.js
require('dotenv').config();
const express = require('express');
const mariadb = require('mariadb');
const path = require('path');
const app = express();
const port = process.env.PORT || 3000;
const dbService = require('./src/services/dbService'); // Database service
const apiRouter = require('./src/routes/apiRouter'); // Adjust the path as necessary
const { validateQueryInteger } = require('./src/middlewares/securityControls');

app.use(express.static('public')); // Serve static files from the public directory

app.get('/', async (req, res) => {
    try {
        const isConnected = await dbService.testConnection();
        res.send(`Connected to MariaDB successfully! ${isConnected}`);
    } catch (err) {
        console.error(err);
        res.status(500).send('Failed to connect to MariaDB');
    }
});

// Use the API router for routes starting with '/api'
app.use('/api', apiRouter);

app.get('/chart', async (req, res) => {
    try {
        const data = await dbService.getCompromisedData(); // Fetch data for chart
        res.sendFile(path.join(__dirname, 'src/views/chart.html')); // Send the HTML file
    } catch (err) {
        console.error(err);
        res.status(500).send('Error fetching chart data');
    }
});

app.get('/data', async (req, res) => {
    const ctfId = validateQueryInteger(req.query.ctf_id); // Get ctf_id from query parameters
    console.log(ctfId)
    if (!ctfId || ctfId==-1) {
        return res.status(400).send('CTF ID is required');
    }
    try {
        const data = await dbService.getPwnedInfo(ctfId);
        res.json(data);
    } catch (err) {
        console.error('Error fetching data for CTF:', err);
        res.status(500).send('Error fetching data for CTF');
    }
});


app.listen(port, () => {
    console.log(`Server is running on http://localhost:${port}`);
});
