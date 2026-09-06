/* ═══════════════════════════════════════════════════════
   SwasthyaSetu AI — Risk Engine (Web port)
   Faithful 1:1 port of lib/domain/rules/risk_engine.dart
   and lib/domain/rules/vulnerability.dart.

   Same inputs → same score, same band, same fired rules.
   Deterministic: no network, no randomness, no clock.
   ═══════════════════════════════════════════════════════ */
(function (global) {
  'use strict';

  const GREEN_MAX = 30;
  const YELLOW_MAX = 60;
  const CRITICAL_FLOOR = 61;
  const MAX_SCORE = 100;

  const Band = { GREEN: 'GREEN', YELLOW: 'YELLOW', RED: 'RED' };
  const Sev = { ADVISORY: 'advisory', WARNING: 'warning', CRITICAL: 'critical' };

  const BandLabel = {
    GREEN: 'Normal',
    YELLOW: 'Needs attention',
    RED: 'Urgent',
  };

  const BandAction = {
    GREEN:
      'Readings are within the expected range for this patient. Continue routine monitoring.',
    YELLOW:
      'Some readings need attention. Arrange a health-worker or clinic review, and screen again if anything changes.',
    RED:
      'Readings are concerning. Arrange prompt medical assessment — do not wait for symptoms to worsen.',
  };

  const BandEscalation = { GREEN: 'NONE', YELLOW: 'CLINIC_VISIT', RED: 'EMERGENCY' };

  function bandForScore(score) {
    if (score <= GREEN_MAX) return Band.GREEN;
    if (score <= YELLOW_MAX) return Band.YELLOW;
    return Band.RED;
  }

  /* ── Vulnerability flags ─────────────────────────────── */
  const Vulnerability = {
    elderly: {
      id: 'elderly', label: 'Elderly (65+)', riskPoints: 5,
      explanation: 'Reduced physiological reserve. Oxygen and heart-rate limits are tightened and the fever threshold is lowered, because older adults often mount a smaller temperature response.',
    },
    chronic: {
      id: 'chronic', label: 'Chronic condition', riskPoints: 10,
      explanation: 'An existing long-term condition (diabetes, hypertension, respiratory or cardiac disease) raises clinical concern for the same set of readings.',
    },
    pregnant: {
      id: 'pregnant', label: 'Pregnant', riskPoints: 5,
      explanation: 'Resting heart rate is normally 10–20 bpm higher in pregnancy, so heart-rate limits are raised to avoid false alarms. Fever thresholds are lowered instead.',
    },
    infant: {
      id: 'infant', label: 'Infant (under 1)', riskPoints: 8,
      explanation: 'Infant heart rate is normally much faster than an adult\'s, so heart-rate limits are raised substantially. Any fever in an infant is treated as significant.',
    },
    immunocompromised: {
      id: 'immunocompromised', label: 'Immunocompromised', riskPoints: 10,
      explanation: 'Reduced ability to contain infection. Fever thresholds are lowered and overall concern is raised.',
    },
  };
  const VULN_ORDER = ['elderly', 'chronic', 'pregnant', 'infant', 'immunocompromised'];
  const VULN_RULE_ID = {
    elderly: 'vuln_elderly',
    chronic: 'vuln_chronic',
    pregnant: 'vuln_pregnant',
    infant: 'vuln_infant',
    immunocompromised: 'vuln_immunocompromised',
  };

  /* ── Thresholds (vulnerability- and age-aware) ───────── */
  function thresholdsForPatient(age, flags) {
    const eff = new Set(flags);
    if (age >= 65) eff.add('elderly');
    if (age < 1) eff.add('infant');

    let t = {
      spo2Critical: 90, spo2Warning: 95,
      hrHighCritical: 130, hrHighWarning: 100,
      hrLowCritical: 45, hrLowWarning: 55,
      tempFever: 38.0, tempHigh: 39.0, tempLow: 35.0,
    };

    const hrShifted = eff.has('infant') || eff.has('pregnant');

    if (eff.has('infant')) {
      t = { ...t, hrHighWarning: 160, hrHighCritical: 180, hrLowWarning: 100, hrLowCritical: 90 };
    } else if (eff.has('pregnant')) {
      t = { ...t, hrHighWarning: 110, hrHighCritical: 135, hrLowWarning: 55, hrLowCritical: 45 };
    }

    if (eff.has('elderly')) {
      t = {
        ...t,
        spo2Warning: 96, spo2Critical: 91,
        tempFever: 37.7, tempHigh: 38.6, tempLow: 35.5,
        hrHighWarning: hrShifted ? t.hrHighWarning : 90,
        hrHighCritical: hrShifted ? t.hrHighCritical : 115,
      };
    }
    if (eff.has('chronic')) {
      t = {
        ...t,
        spo2Warning: Math.max(t.spo2Warning, 96),
        spo2Critical: Math.max(t.spo2Critical, 91),
        hrHighWarning: hrShifted ? t.hrHighWarning : Math.min(t.hrHighWarning, 95),
        hrHighCritical: hrShifted ? t.hrHighCritical : Math.min(t.hrHighCritical, 120),
      };
    }
    if (eff.has('immunocompromised')) {
      t = { ...t, tempFever: Math.min(t.tempFever, 37.5), tempHigh: Math.min(t.tempHigh, 38.5) };
    }
    if (eff.has('infant') || eff.has('pregnant')) {
      t = { ...t, tempFever: Math.min(t.tempFever, 37.5), tempHigh: Math.min(t.tempHigh, 38.5) };
    }
    return { thresholds: t, effectiveFlags: eff };
  }

  /* ── Symptom sets ────────────────────────────────────── */
  const RESPIRATORY = new Set(['breathlessness', 'cough', 'sore throat']);
  const RED_FLAGS = new Set(['chest discomfort', 'chest pain', 'confusion', 'unable to drink', 'convulsions', 'severe bleeding']);
  const DEHYDRATION = new Set(['vomiting', 'diarrhea', 'diarrhoea', 'dizziness']);

  /* ── Plain-language description per rule id (from the app) ── */
  const RULE_DESCRIPTIONS = {
    spo2_critical: 'Oxygen saturation below the critical limit means the blood is not carrying enough oxygen. This needs urgent assessment.',
    spo2_warning: 'Oxygen saturation slightly below normal can be an early sign of a chest infection or breathing problem.',
    hr_tachy_critical: 'A very fast pulse at rest can accompany serious infection, dehydration, blood loss, or a heart rhythm problem.',
    hr_tachy_warning: 'A raised pulse at rest is common with fever, pain, anxiety, or dehydration, and is worth re-checking when calm.',
    hr_brady_critical: 'A very slow pulse can reduce blood flow to the brain and needs assessment, particularly with dizziness or fainting.',
    hr_brady_warning: 'A slow pulse can be normal in fit adults, but is worth noting alongside any dizziness or tiredness.',
    temp_high: 'High fever increases fluid loss and can indicate a significant infection.',
    temp_fever: 'Fever is the body responding to infection. Fluids, rest, and monitoring are the first steps.',
    temp_low: 'Low body temperature can follow cold exposure, severe infection, or shock, and is dangerous in the very young and very old.',
    sepsis_screen: 'Fever, a fast pulse, and low oxygen together can mean an infection is affecting the whole body. This needs same-day assessment.',
    ecg_irregular: 'An irregular beat-to-beat interval can indicate a rhythm disturbance. A proper ECG is needed to interpret it.',
    ecg_poor_quality: 'The ECG trace was too noisy to analyse. This says nothing about the heart — it means the electrodes need better contact.',
    spo2_not_measured: 'No oxygen reading was captured. Re-seat the finger sensor and repeat the measurement before relying on this screening.',
    respiratory_symptoms: 'Breathing symptoms alongside abnormal vitals raise the concern for a chest infection.',
    red_flag_symptoms: 'Certain symptoms are treated as danger signs on their own and warrant assessment even when vitals look normal.',
    multiple_symptoms: 'Several symptoms together make significant illness more likely than any one alone.',
    dehydration_symptoms: 'Vomiting, loose stools, and dizziness together suggest fluid loss. Oral rehydration is the immediate priority.',
    vuln_elderly: 'Older adults have less physiological reserve, so thresholds are tightened and fever may be less pronounced.',
    vuln_chronic: 'An existing long-term condition raises the concern attached to the same set of readings.',
    vuln_pregnant: 'Pregnancy raises resting pulse normally, so heart-rate limits are raised while fever limits are lowered.',
    vuln_infant: 'Infants normally have a much faster pulse, and any fever in an infant is treated as significant.',
    vuln_immunocompromised: 'A weakened immune system means infection can progress quickly with fewer outward signs.',
  };

  function fmtTemp(c) { return c.toFixed(1) + '°C'; }

  function humanList(items) {
    const cap = items.map(s => s ? s[0].toUpperCase() + s.slice(1) : s);
    if (cap.length === 1) return cap[0];
    if (cap.length === 2) return cap[0] + ' and ' + cap[1];
    return cap.slice(0, -1).join(', ') + ' and ' + cap[cap.length - 1];
  }

  /* ── The assessment ────────────────────────────────────
     sample: { heartRateBpm, spo2Percent, temperatureC,
               ecgSignalQuality (0..1), rrIntervalMs, rPeakDetected,
               isDemo }
     Returns the same shape as the app's TriageAssessment.       */
  function assess({ sample, symptoms = [], age = 30, flags = [] }) {
    const { thresholds: t, effectiveFlags } = thresholdsForPatient(age, flags);
    const fired = [];
    const add = (id, severity, points, title, detail) =>
      fired.push({ id, severity, points, title, detail, isCritical: severity === Sev.CRITICAL });

    /* SpO₂ */
    if (sample.spo2Percent <= 0) {
      add('spo2_not_measured', Sev.ADVISORY, 0, 'Oxygen saturation not measured',
        'No usable SpO₂ reading was captured for this screening.');
    } else if (sample.spo2Percent < t.spo2Critical) {
      add('spo2_critical', Sev.CRITICAL, 45, 'Oxygen saturation critically low',
        `Measured ${sample.spo2Percent}%, below the ${t.spo2Critical}% critical limit for this patient.`);
    } else if (sample.spo2Percent < t.spo2Warning) {
      add('spo2_warning', Sev.WARNING, 15, 'Oxygen saturation below normal',
        `Measured ${sample.spo2Percent}%, below the ${t.spo2Warning}% expected minimum for this patient.`);
    }

    /* Heart rate */
    if (sample.heartRateBpm > 0) {
      if (sample.heartRateBpm > t.hrHighCritical) {
        add('hr_tachy_critical', Sev.CRITICAL, 35, 'Heart rate severely elevated',
          `Measured ${sample.heartRateBpm} bpm, above the ${t.hrHighCritical} bpm critical limit for this patient.`);
      } else if (sample.heartRateBpm > t.hrHighWarning) {
        add('hr_tachy_warning', Sev.WARNING, 10, 'Heart rate elevated',
          `Measured ${sample.heartRateBpm} bpm, above the ${t.hrHighWarning} bpm expected maximum for this patient.`);
      } else if (sample.heartRateBpm < t.hrLowCritical) {
        add('hr_brady_critical', Sev.CRITICAL, 35, 'Heart rate severely low',
          `Measured ${sample.heartRateBpm} bpm, below the ${t.hrLowCritical} bpm critical limit for this patient.`);
      } else if (sample.heartRateBpm < t.hrLowWarning) {
        add('hr_brady_warning', Sev.WARNING, 10, 'Heart rate low',
          `Measured ${sample.heartRateBpm} bpm, below the ${t.hrLowWarning} bpm expected minimum for this patient.`);
      }
    }

    /* Temperature */
    if (sample.temperatureC > 0) {
      if (sample.temperatureC < t.tempLow) {
        add('temp_low', Sev.CRITICAL, 30, 'Body temperature too low',
          `Measured ${fmtTemp(sample.temperatureC)}, below the ${fmtTemp(t.tempLow)} hypothermia limit.`);
      } else if (sample.temperatureC >= t.tempHigh) {
        add('temp_high', Sev.WARNING, 25, 'High fever',
          `Measured ${fmtTemp(sample.temperatureC)}, at or above the ${fmtTemp(t.tempHigh)} high-fever limit for this patient.`);
      } else if (sample.temperatureC >= t.tempFever) {
        add('temp_fever', Sev.WARNING, 10, 'Fever',
          `Measured ${fmtTemp(sample.temperatureC)}, at or above the ${fmtTemp(t.tempFever)} fever limit for this patient.`);
      }
    }

    /* Sepsis screen */
    if (sample.spo2Percent > 0 && sample.heartRateBpm > 0 && sample.temperatureC > 0) {
      const feverish = sample.temperatureC >= t.tempFever;
      const tachy = sample.heartRateBpm > t.hrHighWarning;
      const hypoxic = sample.spo2Percent < t.spo2Warning;
      if (feverish && tachy && hypoxic) {
        add('sepsis_screen', Sev.CRITICAL, 30, 'Fever with fast pulse and low oxygen',
          'All three together can indicate a serious infection spreading through the body. This combination needs same-day assessment.');
      }
    }

    /* ECG */
    if (sample.ecgSignalQuality > 0) {
      if (sample.ecgSignalQuality < 0.5) {
        add('ecg_poor_quality', Sev.ADVISORY, 0, 'ECG signal quality poor',
          `Rhythm analysis is unreliable at this signal quality (${Math.round(sample.ecgSignalQuality * 100)}%). Re-check electrode contact and repeat if a rhythm assessment is needed.`);
      } else if (sample.rrIntervalMs > 0 && !sample.rPeakDetected) {
        add('ecg_irregular', Sev.WARNING, 20, 'Irregular rhythm detected',
          'The beat-to-beat interval was inconsistent. This is a screening signal only and needs a proper ECG to interpret.');
      }
    }

    /* Symptoms */
    const norm = [...new Set(symptoms.map(s => String(s).trim().toLowerCase()).filter(Boolean))];
    if (norm.length > 0) {
      const redFlags = norm.filter(s => RED_FLAGS.has(s)).sort();
      if (redFlags.length) {
        add('red_flag_symptoms', Sev.CRITICAL, 25, 'Danger sign reported',
          `${humanList(redFlags)} — reported danger sign${redFlags.length > 1 ? 's' : ''} that warrant assessment regardless of the measured vitals.`);
      }
      const respiratory = norm.filter(s => RESPIRATORY.has(s) && !RED_FLAGS.has(s)).sort();
      if (respiratory.length) {
        add('respiratory_symptoms', Sev.WARNING, Math.min(respiratory.length * 5, 15),
          'Respiratory symptoms reported', humanList(respiratory));
      }
      const dehydration = norm.filter(s => DEHYDRATION.has(s)).sort();
      if (dehydration.length >= 2) {
        add('dehydration_symptoms', Sev.WARNING, 15, 'Possible dehydration',
          `${humanList(dehydration)} together raise the risk of fluid loss, especially in hot weather or after flooding.`);
      }
      if (norm.length >= 3) {
        add('multiple_symptoms', Sev.WARNING, 10, 'Several symptoms at once',
          `${norm.length} symptoms reported together.`);
      }
    }

    /* Vulnerability */
    [...effectiveFlags]
      .sort((a, b) => VULN_ORDER.indexOf(a) - VULN_ORDER.indexOf(b))
      .forEach(id => {
        const v = Vulnerability[id];
        if (v) add(VULN_RULE_ID[id], Sev.WARNING, v.riskPoints, `${v.label}: thresholds adjusted`, v.explanation);
      });

    /* Score */
    let score = fired.reduce((sum, r) => sum + r.points, 0);
    const hasCritical = fired.some(r => r.isCritical);
    if (hasCritical && score < CRITICAL_FLOOR) score = CRITICAL_FLOOR;
    score = Math.max(0, Math.min(MAX_SCORE, score));

    const band = bandForScore(score);
    const scoringRules = fired.filter(r => r.points > 0).sort((a, b) => b.points - a.points);

    return {
      band, score, firedRules: fired, scoringRules,
      advisories: fired.filter(r => r.severity === Sev.ADVISORY),
      thresholds: t, effectiveFlags: [...effectiveFlags],
      bandLabel: BandLabel[band],
      recommendedAction: BandAction[band],
      escalationLevel: BandEscalation[band],
      isDemo: !!sample.isDemo,
    };
  }

  global.SwasthyaRisk = {
    assess, bandForScore, thresholdsForPatient,
    MAX_SCORE, GREEN_MAX, YELLOW_MAX, CRITICAL_FLOOR,
    Vulnerability, RULE_DESCRIPTIONS,
    RESPIRATORY_SYMPTOMS: [...RESPIRATORY],
    RED_FLAG_SYMPTOMS: [...RED_FLAGS],
    DEHYDRATION_SYMPTOMS: [...DEHYDRATION],
  };
})(window);
