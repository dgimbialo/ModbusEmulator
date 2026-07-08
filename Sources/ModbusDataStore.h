#ifndef MODBUSDATASTORE_H
#define MODBUSDATASTORE_H

#include <QObject>
#include <QVector>
#include <QBitArray>
#include <QJsonObject>
#include <QModbusDataUnit>

// Central storage for all four Modbus tables.
// All access happens on the GUI thread (QtSerialBus servers deliver
// their callbacks on the thread that owns the device), so no locking
// is required here.
class ModbusDataStore : public QObject
{
    Q_OBJECT

public:
    static constexpr int HoldingRegisterCount = 30000;
    static constexpr int InputRegisterCount   = 30000;
    static constexpr int CoilCount            = 5000;
    static constexpr int DiscreteInputCount   = 10000;

    // Singleton access method
    static ModbusDataStore& instance();

    ModbusDataStore(const ModbusDataStore&) = delete;
    ModbusDataStore& operator=(const ModbusDataStore&) = delete;

    // Holding registers
    QVector<quint16> holdingRegisters() const;
    Q_INVOKABLE void setHoldingRegister(int address, int value);
    Q_INVOKABLE int getHoldingRegister(int address) const;

    // Input registers
    QVector<quint16> inputRegisters() const;
    Q_INVOKABLE void setInputRegister(int address, int value);
    Q_INVOKABLE int getInputRegister(int address) const;

    // Coils / discrete inputs
    QBitArray coils() const;
    QBitArray discreteInputs() const;
    Q_INVOKABLE bool getCoil(int address) const;
    Q_INVOKABLE void setCoil(int address, bool value);
    Q_INVOKABLE bool getDiscreteInput(int address) const;
    Q_INVOKABLE void setDiscreteInput(int address, bool value);

    // Bit manipulation inside a 16-bit register.
    // registerType uses QModbusDataUnit::RegisterType numeric values
    // (3 = InputRegisters, 4 = HoldingRegisters) so it can be called from QML.
    Q_INVOKABLE bool getBit(int address, int bitPosition, int registerType = QModbusDataUnit::HoldingRegisters) const;
    Q_INVOKABLE void setBit(int address, int bitPosition, bool value, int registerType = QModbusDataUnit::HoldingRegisters);

    // Reset every table back to its initial state
    Q_INVOKABLE void resetAll();

    // Project file (de)serialization: sparse representation, only
    // non-zero registers and set bits are stored
    QJsonObject dataToJson() const;
    void dataFromJson(const QJsonObject& data);

signals:
    // Emitted for every single-value modification: table is a
    // QModbusDataUnit::RegisterType numeric value.
    void valueChanged(int table, int address, int value);

    // Coarse-grained notification used by QML views to re-evaluate bindings
    void dataChanged();

    // Emitted after bulk operations (reset); the server re-syncs everything
    void bulkChanged();

private:
    explicit ModbusDataStore(QObject* parent = nullptr);
    ~ModbusDataStore() override;

    void initializeDefaults();

    QVector<quint16> m_holdingRegisters;
    QVector<quint16> m_inputRegisters;
    QBitArray m_coils;
    QBitArray m_discreteInputs;
};

#endif // MODBUSDATASTORE_H
