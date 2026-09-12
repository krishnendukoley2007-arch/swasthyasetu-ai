"""
SSAI-SENSE-01 — 1D-CNN Rhythm Autoencoder Training Script

Trains a lightweight 1D Convolutional Autoencoder on synthetic ECG waveforms
modeled on typical Lead I normal sinus rhythm (NSR) and arrhythmia morphology.
NOT trained on real recorded PhysioNet data — see generate_synthetic_nsr_beats().

To upgrade to real data: use the `wfdb` package to load MIT-BIH Arrhythmia DB
records (e.g. record 100, 101) and replace the synthetic generator below.

Exports trained weights to assets/models/ecg_autoencoder_weights.json for
pure on-device edge inference.
"""

import json
import math
import os
import urllib.request
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim

# Reproducibility
torch.manual_seed(42)
np.random.seed(42)

WINDOW_SIZE = 128  # 128 samples (~0.5s beat window at 250 Hz)
EPOCHS = 25
BATCH_SIZE = 32
LEARNING_RATE = 0.005

class Conv1DAutoencoder(nn.Module):
    """Lightweight 1D-CNN Autoencoder for Edge Waveform Reconstruction."""
    def __init__(self):
        super().__init__()
        # Encoder: 128 -> 64 -> 32 -> 16 (bottleneck)
        self.enc1 = nn.Conv1d(1, 4, kernel_size=5, stride=2, padding=2)    # 128 -> 64
        self.enc2 = nn.Conv1d(4, 2, kernel_size=5, stride=2, padding=2)    # 64 -> 32
        
        # Decoder: 32 -> 64 -> 128
        self.dec1 = nn.ConvTranspose1d(2, 4, kernel_size=4, stride=2, padding=1)  # 32 -> 64
        self.dec2 = nn.ConvTranspose1d(4, 1, kernel_size=4, stride=2, padding=1)  # 64 -> 128
        self.relu = nn.ReLU()

    def forward(self, x):
        # Encode
        z = self.relu(self.enc1(x))
        z = self.relu(self.enc2(z))
        # Decode
        out = self.relu(self.dec1(z))
        out = self.dec2(out)
        return out

def generate_synthetic_nsr_beats(num_beats=1200):
    """
    Generates synthetic Lead I normal sinus rhythm beats using a parametric
    Gaussian P-QRS-T waveform model. Beat morphology parameters (timing,
    amplitude, width) are based on typical clinical ECG physiology at 250 Hz.

    NOTE: This is a synthetic waveform generator, NOT a loader of real
    PhysioNet MIT-BIH recordings. Separation accuracy on these synthetic
    clusters does not predict real-world performance on noisy, inter-patient-
    variable hardware recordings.
    """
    t = np.linspace(0, 0.512, WINDOW_SIZE)
    beats = []
    
    for i in range(num_beats):
        # Physiologic beat model with small natural heart-rate & morphology jitter
        center_qrs = 0.25 + np.random.normal(0, 0.008)
        qrs_width = 0.016 + np.random.normal(0, 0.001)
        qrs_amp = 1.6 + np.random.normal(0, 0.12)
        
        # P-wave (~80ms before QRS)
        p_center = center_qrs - 0.10 + np.random.normal(0, 0.004)
        p_wave = 0.22 * np.exp(-((t - p_center) ** 2) / (2 * (0.022 ** 2)))
        
        # QRS complex (narrow biphasic spike)
        r_wave = qrs_amp * np.exp(-((t - center_qrs) ** 2) / (2 * (qrs_width ** 2)))
        q_wave = -0.25 * np.exp(-((t - (center_qrs - 0.022)) ** 2) / (2 * (0.010 ** 2)))
        s_wave = -0.35 * np.exp(-((t - (center_qrs + 0.022)) ** 2) / (2 * (0.012 ** 2)))
        
        # T-wave (~140ms after QRS)
        t_center = center_qrs + 0.15 + np.random.normal(0, 0.006)
        t_wave = 0.38 * np.exp(-((t - t_center) ** 2) / (2 * (0.038 ** 2)))
        
        # Baseline noise (analog front-end jitter)
        noise = np.random.normal(0, 0.025, WINDOW_SIZE)
        
        beat = p_wave + q_wave + r_wave + s_wave + t_wave + noise
        # Normalize to zero mean, unit variance
        beat = (beat - np.mean(beat)) / (np.std(beat) + 1e-6)
        beats.append(beat)
        
    return np.array(beats, dtype=np.float32)

def generate_synthetic_arrhythmia_beats(num_beats=200):
    """Generates synthetic arrhythmic beats (PVC/VTach morphology) for anomaly validation.
    Same caveat as generate_synthetic_nsr_beats: these are parametric, not real recordings."""
    t = np.linspace(0, 0.512, WINDOW_SIZE)
    beats = []
    for _ in range(num_beats):
        # Wide inverted QRS, missing P wave, discordant T wave (PVC morphology)
        center = 0.25 + np.random.normal(0, 0.01)
        wide_qrs = -1.8 * np.exp(-((t - center) ** 2) / (2 * (0.055 ** 2)))
        secondary = 0.7 * np.exp(-((t - (center + 0.12)) ** 2) / (2 * (0.065 ** 2)))
        noise = np.random.normal(0, 0.05, WINDOW_SIZE)
        beat = wide_qrs + secondary + noise
        beat = (beat - np.mean(beat)) / (np.std(beat) + 1e-6)
        beats.append(beat)
    return np.array(beats, dtype=np.float32)

def train_and_export():
    print("[1/4] Generating training dataset (synthetic NSR beats at 250 Hz)...")
    train_data = generate_synthetic_nsr_beats(num_beats=1500)
    train_tensor = torch.tensor(train_data).unsqueeze(1) # (N, 1, 128)
    
    model = Conv1DAutoencoder()
    criterion = nn.MSELoss()
    optimizer = optim.Adam(model.parameters(), lr=LEARNING_RATE)
    
    print(f"[2/4] Training 1D-CNN Autoencoder ({EPOCHS} epochs, batch size {BATCH_SIZE})...")
    model.train()
    dataset = torch.utils.data.TensorDataset(train_tensor)
    loader = torch.utils.data.DataLoader(dataset, batch_size=BATCH_SIZE, shuffle=True)
    
    for epoch in range(EPOCHS):
        total_loss = 0.0
        for (batch,) in loader:
            optimizer.zero_grad()
            recon = model(batch)
            loss = criterion(recon, batch)
            loss.backward()
            optimizer.step()
            total_loss += loss.item() * len(batch)
        
        avg_loss = total_loss / len(train_data)
        if (epoch + 1) % 5 == 0 or epoch == 0:
            print(f"  Epoch [{epoch+1:2d}/{EPOCHS}] - Reconstruction MSE Loss: {avg_loss:.5f}")
            
    print("[3/4] Validating anomaly separation on synthetic Normal vs. Arrhythmia beats...")
    print("       (NOTE: Synthetic separation — real-world accuracy on hardware recordings TBD)")
    model.eval()
    with torch.no_grad():
        test_normal = torch.tensor(generate_synthetic_nsr_beats(num_beats=100)).unsqueeze(1)
        test_arrhythmia = torch.tensor(generate_synthetic_arrhythmia_beats(num_beats=100)).unsqueeze(1)
        
        recon_norm = model(test_normal)
        recon_arrh = model(test_arrhythmia)
        
        mse_norm = torch.mean((recon_norm - test_normal) ** 2, dim=[1, 2]).numpy()
        mse_arrh = torch.mean((recon_arrh - test_arrhythmia) ** 2, dim=[1, 2]).numpy()
        
        print(f"  Normal NSR Mean MSE:      {np.mean(mse_norm):.4f} (±{np.std(mse_norm):.4f})")
        print(f"  Arrhythmic Beat Mean MSE:  {np.mean(mse_arrh):.4f} (±{np.std(mse_arrh):.4f})")
        threshold = 0.06
        accuracy = (np.mean(mse_norm < threshold) + np.mean(mse_arrh >= threshold)) / 2.0
        print(f"  Synthetic Separation Accuracy: {accuracy * 100:.1f}% (Threshold = {threshold})")
        print(f"  CAVEAT: This is separation on clean synthetic clusters — real-world accuracy")
        print(f"          on noisy AD8232 hardware recordings will be lower and is pending.")

    print("[4/4] Exporting model weights to JSON for on-device pure Dart tensor execution...")
    os.makedirs("assets/models", exist_ok=True)
    
    # Extract weights as nested lists
    state_dict = model.state_dict()
    export_dict = {
        "architecture": "1D-CNN Autoencoder",
        "training_dataset": "Synthetic parametric NSR beats (Gaussian P-QRS-T model, 250 Hz) — not real PhysioNet recordings",
        "input_length": WINDOW_SIZE,
        "anomaly_threshold": threshold,
        "normal_baseline_mse": float(np.mean(mse_norm)),
        "arrhythmia_mse": float(np.mean(mse_arrh)),
        "weights": {
            "enc1_weight": state_dict["enc1.weight"].numpy().tolist(), # (4, 1, 5)
            "enc1_bias": state_dict["enc1.bias"].numpy().tolist(),     # (4,)
            "enc2_weight": state_dict["enc2.weight"].numpy().tolist(), # (2, 4, 5)
            "enc2_bias": state_dict["enc2.bias"].numpy().tolist(),     # (2,)
            "dec1_weight": state_dict["dec1.weight"].numpy().tolist(), # (2, 4, 4)
            "dec1_bias": state_dict["dec1.bias"].numpy().tolist(),     # (4,)
            "dec2_weight": state_dict["dec2.weight"].numpy().tolist(), # (4, 1, 4)
            "dec2_bias": state_dict["dec2.bias"].numpy().tolist(),     # (1,)
        }
    }
    
    out_path = "assets/models/ecg_autoencoder_weights.json"
    with open(out_path, "w") as f:
        json.dump(export_dict, f, indent=2)
        
    print(f"[OK] Successfully trained and exported edge weights artifact to: {out_path} ({os.path.getsize(out_path)} bytes)")

if __name__ == "__main__":
    train_and_export()
