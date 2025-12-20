/* =====================================================
   EC25 Router - Network Configuration JavaScript
   ===================================================== */

document.addEventListener('DOMContentLoaded', function() {
    loadWiFiConfig();
    loadAPStatus();
    loadConnectedClients();
    
    // Actualizar estado cada 30 segundos
    setInterval(loadAPStatus, 30000);
    setInterval(loadConnectedClients, 30000);
});

// =====================================================
// Cargar Configuracion WiFi Actual
// =====================================================
async function loadWiFiConfig() {
    try {
        const response = await fetch('/api/wifi/config');
        const data = await response.json();
        
        if (data.ssid) {
            document.getElementById('wifi-ssid').value = data.ssid;
            document.getElementById('current-ssid').textContent = data.ssid;
        }
        
        if (data.channel) {
            document.getElementById('wifi-channel').value = data.channel;
            document.getElementById('current-channel').textContent = `Canal ${data.channel}`;
        }
        
        if (data.country) {
            const countrySelect = document.getElementById('wifi-country');
            if (countrySelect) {
                countrySelect.value = data.country;
            }
        }
        
        if (data.hidden !== undefined) {
            document.getElementById('wifi-hidden').checked = data.hidden;
        }
        
    } catch (error) {
        console.error('Error cargando config WiFi:', error);
    }
}

// =====================================================
// Guardar Configuracion WiFi
// =====================================================
async function saveWiFiConfig(event) {
    event.preventDefault();
    
    const btn = document.getElementById('btn-save-wifi');
    const statusEl = document.getElementById('wifi-status');
    
    const ssid = document.getElementById('wifi-ssid').value.trim();
    const password = document.getElementById('wifi-password').value;
    const channel = document.getElementById('wifi-channel').value;
    const country = document.getElementById('wifi-country').value;
    const hidden = document.getElementById('wifi-hidden').checked;
    
    // Validaciones
    if (!ssid) {
        showStatus('wifi-status', 'error', 'El nombre de red (SSID) es requerido');
        return false;
    }
    
    if (ssid.length > 32) {
        showStatus('wifi-status', 'error', 'El SSID no puede tener mas de 32 caracteres');
        return false;
    }
    
    if (password && password.length < 8) {
        showStatus('wifi-status', 'error', 'La contrasena debe tener al menos 8 caracteres');
        return false;
    }
    
    if (password && password.length > 63) {
        showStatus('wifi-status', 'error', 'La contrasena no puede tener mas de 63 caracteres');
        return false;
    }
    
    // Deshabilitar boton
    btn.disabled = true;
    btn.innerHTML = '<span class="spinner"></span> Guardando...';
    
    try {
        const response = await fetch('/api/wifi/config', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ ssid, password, channel, country, hidden })
        });
        
        const data = await response.json();
        
        if (data.ok) {
            showStatus('wifi-status', 'success', data.message || 'Configuracion guardada correctamente');
            showNotification('success', 'WiFi reiniciado. La nueva configuracion esta activa.');
            
            // Actualizar info mostrada
            document.getElementById('current-ssid').textContent = ssid;
            document.getElementById('current-channel').textContent = `Canal ${channel}`;
            
            // Limpiar campo de password
            document.getElementById('wifi-password').value = '';
            
        } else {
            showStatus('wifi-status', 'error', data.error || 'Error al guardar configuracion');
        }
        
    } catch (error) {
        console.error('Error:', error);
        showStatus('wifi-status', 'error', 'Error de conexion: ' + error.message);
    } finally {
        btn.disabled = false;
        btn.innerHTML = `
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width:18px;height:18px;">
              <path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"></path>
              <polyline points="17 21 17 13 7 13 7 21"></polyline>
              <polyline points="7 3 7 8 15 8"></polyline>
            </svg>
            Guardar y Reiniciar WiFi
        `;
    }
    
    return false;
}

// =====================================================
// Cargar Estado del AP
// =====================================================
async function loadAPStatus() {
    try {
        const response = await fetch('/api/wifi/status');
        const data = await response.json();
        
        const statusEl = document.getElementById('ap-status');
        const clientsEl = document.getElementById('ap-clients');
        const ipEl = document.getElementById('ap-ip');
        
        if (data.running) {
            statusEl.innerHTML = '<span class="badge badge-success">Activo</span>';
        } else {
            statusEl.innerHTML = '<span class="badge badge-danger">Inactivo</span>';
        }
        
        if (data.clients !== undefined) {
            clientsEl.textContent = data.clients;
        }
        
        if (data.ip) {
            ipEl.textContent = data.ip;
        }
        
    } catch (error) {
        console.error('Error cargando estado AP:', error);
        document.getElementById('ap-status').innerHTML = '<span class="badge badge-warning">Error</span>';
    }
}

// =====================================================
// Escanear Redes WiFi
// =====================================================
async function scanWiFiNetworks() {
    const btn = document.getElementById('btn-scan-wifi');
    const resultsEl = document.getElementById('wifi-scan-results');
    const emptyEl = document.getElementById('wifi-scan-empty');
    
    btn.disabled = true;
    btn.innerHTML = '<span class="spinner"></span> Escaneando...';
    
    try {
        const response = await fetch('/api/wifi/scan');
        const data = await response.json();
        
        if (data.ok && data.networks && data.networks.length > 0) {
            emptyEl.style.display = 'none';
            resultsEl.style.display = 'flex';
            resultsEl.innerHTML = '';
            
            data.networks.forEach(net => {
                const signalStrength = getSignalStrength(net.signal);
                const item = document.createElement('div');
                item.className = 'network-item';
                item.innerHTML = `
                    <div class="network-info">
                        <span class="network-ssid">${escapeHtml(net.ssid) || '(Red Oculta)'}</span>
                        <span class="network-security">${net.security || 'Abierta'} - Canal ${net.channel}</span>
                    </div>
                    <div class="network-signal">
                        <span class="text-muted">${net.signal} dBm</span>
                        ${renderSignalBars(signalStrength)}
                    </div>
                `;
                resultsEl.appendChild(item);
            });
            
            showNotification('success', `Se encontraron ${data.networks.length} redes WiFi`);
            
        } else {
            emptyEl.style.display = 'block';
            emptyEl.textContent = 'No se encontraron redes WiFi';
            resultsEl.style.display = 'none';
        }
        
    } catch (error) {
        console.error('Error escaneando:', error);
        showNotification('error', 'Error al escanear redes: ' + error.message);
    } finally {
        btn.disabled = false;
        btn.innerHTML = `
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="width:18px;height:18px;">
              <path d="M23 4v6h-6"></path>
              <path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"></path>
            </svg>
            Escanear Redes
        `;
    }
}

function getSignalStrength(signal) {
    if (signal > -50) return 4;
    if (signal > -60) return 3;
    if (signal > -70) return 2;
    return 1;
}

function renderSignalBars(strength) {
    let html = '<div class="signal-bars">';
    for (let i = 1; i <= 4; i++) {
        html += `<div class="signal-bar ${i <= strength ? 'active' : ''}"></div>`;
    }
    html += '</div>';
    return html;
}

// =====================================================
// Cargar Clientes Conectados
// =====================================================
async function loadConnectedClients() {
    try {
        const response = await fetch('/api/wifi/clients');
        const data = await response.json();
        
        const tbody = document.getElementById('clients-table-body');
        const countEl = document.getElementById('ap-clients');
        
        if (data.ok && data.clients && data.clients.length > 0) {
            tbody.innerHTML = '';
            
            data.clients.forEach(client => {
                const row = document.createElement('tr');
                row.innerHTML = `
                    <td><code>${client.mac}</code></td>
                    <td>${client.ip || '-'}</td>
                    <td>${client.hostname || '-'}</td>
                    <td>${client.connected_time || '-'}</td>
                `;
                tbody.appendChild(row);
            });
            
            if (countEl) {
                countEl.textContent = data.clients.length;
            }
            
        } else {
            tbody.innerHTML = '<tr><td colspan="4" class="text-center text-muted">No hay clientes conectados</td></tr>';
            if (countEl) {
                countEl.textContent = '0';
            }
        }
        
    } catch (error) {
        console.error('Error cargando clientes:', error);
    }
}

// =====================================================
// Utilidades
// =====================================================
function escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}
