#pragma once
#ifndef BLEHANDLER_H
#define BLEHANDLER_H

#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include "Config.h"
#include "State.h"

class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* server) override;
  void onDisconnect(BLEServer* server) override;
};

class ControlCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pChar) override;
};

void startBLEAdvertising();
void initBLE();
void sendEcgFrame();
void sendTelemetry();

#endif
