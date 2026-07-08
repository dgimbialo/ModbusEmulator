// ModbusDataStore.cpp
#include "ModbusDataStore.h"
#include <QDebug>
#include <QJsonArray>
#include <QJsonObject>

// Singleton instance method
ModbusDataStore& ModbusDataStore::instance()
{
    static ModbusDataStore instance;
    return instance;
}

ModbusDataStore::ModbusDataStore(QObject* parent)
    : QObject(parent)
{
    m_holdingRegisters.resize(HoldingRegisterCount);
    m_inputRegisters.resize(InputRegisterCount);
    m_coils.resize(CoilCount);
    m_discreteInputs.resize(DiscreteInputCount);

    initializeDefaults();
}

ModbusDataStore::~ModbusDataStore() = default;

void ModbusDataStore::initializeDefaults()
{
    m_holdingRegisters.fill(0);
    m_inputRegisters.fill(0);
    m_coils.fill(false);
    m_discreteInputs.fill(false);

    // Domain default: "disable turn off computer" flag - register 20004, bit 14
    m_holdingRegisters[20004] |= (1 << 14);
}

QVector<quint16> ModbusDataStore::holdingRegisters() const
{
    return m_holdingRegisters;
}

void ModbusDataStore::setHoldingRegister(int address, int value)
{
    if (address < 0 || address >= m_holdingRegisters.size())
        return;

    const quint16 v = static_cast<quint16>(qBound(0, value, 65535));
    if (m_holdingRegisters[address] == v)
        return;

    m_holdingRegisters[address] = v;
    emit valueChanged(QModbusDataUnit::HoldingRegisters, address, v);
    emit dataChanged();
}

int ModbusDataStore::getHoldingRegister(int address) const
{
    if (address >= 0 && address < m_holdingRegisters.size())
        return m_holdingRegisters[address];
    return 0;
}

QVector<quint16> ModbusDataStore::inputRegisters() const
{
    return m_inputRegisters;
}

void ModbusDataStore::setInputRegister(int address, int value)
{
    if (address < 0 || address >= m_inputRegisters.size())
        return;

    const quint16 v = static_cast<quint16>(qBound(0, value, 65535));
    if (m_inputRegisters[address] == v)
        return;

    m_inputRegisters[address] = v;
    emit valueChanged(QModbusDataUnit::InputRegisters, address, v);
    emit dataChanged();
}

int ModbusDataStore::getInputRegister(int address) const
{
    if (address >= 0 && address < m_inputRegisters.size())
        return m_inputRegisters[address];
    return 0;
}

QBitArray ModbusDataStore::coils() const
{
    return m_coils;
}

QBitArray ModbusDataStore::discreteInputs() const
{
    return m_discreteInputs;
}

bool ModbusDataStore::getCoil(int address) const
{
    if (address >= 0 && address < m_coils.size())
        return m_coils.testBit(address);
    return false;
}

void ModbusDataStore::setCoil(int address, bool value)
{
    if (address < 0 || address >= m_coils.size())
        return;
    if (m_coils.testBit(address) == value)
        return;

    m_coils.setBit(address, value);
    emit valueChanged(QModbusDataUnit::Coils, address, value ? 1 : 0);
    emit dataChanged();
}

bool ModbusDataStore::getDiscreteInput(int address) const
{
    if (address >= 0 && address < m_discreteInputs.size())
        return m_discreteInputs.testBit(address);
    return false;
}

void ModbusDataStore::setDiscreteInput(int address, bool value)
{
    if (address < 0 || address >= m_discreteInputs.size())
        return;
    if (m_discreteInputs.testBit(address) == value)
        return;

    m_discreteInputs.setBit(address, value);
    emit valueChanged(QModbusDataUnit::DiscreteInputs, address, value ? 1 : 0);
    emit dataChanged();
}

bool ModbusDataStore::getBit(int address, int bitPosition, int registerType) const
{
    if (bitPosition < 0 || bitPosition > 15) {
        qWarning() << "Bit position out of range (0-15):" << bitPosition;
        return false;
    }

    switch (registerType) {
    case QModbusDataUnit::InputRegisters:
        return (getInputRegister(address) & (1 << bitPosition)) != 0;
    case QModbusDataUnit::HoldingRegisters:
    default:
        return (getHoldingRegister(address) & (1 << bitPosition)) != 0;
    }
}

void ModbusDataStore::setBit(int address, int bitPosition, bool value, int registerType)
{
    if (bitPosition < 0 || bitPosition > 15) {
        qWarning() << "Bit position out of range (0-15):" << bitPosition;
        return;
    }

    const auto apply = [&](int current) {
        return value ? (current | (1 << bitPosition))
                     : (current & ~(1 << bitPosition));
    };

    switch (registerType) {
    case QModbusDataUnit::InputRegisters:
        setInputRegister(address, apply(getInputRegister(address)));
        break;
    case QModbusDataUnit::HoldingRegisters:
    default:
        setHoldingRegister(address, apply(getHoldingRegister(address)));
        break;
    }
}

void ModbusDataStore::resetAll()
{
    initializeDefaults();
    qInfo() << "Data store reset to defaults";
    emit bulkChanged();
    emit dataChanged();
}

QJsonObject ModbusDataStore::dataToJson() const
{
    const auto registersToJson = [](const QVector<quint16>& regs) {
        QJsonObject obj;
        for (int i = 0; i < regs.size(); ++i) {
            if (regs[i] != 0)
                obj[QString::number(i)] = regs[i];
        }
        return obj;
    };

    const auto bitsToJson = [](const QBitArray& bits) {
        QJsonArray arr;
        for (int i = 0; i < bits.size(); ++i) {
            if (bits.testBit(i))
                arr.append(i);
        }
        return arr;
    };

    QJsonObject data;
    data[QStringLiteral("holdingRegisters")] = registersToJson(m_holdingRegisters);
    data[QStringLiteral("inputRegisters")] = registersToJson(m_inputRegisters);
    data[QStringLiteral("coils")] = bitsToJson(m_coils);
    data[QStringLiteral("discreteInputs")] = bitsToJson(m_discreteInputs);
    return data;
}

void ModbusDataStore::dataFromJson(const QJsonObject& data)
{
    const auto registersFromJson = [](const QJsonObject& obj, QVector<quint16>& regs) {
        regs.fill(0);
        for (auto it = obj.constBegin(); it != obj.constEnd(); ++it) {
            bool ok = false;
            const int address = it.key().toInt(&ok);
            if (ok && address >= 0 && address < regs.size())
                regs[address] = static_cast<quint16>(qBound(0, it.value().toInt(), 65535));
        }
    };

    const auto bitsFromJson = [](const QJsonArray& arr, QBitArray& bits) {
        bits.fill(false);
        for (const auto& v : arr) {
            const int address = v.toInt(-1);
            if (address >= 0 && address < bits.size())
                bits.setBit(address, true);
        }
    };

    registersFromJson(data.value(QStringLiteral("holdingRegisters")).toObject(), m_holdingRegisters);
    registersFromJson(data.value(QStringLiteral("inputRegisters")).toObject(), m_inputRegisters);
    bitsFromJson(data.value(QStringLiteral("coils")).toArray(), m_coils);
    bitsFromJson(data.value(QStringLiteral("discreteInputs")).toArray(), m_discreteInputs);

    emit bulkChanged();
    emit dataChanged();
}
