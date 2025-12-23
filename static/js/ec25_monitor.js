/**
 * EC25 Monitor - Manejo de streaming de datos en tiempo real usando SSE
 */

let ec25EventSource = null;
let reconnectAttempts = 0;
const MAX_RECONNECT_ATTEMPTS = 5;
const RECONNECT_DELAY = 3000; // 3 segundos

/**
 * Inicializa el EventSource para SSE
 */
function initEC25Stream() {
  // Si ya existe una conexión, cerrarla
  if (ec25EventSource) {
    ec25EventSource.close();
  }

  try {
    ec25EventSource = new EventSource('/api/ec25/stream');
    
    ec25EventSource.onopen = () => {
      console.log('✅ EC25 stream conectado');
      reconnectAttempts = 0;
    };
    
    ec25EventSource.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        updateEC25UI(data);
      } catch (e) {
        console.error('Error parseando datos EC25:', e);
      }
    };
    
    ec25EventSource.onerror = (error) => {
      console.error('❌ Error en EC25 stream:', error);
      ec25EventSource.close();
      
      // Intentar reconectar con backoff exponencial
      if (reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
        reconnectAttempts++;
        const delay = RECONNECT_DELAY * reconnectAttempts;
        console.log(`🔄 Reconectando en ${delay/1000}s (intento ${reconnectAttempts}/${MAX_RECONNECT_ATTEMPTS})`);
        setTimeout(initEC25Stream, delay);
      } else {
        console.log('⚠️ Max reintentos alcanzados. Usando polling fallback.');
        startEC25Polling();
      }
    };
    
  } catch (e) {
    console.error('Error inicializando EC25 stream:', e);
    startEC25Polling();
  }
}

/**
 * Actualiza la UI con los datos del EC25
 */
function updateEC25UI(data) {
  if (!data.detected || !data.enabled) {
    // Módem no disponible
    setEC25UIUnavailable();
    return;
  }
  
  // Actualizar señal
  if (data.signal) {
    updateSignalUI(data.signal);
  }
  
  // Actualizar info de red
  if (data.network) {
    updateNetworkUI(data.network);
  }
  
  // Timestamp de última actualización
  updateLastUpdate(data.timestamp);
}

/**
 * Actualiza UI de señal
 */
function updateSignalUI(signal) {
  // CSQ
  const csqEl = document.getElementById('csq');
  if (csqEl) {
    csqEl.textContent = signal.csq || 'N/A';
  }
  
  // QCSQ - Parsear métricas individuales
  if (signal.qcsq && signal.qcsq !== 'N/A') {
    const rsrpMatch = signal.qcsq.match(/RSRP\s+(-?\d+)dBm/);
    const rsrqMatch = signal.qcsq.match(/RSRQ\s+(-?\d+)dB/);
    const sinrMatch = signal.qcsq.match(/SINR\s+(-?\d+)dB/);
    
    if (rsrpMatch) {
      const rsrp = parseInt(rsrpMatch[1]);
      const rsrpColor = rsrp > -80 ? '#22c55e' : rsrp > -90 ? '#84cc16' : rsrp > -100 ? '#eab308' : rsrp > -110 ? '#f97316' : '#ef4444';
      const rsrpIcon = rsrp > -80 ? '✅' : rsrp > -90 ? '🟢' : rsrp > -100 ? '🟡' : rsrp > -110 ? '🟠' : '🔴';
      const rsrpEl = document.getElementById('rsrp');
      if (rsrpEl) {
        rsrpEl.innerHTML = `<span style="color: ${rsrpColor}">${rsrpIcon} ${rsrp} dBm</span>`;
      }
    }
    
    if (rsrqMatch) {
      const rsrq = parseInt(rsrqMatch[1]);
      const rsrqColor = rsrq > -10 ? '#22c55e' : rsrq > -15 ? '#84cc16' : rsrq > -20 ? '#eab308' : '#ef4444';
      const rsrqIcon = rsrq > -10 ? '✅' : rsrq > -15 ? '🟢' : rsrq > -20 ? '🟡' : '🔴';
      const rsrqEl = document.getElementById('rsrq');
      if (rsrqEl) {
        rsrqEl.innerHTML = `<span style="color: ${rsrqColor}">${rsrqIcon} ${rsrq} dB</span>`;
      }
    }
    
    if (sinrMatch) {
      const sinr = parseInt(sinrMatch[1]);
      const sinrColor = sinr > 20 ? '#22c55e' : sinr > 13 ? '#84cc16' : sinr > 0 ? '#eab308' : '#ef4444';
      const sinrIcon = sinr > 20 ? '✅' : sinr > 13 ? '🟢' : sinr > 0 ? '🟡' : '🔴';
      const sinrEl = document.getElementById('sinr');
      if (sinrEl) {
        sinrEl.innerHTML = `<span style="color: ${sinrColor}">${sinrIcon} ${sinr} dB</span>`;
      }
    }
  }
  
  // Signal strength bar (basado en CSQ)
  const csqMatch = signal.csq?.match(/(\d+)\/31/);
  if (csqMatch) {
    const strength = parseInt(csqMatch[1]);
    const percent = Math.round((strength / 31) * 100);
    const color = strength >= 20 ? '#22c55e' : strength >= 10 ? '#eab308' : '#ef4444';
    const strengthEl = document.getElementById('signalStrength');
    if (strengthEl) {
      strengthEl.innerHTML = `
        <div class="meter-bar">
          <div class="meter-fill" style="width: ${percent}%; background: ${color};"></div>
        </div>
        <div class="meter-label">${percent}%</div>
      `;
    }
  }
}

/**
 * Actualiza UI de red
 */
function updateNetworkUI(network) {
  const operatorEl = document.getElementById('operator');
  if (operatorEl) {
    operatorEl.textContent = network.operator || 'N/A';
  }
  
  const networkEl = document.getElementById('network');
  if (networkEl) {
    networkEl.textContent = network.network || 'N/A';
  }
  
  const regEl = document.getElementById('registration');
  if (regEl) {
    regEl.textContent = network.registration || 'N/A';
  }
  
  const simEl = document.getElementById('sim');
  if (simEl) {
    simEl.textContent = network.sim || 'N/A';
  }
}

/**
 * Marca UI como no disponible
 */
function setEC25UIUnavailable() {
  const elements = ['csq', 'rsrp', 'rsrq', 'sinr', 'operator', 'network', 'registration', 'sim'];
  elements.forEach(id => {
    const el = document.getElementById(id);
    if (el) {
      el.textContent = 'N/A';
    }
  });
  
  const strengthEl = document.getElementById('signalStrength');
  if (strengthEl) {
    strengthEl.innerHTML = `
      <div class="meter-bar">
        <div class="meter-fill" style="width: 0%; background: #6b7280;"></div>
      </div>
      <div class="meter-label">0%</div>
    `;
  }
}

/**
 * Actualiza timestamp de última actualización
 */
function updateLastUpdate(timestamp) {
  const lastUpdateEl = document.getElementById('ec25LastUpdate');
  if (lastUpdateEl) {
    const date = new Date(timestamp * 1000);
    const timeStr = date.toLocaleTimeString('es-ES');
    lastUpdateEl.textContent = `Última actualización: ${timeStr}`;
  }
}

/**
 * Polling fallback si SSE falla
 */
let pollingInterval = null;

function startEC25Polling() {
  // Detener polling anterior si existe
  if (pollingInterval) {
    clearInterval(pollingInterval);
  }
  
  console.log('📊 Iniciando polling fallback (5s)');
  
  // Polling cada 5 segundos
  pollingInterval = setInterval(async () => {
    try {
      const response = await fetch('/api/ec25/data');
      const data = await response.json();
      updateEC25UI(data);
    } catch (e) {
      console.error('Error en polling EC25:', e);
    }
  }, 5000);
  
  // Primera carga inmediata
  fetch('/api/ec25/data')
    .then(r => r.json())
    .then(updateEC25UI)
    .catch(e => console.error('Error cargando datos EC25:', e));
}

/**
 * Detiene el stream/polling
 */
function stopEC25Monitor() {
  if (ec25EventSource) {
    ec25EventSource.close();
    ec25EventSource = null;
  }
  
  if (pollingInterval) {
    clearInterval(pollingInterval);
    pollingInterval = null;
  }
  
  console.log('🛑 EC25 monitor detenido');
}

// Auto-iniciar al cargar la página
document.addEventListener('DOMContentLoaded', () => {
  // Verificar si EC25 está disponible antes de iniciar
  fetch('/api/ec25/status')
    .then(r => r.json())
    .then(status => {
      if (status.available) {
        // Usar SSE por defecto
        initEC25Stream();
      } else {
        console.log('⚠️ EC25 no disponible, no se inicia monitor');
        setEC25UIUnavailable();
      }
    })
    .catch(e => {
      console.error('Error verificando EC25:', e);
    });
});

// Limpiar al cerrar/salir de la página
window.addEventListener('beforeunload', stopEC25Monitor);
