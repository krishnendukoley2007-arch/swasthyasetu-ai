#include "BLEHandler.h"

void MyServerCallbacks::onConnect(BLEServer* server) {
  deviceConnected = true;
  connectEventPending = true;
  Serial.println(F("[BLE] CONNECTED"));
}

void MyServerCallbacks::onDisconnect(BLEServer* server) {
  deviceConnected = false;
  ecgStreaming = false;
  disconnectEventPending = true;
  Serial.println(F("[BLE] DISCONNECTED"));
}

void ControlCallbacks::onWrite(BLECharacteristic* pChar) {
  String rx = pChar->getValue();
  if (rx.length() == 0) return;
  uint8_t command = (uint8_t)rx[0];
  Serial.printf("[CONTROL] 0x%02X\n", command);
  if (command == 0xA1) {
    ecgStreaming = true;
    ecgSeq = 0;
    frameFill = 0;
    Serial.println(F("[ECG] STREAM START"));
  } else if (command == 0xA0) {
    ecgStreaming = false;
    Serial.println(F("[ECG] STREAM STOP"));
  }
}

void startBLEAdvertising() {
  BLEAdvertising* advertising = BLEDevice::getAdvertising();
  if (!advertisingConfigured) {
    advertising->addServiceUUID(SERVICE_UUID);
    advertising->setScanResponse(true);
    advertising->setMinPreferred(0x06);
    advertising->setMaxPreferred(0x12);
    advertisingConfigured = true;
  }
  BLEDevice::startAdvertising();
  lastAdvertiseAt = millis();
  Serial.println(F("[BLE] advertising as SSAI-SENSE-01"));
}

void initBLE() {
  BLEDevice::init("SSAI-SENSE-01");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService* pService = pServer->createService(SERVICE_UUID);

  BLECharacteristic* pInfo = pService->createCharacteristic(
      DEVICE_INFO_UUID, BLECharacteristic::PROPERTY_READ);
  pInfo->setValue(FIRMWARE_VERSION);

  pLiveVitals = pService->createCharacteristic(
      LIVE_VITALS_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  pLiveVitals->addDescriptor(new BLE2902());

  pEcgStream = pService->createCharacteristic(
      ECG_STREAM_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  pEcgStream->addDescriptor(new BLE2902());

  BLECharacteristic* pControl = pService->createCharacteristic(
      CONTROL_UUID,
      BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR);
  pControl->setCallbacks(new ControlCallbacks());

  pService->start();
  startBLEAdvertising();
}

void sendEcgFrame() {
  if (!deviceConnected || !ecgStreaming || pEcgStream == nullptr) {
    frameFill = 0;
    return;
  }
  if (frameFill < ECG_FRAME_SAMPLES) return;

  uint8_t packet[20];
  packet[0] = 0x02;
  packet[1] = PROTOCOL_VERSION;
  packet[2] = ecgSeq & 0xFF;
  packet[3] = (ecgSeq >> 8) & 0xFF;
  memcpy(&packet[4], frameBuf, 16);
  ecgSeq++;

  pEcgStream->setValue(packet, 20);
  pEcgStream->notify();
  framesSent++;

  frameFill = 0;
}

void sendTelemetry() {
  if (!deviceConnected || pLiveVitals == nullptr) return;
  uint32_t now = millis();
  if (now - lastTelemetry < TELEMETRY_MS) return;
  lastTelemetry = now;

  uint8_t t[20];
  memset(t, 0, sizeof(t));
  t[0] = 0x01;
  t[1] = PROTOCOL_VERSION;
  t[2] = currentBpm;
  t[3] = 0;                                         // SpO2: not measured
  t[6] = lastRrMs & 0xFF;
  t[7] = (lastRrMs >> 8) & 0xFF;
  t[8] = ecgQuality;
  uint8_t flags = 0;
  if (rPeakPulse) flags |= 0x01;
  if (leadOff)    flags |= 0x04;
  t[9] = flags;
  t[14] = batteryPercent;                           // 0 when no gauge wired
  t[15] = 0x00;
  uint32_t up = now;
  memcpy(&t[16], &up, 4);

  rPeakPulse = false;

  pLiveVitals->setValue(t, 20);
  pLiveVitals->notify();
  telemetrySent++;
}
