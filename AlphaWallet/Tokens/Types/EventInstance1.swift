// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import RealmSwift

//hhh rename to replace
class EventInstance1: Object {
    static func generatePrimaryKey(fromContract contract: AlphaWallet.Address, server: RPCServer, eventName: String, blockNumber: Int, logIndex: Int) -> String {
        "\(contract.eip55String)-\(server.chainID)-\(eventName)-\(blockNumber)-\(logIndex)"
    }

    @objc dynamic var primaryKey: String = ""
    @objc dynamic var contract: String = Constants.nullAddress.eip55String
    @objc dynamic var chainId: Int = 0
    @objc dynamic var eventName: String = ""
    @objc dynamic var blockNumber: Int = 0
    @objc dynamic var logIndex: Int = 0
    @objc dynamic var json: String = "{}"

    convenience init(contract: AlphaWallet.Address = Constants.nullAddress, server: RPCServer, eventName: String, blockNumber: Int, logIndex: Int, json: String) {
        self.init()
        self.primaryKey = EventInstance1.generatePrimaryKey(fromContract: contract, server: server, eventName: eventName, blockNumber: blockNumber, logIndex: logIndex)
        self.contract = contract.eip55String
        self.chainId = server.chainID
        self.eventName = eventName
        self.blockNumber = blockNumber
        self.logIndex = logIndex
        //hhhhhhhhh probably have to convert to the correct types, somewhere, before storing
        self.json = json
    }

    override static func primaryKey() -> String? {
        return "primaryKey"
    }
}
