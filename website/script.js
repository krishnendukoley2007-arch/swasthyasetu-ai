/* ═══════════════════════════════════════════════════════
   SwasthyaSetu AI — Landing + Live Dashboard Scripts
   Web Bluetooth · Real-time ECG · Sparkline graphs
   Matches firmware v2.2.0 protocol
   ═══════════════════════════════════════════════════════ */

// ── NAVBAR SCROLL EFFECT ───────────────────────────────
const navbar = document.getElementById('navbar');
const navToggle = document.getElementById('navToggle');
const navLinks = document.getElementById('navLinks');

window.addEventListener('scroll', () => {
    navbar.classList.toggle('scrolled', window.scrollY > 50);
});

navToggle.addEventListener('click', () => {
    navLinks.classList.toggle('open');
    navToggle.classList.toggle('active');
});

navLinks.querySelectorAll('a').forEach(link => {
    link.addEventListener('click', () => {
        navLinks.classList.remove('open');
        navToggle.classList.remove('active');
    });
});

// ── THEME TOGGLE ───────────────────────────────────────
const themeToggleBtn = document.getElementById('themeToggleBtn');
if (themeToggleBtn) {
    themeToggleBtn.addEventListener('click', () => {
        document.body.classList.toggle('light-mode');
        if (document.body.classList.contains('light-mode')) {
            themeToggleBtn.innerHTML = '🌙 Dark Mode';
        } else {
            themeToggleBtn.innerHTML = '☀️ Outdoor Mode';
        }
    });
}

// ── SMOOTH SCROLL ──────────────────────────────────────
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) target.scrollIntoView({ behavior: 'smooth', block: 'start' });
    });
});

// ── ANIMATED COUNTERS ──────────────────────────────────
function animateCounter(el) {
    const target = parseInt(el.dataset.target);
    if (!target) return;
    const duration = 2000;
    const start = performance.now();
    function update(now) {
        const elapsed = now - start;
        const progress = Math.min(elapsed / duration, 1);
        const eased = 1 - Math.pow(1 - progress, 3);
        el.textContent = Math.round(eased * target);
        if (progress < 1) requestAnimationFrame(update);
    }
    requestAnimationFrame(update);
}

// ── INTERSECTION OBSERVER ──────────────────────────────
const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            entry.target.classList.add('visible');
            if (entry.target.closest('.hero-stats')) {
                entry.target.querySelectorAll('.stat-number[data-target]').forEach(animateCounter);
            }
            observer.unobserve(entry.target);
        }
    });
}, { threshold: 0.15, rootMargin: '0px 0px -50px 0px' });

document.querySelectorAll(
    '.feature-card, .flow-step, .hw-card, .download-card, .section-header'
).forEach(el => {
    el.classList.add('animate-in');
    observer.observe(el);
});

const heroStats = document.querySelector('.hero-stats');
if (heroStats) {
    heroStats.classList.add('animate-in');
    observer.observe(heroStats);
}

document.querySelectorAll('.features-grid .feature-card').forEach((card, i) => {
    card.style.transitionDelay = `${i * 0.08}s`;
});

// ── 3D TILT EFFECT ─────────────────────────────────────
document.querySelectorAll('.impact-card').forEach(card => {
    card.addEventListener('mousemove', (e) => {
        const rect = card.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;
        const centerX = rect.width / 2;
        const centerY = rect.height / 2;
        const rotateX = ((y - centerY) / centerY) * -10; // Max 10 deg
        const rotateY = ((x - centerX) / centerX) * 10;
        
        card.style.transform = `perspective(1000px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) scale3d(1.02, 1.02, 1.02)`;
        card.style.transition = 'none';
        card.style.zIndex = '10';
    });
    
    card.addEventListener('mouseleave', () => {
        card.style.transform = 'perspective(1000px) rotateX(0deg) rotateY(0deg) scale3d(1, 1, 1)';
        card.style.transition = 'all 0.4s var(--ease-out)';
        card.style.zIndex = '1';
    });
});

// ── PARTICLE SYSTEM ────────────────────────────────────
class ParticleSystem {
    constructor(canvas) {
        this.canvas = canvas;
        this.ctx = canvas.getContext('2d');
        this.particles = [];
        this.resize();
        window.addEventListener('resize', () => this.resize());
    }
    resize() {
        this.canvas.width = this.canvas.parentElement.offsetWidth;
        this.canvas.height = this.canvas.parentElement.offsetHeight;
        this.init();
    }
    init() {
        this.particles = [];
        const count = Math.min(Math.floor(this.canvas.width * this.canvas.height / 15000), 80);
        for (let i = 0; i < count; i++) {
            this.particles.push({
                x: Math.random() * this.canvas.width,
                y: Math.random() * this.canvas.height,
                vx: (Math.random() - 0.5) * 0.3,
                vy: (Math.random() - 0.5) * 0.3,
                r: Math.random() * 2 + 0.5,
                alpha: Math.random() * 0.5 + 0.1
            });
        }
    }
    draw() {
        this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
        this.particles.forEach((p, i) => {
            p.x += p.vx;
            p.y += p.vy;
            if (p.x < 0 || p.x > this.canvas.width) p.vx *= -1;
            if (p.y < 0 || p.y > this.canvas.height) p.vy *= -1;
            this.ctx.beginPath();
            this.ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
            this.ctx.fillStyle = `rgba(6, 182, 212, ${p.alpha})`;
            this.ctx.fill();
            for (let j = i + 1; j < this.particles.length; j++) {
                const p2 = this.particles[j];
                const dx = p.x - p2.x;
                const dy = p.y - p2.y;
                const dist = Math.sqrt(dx * dx + dy * dy);
                if (dist < 120) {
                    this.ctx.beginPath();
                    this.ctx.moveTo(p.x, p.y);
                    this.ctx.lineTo(p2.x, p2.y);
                    this.ctx.strokeStyle = `rgba(6, 182, 212, ${0.08 * (1 - dist / 120)})`;
                    this.ctx.lineWidth = 0.5;
                    this.ctx.stroke();
                }
            }
        });
        requestAnimationFrame(() => this.draw());
    }
}
const particleCanvas = document.getElementById('particleCanvas');
if (particleCanvas) { const ps = new ParticleSystem(particleCanvas); ps.draw(); }

// ── THREE.JS HARDWARE VIEWER ───────────────────────────
function initThreeJS() {
    const canvas = document.getElementById('threeCanvas');
    if (!canvas || typeof THREE === 'undefined') return;

    const renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true });
    renderer.setPixelRatio(window.devicePixelRatio);
    
    const container = canvas.parentElement;
    renderer.setSize(container.clientWidth, container.clientHeight);

    const scene = new THREE.Scene();
    
    const camera = new THREE.PerspectiveCamera(45, container.clientWidth / container.clientHeight, 0.1, 100);
    camera.position.set(0, 3, 7);
    camera.lookAt(0, 0, 0);

    // Lighting
    const ambientLight = new THREE.AmbientLight(0xffffff, 0.6);
    scene.add(ambientLight);
    
    const dirLight = new THREE.DirectionalLight(0x06b6d4, 1.5);
    dirLight.position.set(5, 5, 5);
    scene.add(dirLight);

    const backLight = new THREE.DirectionalLight(0x8b5cf6, 1);
    backLight.position.set(-5, 5, -5);
    scene.add(backLight);

    // Create a stylized representation of the ESP32 hardware board
    const boardGeo = new THREE.BoxGeometry(3, 0.2, 4);
    const boardMat = new THREE.MeshPhysicalMaterial({
        color: 0x111827,
        metalness: 0.8,
        roughness: 0.2,
        clearcoat: 1.0,
        clearcoatRoughness: 0.1
    });
    const board = new THREE.Mesh(boardGeo, boardMat);
    scene.add(board);

    // ESP32 Chip
    const chipGeo = new THREE.BoxGeometry(1.2, 0.3, 1.5);
    const chipMat = new THREE.MeshStandardMaterial({ color: 0x222222, metalness: 0.5, roughness: 0.8 });
    const chip = new THREE.Mesh(chipGeo, chipMat);
    chip.position.set(0, 0.2, -0.5);
    scene.add(chip);

    // MAX30102
    const sensorGeo = new THREE.BoxGeometry(0.5, 0.25, 0.5);
    const sensorMat = new THREE.MeshStandardMaterial({ color: 0xef4444, emissive: 0xef4444, emissiveIntensity: 0.5 });
    const sensor = new THREE.Mesh(sensorGeo, sensorMat);
    sensor.position.set(1, 0.2, 1.2);
    scene.add(sensor);

    // MLX90614
    const mlxGeo = new THREE.CylinderGeometry(0.3, 0.3, 0.4, 16);
    const mlxMat = new THREE.MeshStandardMaterial({ color: 0x64748b, metalness: 0.9, roughness: 0.1 });
    const mlx = new THREE.Mesh(mlxGeo, mlxMat);
    mlx.position.set(-1, 0.3, 1.2);
    scene.add(mlx);

    // Group for rotation
    const deviceGroup = new THREE.Group();
    deviceGroup.add(board);
    deviceGroup.add(chip);
    deviceGroup.add(sensor);
    deviceGroup.add(mlx);
    scene.add(deviceGroup);

    // Interaction
    let isDragging = false;
    let previousMousePosition = { x: 0, y: 0 };
    let targetRotation = { x: 0.3, y: 0.5 };
    let currentRotation = { x: 0.3, y: 0.5 };

    canvas.addEventListener('mousedown', (e) => {
        isDragging = true;
    });
    
    window.addEventListener('mouseup', () => {
        isDragging = false;
    });

    window.addEventListener('mousemove', (e) => {
        if (isDragging) {
            const deltaMove = {
                x: e.offsetX - previousMousePosition.x,
                y: e.offsetY - previousMousePosition.y
            };
            targetRotation.y += deltaMove.x * 0.01;
            targetRotation.x += deltaMove.y * 0.01;
            
            // Limit vertical rotation
            targetRotation.x = Math.max(-Math.PI/2, Math.min(Math.PI/2, targetRotation.x));
        }
        previousMousePosition = { x: e.offsetX, y: e.offsetY };
    });

    // Handle touch
    canvas.addEventListener('touchstart', (e) => {
        isDragging = true;
        previousMousePosition = { x: e.touches[0].clientX, y: e.touches[0].clientY };
    }, {passive: true});

    window.addEventListener('touchend', () => {
        isDragging = false;
    });

    window.addEventListener('touchmove', (e) => {
        if (isDragging) {
            const deltaMove = {
                x: e.touches[0].clientX - previousMousePosition.x,
                y: e.touches[0].clientY - previousMousePosition.y
            };
            targetRotation.y += deltaMove.x * 0.01;
            targetRotation.x += deltaMove.y * 0.01;
            targetRotation.x = Math.max(-Math.PI/2, Math.min(Math.PI/2, targetRotation.x));
            previousMousePosition = { x: e.touches[0].clientX, y: e.touches[0].clientY };
        }
    }, {passive: true});


    function animate() {
        requestAnimationFrame(animate);
        
        // Auto rotate slowly if not interacting
        if (!isDragging) {
            targetRotation.y += 0.002;
        }

        // Smoothly interpolate rotation
        currentRotation.x += (targetRotation.x - currentRotation.x) * 0.1;
        currentRotation.y += (targetRotation.y - currentRotation.y) * 0.1;

        deviceGroup.rotation.x = currentRotation.x;
        deviceGroup.rotation.y = currentRotation.y;

        renderer.render(scene, camera);
    }
    
    animate();

    window.addEventListener('resize', () => {
        camera.aspect = container.clientWidth / container.clientHeight;
        camera.updateProjectionMatrix();
        renderer.setSize(container.clientWidth, container.clientHeight);
    });
}

window.addEventListener('DOMContentLoaded', initThreeJS);

// ── HERO ECG WAVEFORM ──────────────────────────────────
class ECGWaveform {
    constructor(canvas, color = 'rgba(6, 182, 212, 0.6)', lineWidth = 2) {
        this.canvas = canvas;
        this.ctx = canvas.getContext('2d');
        this.color = color;
        this.lineWidth = lineWidth;
        this.offset = 0;
        this.resize();
        window.addEventListener('resize', () => this.resize());
    }
    resize() {
        const parent = this.canvas.parentElement;
        this.canvas.width = parent.offsetWidth;
        this.canvas.height = parent.offsetHeight;
    }
    ecgSample(t) {
        t = ((t % 1) + 1) % 1;
        if (t > 0.05 && t < 0.15) return 0.12 * Math.sin((t - 0.05) / 0.1 * Math.PI);
        if (t > 0.18 && t < 0.22) return -0.15 * Math.sin((t - 0.18) / 0.04 * Math.PI);
        if (t > 0.22 && t < 0.28) return 0.85 * Math.sin((t - 0.22) / 0.06 * Math.PI);
        if (t > 0.28 && t < 0.32) return -0.25 * Math.sin((t - 0.28) / 0.04 * Math.PI);
        if (t > 0.38 && t < 0.52) return 0.18 * Math.sin((t - 0.38) / 0.14 * Math.PI);
        return 0;
    }
    draw() {
        const { ctx, canvas } = this;
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        const midY = canvas.height / 2;
        const amplitude = canvas.height * 0.35;
        const beatsVisible = 4;
        const pointsPerBeat = canvas.width / beatsVisible;
        ctx.beginPath();
        ctx.strokeStyle = this.color;
        ctx.lineWidth = this.lineWidth;
        ctx.lineJoin = 'round';
        for (let x = 0; x < canvas.width; x++) {
            const t = (x + this.offset) / pointsPerBeat;
            const y = midY - this.ecgSample(t) * amplitude;
            if (x === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        }
        ctx.stroke();
        ctx.strokeStyle = this.color.replace(/[\d.]+\)$/, '0.2)');
        ctx.lineWidth = this.lineWidth + 4;
        ctx.stroke();
        this.offset += 1.5;
        requestAnimationFrame(() => this.draw());
    }
}
const ecgCanvas = document.getElementById('ecgCanvas');
if (ecgCanvas) { const heroEcg = new ECGWaveform(ecgCanvas, 'rgba(6, 182, 212, 0.5)', 2); heroEcg.draw(); }


// ══════════════════════════════════════════════════════
// LIVE DASHBOARD — Web Bluetooth + Real-time graphs
// Protocol matches firmware v2.1.0
// ══════════════════════════════════════════════════════

const SERVICE     = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
const CHAR_VITALS = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';
const CHAR_ECG    = '6e400004-b5a3-f393-e0a9-e50e24dcca9e';
const CHAR_MOTION = '6e400005-b5a3-f393-e0a9-e50e24dcca9e';

// DOM elements
const connectBtn      = document.getElementById('connectBtn');
const connectionDot   = document.getElementById('connectionDot');
const connectionLabel = document.getElementById('connectionLabel');
const connectionDevice= document.getElementById('connectionDevice');
const connectionTimer = document.getElementById('connectionTimer');
const ecgLiveDot      = document.getElementById('ecgLiveDot');
const ecgLabel        = document.getElementById('ecgLabel');
const measureBtn      = document.getElementById('measureBtn');
const measureProgress = document.getElementById('measureProgress');
const measureFill     = document.getElementById('measureFill');
const measureTimer    = document.getElementById('measureTimer');

// State
let btDevice = null;
let isConnected = false;
let connectStartTime = 0;
let timerInterval = null;

// Data buffers
const ecgSamples = [];          // Raw ECG int16 samples from BLE
const hrHistory = [];            // HR readings over time
const tempHistory = [];          // Temperature readings over time
const MAX_ECG = 250 * 6;        // 6 seconds of ECG at 250 Hz
const MAX_HISTORY = 60;          // 60 data points for sparklines

// Current values
let currentHR = 0, currentSpO2 = 0, currentTemp = 0;
let currentRR = 0, currentQuality = 0, currentBattery = 0;
let isLeadOff = true;

// ── CONNECT / DISCONNECT ───────────────────────────────
if (connectBtn) {
    connectBtn.addEventListener('click', async () => {
        if (isConnected) {
            disconnect();
            return;
        }

        if (!navigator.bluetooth) {
            alert('Web Bluetooth is not supported in this browser.\nPlease use Chrome or Edge on desktop or Android.');
            return;
        }

        try {
            connectBtn.textContent = 'Scanning...';
            connectionLabel.textContent = 'SCANNING';
            connectionLabel.style.color = '#f59e0b';

            btDevice = await navigator.bluetooth.requestDevice({
                filters: [{ name: 'SSAI-SENSE-01' }],
                optionalServices: [SERVICE],
            });

            btDevice.addEventListener('gattserverdisconnected', onDisconnect);

            connectBtn.textContent = 'Connecting...';
            connectionLabel.textContent = 'CONNECTING';

            const server = await btDevice.gatt.connect();
            const svc = await server.getPrimaryService(SERVICE);

            const vitalsChar = await svc.getCharacteristic(CHAR_VITALS);
            const ecgChar = await svc.getCharacteristic(CHAR_ECG);

            await vitalsChar.startNotifications();
            vitalsChar.addEventListener('characteristicvaluechanged', onTelemetry);

            await ecgChar.startNotifications();
            ecgChar.addEventListener('characteristicvaluechanged', onEcgData);

            // Motion characteristic (optional — may not exist on older firmware)
            try {
                const motionChar = await svc.getCharacteristic(CHAR_MOTION);
                await motionChar.startNotifications();
                motionChar.addEventListener('characteristicvaluechanged', onMotionData);
                console.log('[BLE] Motion characteristic subscribed');
            } catch (e) {
                console.warn('[BLE] Motion characteristic not available:', e.message);
            }

            // Connected!
            isConnected = true;
            connectStartTime = Date.now();

            connectBtn.textContent = 'Disconnect';
            connectBtn.classList.add('connected');
            connectionDot.classList.add('live');
            connectionLabel.textContent = 'CONNECTED';
            connectionLabel.style.color = '#10b981';
            connectionDevice.textContent = btDevice.name || 'SSAI-SENSE-01';
            ecgLiveDot.classList.add('live');
            ecgLabel.textContent = 'LIVE';
            ecgLabel.style.color = '#10b981';
            measureBtn.disabled = false;

            timerInterval = setInterval(updateTimer, 1000);

        } catch (error) {
            console.error('Bluetooth error:', error);
            onDisconnect();
            if (error.name !== 'NotFoundError') {
                alert('Connection failed: ' + error.message);
            }
        }
    });
}

function disconnect() {
    if (btDevice && btDevice.gatt.connected) {
        btDevice.gatt.disconnect();
    }
}

function onDisconnect() {
    isConnected = false;
    if (timerInterval) { clearInterval(timerInterval); timerInterval = null; }

    if (connectBtn) {
        connectBtn.textContent = 'Connect ESP32';
        connectBtn.classList.remove('connected');
    }
    if (connectionDot) connectionDot.classList.remove('live');
    if (connectionLabel) {
        connectionLabel.textContent = 'DISCONNECTED';
        connectionLabel.style.color = '#64748b';
    }
    if (connectionDevice) connectionDevice.textContent = '';
    if (connectionTimer) connectionTimer.textContent = '';
    if (ecgLiveDot) ecgLiveDot.classList.remove('live');
    if (ecgLabel) { ecgLabel.textContent = 'DEMO'; ecgLabel.style.color = '#64748b'; }
    if (measureBtn) measureBtn.disabled = true;
}

function updateTimer() {
    if (!isConnected || !connectionTimer) return;
    const elapsed = Math.floor((Date.now() - connectStartTime) / 1000);
    const m = Math.floor(elapsed / 60);
    const s = elapsed % 60;
    connectionTimer.textContent = `${m}:${s.toString().padStart(2, '0')}`;
}

// ── TELEMETRY HANDLER ──────────────────────────────────
// Firmware v2.1.0 telemetry frame (20 bytes):
// [0] = 0x01, [1] = 0x01, [2] = HR, [3] = SpO2,
// [4-5] = temp*100 (int16 LE), [6-7] = RR ms (uint16 LE),
// [8] = quality (0 or 100), [9] = flags (0x04 = lead off),
// [14] = battery %
function onTelemetry(event) {
    const v = event.target.value;
    if (v.byteLength !== 20 || v.getUint8(0) !== 0x01) return;

    currentHR       = v.getUint8(2);
    currentSpO2     = v.getUint8(3);
    currentTemp     = v.getInt16(4, true) / 100.0;
    currentRR       = v.getUint16(6, true);
    currentQuality  = v.getUint8(8);
    const flags     = v.getUint8(9);
    isLeadOff       = (flags & 0x04) !== 0;
    currentBattery  = v.getUint8(14);

    // Push to history
    if (currentHR > 0) hrHistory.push(currentHR);
    if (hrHistory.length > MAX_HISTORY) hrHistory.shift();

    if (currentTemp > 20 && currentTemp < 45) tempHistory.push(currentTemp);
    if (tempHistory.length > MAX_HISTORY) tempHistory.shift();

    updateVitalsUI();
}

// ── ECG DATA HANDLER ───────────────────────────────────
// Firmware v2.1.0 ECG frame (20 bytes):
// [0] = 0x02, [1] = 0x01, [2-3] = unused,
// [4-19] = 8 x int16 LE filtered ECG samples
function onEcgData(event) {
    const v = event.target.value;
    if (v.byteLength < 4 || v.getUint8(0) !== 0x02) return;

    for (let o = 4; o + 2 <= v.byteLength; o += 2) {
        ecgSamples.push(v.getInt16(o, true));
    }

    if (ecgSamples.length > MAX_ECG) {
        ecgSamples.splice(0, ecgSamples.length - MAX_ECG);
    }
}

// ── MOTION DATA HANDLER ────────────────────────────────
// Firmware v2.2.0 motion frame (20 bytes):
// [0] = 0x03, [1] = 0x01,
// [2-3] = accelX*1000 (int16 LE), [4-5] = accelY*1000,
// [6-7] = accelZ*1000, [8-9] = gyroX*10,
// [10-11] = gyroY*10, [12-13] = gyroZ*10,
// [14] = fallDetected flag
function onMotionData(event) {
    const v = event.target.value;
    if (v.byteLength < 15 || v.getUint8(0) !== 0x03) return;

    const ax = v.getInt16(2, true) / 1000.0;
    const ay = v.getInt16(4, true) / 1000.0;
    const az = v.getInt16(6, true) / 1000.0;
    const gx = v.getInt16(8, true) / 10.0;
    const gy = v.getInt16(10, true) / 10.0;
    const gz = v.getInt16(12, true) / 10.0;
    const fall = v.getUint8(14) === 1;

    accelXHistory.push(ax);
    accelYHistory.push(ay);
    accelZHistory.push(az);
    gyroXHistory.push(gx);
    gyroYHistory.push(gy);
    gyroZHistory.push(gz);

    if (accelXHistory.length > MAX_HISTORY) {
        accelXHistory.shift(); accelYHistory.shift(); accelZHistory.shift();
        gyroXHistory.shift(); gyroYHistory.shift(); gyroZHistory.shift();
    }

    // Fall detection UI
    const fallStatus = document.getElementById('fallStatus');
    if (fallStatus) {
        if (fall) {
            fallStatus.textContent = '⚠ FALL DETECTED';
            fallStatus.style.background = 'rgba(239,68,68,0.15)';
            fallStatus.style.color = '#ef4444';
            // Browser notification
            if ('Notification' in window && Notification.permission === 'granted') {
                new Notification('⚠️ Fall Detected!', {
                    body: 'SwasthyaSetu AI detected a potential fall. Check on the patient immediately.',
                    icon: 'https://cdn-icons-png.flaticon.com/512/2966/2966327.png'
                });
            }
        } else {
            fallStatus.textContent = 'STABLE';
            fallStatus.style.background = 'rgba(16,185,129,0.15)';
            fallStatus.style.color = '#10b981';
        }
    }
}

// ── UPDATE VITALS UI ───────────────────────────────────
function updateVitalsUI() {
    const el = (id) => document.getElementById(id);

    // Heart Rate
    const hrEl = el('vitalHR');
    if (hrEl) hrEl.textContent = isLeadOff ? '--' : (currentHR || '--');
    const rrEl = el('vitalRR');
    if (rrEl) rrEl.textContent = isLeadOff ? '--' : (currentRR || '--');

    const hrStatus = el('hrStatus');
    if (hrStatus && !isLeadOff && currentHR > 0) {
        if (currentHR < 60) { hrStatus.textContent = 'LOW'; hrStatus.style.background = 'rgba(239,68,68,0.15)'; hrStatus.style.color = '#ef4444'; }
        else if (currentHR > 100) { hrStatus.textContent = 'HIGH'; hrStatus.style.background = 'rgba(239,68,68,0.15)'; hrStatus.style.color = '#ef4444'; }
        else { hrStatus.textContent = 'NORMAL'; hrStatus.style.background = 'rgba(16,185,129,0.15)'; hrStatus.style.color = '#10b981'; }
    }

    // SpO2
    const spo2El = el('vitalSpO2');
    if (spo2El) spo2El.textContent = currentSpO2 > 0 ? currentSpO2 : '--';

    const spo2Status = el('spo2Status');
    if (spo2Status && currentSpO2 > 0) {
        if (currentSpO2 < 94) { spo2Status.textContent = 'LOW'; spo2Status.style.background = 'rgba(239,68,68,0.15)'; spo2Status.style.color = '#ef4444'; }
        else { spo2Status.textContent = 'NORMAL'; spo2Status.style.background = 'rgba(16,185,129,0.15)'; spo2Status.style.color = '#10b981'; }
    }

    // SpO2 Ring
    const ring = el('spo2Ring');
    if (ring && currentSpO2 > 0) {
        const circumference = 2 * Math.PI * 42;
        const offset = circumference * (1 - currentSpO2 / 100);
        ring.style.strokeDashoffset = offset;
    }

    // Temperature
    const tempEl = el('vitalTemp');
    if (tempEl) tempEl.textContent = (currentTemp > 20 && currentTemp < 45) ? currentTemp.toFixed(1) : '--';

    const tempStatus = el('tempStatus');
    if (tempStatus && currentTemp > 20) {
        if (currentTemp > 38) { tempStatus.textContent = 'FEVER'; tempStatus.style.background = 'rgba(239,68,68,0.15)'; tempStatus.style.color = '#ef4444'; }
        else if (currentTemp < 35) { tempStatus.textContent = 'LOW'; tempStatus.style.background = 'rgba(245,158,11,0.15)'; tempStatus.style.color = '#f59e0b'; }
        else { tempStatus.textContent = 'NORMAL'; tempStatus.style.background = 'rgba(16,185,129,0.15)'; tempStatus.style.color = '#10b981'; }
    }

    // Battery
    const battEl = el('vitalBatt');
    if (battEl) battEl.textContent = currentBattery;
    const battFill = el('battFill');
    if (battFill) battFill.style.width = currentBattery + '%';

    // Quality & Leads
    const qualEl = el('vitalQual');
    if (qualEl) qualEl.textContent = currentQuality + '%';
    const leadsEl = el('vitalLeads');
    if (leadsEl) {
        leadsEl.textContent = isLeadOff ? 'OFF' : 'ON';
        leadsEl.style.color = isLeadOff ? '#ef4444' : '#10b981';
    }
}

// ── CHART.JS INITIALIZATION ──────────────────────────────
Chart.defaults.color = 'rgba(148, 163, 184, 0.8)';
Chart.defaults.font.family = "'Inter', sans-serif";

const commonOptions = {
    responsive: true,
    maintainAspectRatio: false,
    animation: { duration: 0 },
    plugins: { legend: { display: false }, tooltip: { enabled: true, mode: 'index', intersect: false } },
    scales: {
        x: { display: true, grid: { color: 'rgba(255,255,255,0.03)' }, ticks: { display: false } },
        y: { display: true, grid: { color: 'rgba(255,255,255,0.05)' }, position: 'right' }
    },
    elements: {
        point: { radius: 0, hitRadius: 10, hoverRadius: 4 },
        line: { borderWidth: 2, tension: 0.4 }
    },
    interaction: { mode: 'nearest', axis: 'x', intersect: false }
};

let hrChart, tempChart, accelChart, gyroChart;

function initCharts() {
    const ctxHR = document.getElementById('chartHR').getContext('2d');
    const gradHR = ctxHR.createLinearGradient(0, 0, 0, 100);
    gradHR.addColorStop(0, 'rgba(239, 68, 68, 0.3)');
    gradHR.addColorStop(1, 'rgba(239, 68, 68, 0.05)');
    
    hrChart = new Chart(ctxHR, {
        type: 'line',
        data: {
            labels: new Array(MAX_HISTORY).fill(''),
            datasets: [{ label: 'HR', data: new Array(MAX_HISTORY).fill(0), borderColor: '#ef4444', backgroundColor: gradHR, fill: true }]
        },
        options: { ...commonOptions, scales: { ...commonOptions.scales, y: { min: 40, max: 140, position: 'right', grid: { color: 'rgba(255,255,255,0.05)' } } } }
    });

    const ctxTemp = document.getElementById('chartTemp').getContext('2d');
    const gradTemp = ctxTemp.createLinearGradient(0, 0, 0, 100);
    gradTemp.addColorStop(0, 'rgba(245, 158, 11, 0.3)');
    gradTemp.addColorStop(1, 'rgba(245, 158, 11, 0.05)');
    
    tempChart = new Chart(ctxTemp, {
        type: 'line',
        data: {
            labels: new Array(MAX_HISTORY).fill(''),
            datasets: [{ label: 'Temp', data: new Array(MAX_HISTORY).fill(36.5), borderColor: '#f59e0b', backgroundColor: gradTemp, fill: true }]
        },
        options: { ...commonOptions, scales: { ...commonOptions.scales, y: { min: 34, max: 40, position: 'right', grid: { color: 'rgba(255,255,255,0.05)' } } } }
    });

    const ctxAccel = document.getElementById('chartAccel').getContext('2d');
    accelChart = new Chart(ctxAccel, {
        type: 'line',
        data: {
            labels: new Array(MAX_HISTORY).fill(''),
            datasets: [
                { label: 'X', data: new Array(MAX_HISTORY).fill(0), borderColor: '#ef4444', borderWidth: 1.5 },
                { label: 'Y', data: new Array(MAX_HISTORY).fill(0), borderColor: '#10b981', borderWidth: 1.5 },
                { label: 'Z', data: new Array(MAX_HISTORY).fill(1), borderColor: '#3b82f6', borderWidth: 1.5 }
            ]
        },
        options: { ...commonOptions, scales: { ...commonOptions.scales, y: { min: -2, max: 2, position: 'right' } } }
    });

    const ctxGyro = document.getElementById('chartGyro').getContext('2d');
    gyroChart = new Chart(ctxGyro, {
        type: 'line',
        data: {
            labels: new Array(MAX_HISTORY).fill(''),
            datasets: [
                { label: 'X', data: new Array(MAX_HISTORY).fill(0), borderColor: '#ef4444', borderWidth: 1.5 },
                { label: 'Y', data: new Array(MAX_HISTORY).fill(0), borderColor: '#10b981', borderWidth: 1.5 },
                { label: 'Z', data: new Array(MAX_HISTORY).fill(0), borderColor: '#3b82f6', borderWidth: 1.5 }
            ]
        },
        options: { ...commonOptions, scales: { ...commonOptions.scales, y: { min: -250, max: 250, position: 'right' } } }
    });
}
window.addEventListener('DOMContentLoaded', initCharts);

// Data histories for MPU6050
const accelXHistory = [], accelYHistory = [], accelZHistory = [];
const gyroXHistory = [], gyroYHistory = [], gyroZHistory = [];

function updateCharts() {
    if(hrChart) { hrChart.data.datasets[0].data = hrHistory; hrChart.update(); }
    if(tempChart) { tempChart.data.datasets[0].data = tempHistory; tempChart.update(); }
    
    if(accelChart) {
        accelChart.data.datasets[0].data = accelXHistory;
        accelChart.data.datasets[1].data = accelYHistory;
        accelChart.data.datasets[2].data = accelZHistory;
        accelChart.update();
    }
    if(gyroChart) {
        gyroChart.data.datasets[0].data = gyroXHistory;
        gyroChart.data.datasets[1].data = gyroYHistory;
        gyroChart.data.datasets[2].data = gyroZHistory;
        gyroChart.update();
    }
}
setInterval(updateCharts, 500);

// ── MAIN ECG RENDERER ──────────────────────────────────
const ecgMainCanvas = document.getElementById('ecgMainCanvas');
let ecgDemoWaveform = new ECGWaveform(
    document.createElement('canvas'), 'rgba(16, 185, 129, 0.8)', 1.5
);

function renderECG() {
    requestAnimationFrame(renderECG);

    const canvas = ecgMainCanvas;
    if (!canvas) return;

    const dpr = window.devicePixelRatio || 1;
    const w = canvas.clientWidth;
    const h = canvas.clientHeight;
    if (w === 0 || h === 0) return;
    canvas.width = w * dpr;
    canvas.height = h * dpr;
    const ctx = canvas.getContext('2d');
    ctx.scale(dpr, dpr);

    // Background
    ctx.fillStyle = '#060a14';
    ctx.fillRect(0, 0, w, h);

    // Grid
    ctx.strokeStyle = 'rgba(6, 182, 212, 0.06)';
    ctx.lineWidth = 1;
    const gridSpacing = 20;
    for (let x = 0; x < w; x += gridSpacing) {
        ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, h); ctx.stroke();
    }
    for (let y = 0; y < h; y += gridSpacing) {
        ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke();
    }

    // Major grid lines
    ctx.strokeStyle = 'rgba(6, 182, 212, 0.12)';
    for (let x = 0; x < w; x += gridSpacing * 5) {
        ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, h); ctx.stroke();
    }
    for (let y = 0; y < h; y += gridSpacing * 5) {
        ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke();
    }

    if (isConnected && ecgSamples.length > 10) {
        // Real ECG data
        let lo = Infinity, hi = -Infinity;
        for (const s of ecgSamples) {
            if (s < lo) lo = s;
            if (s > hi) hi = s;
        }
        const span = Math.max(1, hi - lo);
        const mid = (hi + lo) / 2;
        const yPad = h * 0.15;

        // Fill gradient
        const fillGrad = ctx.createLinearGradient(0, 0, 0, h);
        fillGrad.addColorStop(0, 'rgba(16, 185, 129, 0.2)');
        fillGrad.addColorStop(1, 'rgba(16, 185, 129, 0.0)');

        ctx.beginPath();
        for (let i = 0; i < ecgSamples.length; i++) {
            const x = (i / (ecgSamples.length - 1)) * w;
            const norm = (ecgSamples[i] - mid) / (span / 2);
            const y = h / 2 - norm * (h / 2 - yPad);
            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        }
        ctx.lineTo(w, h);
        ctx.lineTo(0, h);
        ctx.closePath();
        ctx.fillStyle = fillGrad;
        ctx.fill();

        // Glow layer
        ctx.beginPath();
        ctx.strokeStyle = 'rgba(16, 185, 129, 0.3)';
        ctx.lineWidth = 6;
        ctx.lineJoin = 'round';
        for (let i = 0; i < ecgSamples.length; i++) {
            const x = (i / (ecgSamples.length - 1)) * w;
            const norm = (ecgSamples[i] - mid) / (span / 2);
            const y = h / 2 - norm * (h / 2 - yPad);
            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        }
        ctx.stroke();

        // Main trace
        ctx.beginPath();
        ctx.strokeStyle = '#10b981';
        ctx.lineWidth = 2.5;
        ctx.lineJoin = 'round';
        for (let i = 0; i < ecgSamples.length; i++) {
            const x = (i / (ecgSamples.length - 1)) * w;
            const norm = (ecgSamples[i] - mid) / (span / 2);
            const y = h / 2 - norm * (h / 2 - yPad);
            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        }
        ctx.stroke();

        // Lead-off indicator
        if (isLeadOff) {
            ctx.fillStyle = 'rgba(239, 68, 68, 0.9)';
            ctx.font = '600 14px "JetBrains Mono", monospace';
            ctx.textAlign = 'center';
            ctx.fillText('⚠ LEADS OFF', w / 2, 24);
        }

    } else {
        // Demo ECG waveform
        ecgDemoWaveform.offset += 1.5;
        const beatsVisible = 4;
        const pointsPerBeat = w / beatsVisible;
        const midY = h / 2;
        const amplitude = h * 0.3;

        ctx.beginPath();
        ctx.strokeStyle = 'rgba(6, 182, 212, 0.15)';
        ctx.lineWidth = 6;
        ctx.lineJoin = 'round';
        for (let x = 0; x < w; x++) {
            const t = (x + ecgDemoWaveform.offset) / pointsPerBeat;
            const y = midY - ecgDemoWaveform.ecgSample(t) * amplitude;
            if (x === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        }
        ctx.stroke();

        ctx.beginPath();
        ctx.strokeStyle = 'rgba(6, 182, 212, 0.5)';
        ctx.lineWidth = 2;
        for (let x = 0; x < w; x++) {
            const t = (x + ecgDemoWaveform.offset) / pointsPerBeat;
            const y = midY - ecgDemoWaveform.ecgSample(t) * amplitude;
            if (x === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        }
        ctx.stroke();

        // Label
        ctx.fillStyle = 'rgba(100, 116, 139, 0.6)';
        ctx.font = '500 13px Inter, sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText('Connect SSAI-SENSE-01 to see live ECG', w / 2, h - 16);
    }
}
renderECG();

// ── SPARKLINE UPDATE LOOP ──────────────────────────────
setInterval(() => {
    drawSparkline('sparkHR', hrHistory, 'rgba(239, 68, 68, 0.8)', 50, 120);
    drawSparkline('sparkTemp', tempHistory, 'rgba(245, 158, 11, 0.8)', 34, 40);
}, 500);

// ── DEMO MODE (when not connected) ─────────────────────
let demoInterval = setInterval(() => {
    if (isConnected) return;

    // Simulate demo data
    currentHR = 70 + Math.floor(Math.random() * 7);
    currentSpO2 = 97 + Math.floor(Math.random() * 3);
    currentTemp = 36.2 + Math.random() * 0.6;
    currentRR = 800 + Math.floor(Math.random() * 100);
    currentQuality = 92;
    currentBattery = 85;
    isLeadOff = false;

    hrHistory.push(currentHR);
    if (hrHistory.length > MAX_HISTORY) hrHistory.shift();
    tempHistory.push(currentTemp);
    if (tempHistory.length > MAX_HISTORY) tempHistory.shift();
    
    // Simulate MPU6050 Demo data
    accelXHistory.push((Math.random() - 0.5) * 0.1);
    accelYHistory.push((Math.random() - 0.5) * 0.1);
    accelZHistory.push(1.0 + (Math.random() - 0.5) * 0.05);
    
    gyroXHistory.push((Math.random() - 0.5) * 10);
    gyroYHistory.push((Math.random() - 0.5) * 10);
    gyroZHistory.push((Math.random() - 0.5) * 10);

    if (accelXHistory.length > MAX_HISTORY) {
        accelXHistory.shift(); accelYHistory.shift(); accelZHistory.shift();
        gyroXHistory.shift(); gyroYHistory.shift(); gyroZHistory.shift();
    }

    updateVitalsUI();
}, 1500);

// Request notification permission for fall alerts
if ('Notification' in window && Notification.permission === 'default') {
    Notification.requestPermission();
}

// ── INDEXEDDB PATIENT HISTORY ────────────────────────────
let db;
const request = indexedDB.open('SwasthyaSetuDB', 1);

request.onupgradeneeded = function(event) {
    db = event.target.result;
    if (!db.objectStoreNames.contains('measurements')) {
        db.createObjectStore('measurements', { keyPath: 'id', autoIncrement: true });
    }
};

request.onsuccess = function(event) {
    db = event.target.result;
    loadHistory();
};

function saveMeasurement(hr, spo2, temp, resultStr) {
    if (!db) return;
    const tx = db.transaction('measurements', 'readwrite');
    const store = tx.objectStore('measurements');
    const record = {
        date: new Date().toISOString(),
        hr: hr,
        spo2: spo2,
        temp: temp,
        result: resultStr
    };
    store.add(record);
    tx.oncomplete = () => loadHistory();
}

function loadHistory() {
    if (!db) return;
    const tx = db.transaction('measurements', 'readonly');
    const store = tx.objectStore('measurements');
    const getReq = store.getAll();
    
    getReq.onsuccess = function(event) {
        const records = event.target.result;
        const tbody = document.getElementById('historyTableBody');
        if (!tbody) return;
        
        if (records.length === 0) {
            tbody.innerHTML = `<tr><td colspan="5" style="padding: 20px 0; text-align: center; color: var(--text-muted);">No measurements saved yet. Click "Start 30s Measurement" to save one.</td></tr>`;
            return;
        }
        
        tbody.innerHTML = '';
        // Reverse array to show newest first
        records.reverse().forEach(record => {
            const tr = document.createElement('tr');
            tr.style.borderBottom = '1px solid var(--border-subtle)';
            
            const date = new Date(record.date);
            const dateStr = date.toLocaleDateString() + ' ' + date.toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'});
            
            let resColor = 'var(--text-primary)';
            if (record.result === 'URGENT') resColor = 'var(--accent-red)';
            if (record.result === 'SOON') resColor = 'var(--accent-amber)';
            if (record.result === 'ROUTINE') resColor = 'var(--accent-green)';

            tr.innerHTML = `
                <td style="padding: 10px 0; color: var(--text-secondary);">${dateStr}</td>
                <td>${record.hr}</td>
                <td>${record.spo2}</td>
                <td>${record.temp.toFixed(1)}</td>
                <td style="font-weight: 700; color: ${resColor};">${record.result}</td>
            `;
            tbody.appendChild(tr);
        });
    };
}

// Simulated Measurement Button Logic
if (measureBtn) {
    measureBtn.addEventListener('click', () => {
        if (!isConnected && !isDemoMode) return;
        measureBtn.disabled = true;
        measureProgress.style.display = 'block';
        measureFill.style.width = '0%';
        
        let secondsLeft = 30;
        const interval = setInterval(() => {
            secondsLeft--;
            measureTimer.textContent = `${secondsLeft}s remaining`;
            measureFill.style.width = `${((30 - secondsLeft) / 30) * 100}%`;
            
            if (secondsLeft <= 0) {
                clearInterval(interval);
                measureBtn.disabled = false;
                measureProgress.style.display = 'none';
                
                // Use the real risk engine
                const sample = {
                    heartRateBpm: currentHR,
                    spo2Percent: currentSpO2,
                    temperatureC: currentTemp,
                    ecgSignalQuality: currentQuality / 100,
                    rrIntervalMs: currentRR,
                    rPeakDetected: !isLeadOff,
                    isDemo: !isConnected
                };
                
                let result;
                if (typeof SwasthyaRisk !== 'undefined') {
                    result = SwasthyaRisk.assess({ sample });
                } else {
                    // Fallback if risk engine not loaded
                    let band = 'GREEN';
                    if (currentHR > 100 || currentHR < 50 || currentSpO2 < 92) band = 'RED';
                    else if (currentSpO2 < 95 || currentTemp > 37.8) band = 'YELLOW';
                    result = { band, score: 0, bandLabel: band, recommendedAction: '', firedRules: [] };
                }
                
                // Map band to result string for history
                const bandToResult = { GREEN: 'ROUTINE', YELLOW: 'SOON', RED: 'URGENT' };
                const resultStr = bandToResult[result.band] || 'ROUTINE';
                
                saveMeasurement(currentHR, currentSpO2, currentTemp, resultStr);
                
                // Show triage card
                showTriageCard(result);
            }
        }, 1000);
    });
}

// Track demo mode to allow fake measurements
let isDemoMode = true;

// ── PDF EXPORT ──────────────────────────────────────────
const exportPdfBtn = document.getElementById('exportPdfBtn');
if (exportPdfBtn) {
    exportPdfBtn.addEventListener('click', () => {
        if (typeof jspdf === 'undefined') {
            alert("PDF library is still loading. Please try again in a moment.");
            return;
        }
        
        const { jsPDF } = window.jspdf;
        const doc = new jsPDF();
        
        doc.setFontSize(22);
        doc.setTextColor(37, 99, 235);
        doc.text("SwasthyaSetu AI - Medical Report", 20, 20);
        
        doc.setFontSize(12);
        doc.setTextColor(100, 116, 139);
        doc.text(`Generated on: ${new Date().toLocaleString()}`, 20, 30);
        
        doc.setTextColor(0, 0, 0);
        doc.setFontSize(16);
        doc.text("Current Vitals Summary", 20, 45);
        
        doc.setFontSize(12);
        doc.text(`Heart Rate: ${currentHR > 0 ? currentHR : '--'} bpm`, 20, 55);
        doc.text(`SpO2: ${currentSpO2 > 0 ? currentSpO2 : '--'} %`, 20, 65);
        doc.text(`Temperature: ${currentTemp > 20 ? currentTemp.toFixed(1) : '--'} C`, 20, 75);
        
        // Use real risk engine for PDF triage
        let resultStr = 'ROUTINE';
        let bandLabel = 'Normal';
        let action = '';
        if (typeof SwasthyaRisk !== 'undefined') {
            const sample = {
                heartRateBpm: currentHR,
                spo2Percent: currentSpO2,
                temperatureC: currentTemp,
                ecgSignalQuality: currentQuality / 100,
                rrIntervalMs: currentRR,
                rPeakDetected: !isLeadOff,
                isDemo: !isConnected
            };
            const result = SwasthyaRisk.assess({ sample });
            const bandToResult = { GREEN: 'ROUTINE', YELLOW: 'SOON', RED: 'URGENT' };
            resultStr = bandToResult[result.band] || 'ROUTINE';
            bandLabel = result.bandLabel;
            action = result.recommendedAction;
        } else {
            if (currentHR > 100 || currentHR < 50 || currentSpO2 < 92) resultStr = 'URGENT';
            else if (currentSpO2 < 95 || currentTemp > 37.8) resultStr = 'SOON';
        }
        
        doc.setFontSize(14);
        doc.text(`Triage Assessment: ${resultStr} (${bandLabel})`, 20, 90);
        if (action) {
            doc.setFontSize(10);
            doc.setTextColor(60, 60, 60);
            const lines = doc.splitTextToSize(action, 170);
            doc.text(lines, 20, 100);
        }
        
        doc.setFontSize(10);
        doc.setTextColor(100, 116, 139);
        doc.text("Disclaimer: This report is generated automatically by a screening tool.", 20, 280);
        
        doc.save("SwasthyaSetu_Report.pdf");
    });
}

// ── TRIAGE RESULT CARD UI ──────────────────────────────
function showTriageCard(result) {
    const card = document.getElementById('triageCard');
    const strip = document.getElementById('triageBandStrip');
    const icon = document.getElementById('triageBandIcon');
    const label = document.getElementById('triageBandLabel');
    const score = document.getElementById('triageScore');
    const action = document.getElementById('triageAction');
    const rulesContainer = document.getElementById('triageRulesContainer');

    if (!card) return;

    let color = 'var(--text-primary)';
    let iconStr = '🟢';
    if (result.band === 'YELLOW') {
        color = 'var(--accent-amber)';
        iconStr = '🟡';
    } else if (result.band === 'RED') {
        color = 'var(--accent-red)';
        iconStr = '🔴';
    } else {
        color = 'var(--accent-green)';
        iconStr = '🟢';
    }

    strip.style.backgroundColor = color;
    icon.textContent = iconStr;
    label.textContent = result.bandLabel;
    label.style.color = color;
    score.textContent = `Risk Score: ${result.score}`;
    action.textContent = result.recommendedAction;

    rulesContainer.innerHTML = '';
    result.scoringRules.forEach(rule => {
        const div = document.createElement('div');
        div.style.padding = '8px 12px';
        div.style.background = 'rgba(255,255,255,0.02)';
        div.style.borderLeft = `3px solid ${rule.isCritical ? 'var(--accent-red)' : 'var(--accent-amber)'}`;
        div.style.borderRadius = '4px';
        
        const title = document.createElement('div');
        title.style.fontWeight = '600';
        title.style.fontSize = '0.9rem';
        title.textContent = rule.title;
        
        const detail = document.createElement('div');
        detail.style.fontSize = '0.8rem';
        detail.style.color = 'var(--text-muted)';
        detail.style.marginTop = '4px';
        detail.textContent = rule.detail;
        
        div.appendChild(title);
        div.appendChild(detail);
        rulesContainer.appendChild(div);
    });

    card.style.display = 'block';
}

console.log('🏥 SwasthyaSetu AI — Website loaded successfully');
console.log('📡 Web Bluetooth dashboard ready for SSAI-SENSE-01 (fw v2.2.0)');

// ── PWA SERVICE WORKER ─────────────────────────────────
if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
        navigator.serviceWorker.register('./sw.js').then(registration => {
            console.log('ServiceWorker registration successful with scope: ', registration.scope);
        }).catch(error => {
            console.log('ServiceWorker registration failed: ', error);
        });
    });
}
