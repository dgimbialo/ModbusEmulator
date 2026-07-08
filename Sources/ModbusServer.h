#ifndef MODBUSSERVER_H
#define MODBUSSERVER_H

#include <QObject>
#include <QModbusServer>
#include <QModbusDataUnit>
#include <QStringList>
#include <functional>

// Mixin that reports client read access. QModbusServer::readData() is
// invoked for every read request a Modbus client sends, so hooking it
// gives us live traffic statistics. A template is used because the same
// hook is needed for both the RTU and the TCP server base classes
// (Q_OBJECT cannot be used in templates, hence the std::function callback).
template <typename BaseServer>
class ObservableModbusServer : public BaseServer
{
public:
    using BaseServer::BaseServer;

    std::function<void(QModbusDataUnit::RegisterType, int, int)> onDataRead;

protected:
    bool readData(QModbusDataUnit* newData) const override
    {
        if (newData && onDataRead)
            onDataRead(newData->registerType(), newData->startAddress(), int(newData->valueCount()));
        return BaseServer::readData(newData);
    }
};

// QML-facing facade around QtSerialBus. Owns the actual QModbusServer
// instance (RTU or TCP, recreated on every start) and keeps it in sync
// with ModbusDataStore in both directions.
class ModbusServer : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool running READ isRunning NOTIFY runningChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY statusChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY statusChanged)

    Q_PROPERTY(int connectionType READ connectionType WRITE setConnectionType NOTIFY settingsChanged)
    Q_PROPERTY(QString portName READ portName WRITE setPortName NOTIFY settingsChanged)
    Q_PROPERTY(int baudRate READ baudRate WRITE setBaudRate NOTIFY settingsChanged)
    Q_PROPERTY(int dataBits READ dataBits WRITE setDataBits NOTIFY settingsChanged)
    Q_PROPERTY(int parity READ parity WRITE setParity NOTIFY settingsChanged)
    Q_PROPERTY(int stopBits READ stopBits WRITE setStopBits NOTIFY settingsChanged)
    Q_PROPERTY(int tcpPort READ tcpPort WRITE setTcpPort NOTIFY settingsChanged)
    Q_PROPERTY(int serverAddress READ serverAddress WRITE setServerAddress NOTIFY settingsChanged)

    Q_PROPERTY(QStringList availablePorts READ availablePorts NOTIFY availablePortsChanged)

    Q_PROPERTY(int readRequests READ readRequests NOTIFY statsChanged)
    Q_PROPERTY(int writeRequests READ writeRequests NOTIFY statsChanged)
    Q_PROPERTY(int errorCount READ errorCount NOTIFY statsChanged)

public:
    enum ConnectionType { Rtu = 0, Tcp = 1 };
    Q_ENUM(ConnectionType)

    explicit ModbusServer(QObject* parent = nullptr);
    ~ModbusServer() override;

    Q_INVOKABLE bool start();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void refreshPorts();
    Q_INVOKABLE void resetStatistics();

    bool isRunning() const;
    QString statusText() const;
    QString lastError() const { return m_lastError; }

    int connectionType() const { return m_connectionType; }
    void setConnectionType(int type);

    QString portName() const { return m_portName; }
    void setPortName(const QString& name);

    int baudRate() const { return m_baudRate; }
    void setBaudRate(int baud);

    int dataBits() const { return m_dataBits; }
    void setDataBits(int bits);

    // QSerialPort::Parity numeric value (0 = None, 2 = Even, 3 = Odd)
    int parity() const { return m_parity; }
    void setParity(int parity);

    int stopBits() const { return m_stopBits; }
    void setStopBits(int bits);

    int tcpPort() const { return m_tcpPort; }
    void setTcpPort(int port);

    int serverAddress() const { return m_serverAddress; }
    void setServerAddress(int address);

    QStringList availablePorts() const { return m_availablePorts; }

    int readRequests() const { return m_readRequests; }
    int writeRequests() const { return m_writeRequests; }
    int errorCount() const { return m_errorCount; }

signals:
    void runningChanged();
    void statusChanged();
    void settingsChanged();
    void availablePortsChanged();
    void statsChanged();

private slots:
    void handleDataWritten(QModbusDataUnit::RegisterType table, int address, int size);
    void handleError(QModbusDevice::Error error);
    void handleStateChanged(QModbusDevice::State state);
    void onStoreValueChanged(int table, int address, int value);
    void onStoreBulkChanged();

private:
    void handleDataRead(QModbusDataUnit::RegisterType table, int address, int size);
    void destroyServer();
    QModbusDataUnitMap createDataUnitMap() const;
    void syncAllToServer();
    void setLastError(const QString& message);

    QModbusServer* m_server = nullptr;

    // Connection settings
    int m_connectionType = Rtu;
    QString m_portName;
    int m_baudRate = 115200;
    int m_dataBits = 8;
    int m_parity = 0;   // QSerialPort::NoParity
    int m_stopBits = 1;
    int m_tcpPort = 502;
    int m_serverAddress = 1;

    QStringList m_availablePorts;
    QString m_lastError;

    // Traffic statistics
    int m_readRequests = 0;
    int m_writeRequests = 0;
    int m_errorCount = 0;

    // Re-entrancy guard: true while pushing client-written values into the
    // data store, so the resulting valueChanged() is not echoed back.
    bool m_syncingFromClient = false;

    // True while we write to the server ourselves. QModbusServer::setData()
    // internally triggers readData()/dataWritten() for every value, so this
    // guard keeps our own updates out of the traffic statistics and log.
    bool m_internalUpdate = false;
};

#endif // MODBUSSERVER_H
