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
