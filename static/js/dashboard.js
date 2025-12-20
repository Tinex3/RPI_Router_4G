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

  // Signal
  try {
    const sig = await (await fetch("/api/signal")).json();
    document.getElementById("csq").textContent = sig.csq || "N/A";
    
    // Parsear QCSQ para extraer métricas individuales
    // Formato: "LTE: RSRP -100dBm, RSRQ -17dB, SINR 95dB"
    if (sig.qcsq) {
      const rsrpMatch = sig.qcsq.match(/RSRP\s+(-?\d+)dBm/);
      const rsrqMatch = sig.qcsq.match(/RSRQ\s+(-?\d+)dB/);
      const sinrMatch = sig.qcsq.match(/SINR\s+(-?\d+)dB/);
      
      if (rsrpMatch) {
        const rsrp = parseInt(rsrpMatch[1]);
        const rsrpColor = rsrp > -80 ? "#22c55e" : rsrp > -90 ? "#84cc16" : rsrp > -100 ? "#eab308" : rsrp > -110 ? "#f97316" : "#ef4444";
        const rsrpIcon = rsrp > -80 ? "✅" : rsrp > -90 ? "🟢" : rsrp > -100 ? "🟡" : rsrp > -110 ? "🟠" : "🔴";
        document.getElementById("rsrp").innerHTML = `<span style="color: ${rsrpColor}">${rsrpIcon} ${rsrp} dBm</span>`;
      }
      
      if (rsrqMatch) {
        const rsrq = parseInt(rsrqMatch[1]);
        const rsrqColor = rsrq > -10 ? "#22c55e" : rsrq > -15 ? "#84cc16" : rsrq > -20 ? "#eab308" : "#ef4444";
        const rsrqIcon = rsrq > -10 ? "✅" : rsrq > -15 ? "🟢" : rsrq > -20 ? "🟡" : "🔴";
        document.getElementById("rsrq").innerHTML = `<span style="color: ${rsrqColor}">${rsrqIcon} ${rsrq} dB</span>`;
      }
      
      if (sinrMatch) {
        const sinr = parseInt(sinrMatch[1]);
        const sinrColor = sinr > 20 ? "#22c55e" : sinr > 13 ? "#84cc16" : sinr > 0 ? "#eab308" : "#ef4444";
        const sinrIcon = sinr > 20 ? "✅" : sinr > 13 ? "🟢" : sinr > 0 ? "🟡" : "🔴";
        document.getElementById("sinr").innerHTML = `<span style="color: ${sinrColor}">${sinrIcon} ${sinr} dB</span>`;
      }
    }
    
    // Signal strength bar (basado en CSQ)
    const csqMatch = sig.csq?.match(/(\d+)\/31/);
    if (csqMatch) {
      const strength = parseInt(csqMatch[1]);
      const percent = Math.round((strength / 31) * 100);
      const color = strength >= 20 ? "#22c55e" : strength >= 10 ? "#eab308" : "#ef4444";
      document.getElementById("signalStrength").innerHTML = `
        <div class="meter-bar">
          <div class="meter-fill" style="width: ${percent}%; background: ${color};"></div>
        </div>
        <div class="meter-label">${percent}%</div>
      `;
    }
  } catch (e) {
    document.getElementById("csq").textContent = "Error";
    document.getElementById("rsrp").textContent = "–";
    document.getElementById("rsrq").textContent = "–";
    document.getElementById("sinr").textContent = "–";
  }

  // Modem Info
  try {
    const info = await (await fetch("/api/modem/info")).json();
    document.getElementById("operator").textContent = info.operator || "N/A";
    document.getElementById("network").textContent = info.network || "N/A";
    document.getElementById("registration").textContent = info.registration || "N/A";
    document.getElementById("sim").textContent = info.sim || "N/A";
  } catch (e) {
    document.getElementById("operator").textContent = "Error";
  }
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

setInterval(load, 5000);
setInterval(loadSystemInfo, 10000);
checkEC25Availability();
load();
loadSystemInfo();
