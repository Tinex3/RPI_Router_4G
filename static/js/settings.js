/* =====================================================
   EC25 Router - Settings Page JavaScript
   ===================================================== */

// ============== APN Configuration ==============

async function saveAPN() {
  const apn = document.getElementById("apn").value.trim();
  const statusEl = document.getElementById("apn-status");
  
  if (!apn) {
    showStatus("apn-status", "error", "El APN no puede estar vacio");
    return;
  }
  
  try {
    const response = await fetch("/api/apn", {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({apn})
    });
    
    const data = await response.json();
    
    if (data.ok) {
      showStatus("apn-status", "success", "APN actualizado correctamente");
      showNotification("success", "APN guardado: " + apn);
    } else {
      showStatus("apn-status", "error", data.error || "Error al guardar APN");
    }
  } catch (e) {
    showStatus("apn-status", "error", "Error de conexion");
  }
}

// ============== Security Configuration ==============

async function applySecurity() {
  const isolate_clients = document.getElementById("isolate").checked;
  
  try {
    const response = await fetch("/api/security", {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({isolate_clients})
    });
    
    const data = await response.json();
    
    if (data.ok) {
      showStatus("security-status", "success", "Configuracion de seguridad aplicada");
      showNotification("success", isolate_clients ? "Clientes WiFi aislados" : "Aislamiento desactivado");
    } else {
      showStatus("security-status", "error", data.error || "Error al aplicar seguridad");
    }
  } catch (e) {
    showStatus("security-status", "error", "Error de conexion");
  }
}

// ============== EC25 Control ==============

async function loadEC25Status() {
  try {
    const response = await fetch("/api/ec25/status");
    const data = await response.json();
    
    const checkbox = document.getElementById("ec25Enabled");
    const hint = document.getElementById("ec25Hint");
    
    checkbox.checked = data.enabled;
    
    if (!data.detected) {
      hint.textContent = "⚠️ Módem EC25 no detectado";
      hint.style.color = "#ff9800";
      checkbox.disabled = true;
    } else {
      hint.textContent = data.enabled ? "✓ Módem habilitado y detectado" : "Módem detectado pero deshabilitado";
      hint.style.color = data.enabled ? "#4caf50" : "#999";
      checkbox.disabled = false;
    }
  } catch (e) {
    document.getElementById("ec25Hint").textContent = "Error al cargar estado";
  }
}

async function toggleEC25() {
  const enabled = document.getElementById("ec25Enabled").checked;
  
  try {
    const response = await fetch("/api/ec25/toggle", {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({enabled})
    });
    
    const data = await response.json();
    
    if (data.ok) {
      showStatus("ec25-status", "success", enabled ? "EC25 habilitado" : "EC25 deshabilitado. Reinicia el sistema.");
      showNotification("success", enabled ? "Módem EC25 habilitado" : "Módem EC25 deshabilitado");
      setTimeout(() => loadEC25Status(), 500);
    } else {
      showStatus("ec25-status", "error", "Error al cambiar estado");
    }
  } catch (e) {
    showStatus("ec25-status", "error", "Error de conexion");
  }
}

// Cargar estado al iniciar
document.addEventListener('DOMContentLoaded', () => {
  loadEC25Status();
  checkEC25Availability();
});

async function checkEC25Availability() {
  try {
    const response = await fetch("/api/ec25/status");
    const data = await response.json();
    
    // Ocultar elementos EC25 si no está disponible
    const ec25Elements = document.querySelectorAll('.ec25-only');
    ec25Elements.forEach(el => {
      el.style.display = data.available ? '' : 'none';
    });
  } catch (e) {
    console.error("Error checking EC25 availability:", e);
  }
}
