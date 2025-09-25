const API_BASE_URL = window.ENV.API_URL;

if (!API_BASE_URL) {
    console.error("❌ No se definió API_URL en config.js");
}

// Inicializar configuración
async function initializeApp() {
    console.log(`🌐 API Base URL: ${API_BASE_URL}`);
    
    // Verificar conexión
    await checkApiHealth();
}

function openSetModal() {
    document.getElementById("setModal").style.display = "block";
}

function openGetModal() {
    document.getElementById("getModal").style.display = "block";
}

function closeModal(id) {
    document.getElementById(id).style.display = "none";
}

function showMessage(message) {
    const box = document.getElementById("messageBox");
    box.innerText = message;
    box.style.display = "block";
}

async function setValue() {
    const key = document.getElementById("setKey").value;
    const value = document.getElementById("setValue").value;

    if (!key || !value) {
        showMessage("Debes ingresar una clave y un valor.");
        return;
    }

    try {
        const response = await fetch(`${API_BASE_URL}/set/${key}/${value}`, {
            method: 'POST'
        });
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const data = await response.json();
        
        if (data.error) {
            showMessage(`Error: ${data.error}`);
        } else {
            showMessage("¡Clave guardada!");
        }
    } catch (error) {
        showMessage(`Error de conexión: ${error.message}`);
    }
    
    closeModal("setModal");
}

async function getValue() {
    const key = document.getElementById("getKey").value;

    if (!key) {
        showMessage("Debes ingresar una clave.");
        return;
    }

    try {
        const response = await fetch(`${API_BASE_URL}/get/${key}`);
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const data = await response.json();
        
        if (data.error) {
            showMessage(`Error: ${data.error}`);
        } else {
            const value = data.value !== null ? data.value : "No encontrado";
            showMessage(`Valor para clave "${key}": ${value}`);
        }
    } catch (error) {
        showMessage(`Error de conexión: ${error.message}`);
    }
    
    closeModal("getModal");
}

// Verificar estado de la API
async function checkApiHealth() {
    try {
        const response = await fetch(`${API_BASE_URL}/health`);
        const data = await response.json();
        console.log('🏥 Estado de la API:', data);
        
        // Mostrar información en consola para debug
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

window.onclick = function(event) {
    if (event.target.classList.contains("modal")) {
        event.target.style.display = "none";
    }
}

// Inicializar cuando se carga la página
window.addEventListener('load', initializeApp);