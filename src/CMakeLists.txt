set(CMAKE_INCLUDE_CURRENT_DIR ON)
add_definitions(-DTRANSLATION_DOMAIN=\"plasma_applet_org.cesar.plasmacontrolcenter\")

# Static copy of the DBusMenu importer used by the upstream System Tray.
set(dbusmenu_SRCS
    dbusmenuqt/dbusmenuimporter.cpp
    dbusmenuqt/dbusmenushortcut_p.cpp
    dbusmenuqt/dbusmenutypes_p.cpp
    dbusmenuqt/utils.cpp
)
set_source_files_properties(dbusmenuqt/com.canonical.dbusmenu.xml PROPERTIES
    NO_NAMESPACE true
    INCLUDE "dbusmenutypes_p.h"
    CLASSNAME DBusMenuInterface
)
qt_add_dbus_interface(dbusmenu_SRCS dbusmenuqt/com.canonical.dbusmenu.xml dbusmenu_interface)
ecm_qt_declare_logging_category(dbusmenu_SRCS HEADER dbusmenu_debug.h
    IDENTIFIER DBUSMENUQT
    CATEGORY_NAME org.kde.libdbusmenuqt
    DEFAULT_SEVERITY Info
    DESCRIPTION "libdbusmenu debug"
    EXPORT PLASMACONTROLCENTER)
add_library(pcc_dbusmenuqt STATIC ${dbusmenu_SRCS})
target_link_libraries(pcc_dbusmenuqt Qt6::DBus Qt6::Widgets)
set_property(TARGET pcc_dbusmenuqt PROPERTY POSITION_INDEPENDENT_CODE ON)
target_include_directories(pcc_dbusmenuqt PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/dbusmenuqt)

set(systemtray_SRCS
    dbusserviceobserver.cpp
    plasmoidregistry.cpp
    statusnotifieritemhost.cpp
    statusnotifieritemsource.cpp
    systemtraysettings.cpp
    systemtraytypes.cpp
    systemtraymodel.cpp
    sortedsystemtraymodel.cpp
)

qt_add_dbus_interface(systemtray_SRCS ${KSTATUSNOTIFIERITEM_DBUS_INTERFACES_DIR}/kf6_org.kde.StatusNotifierWatcher.xml statusnotifierwatcher_interface)
qt_add_dbus_interface(systemtray_SRCS dbus/org.freedesktop.DBus.Properties.xml dbusproperties)

set(statusnotifieritem_xml ${KSTATUSNOTIFIERITEM_DBUS_INTERFACES_DIR}/kf6_org.kde.StatusNotifierItem.xml)
set_source_files_properties(${statusnotifieritem_xml} PROPERTIES
    NO_NAMESPACE false
    INCLUDE "systemtraytypes.h"
    CLASSNAME OrgKdeStatusNotifierItem
)
qt_add_dbus_interface(systemtray_SRCS ${statusnotifieritem_xml} statusnotifieritem_interface)

ecm_qt_declare_logging_category(systemtray_SRCS HEADER debug.h
    IDENTIFIER SYSTEM_TRAY
    CATEGORY_NAME org.cesar.plasmacontrolcenter
    DEFAULT_SEVERITY Info
    DESCRIPTION "Plasma Control Center applet"
    EXPORT PLASMACONTROLCENTER)

plasma_add_applet(org.cesar.plasmacontrolcenter
    CPP_SOURCES
        systemtray.cpp
        ${systemtray_SRCS}
    QML_SOURCES
        qml/AbstractItem.qml
        qml/BackgroundAppItem.qml
        qml/ConfigGeneral.qml
        qml/CurrentItemHighLight.qml
        qml/ExpanderArrow.qml
        qml/ItemLoader.qml
        qml/PlasmoidItem.qml
        qml/PulseAnimation.qml
        qml/SystemTrayState.qml
        qml/CompactApplet.qml
        qml/config.qml
        qml/ExpandedRepresentation.qml
        qml/HiddenItemsView.qml
        qml/main.qml
        qml/PlasmoidPopupsContainer.qml
        qml/StatusNotifierItem.qml
    RESOURCES
        main.xml
)

target_include_directories(org.cesar.plasmacontrolcenter PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(org.cesar.plasmacontrolcenter PRIVATE
    Qt6::DBus Qt6::Gui Qt6::GuiPrivate Qt6::Quick
    KF6::ConfigCore KF6::CoreAddons KF6::IconThemes KF6::I18n KF6::KIOGui
    KF6::JobWidgets KF6::Service KF6::ItemModels KF6::WindowSystem KF6::XmlGui
    Plasma::Plasma Plasma::PlasmaQuick pcc_dbusmenuqt)
