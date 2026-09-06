/* ═══════════════════════════════════════════════════════
   SwasthyaSetu AI — Landing Page Scripts
   Particle system · ECG animation · Scroll effects
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

// Close mobile menu on link click
navLinks.querySelectorAll('a').forEach(link => {
    link.addEventListener('click', () => {
        navLinks.classList.remove('open');
        navToggle.classList.remove('active');
    });
});

// ── SMOOTH SCROLL FOR ANCHOR LINKS ─────────────────────
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        e.preventDefault();
        const target = document.querySelector(this.getAttribute('href'));
        if (target) {
            target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
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
        // Ease out cubic
        const eased = 1 - Math.pow(1 - progress, 3);
        el.textContent = Math.round(eased * target);
        if (progress < 1) requestAnimationFrame(update);
    }
    
    requestAnimationFrame(update);
}

// ── INTERSECTION OBSERVER FOR ANIMATIONS ───────────────
const observerOptions = { threshold: 0.15, rootMargin: '0px 0px -50px 0px' };

const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            entry.target.classList.add('visible');
            
            // Animate counters when hero stats come into view
            if (entry.target.closest('.hero-stats')) {
                entry.target.querySelectorAll('.stat-number[data-target]').forEach(animateCounter);
            }
            
            observer.unobserve(entry.target);
        }
    });
}, observerOptions);

// Observe all cards and sections for animate-in
document.querySelectorAll(
    '.problem-card, .feature-card, .flow-step, .spec-card, .principle-card, .triage-band, .triage-feature, .download-card, .perm-row, .app-feature-item'
).forEach(el => {
    el.classList.add('animate-in');
    observer.observe(el);
});

// Observe hero stats
const heroStats = document.querySelector('.hero-stats');
if (heroStats) {
    heroStats.classList.add('animate-in');
    observer.observe(heroStats);
}

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

            // Draw connections
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
if (particleCanvas) {
    const ps = new ParticleSystem(particleCanvas);
    ps.draw();
}

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

    // Generate a single ECG-like beat pattern
    ecgSample(t) {
        // Normalised t in [0, 1] for one beat
        t = ((t % 1) + 1) % 1;

        // P wave
        if (t > 0.05 && t < 0.15) {
            return 0.12 * Math.sin((t - 0.05) / 0.1 * Math.PI);
        }
        // QRS complex
        if (t > 0.18 && t < 0.22) {
            return -0.15 * Math.sin((t - 0.18) / 0.04 * Math.PI);
        }
        if (t > 0.22 && t < 0.28) {
            return 0.85 * Math.sin((t - 0.22) / 0.06 * Math.PI);
        }
        if (t > 0.28 && t < 0.32) {
            return -0.25 * Math.sin((t - 0.28) / 0.04 * Math.PI);
        }
        // T wave
        if (t > 0.38 && t < 0.52) {
            return 0.18 * Math.sin((t - 0.38) / 0.14 * Math.PI);
        }

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

            if (x === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
        }

        ctx.stroke();

        // Glow effect
        ctx.strokeStyle = this.color.replace(/[\d.]+\)$/, '0.2)');
        ctx.lineWidth = this.lineWidth + 4;
        ctx.stroke();

        this.offset += 1.5;
        requestAnimationFrame(() => this.draw());
    }
}

// Hero ECG
const ecgCanvas = document.getElementById('ecgCanvas');
if (ecgCanvas) {
    const heroEcg = new ECGWaveform(ecgCanvas, 'rgba(6, 182, 212, 0.5)', 2);
    heroEcg.draw();
}

// Phone demo ECG
const demoEcgCanvas = document.getElementById('demoEcgCanvas');
if (demoEcgCanvas) {
    const demoEcg = new ECGWaveform(demoEcgCanvas, 'rgba(16, 185, 129, 0.8)', 1.5);
    demoEcg.draw();
}

// ── ANIMATED HEART RATE IN PHONE DEMO ──────────────────
const demoHR = document.getElementById('demoHR');
if (demoHR) {
    setInterval(() => {
        // Simulate slight HR variation 70–76
        const hr = 70 + Math.floor(Math.random() * 7);
        demoHR.textContent = hr;
    }, 2000);
}

// ── STAGGER ANIMATIONS ON FEATURE CARDS ────────────────
document.querySelectorAll('.features-grid .feature-card').forEach((card, i) => {
    card.style.transitionDelay = `${i * 0.08}s`;
});

document.querySelectorAll('.hardware-specs .spec-card').forEach((card, i) => {
    card.style.transitionDelay = `${i * 0.1}s`;
});

document.querySelectorAll('.permissions-table .perm-row').forEach((row, i) => {
    row.style.transitionDelay = `${i * 0.1}s`;
});

// ── PARALLAX ON HARDWARE IMAGE ─────────────────────────
const hwImg = document.getElementById('hardwareImg');
if (hwImg) {
    window.addEventListener('scroll', () => {
        const rect = hwImg.getBoundingClientRect();
        if (rect.top < window.innerHeight && rect.bottom > 0) {
            const progress = (window.innerHeight - rect.top) / (window.innerHeight + rect.height);
            hwImg.style.transform = `scale(1) translateY(${(progress - 0.5) * 20}px)`;
        }
    });
}

// ── SMOOTH REVEAL FOR SECTION HEADERS ──────────────────
document.querySelectorAll('.section-header').forEach(header => {
    header.classList.add('animate-in');
    observer.observe(header);
});

// ── WEB BLUETOOTH INTEGRATION ─────────────────────────
const webConnectBtn = document.getElementById('webConnectBtn');
const webConnectStatus = document.getElementById('webConnectStatus');

if (webConnectBtn) {
    const SERVICE = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
    const CHAR_VITALS = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';
    const CHAR_ECG    = '6e400004-b5a3-f393-e0a9-e50e24dcca9e';
    const CHAR_CTRL   = '6e400005-b5a3-f393-e0a9-e50e24dcca9e';

    let btDevice = null;
    let btServer = null;
    let ctrlChar = null;
    let isStreaming = false;

    // We'll store incoming real samples here
    const realSamples = [];
    const SAMPLE_HZ = 250;
    const WINDOW_S = 4;
    
    // Original fake HR interval id
    let fakeHrInterval = null;

    if (demoHR) {
        fakeHrInterval = setInterval(() => {
            if (isStreaming) return; // Skip if we have real data
            const hr = 70 + Math.floor(Math.random() * 7);
            demoHR.textContent = hr;
        }, 2000);
    }

    webConnectBtn.addEventListener('click', async () => {
        if (btDevice && btDevice.gatt.connected) {
            // Disconnect
            if (ctrlChar && isStreaming) {
                try { await ctrlChar.writeValueWithResponse(new Uint8Array([0xA0])); } catch(e) {}
            }
            btDevice.gatt.disconnect();
            return;
        }

        if (!navigator.bluetooth) {
            alert('Web Bluetooth is not supported in this browser. Please use Chrome or Edge on a desktop or Android device.');
            return;
        }

        try {
            webConnectBtn.textContent = 'Scanning...';
            webConnectStatus.textContent = 'PAIRING';
            webConnectStatus.style.color = 'var(--accent-amber)';

            btDevice = await navigator.bluetooth.requestDevice({
                filters: [{ name: 'SSAI-SENSE-01' }],
                optionalServices: [SERVICE],
            });

            btDevice.addEventListener('gattserverdisconnected', onDisconnect);

            webConnectBtn.textContent = 'Connecting...';
            btServer = await btDevice.gatt.connect();
            const svc = await btServer.getPrimaryService(SERVICE);
            
            const vitalsChar = await svc.getCharacteristic(CHAR_VITALS);
            const ecgChar = await svc.getCharacteristic(CHAR_ECG);
            ctrlChar = await svc.getCharacteristic(CHAR_CTRL);

            await vitalsChar.startNotifications();
            vitalsChar.addEventListener('characteristicvaluechanged', onTelemetry);
            
            await ecgChar.startNotifications();
            ecgChar.addEventListener('characteristicvaluechanged', onRealEcg);

            // Start stream
            await ctrlChar.writeValueWithResponse(new Uint8Array([0xA1]));
            isStreaming = true;

            webConnectBtn.textContent = 'Disconnect ESP32';
            webConnectBtn.style.background = 'rgba(239, 68, 68, 0.1)';
            webConnectBtn.style.color = 'var(--accent-red)';
            webConnectStatus.textContent = 'LIVE STREAMING';
            webConnectStatus.style.color = 'var(--accent-green)';
            
            // Switch UI to real mode
            document.querySelector('.demo-live').textContent = '● ESP32 LIVE';

            // Hijack the demoEcg drawing loop
            if (demoEcg) {
                demoEcg.draw = drawRealEcg.bind(demoEcg);
            }

        } catch (error) {
            console.error('Bluetooth error:', error);
            onDisconnect();
            alert('Failed to connect: ' + error.message);
        }
    });

    function onDisconnect() {
        isStreaming = false;
        webConnectBtn.textContent = 'Connect ESP32';
        webConnectBtn.style.background = 'var(--gradient-primary)';
        webConnectBtn.style.color = 'white';
        webConnectStatus.textContent = 'DISCONNECTED';
        webConnectStatus.style.color = 'var(--text-muted)';
        document.querySelector('.demo-live').textContent = '● DEMO';
        
        // Restore demo drawing
        if (demoEcg) {
            demoEcg.draw = ECGWaveform.prototype.draw.bind(demoEcg);
            demoEcg.draw();
        }
    }

    function onTelemetry(event) {
        const v = event.target.value;
        if (v.byteLength !== 20 || v.getUint8(0) !== 0x01) return;

        const hr = v.getUint8(2);
        const spo2 = v.getUint8(3);
        const temp = v.getInt16(4, true) / 100;
        const qual = v.getUint8(8);

        if (hr > 0 && demoHR) demoHR.textContent = hr;
        
        // Update other DOM elements if they have IDs, right now we just use demoHR
        // Could easily add IDs to SpO2 and Temp in the HTML
    }

    function onRealEcg(event) {
        const v = event.target.value;
        if (v.byteLength < 4 || v.getUint8(0) !== 0x02) return;

        for (let o = 4; o + 2 <= v.byteLength; o += 2) {
            realSamples.push(v.getInt16(o, true));
        }
        
        const keep = SAMPLE_HZ * WINDOW_S;
        if (realSamples.length > keep) {
            realSamples.splice(0, realSamples.length - keep);
        }
    }

    function drawRealEcg() {
        if (!isStreaming) return; // Fallback handled in onDisconnect
        
        requestAnimationFrame(() => drawRealEcg.call(this));
        
        const { ctx, canvas } = this;
        ctx.clearRect(0, 0, canvas.width, canvas.height);

        if (realSamples.length < 2) return;

        let lo = Infinity, hi = -Infinity;
        for (const s of realSamples) {
            if (s < lo) lo = s;
            if (s > hi) hi = s;
        }
        
        const span = Math.max(1, hi - lo);
        const mid = (hi + lo) / 2;
        const yPad = canvas.height * 0.15;
        const h = canvas.height;
        const w = canvas.width;

        ctx.beginPath();
        ctx.strokeStyle = this.color;
        ctx.lineWidth = this.lineWidth;
        ctx.lineJoin = 'round';

        for (let i = 0; i < realSamples.length; i++) {
            const x = (i / (SAMPLE_HZ * WINDOW_S - 1)) * w;
            const norm = (realSamples[i] - mid) / (span / 2);
            const y = h / 2 - norm * (h / 2 - yPad);
            
            if (i === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
        }
        ctx.stroke();

        // Glow
        ctx.strokeStyle = this.color.replace(/[\d.]+\)$/, '0.3)');
        ctx.lineWidth = this.lineWidth + 2;
        ctx.stroke();
    }
}

console.log('🏥 SwasthyaSetu AI — Website loaded successfully');
