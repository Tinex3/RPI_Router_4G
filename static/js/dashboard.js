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
    document.getElementById("qcsq").textContent = sig.qcsq || "N/A";
    
    // Signal strength bar
    const csqMatch = sig.csq?.match(/(\d+)\/31/);
    if (csqMatch) {
      const strength = parseInt(csqMatch[1]);
      const percent = Math.round((strength / 31) * 100);
      const color = strength >= 20 ? "#0f0" : strength >= 10 ? "#ff0" : "#f00";
      document.getElementById("signalStrength").innerHTML = `
        <div class="meter-bar">
          <div class="meter-fill" style="width: ${percent}%; background: ${color};"></div>
        </div>
        <div class="meter-label">${percent}%</div>
      `;
    }
  } catch (e) {
    document.getElementById("csq").textContent = "Error";
    document.getElementById("qcsq").textContent = "Módem no detectado";
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
load();
