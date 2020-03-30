// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import RealmSwift

//hhh remove `Event`, and rename this. Watch out. It's realm. Have to delete app!
class EventInstance: Object {
    static func generatePrimaryKey(fromContract contract: AlphaWallet.Address, server: RPCServer, eventName: String, blockNumber: Int, logIndex: Int, filter: String) -> String {
        "\(contract.eip55String)-\(server.chainID)-\(eventName)-\(blockNumber)-\(logIndex)-\(filter)"
    }

    @objc dynamic var primaryKey: String = ""
    @objc dynamic var contract: String = Constants.nullAddress.eip55String
    @objc dynamic var chainId: Int = 0
    @objc dynamic var eventName: String = ""
    @objc dynamic var blockNumber: Int = 0
    @objc dynamic var logIndex: Int = 0
    @objc dynamic var filter: String = ""
    @objc dynamic var json: String = "{}" {
        didSet {
            _data = EventInstance.convertJsonToDictionary(json)
        }
    }

    //hhh maybe rename to "parameters" instead of data
    //hhh this is needed because Realm objects' properties (`json`) don't fire didSet after the object has been written to the database
    var _data: [String: AssetInternalValue]?
    //hhh maybe rename to "parameters" instead of data
    var data: [String: AssetInternalValue] {
        if let _data = _data {
            return _data
        } else {
            let value = EventInstance.convertJsonToDictionary(json)
            _data = value
            return value
        }
    }

    convenience init(contract: AlphaWallet.Address = Constants.nullAddress, server: RPCServer, eventName: String, blockNumber: Int, logIndex: Int, filter: String, json: String) {
        self.init()
        self.primaryKey = EventInstance.generatePrimaryKey(fromContract: contract, server: server, eventName: eventName, blockNumber: blockNumber, logIndex: logIndex, filter: filter)
        self.contract = contract.eip55String
        self.chainId = server.chainID
        self.eventName = eventName
        self.blockNumber = blockNumber
        self.logIndex = logIndex
        self.filter = filter
        //hhhhhhhhh probably have to convert to the correct types, somewhere, before storing
        self.json = json
        self._data = EventInstance.convertJsonToDictionary(json)
    }

    override static func primaryKey() -> String? {
        return "primaryKey"
    }

    //hhh keep? Do we have `data`?
    override static func ignoredProperties() -> [String] {
        return ["_data", "data"]
    }

    //hhh rename
    private static func convertJsonToDictionary(_ json: String) -> [String: AssetInternalValue] {
        //hhh is this called when reading from database? Otherwise data isn't set into and we'll always have to make it computed and cache ourselves in `_data`
        //hhh2 need to convert keys to AssetInternalValue
        let dict = json.data(using: .utf8).flatMap({ (try? JSONSerialization.jsonObject(with: $0, options: [])) as? [String: Any] }) ?? .init()
        for (key, value) in dict {
            NSLog("xxx \(key) = \(value) type: \(type(of: value))")
        }

        return Dictionary(uniqueKeysWithValues: dict.compactMap { key, value -> (String, AssetInternalValue)? in
            switch value {
            case let string as String:
                return (key, .string(string))
            case let number as NSNumber:
                //hhh2 convert to BigInt or BigUInt maybe? Might be floating point also
                return (key, .string(String(describing: number)))
            default:
                //hhh2 good or not? Maybe drop this key-value pair instead?
                //return (key, .string(String(value)))
                return nil
            }
        })
    }
}
