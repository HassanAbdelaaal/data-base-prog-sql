const movieForm = document.getElementById('movieForm');
const moviesList = document.getElementById('moviesList');
const messageDiv = document.getElementById('message');

// Load movies on page load
document.addEventListener('DOMContentLoaded', () => {
    loadMovies();
});

// Handle form submission
movieForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const formData = {
        userName: document.getElementById('userName').value.trim(),
        movieName: document.getElementById('movieName').value.trim(),
        genre: document.getElementById('genre').value,
        rating: parseInt(document.getElementById('rating').value)
    };

    try {
        const response = await fetch('/api/movies', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(formData)
        });

        const data = await response.json();

        if (data.success) {
            showMessage('🎉 Movie added successfully!', 'success');
            movieForm.reset();
            loadMovies();
        } else {
            showMessage('❌ Error adding movie', 'error');
        }
    } catch (error) {
        showMessage('❌ Error: ' + error.message, 'error');
    }
});

// Load all movies
async function loadMovies() {
    try {
        const response = await fetch('/api/movies');
        const movies = await response.json();

        if (movies.length === 0) {
            moviesList.innerHTML = `
                <div class="empty-state">
                    <p>🎬 No movies yet!</p>
                    <small>Add your first favorite movie above</small>
                </div>
            `;
            return;
        }

        moviesList.innerHTML = movies.map(movie => `
            <div class="movie-card">
                <h3>🎬 ${escapeHtml(movie.movieName)}</h3>
                <div class="movie-info">
                    <span>👤 ${escapeHtml(movie.userName)}</span>
                    <span>🎭 ${escapeHtml(movie.genre)}</span>
                    <span class="movie-rating">⭐ ${movie.rating}/10</span>
                </div>
                <small class="movie-date">📅 Added: ${formatDate(movie.dateAdded)}</small>
                <br>
                <button class="btn-delete" onclick="deleteMovie(${movie.id})">
                    🗑️ Delete
                </button>
            </div>
        `).join('');
    } catch (error) {
        moviesList.innerHTML = `
            <div class="empty-state">
                <p>❌ Error loading movies</p>
                <small>${error.message}</small>
            </div>
        `;
    }
}

// Delete movie
async function deleteMovie(id) {
    if (!confirm('Are you sure you want to delete this movie?')) {
        return;
    }

    try {
        const response = await fetch(`/api/movies/${id}`, {
            method: 'DELETE'
        });

        const data = await response.json();

        if (data.success) {
            showMessage('✅ Movie deleted successfully', 'success');
            loadMovies();
        }
    } catch (error) {
        showMessage('❌ Error deleting movie: ' + error.message, 'error');
    }
}

// Show message
function showMessage(text, type) {
    messageDiv.textContent = text;
    messageDiv.className = `message ${type}`;
    
    setTimeout(() => {
        messageDiv.style.display = 'none';
    }, 4000);
}

// Format date
function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', { 
        year: 'numeric', 
        month: 'long', 
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}

// Escape HTML to prevent XSS
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}