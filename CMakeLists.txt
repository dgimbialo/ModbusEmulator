cmake_minimum_required(VERSION 3.16)
project(ModbusEmulator LANGUAGES CXX)

# Set C++ standard
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOMOC ON)

# set(QT_DEBUG_FIND_PACKAGE ON)

# Find Qt libraries
find_package(Qt6 6.4 REQUIRED COMPONENTS Sql Core Gui Qml Quick QuickControls2 SerialPort SerialBus)
qt_standard_project_setup()


# Add source files
set(SOURCES
    Sources/main.cpp
    Sources/ModbusServer.cpp
    Sources/ModbusDataStore.cpp
    Sources/LogHandler.cpp
    Sources/ProjectManager.cpp
)

set(HEADERS
    Sources/ModbusServer.h
    Sources/ModbusDataStore.h
    Sources/LogHandler.h
    Sources/ProjectManager.h
)

qt6_add_resources(RESOURCES resources.qrc)

# Add executable (with the application icon on Windows)
if(WIN32)
    add_executable(${PROJECT_NAME} WIN32 ${SOURCES} ${HEADERS} app_icon.rc)
else()
    add_executable(${PROJECT_NAME} ${SOURCES} ${HEADERS})
endif()

# Add resources to the target
target_sources(${PROJECT_NAME} PRIVATE ${RESOURCES})

# Link Qt libraries
target_link_libraries(${PROJECT_NAME} 
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::SerialPort
    Qt6::SerialBus
    Qt6::Sql
)
