// ============== WiFi AP Configuration ==============

async function loadWiFiConfig() {
  try {
    const response = await fetch("/api/wifi/config");
    const config = await response.json();
    
    document.getElementById("wifi-ssid").value = config.ssid || "";
    document.getElementById("wifi-channel").value = config.channel || "6";
    // Password no se muestra por seguridad, solo placeholder
    document.getElementById("wifi-password").placeholder = config.password_masked || "********";
    
  } catch (e) {
    console.error("Error loading WiFi config:", e);
  }
}

async function saveWiFi() {
  const ssid = document.getElementById("wifi-ssid").value.trim();
  const password = document.getElementById("wifi-password").value;
  const channel = document.getElementById("wifi-channel").value;
  const statusEl = document.getElementById("wifi-status");
  
  if (!ssid) {
    statusEl.textContent = "Error: SSID no puede estar vacio";
    statusEl.className = "status-msg error";
    return;
  }
  
  if (password && password.length < 8) {
    statusEl.textContent = "Error: Password debe tener minimo 8 caracteres";
    statusEl.className = "status-msg error";
    return;
  }
  
  statusEl.textContent = "Guardando y reiniciando WiFi...";
  statusEl.className = "status-msg info";
  
  try {
    const response = await fetch("/api/wifi/config", {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({ssid, password, channel})
    });
    
    const data = await response.json();
    
    if (data.ok) {
      statusEl.textContent = "WiFi actualizado! Nueva red: " + data.ssid;
      statusEl.className = "status-msg success";
      // Limpiar campo de password
      document.getElementById("wifi-password").value = "";
      // Recargar config
      loadWiFiConfig();
    } else {
      statusEl.textContent = "Error: " + data.error;
      statusEl.className = "status-msg error";
    }
  } catch (e) {
    statusEl.textContent = "Error de conexion";
    statusEl.className = "status-msg error";
  }
}

function togglePassword(inputId) {
  const input = document.getElementById(inputId);
  input.type = input.type === "password" ? "text" : "password";
}

// Cargar config al inicio
document.addEventListener("DOMContentLoaded", loadWiFiConfig);

// ============== APN & Security ==============

async function saveAPN(){
  const apn = document.getElementById("apn").value.trim();
  await fetch("/api/apn", {
    method:"POST",
    headers:{"Content-Type":"application/json"},
    body: JSON.stringify({apn})
  });
  alert("APN actualizado");
}

async function applySecurity(){
  const isolate_clients = document.getElementById("isolate").checked;
  await fetch("/api/security", {
    method:"POST",
    headers:{"Content-Type":"application/json"},
    body: JSON.stringify({isolate_clients})
  });
  alert("Seguridad aplicada");
}
