// Gateway LoRaWAN Configuration JavaScript
// Maneja la configuracion de BasicStation

document.addEventListener('DOMContentLoaded', function() {
    checkSpiStatus();
    checkDockerStatus();
    checkContainerStatus();
    loadGatewayConfig();
});

// =====================================================================
// SPI STATUS
// =====================================================================

async function checkSpiStatus() {
    try {
        const response = await fetch('/api/gateway/spi-status');
        const data = await response.json();
        
        const statusDiv = document.getElementById('spiStatus');
        const statusText = document.getElementById('spiStatusText');
        const badge = document.getElementById('spiBadge');
        const enableBtn = document.getElementById('enableSpiBtn');
        
        if (data.enabled) {
            statusDiv.classList.remove('not-installed');
            statusText.textContent = 'Bus SPI habilitado y funcionando (/dev/spidev0.0)';
            badge.className = 'status-badge running';
            badge.innerHTML = '<span class="status-dot"></span><span>Habilitado</span>';
            enableBtn.style.display = 'none';
        } else {
            statusDiv.classList.add('not-installed');
            statusText.textContent = 'SPI no esta habilitado. Es necesario para el concentrador LoRa.';
            badge.className = 'status-badge stopped';
            badge.innerHTML = '<span class="status-dot"></span><span>Deshabilitado</span>';
            enableBtn.style.display = 'block';
        }
    } catch (error) {
        console.error('Error checking SPI status:', error);
    }
}

async function enableSpi() {
    const btn = document.getElementById('enableSpiBtn');
    btn.disabled = true;
    btn.innerHTML = '<span class="btn-icon"><span class="spinner-small"></span> Habilitando...</span>';
    
    try {
        const response = await fetch('/api/gateway/enable-spi', {
            method: 'POST'
        });
        const data = await response.json();
        
        if (data.success) {
            showNotification(data.message, 'success');
            
            // Si requiere reinicio, preguntar
            if (data.message.includes('reiniciar') || data.message.includes('Reinicia')) {
                if (confirm('SPI habilitado. Se requiere reiniciar para aplicar los cambios. ¿Reiniciar ahora?')) {
                    window.location.href = '/api/system/restart';
                }
            }
            
            checkSpiStatus();
        } else {
            showNotification('Error: ' + data.message, 'error');
        }
    } catch (error) {
        showNotification('Error de conexion', 'error');
    }
    
    btn.disabled = false;
    btn.innerHTML = '<span class="btn-icon"><svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/></svg> Habilitar SPI</span>';
}

// =====================================================================
// DOCKER STATUS
// =====================================================================

async function checkDockerStatus() {
    try {
        const response = await fetch('/api/gateway/docker-status');
        const data = await response.json();
        
        const statusDiv = document.getElementById('dockerStatus');
        const statusText = document.getElementById('dockerStatusText');
        const badge = document.getElementById('dockerBadge');
        const installBtn = document.getElementById('installDockerBtn');
        
        if (data.installed) {
            statusDiv.classList.remove('not-installed');
            statusText.textContent = `Version: ${data.version}`;
            badge.className = 'status-badge running';
            badge.innerHTML = '<span class="status-dot"></span><span>Instalado</span>';
            installBtn.style.display = 'none';
        } else {
            statusDiv.classList.add('not-installed');
            statusText.textContent = 'Docker no esta instalado. Es necesario para ejecutar BasicStation.';
            badge.className = 'status-badge stopped';
            badge.innerHTML = '<span class="status-dot"></span><span>No instalado</span>';
            installBtn.style.display = 'block';
        }
    } catch (error) {
        console.error('Error checking Docker status:', error);
    }
}

async function installDocker() {
    const modal = document.getElementById('dockerInstallModal');
    const logsDiv = document.getElementById('dockerInstallLogs');
    const closeBtn = document.getElementById('closeDockerModalBtn');
    
    modal.classList.add('active');
    closeBtn.disabled = true;
    logsDiv.textContent = 'Iniciando instalacion de Docker...\n';
    
    try {
        // Iniciar instalacion
        const response = await fetch('/api/gateway/install-docker', {
            method: 'POST'
        });
        
        const data = await response.json();
        
        if (data.success) {
            // Iniciar polling de logs
            pollDockerInstallLogs(logsDiv, closeBtn);
        } else {
            logsDiv.textContent += '❌ Error: ' + data.error + '\n';
            closeBtn.disabled = false;
        }
    } catch (error) {
        logsDiv.textContent += '❌ Error de conexion: ' + error.message + '\n';
        closeBtn.disabled = false;
    }
}

let dockerPollInterval = null;

async function pollDockerInstallLogs(logsDiv, closeBtn) {
    // Limpiar intervalo anterior si existe
    if (dockerPollInterval) {
        clearInterval(dockerPollInterval);
    }
    
    let lastLength = 0;
    
    dockerPollInterval = setInterval(async () => {
        try {
            const response = await fetch('/api/gateway/install-docker/status');
            const data = await response.json();
            
            // Actualizar logs solo si hay contenido nuevo
            if (data.logs && data.logs.length > lastLength) {
                logsDiv.textContent = data.logs;
                lastLength = data.logs.length;
                // Auto-scroll al final
                logsDiv.scrollTop = logsDiv.scrollHeight;
            }
            
            // Si termino, detener polling
            if (!data.running && data.complete) {
                clearInterval(dockerPollInterval);
                dockerPollInterval = null;
                
                // Verificar si fue exitoso
                if (data.logs.includes('DOCKER INSTALADO CORRECTAMENTE') || 
                    data.logs.includes('Docker ya esta instalado')) {
                    logsDiv.textContent += '\n\n✅ Instalacion completada!\n';
                    logsDiv.textContent += '⚠️ IMPORTANTE: Debes cerrar sesion y volver a iniciar,\n';
                    logsDiv.textContent += '   o reiniciar el sistema para usar Docker sin sudo.\n';
                    showNotification('Docker instalado correctamente', 'success');
                    
                    // Actualizar estado despues de un momento
                    setTimeout(() => {
                        checkDockerStatus();
                    }, 2000);
                } else if (data.logs.includes('[ERROR]')) {
                    logsDiv.textContent += '\n\n❌ La instalacion tuvo errores.\n';
                    showNotification('Error en instalacion de Docker', 'error');
                }
                
                closeBtn.disabled = false;
            }
        } catch (error) {
            console.error('Error polling logs:', error);
        }
    }, 1000); // Polling cada segundo
}

// Cerrar modal y limpiar
function closeDockerModal() {
    if (dockerPollInterval) {
        clearInterval(dockerPollInterval);
        dockerPollInterval = null;
    }
    document.getElementById('dockerInstallModal').classList.remove('active');
}

// =====================================================================
// CONTAINER STATUS
// =====================================================================

async function checkContainerStatus() {
    try {
        const response = await fetch('/api/gateway/container-status');
        const data = await response.json();
        
        const badge = document.getElementById('containerBadge');
        const statusText = document.getElementById('containerStatus');
        const startBtn = document.getElementById('startBtn');
        const stopBtn = document.getElementById('stopBtn');
        
        if (data.running) {
            badge.className = 'status-badge running';
            statusText.textContent = 'Ejecutando';
            startBtn.disabled = true;
            stopBtn.disabled = false;
        } else if (data.exists) {
            badge.className = 'status-badge stopped';
            statusText.textContent = 'Detenido';
            startBtn.disabled = false;
            stopBtn.disabled = true;
        } else {
            badge.className = 'status-badge not-installed';
            statusText.textContent = 'No iniciado';
            startBtn.disabled = false;
            stopBtn.disabled = true;
        }
        
        // Cargar EUI si existe
        if (data.gateway_eui && data.gateway_eui !== '0000000000000000') {
            document.getElementById('gatewayEui').textContent = data.gateway_eui;
        }
    } catch (error) {
        console.error('Error checking container status:', error);
    }
}

// =====================================================================
// GATEWAY EUI DETECTION
// =====================================================================

async function detectEui() {
    const btn = document.getElementById('detectEuiBtn');
    const euiSpan = document.getElementById('gatewayEui');
    
    btn.disabled = true;
    euiSpan.innerHTML = '<span class="loading-eui"><span class="spinner-small"></span> Detectando... (puede tardar 1-2 min)</span>';
    
    try {
        const response = await fetch('/api/gateway/detect-eui', {
            method: 'POST'
        });
        const data = await response.json();
        
        if (data.success && data.eui) {
            euiSpan.textContent = data.eui;
            showNotification('Gateway EUI detectado: ' + data.eui, 'success');
        } else {
            euiSpan.textContent = 'Error';
            let errorMsg = data.error || 'No se pudo detectar el EUI';
            
            // Si hay output, mostrarlo en consola y notificación más detallada
            if (data.output) {
                console.log('Detect EUI output:', data.output);
                errorMsg += '\n\nVer consola (F12) para más detalles.';
            }
            
            showNotification(errorMsg, 'error');
            
            // Mostrar output en los logs si la sección está visible
            const logsSection = document.getElementById('logsSection');
            const logsDiv = document.getElementById('containerLogs');
            if (data.output) {
                logsSection.style.display = 'block';
                logsDiv.textContent = '=== Output de detección EUI ===\n\n' + data.output;
            }
        }
    } catch (error) {
        euiSpan.textContent = 'Error';
        showNotification('Error de conexion: ' + error.message, 'error');
    }
    
    btn.disabled = false;
}

function copyEui() {
    const eui = document.getElementById('gatewayEui').textContent;
    if (eui && eui !== '--' && eui !== 'Error') {
        navigator.clipboard.writeText(eui).then(() => {
            showNotification('EUI copiado al portapapeles', 'success');
        });
    }
}

// =====================================================================
// CONFIGURATION
// =====================================================================

async function loadGatewayConfig() {
    try {
        const response = await fetch('/api/gateway/config');
        const data = await response.json();
        
        if (data.success) {
            const config = data.config;
            
            document.getElementById('tcUri').value = config.tc_uri || '';
            document.getElementById('tcKey').value = config.tc_key || '';
            document.getElementById('hasGps').checked = config.has_gps !== '0';
            
            if (config.gateway_eui && config.gateway_eui !== '0000000000000000') {
                document.getElementById('gatewayEui').textContent = config.gateway_eui;
            }
            
            // Seleccionar preset si coincide
            const presetBtns = document.querySelectorAll('.preset-btn');
            presetBtns.forEach(btn => {
                if (btn.dataset.uri === config.tc_uri) {
                    btn.classList.add('active');
                }
            });
        }
    } catch (error) {
        console.error('Error loading config:', error);
    }
}

async function saveGatewayConfig(event) {
    event.preventDefault();
    
    const formData = {
        tc_uri: document.getElementById('tcUri').value,
        tc_key: document.getElementById('tcKey').value,
        has_gps: document.getElementById('hasGps').checked ? '1' : '0',
        gateway_eui: document.getElementById('gatewayEui').textContent
    };
    
    // Validar EUI
    if (!formData.gateway_eui || formData.gateway_eui === '--' || formData.gateway_eui === 'Error') {
        showNotification('Primero detecta el Gateway EUI', 'warning');
        return;
    }
    
    try {
        const response = await fetch('/api/gateway/config', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(formData)
        });
        
        const data = await response.json();
        
        if (data.success) {
            showNotification('Configuracion guardada correctamente', 'success');
        } else {
            showNotification(data.error || 'Error guardando configuracion', 'error');
        }
    } catch (error) {
        showNotification('Error de conexion', 'error');
    }
}

function selectPreset(btn) {
    // Quitar clase active de todos
    document.querySelectorAll('.preset-btn').forEach(b => b.classList.remove('active'));
    
    // Agregar clase active al seleccionado
    btn.classList.add('active');
    
    const uri = btn.dataset.uri;
    const uriInput = document.getElementById('tcUri');
    
    if (uri === 'custom') {
        uriInput.value = '';
        uriInput.focus();
    } else {
        uriInput.value = uri;
    }
}

function togglePassword(inputId) {
    const input = document.getElementById(inputId);
    input.type = input.type === 'password' ? 'text' : 'password';
}

// =====================================================================
// CONTAINER CONTROL
// =====================================================================

async function startContainer() {
    const btn = document.getElementById('startBtn');
    btn.disabled = true;
    btn.innerHTML = '<span class="btn-icon"><span class="spinner-small"></span> Iniciando...</span>';
    
    try {
        const response = await fetch('/api/gateway/start', {
            method: 'POST'
        });
        const data = await response.json();
        
        if (data.success) {
            showNotification('BasicStation iniciado correctamente', 'success');
            checkContainerStatus();
        } else {
            showNotification(data.error || 'Error iniciando contenedor', 'error');
        }
    } catch (error) {
        showNotification('Error de conexion', 'error');
    }
    
    btn.disabled = false;
    btn.innerHTML = '<span class="btn-icon"><svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg> Iniciar BasicStation</span>';
}

async function stopContainer() {
    const btn = document.getElementById('stopBtn');
    btn.disabled = true;
    
    try {
        const response = await fetch('/api/gateway/stop', {
            method: 'POST'
        });
        const data = await response.json();
        
        if (data.success) {
            showNotification('BasicStation detenido', 'success');
            checkContainerStatus();
        } else {
            showNotification(data.error || 'Error deteniendo contenedor', 'error');
        }
    } catch (error) {
        showNotification('Error de conexion', 'error');
    }
    
    btn.disabled = false;
}

// =====================================================================
// LOGS
// =====================================================================

async function viewLogs() {
    const section = document.getElementById('logsSection');
    section.style.display = 'block';
    section.scrollIntoView({ behavior: 'smooth' });
    
    await refreshLogs();
}

async function refreshLogs() {
    const logsDiv = document.getElementById('containerLogs');
    logsDiv.textContent = 'Cargando logs...';
    
    try {
        const response = await fetch('/api/gateway/logs');
        const data = await response.json();
        
        if (data.success) {
            logsDiv.textContent = data.logs || 'No hay logs disponibles';
        } else {
            logsDiv.textContent = 'Error: ' + (data.error || 'No se pudieron obtener los logs');
        }
    } catch (error) {
        logsDiv.textContent = 'Error de conexion: ' + error.message;
    }
    
    // Scroll al final
    logsDiv.scrollTop = logsDiv.scrollHeight;
}

// Cerrar modal
function closeModal(modalId) {
    document.getElementById(modalId).classList.remove('active');
}
