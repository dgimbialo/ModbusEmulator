// LogHandler.h
#ifndef LOGHANDLER_H
#define LOGHANDLER_H

#include <QObject>
#include <QStringList>
#include <QDateTime>
#include <QTimer>

class LogHandler : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList logEntries READ logEntries NOTIFY logEntriesChanged)
    Q_PROPERTY(int maxEntries READ maxEntries WRITE setMaxEntries NOTIFY maxEntriesChanged)

public:
    explicit LogHandler(QObject *parent = nullptr);
    ~LogHandler();

    // Property access
    QStringList logEntries() const { return m_logEntries; }
    int maxEntries() const { return m_maxEntries; }
    void setMaxEntries(int max);

    // Add log entry (batched: the QML model is refreshed at most every 100 ms)
    Q_INVOKABLE void addLogEntry(const QString &message);

    // Clear log
    Q_INVOKABLE void clearLog();

    // Copy the full log to the system clipboard
    Q_INVOKABLE void copyToClipboard() const;

    // Message handler that Qt will call for debug messages
    static void messageHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg);

signals:
    void logEntriesChanged();
    void maxEntriesChanged();

private:
    void flushPending();

    QStringList m_logEntries;
    QStringList m_pendingEntries;
    QTimer m_flushTimer;
    int m_maxEntries;

    // Static instance to use in messageHandler
    static LogHandler* s_instance;
};

#endif // LOGHANDLER_H
