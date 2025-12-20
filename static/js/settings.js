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
