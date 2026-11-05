/*
    SPDX-FileCopyrightText: 2026 Cesar <yugurta@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "controlbackend.h"

#include <KConfigGroup>
#include <KProcess>
#include <KSharedConfig>
#include <QDBusConnectionInterface>
#include <QDBusReply>
#include <QDebug>
#include <QStandardPaths>

ControlBackend::ControlBackend(QObject *parent)
    : QObject(parent)
{
    setupDbusConnections();
    refreshAll();
}

void ControlBackend::setupDbusConnections()
{
    auto bus = QDBusConnection::sessionBus();

    // Señal de brillo (reactiva, 0 polling)
    bus.connect(QStringLiteral("org.kde.Solid.PowerManagement"),
                QStringLiteral("/org/kde/Solid/PowerManagement/Actions/BrightnessControl"),
                QStringLiteral("org.kde.Solid.PowerManagement.Actions.BrightnessControl"),
                QStringLiteral("brightnessChanged"),
                this,
                SLOT(onBrightnessDbusChanged(int)));

    // Señal de propiedades de NightLight (reactiva)
    bus.connect(QStringLiteral("org.kde.KWin.NightLight"),
                QStringLiteral("/org/kde/KWin/NightLight"),
                QStringLiteral("org.freedesktop.DBus.Properties"),
                QStringLiteral("PropertiesChanged"),
                this,
                SLOT(checkNightLightStatus()));

    // Señal de NetworkManager en bus de sistema (reactiva)
    QDBusConnection::systemBus().connect(QStringLiteral("org.freedesktop.NetworkManager"),
                                         QStringLiteral("/org/freedesktop/NetworkManager"),
                                         QStringLiteral("org.freedesktop.DBus.Properties"),
                                         QStringLiteral("PropertiesChanged"),
                                         this,
                                         SLOT(checkWifiStatus()));
}

void ControlBackend::refreshAll()
{
    checkBrightnessStatus();
    checkNightLightStatus();
    checkDarkModeStatus();
    checkPowerProfileStatus();
    checkWifiStatus();
    checkBluetoothStatus();
}

// ----------------------------------------------------------------------------
// BRILLO DE PANTALLA
// ----------------------------------------------------------------------------
void ControlBackend::checkBrightnessStatus()
{
    QDBusInterface brightnessIface(QStringLiteral("org.kde.Solid.PowerManagement"),
                                   QStringLiteral("/org/kde/Solid/PowerManagement/Actions/BrightnessControl"),
                                   QStringLiteral("org.kde.Solid.PowerManagement.Actions.BrightnessControl"),
                                   QDBusConnection::sessionBus());
    if (brightnessIface.isValid()) {
        QDBusReply<int> curReply = brightnessIface.call(QStringLiteral("brightness"));
        QDBusReply<int> maxReply = brightnessIface.call(QStringLiteral("brightnessMax"));

        if (curReply.isValid() && maxReply.isValid() && maxReply.value() > 0) {
            if (!m_brightnessAvailable) {
                m_brightnessAvailable = true;
                Q_EMIT brightnessAvailableChanged(true);
            }
            if (m_brightnessMax != maxReply.value()) {
                m_brightnessMax = maxReply.value();
                Q_EMIT brightnessMaxChanged(m_brightnessMax);
            }
            if (m_brightness != curReply.value()) {
                m_brightness = curReply.value();
                Q_EMIT brightnessChanged(m_brightness);
            }
            return;
        }
    }

    if (m_brightnessAvailable) {
        m_brightnessAvailable = false;
        Q_EMIT brightnessAvailableChanged(false);
    }
}

int ControlBackend::brightness() const
{
    return m_brightness;
}

void ControlBackend::setBrightness(int value)
{
    if (value < 0) value = 0;
    if (value > m_brightnessMax) value = m_brightnessMax;
    if (m_brightness == value) return;

    m_brightness = value;
    Q_EMIT brightnessChanged(m_brightness);

    QDBusMessage msg = QDBusMessage::createMethodCall(
        QStringLiteral("org.kde.Solid.PowerManagement"),
        QStringLiteral("/org/kde/Solid/PowerManagement/Actions/BrightnessControl"),
        QStringLiteral("org.kde.Solid.PowerManagement.Actions.BrightnessControl"),
        QStringLiteral("setBrightness"));
    msg << value;
    QDBusConnection::sessionBus().asyncCall(msg);
}

int ControlBackend::brightnessMax() const
{
    return m_brightnessMax;
}

bool ControlBackend::brightnessAvailable() const
{
    return m_brightnessAvailable;
}

void ControlBackend::onBrightnessDbusChanged(int value)
{
    if (m_brightness != value) {
        m_brightness = value;
        Q_EMIT brightnessChanged(m_brightness);
    }
}

// ----------------------------------------------------------------------------
// NIGHT LIGHT
// ----------------------------------------------------------------------------
bool ControlBackend::nightLightAvailable() const
{
    return m_nightLightAvailable;
}

bool ControlBackend::nightLightActive() const
{
    return m_nightLightActive;
}

void ControlBackend::checkNightLightStatus()
{
    QDBusInterface nlIface(QStringLiteral("org.kde.KWin.NightLight"),
                           QStringLiteral("/org/kde/KWin/NightLight"),
                           QStringLiteral("org.kde.KWin.NightLight"),
                           QDBusConnection::sessionBus());

    if (nlIface.isValid()) {
        const bool available = nlIface.property("available").toBool();
        const bool running = nlIface.property("running").toBool();
        const bool inhibited = nlIface.property("inhibited").toBool();

        if (m_nightLightAvailable != available) {
            m_nightLightAvailable = available;
            Q_EMIT nightLightAvailableChanged(m_nightLightAvailable);
        }

        const bool active = running && !inhibited;
        if (m_nightLightActive != active) {
            m_nightLightActive = active;
            Q_EMIT nightLightActiveChanged(m_nightLightActive);
        }
    }
}

void ControlBackend::toggleNightLight()
{
    QDBusInterface nlIface(QStringLiteral("org.kde.KWin.NightLight"),
                           QStringLiteral("/org/kde/KWin/NightLight"),
                           QStringLiteral("org.kde.KWin.NightLight"),
                           QDBusConnection::sessionBus());
    if (!nlIface.isValid()) return;

    const bool inhibited = nlIface.property("inhibited").toBool();
    if (inhibited) {
        nlIface.call(QStringLiteral("uninhibit"), 0u);
    } else {
        nlIface.call(QStringLiteral("inhibit"));
    }
    checkNightLightStatus();
}

// ----------------------------------------------------------------------------
// ASPECTO / TEMA (Claro, Oscuro, Automático)
// ----------------------------------------------------------------------------
bool ControlBackend::darkMode() const
{
    return m_darkMode;
}

QString ControlBackend::themeMode() const
{
    return m_themeMode;
}

void ControlBackend::checkDarkModeStatus()
{
    KSharedConfigPtr kdeglobals = KSharedConfig::openConfig(QStringLiteral("kdeglobals"), KConfig::SimpleConfig);
    KConfigGroup kdeGroup(kdeglobals, QStringLiteral("KDE"));
    const bool isAuto = kdeGroup.readEntry("AutomaticLookAndFeel", false);

    KConfigGroup genGroup(kdeglobals, QStringLiteral("General"));
    const QString colorScheme = genGroup.readEntry("ColorScheme", QString());

    bool isDark = false;
    if (!colorScheme.isEmpty()) {
        isDark = colorScheme.contains(QLatin1String("Dark"), Qt::CaseInsensitive)
              || colorScheme.contains(QLatin1String("Black"), Qt::CaseInsensitive);
    }

    const QString mode = isAuto ? QStringLiteral("auto") : (isDark ? QStringLiteral("dark") : QStringLiteral("light"));

    if (m_themeMode != mode) {
        m_themeMode = mode;
        Q_EMIT themeModeChanged(m_themeMode);
    }
    if (m_darkMode != isDark) {
        m_darkMode = isDark;
        Q_EMIT darkModeChanged(m_darkMode);
    }
}

void ControlBackend::setThemeMode(const QString &mode)
{
    if (mode == QLatin1String("auto")) {
        KProcess::startDetached(QStringLiteral("kwriteconfig6"), {
            QStringLiteral("--file"), QStringLiteral("kdeglobals"),
            QStringLiteral("--group"), QStringLiteral("KDE"),
            QStringLiteral("--key"), QStringLiteral("AutomaticLookAndFeel"),
            QStringLiteral("--notify"), QStringLiteral("true")
        });
        m_themeMode = QStringLiteral("auto");
        Q_EMIT themeModeChanged(m_themeMode);
    } else if (mode == QLatin1String("dark")) {
        KProcess::startDetached(QStringLiteral("kwriteconfig6"), {
            QStringLiteral("--file"), QStringLiteral("kdeglobals"),
            QStringLiteral("--group"), QStringLiteral("KDE"),
            QStringLiteral("--key"), QStringLiteral("AutomaticLookAndFeel"),
            QStringLiteral("--notify"), QStringLiteral("false")
        });
        KProcess::startDetached(QStringLiteral("plasma-apply-colorscheme"), {QStringLiteral("BreezeDark")});
        m_themeMode = QStringLiteral("dark");
        m_darkMode = true;
        Q_EMIT themeModeChanged(m_themeMode);
        Q_EMIT darkModeChanged(m_darkMode);
    } else { // light
        KProcess::startDetached(QStringLiteral("kwriteconfig6"), {
            QStringLiteral("--file"), QStringLiteral("kdeglobals"),
            QStringLiteral("--group"), QStringLiteral("KDE"),
            QStringLiteral("--key"), QStringLiteral("AutomaticLookAndFeel"),
            QStringLiteral("--notify"), QStringLiteral("false")
        });
        KProcess::startDetached(QStringLiteral("plasma-apply-colorscheme"), {QStringLiteral("BreezeLight")});
        m_themeMode = QStringLiteral("light");
        m_darkMode = false;
        Q_EMIT themeModeChanged(m_themeMode);
        Q_EMIT darkModeChanged(m_darkMode);
    }
    QTimer::singleShot(500, this, &ControlBackend::checkDarkModeStatus);
}

void ControlBackend::cycleThemeMode()
{
    if (m_themeMode == QLatin1String("auto")) {
        setThemeMode(QStringLiteral("light"));
    } else if (m_themeMode == QLatin1String("light")) {
        setThemeMode(QStringLiteral("dark"));
    } else {
        setThemeMode(QStringLiteral("auto"));
    }
}

void ControlBackend::toggleDarkMode()
{
    cycleThemeMode();
}

// ----------------------------------------------------------------------------
// POWER PROFILES
// ----------------------------------------------------------------------------
QString ControlBackend::powerProfile() const
{
    return m_powerProfile;
}

void ControlBackend::setPowerProfile(const QString &profile)
{
    if (m_powerProfile == profile) return;

    QDBusInterface ppIface(QStringLiteral("net.hadess.PowerProfiles"),
                           QStringLiteral("/net/hadess/PowerProfiles"),
                           QStringLiteral("net.hadess.PowerProfiles"),
                           QDBusConnection::systemBus());
    if (ppIface.isValid()) {
        ppIface.setProperty("ActiveProfile", profile);
        m_powerProfile = profile;
        Q_EMIT powerProfileChanged(m_powerProfile);
    }
}

void ControlBackend::cyclePowerProfile()
{
    if (m_powerProfile == QLatin1String("power-saver")) {
        setPowerProfile(QStringLiteral("balanced"));
    } else if (m_powerProfile == QLatin1String("balanced")) {
        setPowerProfile(QStringLiteral("performance"));
    } else {
        setPowerProfile(QStringLiteral("power-saver"));
    }
}

void ControlBackend::checkPowerProfileStatus()
{
    QDBusInterface ppIface(QStringLiteral("net.hadess.PowerProfiles"),
                           QStringLiteral("/net/hadess/PowerProfiles"),
                           QStringLiteral("net.hadess.PowerProfiles"),
                           QDBusConnection::systemBus());
    if (ppIface.isValid()) {
        const QString active = ppIface.property("ActiveProfile").toString();
        if (!active.isEmpty() && m_powerProfile != active) {
            m_powerProfile = active;
            Q_EMIT powerProfileChanged(m_powerProfile);
        }
    }
}

// ----------------------------------------------------------------------------
// WI-FI (100% Asíncrono - Cero bloqueo)
// ----------------------------------------------------------------------------
bool ControlBackend::wifiEnabled() const
{
    return m_wifiEnabled;
}

void ControlBackend::setWifiEnabled(bool enabled)
{
    if (m_wifiEnabled == enabled) return;

    QDBusInterface nmIface(QStringLiteral("org.freedesktop.NetworkManager"),
                           QStringLiteral("/org/freedesktop/NetworkManager"),
                           QStringLiteral("org.freedesktop.NetworkManager"),
                           QDBusConnection::systemBus());
    if (nmIface.isValid()) {
        nmIface.setProperty("WirelessEnabled", enabled);
        m_wifiEnabled = enabled;
        Q_EMIT wifiEnabledChanged(m_wifiEnabled);
        if (!enabled) {
            m_wifiSsid.clear();
            Q_EMIT wifiSsidChanged(m_wifiSsid);
        }
    }
}

void ControlBackend::toggleWifi()
{
    setWifiEnabled(!m_wifiEnabled);
}

QString ControlBackend::wifiSsid() const
{
    return m_wifiSsid;
}

void ControlBackend::checkWifiStatus()
{
    QDBusInterface nmIface(QStringLiteral("org.freedesktop.NetworkManager"),
                           QStringLiteral("/org/freedesktop/NetworkManager"),
                           QStringLiteral("org.freedesktop.NetworkManager"),
                           QDBusConnection::systemBus());
    if (nmIface.isValid()) {
        const bool enabled = nmIface.property("WirelessEnabled").toBool();
        if (m_wifiEnabled != enabled) {
            m_wifiEnabled = enabled;
            Q_EMIT wifiEnabledChanged(m_wifiEnabled);
        }
    }

    if (m_wifiQueryRunning) return;
    m_wifiQueryRunning = true;

    auto *proc = new QProcess(this);
    connect(proc, &QProcess::finished, this, [this, proc](int exitCode) {
        proc->deleteLater();
        m_wifiQueryRunning = false;
        if (exitCode == 0) {
            const QString output = QString::fromUtf8(proc->readAllStandardOutput());
            QString foundSsid;
            const auto lines = output.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
            for (const auto &line : lines) {
                if (line.startsWith(QLatin1String("802-11-wireless:"))) {
                    foundSsid = line.mid(16).trimmed();
                    break;
                }
            }
            if (m_wifiSsid != foundSsid) {
                m_wifiSsid = foundSsid;
                Q_EMIT wifiSsidChanged(m_wifiSsid);
            }
        }
    });

    proc->start(QStringLiteral("nmcli"), {QStringLiteral("-t"), QStringLiteral("-f"), QStringLiteral("TYPE,NAME"), QStringLiteral("connection"), QStringLiteral("show"), QStringLiteral("--active")});
}

// ----------------------------------------------------------------------------
// BLUETOOTH (100% Asíncrono - Cero bloqueo)
// ----------------------------------------------------------------------------
bool ControlBackend::bluetoothEnabled() const
{
    return m_bluetoothEnabled;
}

void ControlBackend::setBluetoothEnabled(bool enabled)
{
    if (m_bluetoothEnabled == enabled) return;
    KProcess::startDetached(QStringLiteral("bluetoothctl"), {QStringLiteral("power"), enabled ? QStringLiteral("on") : QStringLiteral("off")});
    m_bluetoothEnabled = enabled;
    Q_EMIT bluetoothEnabledChanged(m_bluetoothEnabled);
    if (!enabled && !m_bluetoothDevice.isEmpty()) {
        m_bluetoothDevice.clear();
        Q_EMIT bluetoothDeviceChanged(m_bluetoothDevice);
    }
}

void ControlBackend::toggleBluetooth()
{
    setBluetoothEnabled(!m_bluetoothEnabled);
}

QString ControlBackend::bluetoothDevice() const
{
    return m_bluetoothDevice;
}

void ControlBackend::checkBluetoothStatus()
{
    if (m_bluetoothQueryRunning) return;
    m_bluetoothQueryRunning = true;

    auto *proc = new QProcess(this);
    connect(proc, &QProcess::finished, this, [this, proc](int exitCode) {
        proc->deleteLater();
        m_bluetoothQueryRunning = false;
        if (exitCode == 0) {
            const QString output = QString::fromUtf8(proc->readAllStandardOutput());
            const bool isPowered = output.contains(QLatin1String("Powered: yes"));

            if (m_bluetoothEnabled != isPowered) {
                m_bluetoothEnabled = isPowered;
                Q_EMIT bluetoothEnabledChanged(m_bluetoothEnabled);
            }

            if (!isPowered) {
                if (!m_bluetoothDevice.isEmpty()) {
                    m_bluetoothDevice.clear();
                    Q_EMIT bluetoothDeviceChanged(m_bluetoothDevice);
                }
            } else {
                auto *devProc = new QProcess(this);
                connect(devProc, &QProcess::finished, this, [this, devProc](int dExit) {
                    devProc->deleteLater();
                    if (dExit == 0) {
                        const QString dOut = QString::fromUtf8(devProc->readAllStandardOutput()).trimmed();
                        QString devName;
                        const auto lines = dOut.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
                        for (const auto &l : lines) {
                            if (l.startsWith(QLatin1String("Device "))) {
                                const auto parts = l.split(QLatin1Char(' '), Qt::SkipEmptyParts);
                                if (parts.size() >= 3) {
                                    devName = parts.mid(2).join(QLatin1Char(' '));
                                    break;
                                }
                            }
                        }
                        if (m_bluetoothDevice != devName) {
                            m_bluetoothDevice = devName;
                            Q_EMIT bluetoothDeviceChanged(m_bluetoothDevice);
                        }
                    }
                });
                devProc->start(QStringLiteral("bluetoothctl"), {QStringLiteral("devices"), QStringLiteral("Connected")});
            }
        }
    });

    proc->start(QStringLiteral("bluetoothctl"), {QStringLiteral("show")});
}

// ----------------------------------------------------------------------------
// ACCIONES DEL SISTEMA
// ----------------------------------------------------------------------------
void ControlBackend::openSystemSettings()
{
    KProcess::startDetached(QStringLiteral("systemsettings"));
}

void ControlBackend::openAudioSettings()
{
    KProcess::startDetached(QStringLiteral("kcmshell6"), {QStringLiteral("kcm_pulseaudio")});
}

void ControlBackend::openDisplaySettings()
{
    KProcess::startDetached(QStringLiteral("kcmshell6"), {QStringLiteral("kcm_kscreen")});
}

void ControlBackend::openNetworkSettings()
{
    KProcess::startDetached(QStringLiteral("kcmshell6"), {QStringLiteral("kcm_networkmanagement")});
}

void ControlBackend::openBluetoothSettings()
{
    KProcess::startDetached(QStringLiteral("kcmshell6"), {QStringLiteral("kcm_bluetooth")});
}

void ControlBackend::openEnergySettings()
{
    KProcess::startDetached(QStringLiteral("kcmshell6"), {QStringLiteral("kcm_powerdevilprofilesconfig")});
}

void ControlBackend::openKdeConnect()
{
    KProcess::startDetached(QStringLiteral("kdeconnect-app"));
}

void ControlBackend::lockScreen()
{
    QDBusInterface ssIface(QStringLiteral("org.freedesktop.ScreenSaver"),
                           QStringLiteral("/ScreenSaver"),
                           QStringLiteral("org.freedesktop.ScreenSaver"),
                           QDBusConnection::sessionBus());
    if (ssIface.isValid()) {
        ssIface.call(QStringLiteral("Lock"));
    }
}
