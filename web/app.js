// ===== APP.JS CON DETECCIÓN AUTOMÁTICA =====

// Configuración automática de la API
/*
async function getApiBaseUrl() {
    
    const hostname = window.location.hostname;
    const isLocal = hostname === 'localhost' || hostname === '127.0.0.1';
    
    if (isLocal) {
        return 'http://localhost:8000';
    } else {
        // En producción, usar variable de entorno API_URL
        const apiUrl = window.ENV.API_URL;
        
        if (apiUrl) {
            console.log(`🌐 Usando API_URL de variable de entorno: ${apiUrl}`);
            
            try {
                // Verificar que la API responde
                const response = await fetch(`${apiUrl}/health`, { 
                    method: 'GET',
                    timeout: 5000 
                });
                
                if (response.ok) {
                    console.log(`✅ API verificada correctamente: ${apiUrl}`);
                    return apiUrl;
                } else {
                    console.warn(`⚠️ API no responde correctamente en: ${apiUrl}`);
                }
            } catch (error) {
                console.error(`❌ Error verificando API en ${apiUrl}:`, error.message);
            }
        } else {
            console.warn('⚠️ Variable API_URL no está definida');
        }
    }

}

let API_BASE_URL;
*/
const API_BASE_URL = window.ENV.API_URL;

if (!API_BASE_URL) {
    console.error("❌ No se definió API_URL en config.js");
}

// Inicializar configuración
async function initializeApp() {
    //API_BASE_URL = await getApiBaseUrl();
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