async function loadSystemInfo() {
  try {
    const info = await (await fetch("/api/system/info")).json();
    
    if (info.uptime) {
      document.getElementById("sysUptime").textContent = info.uptime;
    }
    if (info.cpu_temp) {
      const temp = parseFloat(info.cpu_temp);
      const color = temp > 70 ? "#ef4444" : temp > 60 ? "#f59e0b" : "#22c55e";
      document.getElementById("sysCPU").innerHTML = `<span style="color:${color}">${info.cpu_temp}</span>`;
    }
    if (info.memory_percent !== undefined) {
      const mem = info.memory_percent;
      const color = mem > 80 ? "#ef4444" : mem > 60 ? "#f59e0b" : "#22c55e";
      document.getElementById("sysMemory").innerHTML = `<span style="color:${color}">${mem}%</span>`;
    }
    if (info.disk_percent !== undefined) {
      const disk = info.disk_percent;
      const color = disk > 80 ? "#ef4444" : disk > 60 ? "#f59e0b" : "#22c55e";
      document.getElementById("sysDisk").innerHTML = `<span style="color:${color}">${disk}%</span>`;
    }
  } catch (e) {
    console.error("Error loading system info:", e);
  }
}

async function checkEC25Availability() {
  try {
    const response = await fetch("/api/ec25/status");
    const data = await response.json();
    
    // Si EC25 no está disponible (no detectado o deshabilitado), ocultar elementos
    const ec25Elements = document.querySelectorAll('.ec25-only');
    ec25Elements.forEach(el => {
      el.style.display = data.available ? '' : 'none';
    });
  } catch (e) {
    console.error("Error checking EC25 availability:", e);
  }
}


async function load() {
  // WAN Status
  try {
    const wan = await (await fetch("/api/wan")).json();
    const statusEl = document.getElementById("wanStatus");
    const statusText = wan.active === "down" ? "⚠️ Desconectado" : 
                       wan.active === "eth" ? "🔌 Ethernet" : 
                       wan.active === "lte" ? "📡 LTE" : wan.active;
    statusEl.textContent = statusText;
    statusEl.className = `status-badge status-${wan.active}`;
    document.getElementById("wanMode").value = wan.mode;
  } catch (e) {
    document.getElementById("wanStatus").textContent = "❌ Error";
  }

  // NOTA: Signal y Modem Info ahora se actualizan vía SSE en ec25_monitor.js
  // Ya no se hacen llamadas directas aquí para evitar duplicación
}

async function saveWan(){
  const mode = document.getElementById("wanMode").value;
  try {
    await fetch("/api/wan", {
      method:"POST",
      headers:{"Content-Type":"application/json"},
      body: JSON.stringify({mode})
    });
    alert("WAN mode actualizado a: " + mode);
    load();
  } catch (e) {
    alert("Error al cambiar WAN mode");
  }
}

async function resetModem(){
  if (!confirm("Reiniciar módem? Se desconectará por ~10 segundos")) return;
  try {
    await fetch("/api/modem/reset", {method:"POST"});
    alert("Modem reiniciando…");
    setTimeout(load, 5000);
  } catch (e) {
    alert("Error al reiniciar módem");
  }
}

async function runSpeedtest() {
  const btn = document.getElementById("speedtestBtn");
  const status = document.getElementById("speedtestStatus");
  const result = document.getElementById("speedtestResult");
  
  btn.disabled = true;
  btn.textContent = "⏳ Ejecutando...";
  status.textContent = "Probando velocidad... Esto puede tomar 30-60 segundos";
  result.style.display = "none";
  
  try {
    const response = await fetch("/api/speedtest", {method: "POST"});
    const data = await response.json();
    
    if (data.success) {
      // Mostrar resultados
      document.getElementById("downloadSpeed").textContent = `${data.download} Mbps`;
      document.getElementById("uploadSpeed").textContent = `${data.upload} Mbps`;
      document.getElementById("pingValue").textContent = `${data.ping} ms`;
      document.getElementById("serverInfo").textContent = `${data.server.name} (${data.server.country})`;
      
      result.style.display = "block";
      status.textContent = "✅ Test completado";
    } else {
      status.textContent = `❌ Error: ${data.error}`;
    }
  } catch (e) {
    status.textContent = "❌ Error ejecutando speedtest";
  } finally {
    btn.disabled = false;
    btn.textContent = "🚀 Iniciar Test";
  }
}

// Actualizar WAN cada 5s (EC25 se actualiza vía SSE)
setInterval(load, 5000);
setInterval(loadSystemInfo, 10000);
checkEC25Availability();
load();
loadSystemInfo();
