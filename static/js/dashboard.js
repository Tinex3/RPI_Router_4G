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

setInterval(load, 5000);
load();
