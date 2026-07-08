// LogHandler.cpp
#include "LogHandler.h"
#include <QGuiApplication>
#include <QClipboard>

// Static instance initialization
LogHandler* LogHandler::s_instance = nullptr;

LogHandler::LogHandler(QObject *parent)
    : QObject(parent), m_maxEntries(1000)
{
    // Store instance for use in static messageHandler
    s_instance = this;

    // Batch UI updates: heavy Modbus polling can produce hundreds of
    // messages per second, refreshing the QML model for each would stall the UI
    m_flushTimer.setInterval(100);
    m_flushTimer.setSingleShot(true);
    connect(&m_flushTimer, &QTimer::timeout, this, &LogHandler::flushPending);
}

LogHandler::~LogHandler()
{
    s_instance = nullptr;
}

void LogHandler::setMaxEntries(int max)
{
    if (m_maxEntries != max) {
        m_maxEntries = max;

        // Trim entries if needed
        while (m_logEntries.size() > m_maxEntries) {
            m_logEntries.removeFirst();
        }

        emit maxEntriesChanged();
        emit logEntriesChanged();
    }
}

void LogHandler::addLogEntry(const QString &message)
{
    // Add timestamp to message
    QString timestamp = QDateTime::currentDateTime().toString("HH:mm:ss.zzz");
    m_pendingEntries.append(QString("[%1] %2").arg(timestamp).arg(message));

    // Keep the pending buffer bounded as well
    while (m_pendingEntries.size() > m_maxEntries)
        m_pendingEntries.removeFirst();

    if (!m_flushTimer.isActive())
        m_flushTimer.start();
}

void LogHandler::flushPending()
{
    if (m_pendingEntries.isEmpty())
        return;

    m_logEntries.append(m_pendingEntries);
    m_pendingEntries.clear();

    // Trim to max size
    while (m_logEntries.size() > m_maxEntries)
        m_logEntries.removeFirst();

    emit logEntriesChanged();
}

void LogHandler::clearLog()
{
    m_pendingEntries.clear();
    m_logEntries.clear();
    emit logEntriesChanged();
}

void LogHandler::copyToClipboard() const
{
    if (QClipboard* clipboard = QGuiApplication::clipboard())
        clipboard->setText(m_logEntries.join(QStringLiteral("\n")));
}

void LogHandler::messageHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg)
{
    Q_UNUSED(context)

    // Skip if no instance available
    if (!s_instance)
        return;

    QString prefix;
    switch (type) {
    case QtDebugMsg:
        prefix = "DEBUG";
        break;
    case QtInfoMsg:
        prefix = "INFO";
        break;
    case QtWarningMsg:
        prefix = "WARNING";
        break;
    case QtCriticalMsg:
        prefix = "CRITICAL";
        break;
    case QtFatalMsg:
        prefix = "FATAL";
        break;
    }

    // Add to log entries
    QString logMessage = QString("[%1] %2").arg(prefix).arg(msg);
    QMetaObject::invokeMethod(s_instance, "addLogEntry", Q_ARG(QString, logMessage));
}
