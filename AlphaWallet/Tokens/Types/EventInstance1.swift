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
    @objc dynamic var json: String = "{}"

    //hhh2 implement
    //hhhhhhhhhh implement this. parse JSON and cache. Will not be outdated, since the event instance is immutable
    //hhh maybe rename to "parameters" instead of data
    var data: [String: AssetInternalValue] = .init()

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
    }

    override static func primaryKey() -> String? {
        return "primaryKey"
    }

    //hhh keep? Do we have `data`?
    override static func ignoredProperties() -> [String] {
        return ["data"]
    }
}
