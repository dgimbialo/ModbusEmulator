#include "ModbusServer.h"
#include "ModbusDataStore.h"

#include <QModbusRtuSerialServer>
#include <QModbusTcpServer>
#include <QSerialPort>
#include <QSerialPortInfo>
#include <QDebug>

namespace {

QString registerTypeName(QModbusDataUnit::RegisterType type)
{
    switch (type) {
    case QModbusDataUnit::Coils:            return QStringLiteral("Coils");
    case QModbusDataUnit::DiscreteInputs:   return QStringLiteral("Discrete Inputs");
    case QModbusDataUnit::InputRegisters:   return QStringLiteral("Input Registers");
    case QModbusDataUnit::HoldingRegisters: return QStringLiteral("Holding Registers");
    default:                                return QStringLiteral("Invalid");
    }
}

} // namespace

ModbusServer::ModbusServer(QObject* parent)
    : QObject(parent)
{
    auto& store = ModbusDataStore::instance();
    connect(&store, &ModbusDataStore::valueChanged, this, &ModbusServer::onStoreValueChanged);
    connect(&store, &ModbusDataStore::bulkChanged, this, &ModbusServer::onStoreBulkChanged);

    refreshPorts();
    if (!m_availablePorts.isEmpty())
        m_portName = m_availablePorts.first();
}

ModbusServer::~ModbusServer()
{
    stop();
}

bool ModbusServer::isRunning() const
{
    return m_server && m_server->state() == QModbusDevice::ConnectedState;
}

QString ModbusServer::statusText() const
{
    if (isRunning()) {
        if (m_connectionType == Tcp)
            return QStringLiteral("TCP · port %1 · unit ID %2").arg(m_tcpPort).arg(m_serverAddress);

        const QString parityChar = m_parity == QSerialPort::EvenParity ? QStringLiteral("E")
                                 : m_parity == QSerialPort::OddParity  ? QStringLiteral("O")
                                                                       : QStringLiteral("N");
        return QStringLiteral("RTU · %1 @ %2 %3%4%5 · unit ID %6")
            .arg(m_portName).arg(m_baudRate).arg(m_dataBits).arg(parityChar).arg(m_stopBits).arg(m_serverAddress);
    }

    if (!m_lastError.isEmpty())
        return QStringLiteral("Error: %1").arg(m_lastError);

    return QStringLiteral("Offline");
}

bool ModbusServer::start()
{
    if (isRunning())
        return true;

    destroyServer();
    setLastError(QString());

    if (m_connectionType == Tcp) {
        auto* server = new ObservableModbusServer<QModbusTcpServer>(this);
        server->onDataRead = [this](QModbusDataUnit::RegisterType t, int a, int s) { handleDataRead(t, a, s); };
        server->setConnectionParameter(QModbusDevice::NetworkAddressParameter, QStringLiteral("0.0.0.0"));
        server->setConnectionParameter(QModbusDevice::NetworkPortParameter, m_tcpPort);
        m_server = server;
    } else {
        if (m_portName.isEmpty()) {
            setLastError(QStringLiteral("No serial port selected"));
            qCritical() << "Cannot start: no serial port selected";
            return false;
        }
        auto* server = new ObservableModbusServer<QModbusRtuSerialServer>(this);
        server->onDataRead = [this](QModbusDataUnit::RegisterType t, int a, int s) { handleDataRead(t, a, s); };
        server->setConnectionParameter(QModbusDevice::SerialPortNameParameter, m_portName);
        server->setConnectionParameter(QModbusDevice::SerialBaudRateParameter, m_baudRate);
        server->setConnectionParameter(QModbusDevice::SerialDataBitsParameter, m_dataBits);
        server->setConnectionParameter(QModbusDevice::SerialParityParameter, m_parity);
        server->setConnectionParameter(QModbusDevice::SerialStopBitsParameter,
                                       m_stopBits == 2 ? QSerialPort::TwoStop : QSerialPort::OneStop);
        m_server = server;
    }

    connect(m_server, &QModbusServer::dataWritten, this, &ModbusServer::handleDataWritten);
    connect(m_server, &QModbusServer::errorOccurred, this, &ModbusServer::handleError);
    connect(m_server, &QModbusServer::stateChanged, this, &ModbusServer::handleStateChanged);

    m_server->setServerAddress(m_serverAddress);
    m_server->setValue(QModbusServer::ServerIdentifier, m_serverAddress);
    m_server->setValue(QModbusServer::ListenOnlyMode, false);
    m_server->setValue(QModbusServer::DeviceBusy, false);

    if (!m_server->setMap(createDataUnitMap())) {
        setLastError(m_server->errorString());
        qCritical() << "Failed to set data unit map:" << m_server->errorString();
        destroyServer();
        return false;
    }

    if (!m_server->connectDevice()) {
        setLastError(m_server->errorString());
        qCritical() << "Failed to start Modbus server:" << m_server->errorString();
        destroyServer();
        return false;
    }

    syncAllToServer();

    qInfo() << "Modbus server started:" << statusText();
    emit runningChanged();
    emit statusChanged();
    return true;
}

void ModbusServer::stop()
{
    if (!m_server)
        return;

    if (m_server->state() != QModbusDevice::UnconnectedState) {
        qInfo() << "Stopping Modbus server";
        m_server->disconnectDevice();
    }

    destroyServer();
    emit runningChanged();
    emit statusChanged();
}

void ModbusServer::destroyServer()
{
    if (!m_server)
        return;

    m_server->disconnect(this);
    m_server->deleteLater();
    m_server = nullptr;
}

void ModbusServer::refreshPorts()
{
    QStringList ports;
    const auto infos = QSerialPortInfo::availablePorts();
    for (const QSerialPortInfo& info : infos)
        ports.append(info.portName());
    ports.sort();

    if (ports != m_availablePorts) {
        m_availablePorts = ports;
        emit availablePortsChanged();
    }
}

void ModbusServer::resetStatistics()
{
    m_readRequests = 0;
    m_writeRequests = 0;
    m_errorCount = 0;
    emit statsChanged();
}

void ModbusServer::setConnectionType(int type)
{
    if (m_connectionType == type)
        return;
    m_connectionType = type;
    emit settingsChanged();
    emit statusChanged();
}

void ModbusServer::setPortName(const QString& name)
{
    if (m_portName == name)
        return;
    m_portName = name;
    emit settingsChanged();
}

void ModbusServer::setBaudRate(int baud)
{
    if (m_baudRate == baud)
        return;
    m_baudRate = baud;
    emit settingsChanged();
}

void ModbusServer::setDataBits(int bits)
{
    if (m_dataBits == bits)
        return;
    m_dataBits = bits;
    emit settingsChanged();
}

void ModbusServer::setParity(int parity)
{
    if (m_parity == parity)
        return;
    m_parity = parity;
    emit settingsChanged();
}

void ModbusServer::setStopBits(int bits)
{
    if (m_stopBits == bits)
        return;
    m_stopBits = bits;
    emit settingsChanged();
}

void ModbusServer::setTcpPort(int port)
{
    if (m_tcpPort == port)
        return;
    m_tcpPort = port;
    emit settingsChanged();
}

void ModbusServer::setServerAddress(int address)
{
    if (m_serverAddress == address)
        return;
    m_serverAddress = address;
    emit settingsChanged();
}

void ModbusServer::setLastError(const QString& message)
{
    m_lastError = message;
    emit statusChanged();
}

QModbusDataUnitMap ModbusServer::createDataUnitMap() const
{
    QModbusDataUnitMap map;
    map.insert(QModbusDataUnit::Coils,
               QModbusDataUnit(QModbusDataUnit::Coils, 0, ModbusDataStore::CoilCount));
    map.insert(QModbusDataUnit::DiscreteInputs,
               QModbusDataUnit(QModbusDataUnit::DiscreteInputs, 0, ModbusDataStore::DiscreteInputCount));
    map.insert(QModbusDataUnit::InputRegisters,
               QModbusDataUnit(QModbusDataUnit::InputRegisters, 0, ModbusDataStore::InputRegisterCount));
    map.insert(QModbusDataUnit::HoldingRegisters,
               QModbusDataUnit(QModbusDataUnit::HoldingRegisters, 0, ModbusDataStore::HoldingRegisterCount));
    return map;
}

void ModbusServer::syncAllToServer()
{
    if (!m_server)
        return;

    auto& store = ModbusDataStore::instance();
    m_internalUpdate = true;

    QModbusDataUnit holding(QModbusDataUnit::HoldingRegisters, 0, store.holdingRegisters());
    m_server->setData(holding);

    QModbusDataUnit input(QModbusDataUnit::InputRegisters, 0, store.inputRegisters());
    m_server->setData(input);

    const QBitArray coils = store.coils();
    QModbusDataUnit coilUnit(QModbusDataUnit::Coils, 0, coils.size());
    for (int i = 0; i < coils.size(); ++i)
        coilUnit.setValue(i, coils.testBit(i) ? 1 : 0);
    m_server->setData(coilUnit);

    const QBitArray discretes = store.discreteInputs();
    QModbusDataUnit discreteUnit(QModbusDataUnit::DiscreteInputs, 0, discretes.size());
    for (int i = 0; i < discretes.size(); ++i)
        discreteUnit.setValue(i, discretes.testBit(i) ? 1 : 0);
    m_server->setData(discreteUnit);

    m_internalUpdate = false;
}

void ModbusServer::onStoreValueChanged(int table, int address, int value)
{
    // Ignore the echo of values we just received from the client
    if (m_syncingFromClient)
        return;

    if (!m_server || m_server->state() != QModbusDevice::ConnectedState)
        return;

    m_internalUpdate = true;
    m_server->setData(static_cast<QModbusDataUnit::RegisterType>(table),
                      static_cast<quint16>(address),
                      static_cast<quint16>(value));
    m_internalUpdate = false;
}

void ModbusServer::onStoreBulkChanged()
{
    if (m_server && m_server->state() == QModbusDevice::ConnectedState)
        syncAllToServer();
}

void ModbusServer::handleDataRead(QModbusDataUnit::RegisterType table, int address, int size)
{
    // Skip internal reads triggered by our own setData()/data() calls
    if (m_internalUpdate || m_syncingFromClient)
        return;

    ++m_readRequests;
    emit statsChanged();

    qDebug().noquote() << QStringLiteral("Read request: %1, start %2, count %3")
                              .arg(registerTypeName(table)).arg(address).arg(size);
}

void ModbusServer::handleDataWritten(QModbusDataUnit::RegisterType table, int address, int size)
{
    // setData() also emits dataWritten() - ignore our own updates
    if (m_internalUpdate)
        return;

    ++m_writeRequests;
    emit statsChanged();

    qDebug().noquote() << QStringLiteral("Write request: %1, start %2, count %3")
                              .arg(registerTypeName(table)).arg(address).arg(size);

    if (!m_server)
        return;

    // Mirror the values the client wrote into the data store so the UI
    // updates live. The guard stops onStoreValueChanged from writing the
    // same values straight back to the server.
    auto& store = ModbusDataStore::instance();
    m_syncingFromClient = true;
    for (int i = 0; i < size; ++i) {
        quint16 value = 0;
        if (!m_server->data(table, static_cast<quint16>(address + i), &value))
            continue;

        switch (table) {
        case QModbusDataUnit::Coils:
            store.setCoil(address + i, value != 0);
            break;
        case QModbusDataUnit::HoldingRegisters:
            store.setHoldingRegister(address + i, value);
            break;
        case QModbusDataUnit::InputRegisters:
            store.setInputRegister(address + i, value);
            break;
        case QModbusDataUnit::DiscreteInputs:
            store.setDiscreteInput(address + i, value != 0);
            break;
        default:
            break;
        }
    }
    m_syncingFromClient = false;
}

void ModbusServer::handleStateChanged(QModbusDevice::State state)
{
    if (state == QModbusDevice::UnconnectedState) {
        emit runningChanged();
        emit statusChanged();
    }
}

void ModbusServer::handleError(QModbusDevice::Error error)
{
    if (error == QModbusDevice::NoError)
        return;

    ++m_errorCount;
    emit statsChanged();

    QString errorName;
    switch (error) {
    case QModbusDevice::ReadError:          errorName = QStringLiteral("Read error");          break;
    case QModbusDevice::WriteError:         errorName = QStringLiteral("Write error");         break;
    case QModbusDevice::ConnectionError:    errorName = QStringLiteral("Connection error");    break;
    case QModbusDevice::ConfigurationError: errorName = QStringLiteral("Configuration error"); break;
    case QModbusDevice::TimeoutError:       errorName = QStringLiteral("Timeout error");       break;
    case QModbusDevice::ProtocolError:      errorName = QStringLiteral("Protocol error");      break;
    case QModbusDevice::ReplyAbortedError:  errorName = QStringLiteral("Reply aborted");       break;
    default:                                errorName = QStringLiteral("Unknown error");       break;
    }

    const QString details = m_server ? m_server->errorString() : QString();
    setLastError(details.isEmpty() ? errorName : QStringLiteral("%1: %2").arg(errorName, details));
    qCritical().noquote() << errorName << (details.isEmpty() ? QString() : QStringLiteral("- %1").arg(details));
}
