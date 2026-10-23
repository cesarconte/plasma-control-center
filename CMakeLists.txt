cmake_minimum_required(VERSION 3.20)
project(plasma-control-center VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(QT_MIN_VERSION "6.8.0")
set(KF_MIN_VERSION "6.10.0")

find_package(ECM ${KF_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(ECMQmlModule)
include(ECMQtDeclareLoggingCategory)
include(FeatureSummary)

find_package(Qt6 ${QT_MIN_VERSION} REQUIRED COMPONENTS DBus Gui GuiPrivate Quick Widgets)
find_package(KF6 ${KF_MIN_VERSION} REQUIRED COMPONENTS
    Config CoreAddons I18n IconThemes ItemModels JobWidgets KIO Package
    Service StatusNotifierItem WindowSystem XmlGui)
find_package(Plasma REQUIRED)
find_package(PlasmaQuick REQUIRED)

add_subdirectory(src)

ki18n_install(po)

feature_summary(WHAT ALL FATAL_ON_MISSING_REQUIRED_PACKAGES)
