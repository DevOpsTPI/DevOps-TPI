const API_BASE_URL = "http://localhost:8080/api";

if (!API_BASE_URL) {
    console.error("❌ No se definió API_URL en config.js");
}

async function initializeApp() {
    console.log(`🌐 API Base URL: ${API_BASE_URL}`);
    
    // Verificar conexión
    await checkApiHealth();

    //Cargar tareas
    fetchTasks();
}

function showMessage(message) {
    const box = document.getElementById("messageBox");
    box.innerText = message;
    box.style.display = "block";
}

// ===== FUNCIONES DE TAREAS =====
async function fetchTasks() {
    try {
        const res = await fetch(`${API_BASE_URL}/tasks`);
        if (!res.ok) throw new Error(`HTTP error! status: ${res.status}`);
        const tasks = await res.json();
        const list = document.getElementById("taskList");
        list.innerHTML = "";
        tasks.forEach(task => {
            const li = document.createElement("li");
            li.className = "task-card";
            li.innerHTML = `
                <button class="task-btn" onclick="toggleTask('${task.id}', ${task.completed})">
                  <i class="bi ${task.completed ? 'bi-check-circle-fill' : 'bi-circle'}"></i>
                </button>
                <span class="task-text ${task.completed ? 'done' : ''}">${task.text}</span>
                <button class="task-btn" onclick="deleteTask('${task.id}')">
                  <i class="bi bi-x"></i>
                </button>
            `;
            list.appendChild(li);
        });
    } catch (error) {
        showMessage(`Error cargando tareas: ${error.message}`);
    }
}

async function addTask() {
    const input = document.getElementById("taskInput");
    const text = input.value.trim();
    if (!text) return;
    try {
        await fetch(`${API_BASE_URL}/tasks?text=${encodeURIComponent(text)}`, { method: "POST" });
        input.value = "";
        fetchTasks();
    } catch (error) {
        showMessage(`Error agregando tarea: ${error.message}`);
    }
}

async function toggleTask(id, completed) {
    console.log("toggleTask:", id, completed);
    try {
        if (completed) {
            await fetch(`${API_BASE_URL}/tasks/${id}/incomplete`, { method: "POST" });
        } else {
            await fetch(`${API_BASE_URL}/tasks/${id}/complete`, { method: "POST" });
        }
        fetchTasks();
    } catch (error) {
        showMessage(`Error cambiando estado: ${error.message}`);
    }
}

async function deleteTask(id) {
    try {
        await fetch(`${API_BASE_URL}/tasks/${id}`, { method: "DELETE" });
        fetchTasks();
    } catch (error) {
        showMessage(`Error eliminando tarea: ${error.message}`);
    }
}

// Verificar estado de la API
async function checkApiHealth() {
    try {
        const response = await fetch(`${API_BASE_URL}/health`);
        const data = await response.json();
        console.log('🏥 Estado de la API:', data);
        
        if (data.status === 'healthy') {
            console.log(`✅ API conectada - Entorno: ${data.environment}`);
        } else {
            console.warn(`⚠️ API con problemas: ${data.redis_error}`);
        }
    } catch (error) {
        console.error('❌ Error verificando API:', error);
        showMessage('No se puede conectar con la API');
    }
}

// Inicializar cuando se carga la página
window.addEventListener('load', initializeApp);
