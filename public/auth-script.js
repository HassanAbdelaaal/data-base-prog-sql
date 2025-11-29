const loginFormElement = document.getElementById('loginFormElement');
const registerFormElement = document.getElementById('registerFormElement');
const messageDiv = document.getElementById('message');

// Switch between login and register forms
function switchToRegister() {
    document.getElementById('loginForm').classList.remove('active');
    document.getElementById('registerForm').classList.add('active');
    messageDiv.style.display = 'none';
}

function switchToLogin() {
    document.getElementById('registerForm').classList.remove('active');
    document.getElementById('loginForm').classList.add('active');
    messageDiv.style.display = 'none';
}

// Handle registration
registerFormElement.addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const formData = {
        username: document.getElementById('registerUsername').value.trim(),
        email: document.getElementById('registerEmail').value.trim()
    };

    try {
        const response = await fetch('/api/auth/register', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(formData)
        });

        const data = await response.json();

        if (data.success) {
            showMessage('✅ Account created successfully! Redirecting...', 'success');
            
            // Store user info in sessionStorage
            sessionStorage.setItem('viewer_id', data.viewer_id);
            sessionStorage.setItem('username', formData.username);
            
            // Redirect to main page after 1.5 seconds
            setTimeout(() => {
                window.location.href = '/app';
            }, 1500);
        } else {
            showMessage('❌ ' + (data.error || 'Registration failed'), 'error');
        }
    } catch (error) {
        showMessage('❌ Error: ' + error.message, 'error');
    }
});

// Handle login
loginFormElement.addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const formData = {
        email: document.getElementById('loginEmail').value.trim(),
        username: document.getElementById('loginUsername').value.trim()
    };

    try {
        const response = await fetch('/api/auth/login', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(formData)
        });

        const data = await response.json();

        if (data.success) {
            showMessage('✅ Login successful! Redirecting...', 'success');
            
            // Store user info in sessionStorage
            sessionStorage.setItem('viewer_id', data.viewer_id);
            sessionStorage.setItem('username', data.username);
            
            // Redirect to main page after 1.5 seconds
            setTimeout(() => {
                window.location.href = '/app';
            }, 1500);
        } else {
            showMessage('❌ ' + (data.error || 'Login failed'), 'error');
        }
    } catch (error) {
        showMessage('❌ Error: ' + error.message, 'error');
    }
});

// Show message
function showMessage(text, type) {
    messageDiv.textContent = text;
    messageDiv.className = `message ${type}`;
    
    setTimeout(() => {
        messageDiv.style.display = 'none';
    }, 4000);
}