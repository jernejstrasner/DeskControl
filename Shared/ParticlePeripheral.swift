import CoreBluetooth

public struct DeskServices {
    static public let control = CBUUID(string: "99FA0001-338A-1024-8A49-009C0215F78A")
    static public let controlCharacteristic = CBUUID(string: "99FA0002-338A-1024-8A49-009C0215F78A")
    static public let controlCharacteristicError = CBUUID(string: "99FA0003-338A-1024-8A49-009C0215F78A")
    static public let referenceOutput = CBUUID(string: "99FA0020-338A-1024-8A49-009C0215F78A")
    static public let referenceOutputCharacteristicPosition = CBUUID(string: "99FA0021-338A-1024-8A49-009C0215F78A")
    static public let referenceOutputCharacteristicManufacturer = CBUUID(string: "00002A29-0000-1000-8000-00805F9B34FB")
    static public let referenceOutputCharacteristicUnknown = CBUUID(string: "99FA002A-338A-1024-8A49-009C0215F78A")
    
    // Empirically determined values matching the Linak protocol
    static public let baseHeight = 6000 // 1/10th mm (620mm lowest desk position)
    static public let maxRange = 6500 // 1/10th mm (650mm travel range)
    
    static public let valueMoveUp = pack("<H", [71, 0])
    static public let valueMoveDown = pack("<H", [70, 0])
    static public let valueWakeUp = pack("<H", [254, 0])
    static public let valueStopMove = pack("<H", [255, 0])
    
    static func characteristicsForService(id: CBUUID) -> [CBUUID] {
        switch id {
        case Self.control:
            return [Self.controlCharacteristic, Self.controlCharacteristicError]
        case Self.referenceOutput:
            return [Self.referenceOutputCharacteristicPosition, Self.referenceOutputCharacteristicManufacturer, Self.referenceOutputCharacteristicUnknown]
        default:
            return []
        }
    }
}
