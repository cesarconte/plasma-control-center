/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QObject>
#include <QProcess>
#include <QTimer>

class ControlBackend : public QObject
{
    Q_OBJECT

    // Brillo de pantalla
    Q_PROPERTY(int brightness READ brightness WRITE setBrightness NOTIFY brightnessChanged)
    Q_PROPERTY(int brightnessMax READ brightnessMax NOTIFY brightnessMaxChanged)
    Q_PROPERTY(bool brightnessAvailable READ brightnessAvailable NOTIFY brightnessAvailableChanged)

    // Luz Nocturna (Night Light)
    Q_PROPERTY(bool nightLightAvailable READ nightLightAvailable NOTIFY nightLightAvailableChanged)
    Q_PROPERTY(bool nightLightActive READ nightLightActive NOTIFY nightLightActiveChanged)

    // Modo Oscuro / Aspecto (Claro, Oscuro, Automático)
    Q_PROPERTY(bool darkMode READ darkMode NOTIFY darkModeChanged)
    Q_PROPERTY(QString themeMode READ themeMode WRITE setThemeMode NOTIFY themeModeChanged)

    // Perfil de Energía
    Q_PROPERTY(QString powerProfile READ powerProfile WRITE setPowerProfile NOTIFY powerProfileChanged)

    // Wi-Fi
    Q_PROPERTY(bool wifiEnabled READ wifiEnabled WRITE setWifiEnabled NOTIFY wifiEnabledChanged)
    Q_PROPERTY(QString wifiSsid READ wifiSsid NOTIFY wifiSsidChanged)

    // Bluetooth
    Q_PROPERTY(bool bluetoothEnabled READ bluetoothEnabled WRITE setBluetoothEnabled NOTIFY bluetoothEnabledChanged)
    Q_PROPERTY(QString bluetoothDevice READ bluetoothDevice NOTIFY bluetoothDeviceChanged)

public:
    explicit ControlBackend(QObject *parent = nullptr);
    ~ControlBackend() override = default;

    // Getters
    int brightness() const;
    void setBrightness(int value);
    int brightnessMax() const;
    bool brightnessAvailable() const;

    bool nightLightAvailable() const;
    bool nightLightActive() const;

    bool darkMode() const;
    QString themeMode() const;
    void setThemeMode(const QString &mode);

    QString powerProfile() const;
    void setPowerProfile(const QString &profile);

    bool wifiEnabled() const;
    void setWifiEnabled(bool enabled);
    QString wifiSsid() const;

    bool bluetoothEnabled() const;
    void setBluetoothEnabled(bool enabled);
    QString bluetoothDevice() const;

public Q_SLOTS:
    void toggleNightLight();
    void toggleDarkMode();
    void cycleThemeMode();
    void toggleWifi();
    void toggleBluetooth();
    void cyclePowerProfile();

    // Lanzadores de módulos KCM / Ajustes
    void openSystemSettings();
    void openAudioSettings();
    void openDisplaySettings();
    void openNetworkSettings();
    void openBluetoothSettings();
    void openEnergySettings();
    void lockScreen();

    // Actualización de estado
    void refreshAll();

Q_SIGNALS:
    void brightnessChanged(int value);
    void brightnessMaxChanged(int max);
    void brightnessAvailableChanged(bool available);
    void nightLightAvailableChanged(bool available);
    void nightLightActiveChanged(bool active);
    void darkModeChanged(bool isDark);
    void themeModeChanged(const QString &mode);
    void powerProfileChanged(const QString &profile);
    void wifiEnabledChanged(bool enabled);
    void wifiSsidChanged(const QString &ssid);
    void bluetoothEnabledChanged(bool enabled);
    void bluetoothDeviceChanged(const QString &device);

private Q_SLOTS:
    void onBrightnessDbusChanged(int value);
    void checkBrightnessStatus();
    void checkNightLightStatus();
    void checkDarkModeStatus();
    void checkPowerProfileStatus();
    void checkWifiStatus();
    void checkBluetoothStatus();

private:
    void setupDbusConnections();

    int m_brightness = 100;
    int m_brightnessMax = 100;
    bool m_brightnessAvailable = false;

    bool m_nightLightAvailable = false;
    bool m_nightLightActive = false;

    bool m_darkMode = false;
    QString m_themeMode = QStringLiteral("auto");
    QString m_powerProfile = QStringLiteral("balanced");

    bool m_wifiEnabled = true;
    QString m_wifiSsid;

    bool m_bluetoothEnabled = false;
    QString m_bluetoothDevice;

    bool m_wifiQueryRunning = false;
    bool m_bluetoothQueryRunning = false;
};
