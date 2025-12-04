let currentFilter = 'all';

// Load tasks on page load
document.addEventListener('DOMContentLoaded', () => {
    loadTasks();
});

// Handle form submission
document.getElementById('taskForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    
    const title = document.getElementById('title').value;
    const description = document.getElementById('description').value;
    
    try {
        const response = await fetch('/tasks', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                title: title,
                description: description,
                completed: false
            })
        });
        
        if (response.ok) {
            showMessage('Task created successfully!');
            document.getElementById('taskForm').reset();
            loadTasks();
        } else {
            showMessage('Error creating task', 'error');
        }
    } catch (error) {
        showMessage('Error: ' + error.message, 'error');
    }
});

// Filter buttons
document.querySelectorAll('.filter-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
        document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
        e.target.classList.add('active');
        currentFilter = e.target.dataset.filter;
        loadTasks();
    });
});

async function loadTasks() {
    try {
        let url = '/tasks';
        if (currentFilter === 'pending') {
            url = '/tasks/pending';
        } else if (currentFilter === 'completed') {
            url = '/tasks/completed';
        }
        
        const response = await fetch(url);
        const tasks = await response.json();
        
        displayTasks(tasks);
    } catch (error) {
        showMessage('Error loading tasks: ' + error.message, 'error');
    }
}

function displayTasks(tasks) {
    const tasksList = document.getElementById('tasksList');
    
    if (tasks.length === 0) {
        tasksList.innerHTML = `
            <div class="empty-state">
                <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"></path>
                </svg>
                <p>No tasks found. Create your first task above!</p>
            </div>
        `;
        return;
    }
    
    tasksList.innerHTML = tasks.map(task => {
        const completedClass = task.completed ? 'completed' : '';
        const statusClass = task.completed ? 'status-completed' : 'status-pending';
        const statusText = task.completed ? 'Completed' : 'Pending';
        const actionButton = !task.completed 
            ? `<button class="btn btn-sm btn-success" onclick="toggleTask(${task.id}, true)">✓ Complete</button>`
            : `<button class="btn btn-sm" onclick="toggleTask(${task.id}, false)">↺ Reopen</button>`;
        
        return `
            <div class="task-item ${completedClass}">
                <div class="task-header">
                    <h3 class="task-title">${escapeHtml(task.title)}</h3>
                    <span class="status-badge ${statusClass}">${statusText}</span>
                </div>
                <p class="task-description">${escapeHtml(task.description || 'No description')}</p>
                <div class="task-actions">
                    ${actionButton}
                    <button class="btn btn-sm btn-danger" onclick="deleteTask(${task.id})">× Delete</button>
                </div>
            </div>
        `;
    }).join('');
}

async function toggleTask(id, completed) {
    try {
        const response = await fetch('/tasks/' + id);
        const task = await response.json();
        
        task.completed = completed;
        
        const updateResponse = await fetch('/tasks/' + id, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(task)
        });
        
        if (updateResponse.ok) {
            showMessage(completed ? 'Task completed!' : 'Task reopened!');
            loadTasks();
        } else {
            showMessage('Error updating task', 'error');
        }
    } catch (error) {
        showMessage('Error: ' + error.message, 'error');
    }
}

async function deleteTask(id) {
    if (!confirm('Are you sure you want to delete this task?')) {
        return;
    }
    
    try {
        const response = await fetch('/tasks/' + id, {
            method: 'DELETE'
        });
        
        if (response.ok) {
            showMessage('Task deleted successfully!');
            loadTasks();
        } else {
            showMessage('Error deleting task', 'error');
        }
    } catch (error) {
        showMessage('Error: ' + error.message, 'error');
    }
}

function showMessage(text, type = 'success') {
    const messageEl = document.getElementById('message');
    messageEl.textContent = text;
    messageEl.style.display = 'block';
    messageEl.style.background = type === 'error' ? '#fee2e2' : '#d1fae5';
    messageEl.style.color = type === 'error' ? '#991b1b' : '#065f46';
    
    setTimeout(() => {
        messageEl.style.display = 'none';
    }, 3000);
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}
