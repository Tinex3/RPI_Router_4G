async function load() {
  try {
    const wan = await (await fetch("/api/wan")).json();
    document.getElementById("wanStatus").innerText = `${wan.active} (mode: ${wan.mode})`;
    document.getElementById("wanMode").value = wan.mode;
  } catch (e) {
    document.getElementById("wanStatus").innerText = "Error cargando WAN";
  }

  try {
    const sig = await (await fetch("/api/signal")).json();
    document.getElementById("signal").innerText = JSON.stringify(sig, null, 2);
  } catch (e) {
    document.getElementById("signal").innerText = "Error: Módem no detectado";
  }

  try {
    const info = await (await fetch("/api/modem/info")).json();
    document.getElementById("modem").innerText = JSON.stringify(info, null, 2);
  } catch (e) {
    document.getElementById("modem").innerText = "Error: No se pudo obtener info";
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
