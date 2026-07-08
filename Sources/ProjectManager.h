#ifndef PROJECTMANAGER_H
#define PROJECTMANAGER_H

#include <QObject>
#include <QUrl>
#include <QVariantMap>

class ModbusServer;

// Saves / loads the whole emulator state as a human-readable JSON project
// file: connection settings, all four Modbus tables, register groups,
// signal generators and view settings. The last opened project is
// remembered (QSettings) and reloaded on the next start.
class ProjectManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString currentFile READ currentFile NOTIFY currentFileChanged)
    Q_PROPERTY(QString currentFileName READ currentFileName NOTIFY currentFileChanged)

public:
    explicit ProjectManager(ModbusServer* server, QObject* parent = nullptr);

    QString currentFile() const { return m_currentFile; }
    QString currentFileName() const;

    // uiState comes from QML: register groups, generators, view settings
    Q_INVOKABLE bool saveToFile(const QUrl& url, const QVariantMap& uiState);
    Q_INVOKABLE bool save(const QVariantMap& uiState);

    // Returns the parsed project document (empty map on failure).
    // Connection settings and register data are applied on the C++ side;
    // QML applies the "ui" section itself.
    Q_INVOKABLE QVariantMap openFile(const QUrl& url);
    Q_INVOKABLE QVariantMap openLast();

    Q_INVOKABLE void closeProject();

signals:
    void currentFileChanged();

private:
    QJsonObject buildDocument(const QVariantMap& uiState) const;
    bool applyDocument(const QJsonObject& root);
    void setCurrentFile(const QString& path);

    ModbusServer* m_server;
    QString m_currentFile;
};

#endif // PROJECTMANAGER_H
