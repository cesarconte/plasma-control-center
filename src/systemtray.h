/*
    SPDX-FileCopyrightText: 2015 Marco Martin <mart@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <QAbstractItemModel>
#include <QPointer>

#include <KConfigWatcher>

#include <Plasma/Containment>

class QQuickItem;

namespace Plasma
{
}
class PlasmoidRegistry;
class PlasmoidModel;
class SystemTraySettings;
class StatusNotifierModel;
class SystemTrayModel;
class SortedSystemTrayModel;
class KJob;
class ControlBackend;

class SystemTray : public Plasma::Containment
{
    Q_OBJECT
    Q_PROPERTY(QAbstractItemModel *systemTrayModel READ sortedSystemTrayModel CONSTANT)
    Q_PROPERTY(QAbstractItemModel *configSystemTrayModel READ configSystemTrayModel CONSTANT)
    Q_PROPERTY(ControlBackend *backend READ backend CONSTANT)

public:
    SystemTray(QObject *parent, const KPluginMetaData &data, const QVariantList &args);
    ~SystemTray() override;

    void init() override;

    void restoreContents(KConfigGroup &group) override;

    QAbstractItemModel *sortedSystemTrayModel();

    QAbstractItemModel *configSystemTrayModel();

    ControlBackend *backend();

    // Invocable utilities
    /**
     * Given an AppletInterface pointer, shows a proper context menu for it
     */
    Q_INVOKABLE void showPlasmoidMenu(QQuickItem *appletInterface, int x, int y);

    /**
     * Find out global coordinates for a popup given local MouseArea
     * coordinates
     */
    Q_INVOKABLE QPointF popupPosition(QQuickItem *visualParent, int x, int y);

    /**
     * @brief isSystemTrayApplet checks if applet is allowed in the System Tray
     * @param appletId also known as plugin Id
     * @return true if it is a system tray applet, otherwise false
     */
    Q_INVOKABLE bool isSystemTrayApplet(const QString &appletId);

    /**
     * Needed to preserve keyboard navigation
     */
    Q_INVOKABLE void stackItemBefore(QQuickItem *newItem, QQuickItem *beforeItem);

    Q_INVOKABLE void stackItemAfter(QQuickItem *newItem, QQuickItem *afterItem);

    Q_INVOKABLE void activate(const QString &service, QPoint pos, QQuickItem *statusNotifierIcon);

    Q_INVOKABLE void secondaryActivate(const QString &service, QPoint pos);

    Q_INVOKABLE void openContextMenu(const QString &service, QPoint pos, QQuickItem *statusNotifierIcon);

    Q_INVOKABLE void scroll(const QString &service, int delta, const QString &direction);

    Q_INVOKABLE QString serviceForItemId(const QString &itemId) const;
    Q_INVOKABLE void activateItemId(const QString &itemId, QPoint pos, QQuickItem *visualItem);
    Q_INVOKABLE void openContextMenuForItemId(const QString &itemId, QPoint pos, QQuickItem *visualItem);
    Q_INVOKABLE QVariantMap extraItemInfo(const QString &itemId) const;

private Q_SLOTS:
    // synchronizes with configuration and deletes not allowed applets
    void onEnabledAppletsChanged();
    // creates an applet *if not already existing*
    void startApplet(const QString &pluginId);
    // deletes/stops all instances of a given applet
    void stopApplet(const QString &pluginId);

private:
    void migrateFromSystrayContainer();
    SystemTrayModel *systemTrayModel();
    void initSettingsAndRegistry();
    void initRegistry();

    KConfigWatcher::Ptr m_configWatcher;
    bool m_xwaylandClientsScale = true;

    QPointer<SystemTraySettings> m_settings;
    QPointer<PlasmoidRegistry> m_plasmoidRegistry;
    bool m_registryInitialized = false;

    PlasmoidModel *m_plasmoidModel = nullptr;
    StatusNotifierModel *m_statusNotifierModel = nullptr;
    SystemTrayModel *m_systemTrayModel = nullptr;
    SortedSystemTrayModel *m_sortedSystemTrayModel = nullptr;
    SortedSystemTrayModel *m_configSystemTrayModel = nullptr;
    ControlBackend *m_backend = nullptr;

    QHash<QString /*plugin id*/, int /*config group*/> m_configGroupIds;
};
