#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QIcon>
#include "ModbusServer.h"
#include "ModbusDataStore.h"
#include "LogHandler.h"
#include "ProjectManager.h"

int main(int argc, char* argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setOrganizationName(QStringLiteral("DG"));
    QGuiApplication::setApplicationName(QStringLiteral("ModbusEmulator"));
    QGuiApplication::setWindowIcon(QIcon(QStringLiteral(":/icons/app_64.png")));

    // Material style as the base; the QML layer customizes it further
    QQuickStyle::setStyle(QStringLiteral("Material"));

    // Use the singleton instance of ModbusDataStore
    ModbusDataStore& dataStore = ModbusDataStore::instance();

    // Create and install log handler
    LogHandler* logHandler = new LogHandler(&app);
    qInstallMessageHandler(LogHandler::messageHandler);

    // Modbus server facade - started/stopped and configured from QML
    ModbusServer modbusServer;

    // Project save/load (JSON)
    ProjectManager projectManager(&modbusServer);

    QQmlApplicationEngine engine;

    // Expose backend objects to QML
    engine.rootContext()->setContextProperty("modbusDataStore", &dataStore);
    engine.rootContext()->setContextProperty("modbusServer", &modbusServer);
    engine.rootContext()->setContextProperty("logHandler", logHandler);
    engine.rootContext()->setContextProperty("projectManager", &projectManager);

    engine.load(QUrl(QStringLiteral("qrc:/qml/Main.qml")));

    if (engine.rootObjects().isEmpty())
        return -1;

    qInfo() << "Modbus Emulator started. Configure the connection and press Start.";

    return app.exec();
}
