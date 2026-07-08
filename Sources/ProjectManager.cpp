#include "ProjectManager.h"
#include "ModbusServer.h"
#include "ModbusDataStore.h"

#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSettings>
#include <QDebug>

namespace {
const QString kFileType = QStringLiteral("ModbusEmulatorProject");
const QString kLastFileKey = QStringLiteral("project/lastFile");
constexpr int kFileVersion = 1;
} // namespace

ProjectManager::ProjectManager(ModbusServer* server, QObject* parent)
    : QObject(parent)
    , m_server(server)
{
}

QString ProjectManager::currentFileName() const
{
    if (m_currentFile.isEmpty())
        return QStringLiteral("Untitled");
    return QFileInfo(m_currentFile).fileName();
}

void ProjectManager::setCurrentFile(const QString& path)
{
    if (m_currentFile == path)
        return;
    m_currentFile = path;
    QSettings().setValue(kLastFileKey, path);
    emit currentFileChanged();
}

QJsonObject ProjectManager::buildDocument(const QVariantMap& uiState) const
{
    QJsonObject connection;
    connection[QStringLiteral("type")] = m_server->connectionType();
    connection[QStringLiteral("portName")] = m_server->portName();
    connection[QStringLiteral("baudRate")] = m_server->baudRate();
    connection[QStringLiteral("dataBits")] = m_server->dataBits();
    connection[QStringLiteral("parity")] = m_server->parity();
    connection[QStringLiteral("stopBits")] = m_server->stopBits();
    connection[QStringLiteral("tcpPort")] = m_server->tcpPort();
    connection[QStringLiteral("unitId")] = m_server->serverAddress();

    QJsonObject root;
    root[QStringLiteral("fileType")] = kFileType;
    root[QStringLiteral("version")] = kFileVersion;
    root[QStringLiteral("connection")] = connection;
    root[QStringLiteral("data")] = ModbusDataStore::instance().dataToJson();
    root[QStringLiteral("ui")] = QJsonObject::fromVariantMap(uiState);
    return root;
}

bool ProjectManager::applyDocument(const QJsonObject& root)
{
    if (root.value(QStringLiteral("fileType")).toString() != kFileType) {
        qWarning() << "Not a Modbus Emulator project file";
        return false;
    }

    const QJsonObject connection = root.value(QStringLiteral("connection")).toObject();
    if (!connection.isEmpty()) {
        m_server->setConnectionType(connection.value(QStringLiteral("type")).toInt(0));
        m_server->setPortName(connection.value(QStringLiteral("portName")).toString());
        m_server->setBaudRate(connection.value(QStringLiteral("baudRate")).toInt(115200));
        m_server->setDataBits(connection.value(QStringLiteral("dataBits")).toInt(8));
        m_server->setParity(connection.value(QStringLiteral("parity")).toInt(0));
        m_server->setStopBits(connection.value(QStringLiteral("stopBits")).toInt(1));
        m_server->setTcpPort(connection.value(QStringLiteral("tcpPort")).toInt(502));
        m_server->setServerAddress(connection.value(QStringLiteral("unitId")).toInt(1));
    }

    ModbusDataStore::instance().dataFromJson(root.value(QStringLiteral("data")).toObject());
    return true;
}

bool ProjectManager::saveToFile(const QUrl& url, const QVariantMap& uiState)
{
    const QString path = url.isLocalFile() ? url.toLocalFile() : url.toString();
    if (path.isEmpty())
        return false;

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qCritical().noquote() << "Cannot write project file:" << path << "-" << file.errorString();
        return false;
    }

    file.write(QJsonDocument(buildDocument(uiState)).toJson(QJsonDocument::Indented));
    file.close();
    setCurrentFile(path);
    qInfo().noquote() << "Project saved:" << path;
    return true;
}

bool ProjectManager::save(const QVariantMap& uiState)
{
    if (m_currentFile.isEmpty())
        return false;
    return saveToFile(QUrl::fromLocalFile(m_currentFile), uiState);
}

QVariantMap ProjectManager::openFile(const QUrl& url)
{
    const QString path = url.isLocalFile() ? url.toLocalFile() : url.toString();

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qCritical().noquote() << "Cannot open project file:" << path << "-" << file.errorString();
        return {};
    }

    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll(), &parseError);
    file.close();

    if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
        qCritical().noquote() << "Invalid project file:" << parseError.errorString();
        return {};
    }

    const QJsonObject root = doc.object();
    if (!applyDocument(root))
        return {};

    setCurrentFile(path);
    qInfo().noquote() << "Project loaded:" << path;
    return root.toVariantMap();
}

QVariantMap ProjectManager::openLast()
{
    const QString last = QSettings().value(kLastFileKey).toString();
    if (last.isEmpty() || !QFile::exists(last))
        return {};
    return openFile(QUrl::fromLocalFile(last));
}

void ProjectManager::closeProject()
{
    ModbusDataStore::instance().resetAll();
    setCurrentFile(QString());
    qInfo() << "New project created";
}
