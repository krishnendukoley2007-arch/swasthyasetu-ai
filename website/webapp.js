// ═══ SwasthyaSetu AI — web app ═══
// Auth (Google) + Firestore sync + Web Bluetooth live monitor.
// BLE protocol matches firmware v2.1.0 (same UUIDs and frames as the app).

// ── BLE protocol constants ──
const SERVICE     = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
const CHAR_VITALS = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';
const CHAR_ECG    = '6e400004-b5a3-f393-e0a9-e50e24dcca9e';
const CHAR_MOTION = '6e400005-b5a3-f393-e0a9-e50e24dcca9e';
const SAMPLE_RATE = 250;
const MAX_ECG = SAMPLE_RATE * 10;         // 10 s buffer
const CAPTURE_SAMPLES = SAMPLE_RATE * 10; // 10 s strip

const $ = (id) => document.getElementById(id);

// ── State ──
const S = {
  btDevice: null, connected: false,
  hr: 0, spo2: 0, temp: 0, rr: 0, battery: 0, leadOff: true, fall: false,
  ecg: [],            // rolling window
  recording: false, rec: [],
  user: null, db: null, auth: null,
  screenings: [],
};

// ── Firebase (optional; demo mode without config) ──
let firebaseReady = false;
async function initFirebase() {
  const cfg = window.FIREBASE_CONFIG || {};
  if (!cfg.apiKey || !cfg.appId) {
    setBanner('Demo mode: Firebase is not configured, so Google sign-in is off and screenings save to this browser only. Fill website/firebase-config.js to enable cloud sync.');
    return;
  }
  const { initializeApp } = await import('https://www.gstatic.com/firebasejs/10.12.2/firebase-app.js');
  const authMod = await import('https://www.gstatic.com/firebasejs/10.12.2/firebase-auth.js');
  const fsMod = await import('https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js');
  const app = initializeApp(cfg);
  S.auth = authMod.getAuth(app);
  S.db = fsMod.getFirestore(app);
  S.fs = fsMod; S.authMod = authMod;

  authMod.onAuthStateChanged(S.auth, (u) => {
    S.user = u;
    $('authBtn').textContent = u ? 'Sign out' : 'Sign in with Google';
    $('authUser').textContent = u ? (u.displayName || u.email) : '';
    refreshList();
  });

  $('authBtn').addEventListener('click', async () => {
    if (S.user) { await authMod.signOut(S.auth); return; }
    const provider = new authMod.GoogleAuthProvider();
    await authMod.signInWithPopup(S.auth, provider);
  });
  firebaseReady = true;
}

// ── BLE connect ──
$('connectBtn').addEventListener('click', async () => {
  if (S.connected) { S.btDevice?.gatt?.disconnect(); return; }
  if (!navigator.bluetooth) {
    alert('Web Bluetooth needs Chrome or Edge on desktop or Android.');
    return;
  }
  try {
    setChip('connecting');
    S.btDevice = await navigator.bluetooth.requestDevice({
      filters: [{ name: 'SSAI-SENSE-01' }],
      optionalServices: [SERVICE],
    });
    S.btDevice.addEventListener('gattserverdisconnected', onDisconnect);
    const server = await S.btDevice.gatt.connect();
    const svc = await server.getPrimaryService(SERVICE);

    const vitals = await svc.getCharacteristic(CHAR_VITALS);
    await vitals.startNotifications();
    vitals.addEventListener('characteristicvaluechanged', onTelemetry);

    const ecg = await svc.getCharacteristic(CHAR_ECG);
    await ecg.startNotifications();
    ecg.addEventListener('characteristicvaluechanged', onEcg);

    try {
      const motion = await svc.getCharacteristic(CHAR_MOTION);
      await motion.startNotifications();
      motion.addEventListener('characteristicvaluechanged', onMotion);
    } catch (_) { /* older firmware has no motion channel */ }

    S.connected = true;
    setChip('live', S.btDevice.name || 'SSAI-SENSE-01');
    $('captureBtn').disabled = false;
    setBanner('');
  } catch (e) {
    onDisconnect();
    if (e.name !== 'NotFoundError') setBanner('Connection failed: ' + e.message);
  }
});

function onDisconnect() {
  S.connected = false;
  setChip('off');
  $('captureBtn').disabled = true;
  $('saveBtn').disabled = true;
}

function setChip(state, name) {
  const c = $('connChip');
  c.className = 'chip';
  if (state === 'live') { c.classList.add('chip-teal'); c.innerHTML = `<span class="dot"></span>${name} · live`; }
  else if (state === 'connecting') { c.classList.add('chip-amber'); c.innerHTML = '<span class="dot"></span>Connecting…'; }
  else { c.classList.add('chip-muted'); c.innerHTML = '<span class="dot"></span>No device'; }
}

function setBanner(msg) {
  const b = $('bannerMsg');
  if (!msg) { b.classList.add('hidden'); return; }
  b.textContent = msg; b.classList.remove('hidden');
}

// ── Telemetry frames (firmware v2.1.0) ──
function onTelemetry(ev) {
  const v = ev.target.value;
  if (v.byteLength !== 20 || v.getUint8(0) !== 0x01) return;
  S.hr = v.getUint8(2);
  S.spo2 = v.getUint8(3);
  S.temp = v.getInt16(4, true) / 100;
  S.rr = v.getUint16(6, true);
  S.leadOff = (v.getUint8(9) & 0x04) !== 0;
  S.battery = v.getUint8(14);
  renderVitals();
}

function onEcg(ev) {
  const v = ev.target.value;
  if (v.byteLength < 4 || v.getUint8(0) !== 0x02) return;
  for (let o = 4; o + 2 <= v.byteLength; o += 2) S.ecg.push(v.getInt16(o, true));
  if (S.ecg.length > MAX_ECG) S.ecg.splice(0, S.ecg.length - MAX_ECG);
  if (S.recording) {
    for (let o = 4; o + 2 <= v.byteLength; o += 2) S.rec.push(v.getInt16(o, true));
    if (S.rec.length >= CAPTURE_SAMPLES) finishCapture();
  }
}

function onMotion(ev) {
  const v = ev.target.value;
  if (v.byteLength < 15 || v.getUint8(0) !== 0x03) return;
  S.fall = v.getUint8(14) === 1;
}

// ── Vitals UI ──
function renderVitals() {
  const dash = '—';
  $('vHR').textContent = S.leadOff || !S.hr ? dash : S.hr;
  $('vSpO2').textContent = S.spo2 || dash;
  $('vTemp').textContent = (S.temp > 20 && S.temp < 45) ? S.temp.toFixed(1) : dash;
  $('vRR').textContent = S.leadOff || !S.rr ? dash : S.rr;

  setStatus($('hrStatus'), !S.hr || S.leadOff ? ['—',''] :
    S.hr < 50 || S.hr > 120 ? ['OUT OF RANGE','chip-coral'] :
    S.hr < 60 || S.hr > 100 ? ['REVIEW','chip-amber'] : ['IN RANGE','chip-teal']);
  setStatus($('spo2Status'), !S.spo2 ? ['—',''] :
    S.spo2 < 92 ? ['LOW','chip-coral'] : S.spo2 < 95 ? ['BORDERLINE','chip-amber'] : ['IN RANGE','chip-teal']);
  setStatus($('tempStatus'), !(S.temp > 20 && S.temp < 45) ? ['—',''] :
    S.temp >= 38 ? ['ELEVATED','chip-coral'] : S.temp >= 37.5 ? ['BORDERLINE','chip-amber'] : ['IN RANGE','chip-teal']);
  setStatus($('fallStatus'), S.fall ? ['FALL SUSPECTED','chip-coral'] : ['NO FALL','chip-teal']);

  $('saveBtn').disabled = !(S.connected && !S.leadOff && S.hr > 0);
}

function setStatus(el, [text, cls]) {
  el.textContent = text;
  el.className = 'chip' + (cls ? ' ' + cls : ' chip-muted');
}

// ── ECG strip renderer (rolling, right-aligned) ──
const canvas = $('ecgCanvas');
const ctx = canvas.getContext('2d');

function drawStrip() {
  const w = canvas.width = canvas.clientWidth * devicePixelRatio;
  const h = canvas.height = 220 * devicePixelRatio;
  ctx.clearRect(0, 0, w, h);

  // Grid: 200 ms columns.
  ctx.strokeStyle = 'rgba(45,212,191,0.08)'; ctx.lineWidth = 1;
  const stepX = w / (MAX_ECG / SAMPLE_RATE / 0.2);
  for (let x = 0; x < w; x += stepX) { ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, h); ctx.stroke(); }

  const n = S.ecg.length;
  if (n < 2) return;

  let lo = Infinity, hi = -Infinity;
  for (const v of S.ecg) { if (v < lo) lo = v; if (v > hi) hi = v; }
  const span = Math.max(1, hi - lo);

  const connected = S.connected && !S.leadOff;
  ctx.strokeStyle = connected ? '#2dd4bf' : '#d97706';
  ctx.lineWidth = 1.6 * devicePixelRatio;
  ctx.lineJoin = 'round';
  ctx.beginPath();
  const off = MAX_ECG - n;
  for (let i = 0; i < n; i++) {
    const x = ((off + i) / MAX_ECG) * w;
    const y = h * 0.9 - ((S.ecg[i] - lo) / span) * h * 0.8;
    i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
  }
  ctx.stroke();

  // Provenance label
  ctx.font = `${11 * devicePixelRatio}px Inter, sans-serif`;
  ctx.fillStyle = 'rgba(231,238,248,0.55)';
  ctx.fillText(connected ? 'MEASURED · Lead I · 250 Hz' : (S.connected ? 'ELECTRODES OFF SKIN' : 'NO DATA — connect board'),
               10 * devicePixelRatio, 16 * devicePixelRatio);
  requestAnimationFrame(drawStrip);
}
requestAnimationFrame(drawStrip);

// ── Capture ──
$('captureBtn').addEventListener('click', () => {
  if (!S.connected || S.recording) return;
  S.recording = true; S.rec = [];
  setBanner('Recording 10 s strip — keep the patient still.');
});
function finishCapture() {
  S.recording = false;
  setBanner(`Recorded ${(S.rec.length / SAMPLE_RATE).toFixed(1)} s (${S.rec.length} samples).`);
}

// ── Triage (bounded score, same bands as the app: 0–30/31–60/61–100) ──
function score(hrd) {
  let pts = 0; const rules = [];
  if (hrd.hr < 50 || hrd.hr > 130) { pts += 45; rules.push('Heart rate far out of range'); }
  else if (hrd.hr < 60 || hrd.hr > 100) { pts += 25; rules.push('Heart rate out of range'); }
  if (hrd.spo2 > 0 && hrd.spo2 < 90) { pts += 45; rules.push('SpO₂ below 90%'); }
  else if (hrd.spo2 > 0 && hrd.spo2 < 94) { pts += 25; rules.push('SpO₂ borderline'); }
  if (hrd.temp >= 39) { pts += 30; rules.push('High fever'); }
  else if (hrd.temp >= 38) { pts += 18; rules.push('Fever'); }
  if (hrd.fall) { pts += 25; rules.push('Fall suspected'); }
  if (hrd.leadOff) { pts += 10; rules.push('Electrodes off skin during capture'); }
  const band = pts >= 61 ? 'RED' : pts >= 31 ? 'YELLOW' : 'GREEN';
  return { score: Math.min(100, pts), band, rules };
}

// ── Save ──
$('saveBtn').addEventListener('click', async () => {
  const name = $('pName').value.trim();
  if (!name) { setBanner('Enter the patient name before saving.'); return; }
  const triage = score(S);
  const row = {
    ts: Date.now(),
    patientName: name,
    age: parseInt($('pAge').value) || null,
    sex: $('pSex').value,
    symptoms: $('pSymptoms').value.trim(),
    hr: S.hr, spo2: S.spo2, tempC: +S.temp.toFixed(1), rrMs: S.rr,
    battery: S.battery, fall: S.fall,
    score: triage.score, band: triage.band, rules: triage.rules,
    ecgSamples: S.rec.length >= SAMPLE_RATE ? S.rec : null,
    uid: S.user?.uid || null,
  };

  if (firebaseReady && S.user) {
    await S.fs.addDoc(S.fs.collection(S.db, 'screenings'), row);
  } else {
    const local = JSON.parse(localStorage.getItem('screenings') || '[]');
    local.unshift(row);
    localStorage.setItem('screenings', JSON.stringify(local.slice(0, 200)));
  }
  setBanner(`Saved — ${triage.band} (${triage.score}/100)${firebaseReady && S.user ? ', synced to Firestore.' : ', kept locally.'}`);
  S.rec = [];
  refreshList();
});

// ── History list ──
async function refreshList() {
  let rows = [];
  if (firebaseReady && S.user) {
    const q = S.fs.query(
      S.fs.collection(S.db, 'screenings'),
      S.fs.where('uid', '==', S.user.uid),
      S.fs.orderBy('ts', 'desc'), S.fs.limit(50));
    const snap = await S.fs.getDocs(q);
    rows = snap.docs.map(d => d.data());
  } else {
    rows = JSON.parse(localStorage.getItem('screenings') || '[]');
  }
  renderList(rows);
}
$('refreshList').addEventListener('click', refreshList);

function renderList(rows) {
  const el = $('screeningList');
  if (!rows.length) {
    el.innerHTML = '<p class="muted empty-note">No screenings yet. Connect the board and save one.</p>';
    return;
  }
  el.innerHTML = rows.map(r => {
    const bandCls = r.band === 'RED' ? 'band-r' : r.band === 'YELLOW' ? 'band-y' : 'band-g';
    const when = new Date(r.ts).toLocaleString();
    return `<div class="srow">
      <span class="band ${bandCls}"></span>
      <div class="meta">
        <div class="name">${escapeHtml(r.patientName)} · <b>${r.band}</b> ${r.score}/100</div>
        <div class="sub">${when}${r.symptoms ? ' · ' + escapeHtml(r.symptoms) : ''}${r.rules?.length ? ' · ' + escapeHtml(r.rules[0]) : ''}</div>
      </div>
      <div class="vitals">
        <div class="v"><b>${r.hr || '—'}</b><span>bpm</span></div>
        <div class="v"><b>${r.spo2 || '—'}</b><span>%</span></div>
        <div class="v"><b>${r.tempC ?? '—'}</b><span>°C</span></div>
      </div>
    </div>`;
  }).join('');
}
function escapeHtml(s) { return String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }

// ── Boot ──
initFirebase().catch(e => setBanner('Cloud unavailable: ' + e.message));
refreshList();
