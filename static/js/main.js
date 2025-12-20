/* =====================================================
   EC25 Router - Main JavaScript
   ===================================================== */

// =====================================================
// Sidebar Toggle (Mobile)
// =====================================================
document.addEventListener('DOMContentLoaded', function() {
    const sidebarToggle = document.getElementById('sidebarToggle');
    const sidebar = document.getElementById('sidebar');
    
    // Crear overlay para cerrar sidebar en mobile
    const overlay = document.createElement('div');
    overlay.className = 'sidebar-overlay';
    document.body.appendChild(overlay);
    
    if (sidebarToggle && sidebar) {
        sidebarToggle.addEventListener('click', function() {
            sidebar.classList.toggle('open');
            overlay.classList.toggle('show');
        });
        
        overlay.addEventListener('click', function() {
            sidebar.classList.remove('open');
            overlay.classList.remove('show');
        });
    }
});

// =====================================================
// Modal Functions
// =====================================================
let pendingAction = null;

function confirmAction(action) {
    const modal = document.getElementById('confirmModal');
    const title = document.getElementById('modalTitle');
    const message = document.getElementById('modalMessage');
    const confirmBtn = document.getElementById('modalConfirm');
    
    pendingAction = action;
    
    if (action === 'restart') {
        title.textContent = 'Confirmar Reinicio';
        message.textContent = 'El dispositivo se reiniciara. Perderas la conexion temporalmente. ¿Continuar?';
        confirmBtn.className = 'btn btn-warning';
        confirmBtn.textContent = 'Reiniciar';
    } else if (action === 'shutdown') {
        title.textContent = 'Confirmar Apagado';
        message.textContent = 'El dispositivo se apagara completamente. ¿Estas seguro?';
        confirmBtn.className = 'btn btn-danger';
        confirmBtn.textContent = 'Apagar';
    }
    
    modal.classList.add('show');
    
    confirmBtn.onclick = executeAction;
}

function closeModal() {
    const modal = document.getElementById('confirmModal');
    modal.classList.remove('show');
    pendingAction = null;
}

async function executeAction() {
    if (!pendingAction) return;
    
    const confirmBtn = document.getElementById('modalConfirm');
    confirmBtn.disabled = true;
    confirmBtn.innerHTML = '<span class="spinner"></span> Ejecutando...';
    
    try {
        const response = await fetch(`/api/system/${pendingAction}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        });
        
        const data = await response.json();
        
        if (data.ok) {
            showNotification('success', data.message || 'Accion ejecutada correctamente');
            // Redirigir a pagina de espera si es necesario
            if (pendingAction === 'restart') {
                setTimeout(() => {
                    window.location.href = '/restarting';
                }, 1000);
            }
        } else {
            showNotification('error', data.error || 'Error al ejecutar la accion');
        }
    } catch (error) {
        showNotification('error', 'Error de conexion: ' + error.message);
    } finally {
        closeModal();
        confirmBtn.disabled = false;
        confirmBtn.textContent = 'Confirmar';
    }
}

// Cerrar modal con Escape
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        closeModal();
    }
});

// =====================================================
// Notification System
// =====================================================
function showNotification(type, message, duration = 5000) {
    // Remover notificaciones anteriores
    const existing = document.querySelector('.notification');
    if (existing) existing.remove();
    
    const notification = document.createElement('div');
    notification.className = `notification notification-${type}`;
    notification.innerHTML = `
        <span class="notification-message">${message}</span>
        <button class="notification-close" onclick="this.parentElement.remove()">&times;</button>
    `;
    
    // Estilos inline para la notificacion
    notification.style.cssText = `
        position: fixed;
        top: 80px;
        right: 20px;
        padding: 16px 20px;
        border-radius: 8px;
        display: flex;
        align-items: center;
        gap: 12px;
        z-index: 3000;
        animation: slideIn 0.3s ease;
        max-width: 400px;
        box-shadow: 0 8px 24px rgba(0,0,0,0.3);
    `;
    
    if (type === 'success') {
        notification.style.background = 'rgba(34, 197, 94, 0.95)';
        notification.style.color = 'white';
    } else if (type === 'error') {
        notification.style.background = 'rgba(239, 68, 68, 0.95)';
        notification.style.color = 'white';
    } else if (type === 'warning') {
        notification.style.background = 'rgba(245, 158, 11, 0.95)';
        notification.style.color = '#1a1a1a';
    } else {
        notification.style.background = 'rgba(59, 130, 246, 0.95)';
        notification.style.color = 'white';
    }
    
    document.body.appendChild(notification);
    
    // Auto-remove
    if (duration > 0) {
        setTimeout(() => {
            notification.style.animation = 'slideOut 0.3s ease';
            setTimeout(() => notification.remove(), 300);
        }, duration);
    }
}

// Agregar estilos de animacion
const style = document.createElement('style');
style.textContent = `
    @keyframes slideIn {
        from { transform: translateX(100%); opacity: 0; }
        to { transform: translateX(0); opacity: 1; }
    }
    @keyframes slideOut {
        from { transform: translateX(0); opacity: 1; }
        to { transform: translateX(100%); opacity: 0; }
    }
    .notification-close {
        background: none;
        border: none;
        font-size: 1.2rem;
        cursor: pointer;
        color: inherit;
        opacity: 0.8;
        padding: 0;
        line-height: 1;
    }
    .notification-close:hover { opacity: 1; }
`;
document.head.appendChild(style);

// =====================================================
// Status Message Helper
// =====================================================
function showStatus(elementId, type, message) {
    const el = document.getElementById(elementId);
    if (!el) return;
    
    el.className = `status-msg ${type} show`;
    el.textContent = message;
    
    // Auto-hide after 5 seconds
    setTimeout(() => {
        el.classList.remove('show');
    }, 5000);
}

// =====================================================
// Password Toggle
// =====================================================
function togglePassword(inputId) {
    const input = document.getElementById(inputId);
    if (!input) return;
    
    if (input.type === 'password') {
        input.type = 'text';
    } else {
        input.type = 'password';
    }
}

// =====================================================
// Utility Functions
// =====================================================
function formatBytes(bytes, decimals = 2) {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const dm = decimals < 0 ? 0 : decimals;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
}

function formatUptime(seconds) {
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds % 86400) / 3600);
    const mins = Math.floor((seconds % 3600) / 60);
    
    let result = '';
    if (days > 0) result += `${days}d `;
    if (hours > 0) result += `${hours}h `;
    result += `${mins}m`;
    
    return result;
}

// =====================================================
// API Helper
// =====================================================
async function apiRequest(method, endpoint, data = null) {
    const options = {
        method: method.toUpperCase(),
        headers: {
            'Content-Type': 'application/json',
            'X-Requested-With': 'XMLHttpRequest'
        }
    };
    
    if (data && method.toUpperCase() !== 'GET') {
        options.body = JSON.stringify(data);
    }
    
    try {
        const response = await fetch(endpoint, options);
        
        // Check for session expiration
        if (response.redirected && response.url.includes('login')) {
            window.location.href = '/login?expired=true';
            throw new Error('Sesion expirada');
        }
        
        const result = await response.json();
        return result;
    } catch (error) {
        console.error('API Error:', error);
        throw error;
    }
}
