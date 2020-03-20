// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import BigInt
import Kanna

//Origin's output type
enum OriginAsType: String {
    case address
    case uint
    case utf8
    case e18
    case e8
    case e4
    case e2
    case bytes
    case bool
    case void

    var solidityReturnType: SolidityType {
        switch self {
        case .address:
            return .address
        case .uint:
            return .uint256
        case .utf8:
            return .string
        case .e18, .e8, .e4, .e2:
            return .uint256
        case .bytes:
            return .bytes
        case .bool:
            return .bool
        case .void:
            return .void
        }
    }
}

enum Origin {
    //hhh add `.event`? How about storage? Maybe storage of the attribute is separate and already handled like other attributes. But we have to capture attributes that are `Origin.event` and watch for those using the filter? And when the events fire (we add a new token ID or lose a token ID), so have to store the entire list of events locally. Also handle when we get the historical event list the first time and everytime app launch/resumes (to catch up)
    case tokenId(TokenIdOrigin)
    case function(FunctionOrigin)
    case userEntry(UserEntryOrigin)
    case event(EventOrigin)

    private var originElement: XMLElement {
        switch self {
        case .tokenId(let origin):
            return origin.originElement
        case .function(let origin):
            return origin.originElement
        case .userEntry(let origin):
            return origin.originElement
        case .event(let origin):
            return origin.originElement
        }
    }
    private var xmlContext: XmlContext {
        switch self {
        case .tokenId(let origin):
            return origin.xmlContext
        case .function(let origin):
            return origin.xmlContext
        case .userEntry(let origin):
            return origin.xmlContext
        case .event(let origin):
            return origin.xmlContext
        }
    }
    var userEntryId: AttributeId? {
        switch self {
        case .tokenId, .function, .event:
            return nil
        case .userEntry(let origin):
            return origin.attributeId
        }
    }
    var isImmediatelyAvailable: Bool {
        switch self {
        case .tokenId, .userEntry, .event:
            return true
        case .function:
            return false
        }
    }

    init?(forTokenIdElement tokenIdElement: XMLElement, xmlContext: XmlContext) {
        let bitmask = XMLHandler.getBitMask(fromTokenIdElement: tokenIdElement) ?? TokenScript.defaultBitmask
        guard let asType = tokenIdElement["as"].flatMap({ OriginAsType(rawValue: $0) }) else { return nil }
        let bitShift = Origin.bitShiftCount(forBitMask: bitmask)
        self = .tokenId(.init(originElement: tokenIdElement, xmlContext: xmlContext, bitmask: bitmask, bitShift: bitShift, asType: asType))
    }

    init?(forEthereumFunctionElement ethereumFunctionElement: XMLElement, attributeId: AttributeId, originContract: AlphaWallet.Address, xmlContext: XmlContext) {
        let bitmask = XMLHandler.getBitMask(fromTokenIdElement: ethereumFunctionElement) ?? TokenScript.defaultBitmask
        let bitShift = Origin.bitShiftCount(forBitMask: bitmask)
        guard let result = FunctionOrigin(forEthereumFunctionCallElement: ethereumFunctionElement, attributeId: attributeId, originContract: originContract, xmlContext: xmlContext, bitmask: bitmask, bitShift: bitShift) else { return nil }
        self = .function(result)
    }

    init?(forUserEntryElement userEntryElement: XMLElement, attributeId: AttributeId, xmlContext: XmlContext) {
        let bitmask = XMLHandler.getBitMask(fromTokenIdElement: userEntryElement) ?? TokenScript.defaultBitmask
        let bitShift = Origin.bitShiftCount(forBitMask: bitmask)
        guard let asType = userEntryElement["as"].flatMap({ OriginAsType(rawValue: $0) }) else { return nil }
        self = .userEntry(.init(originElement: userEntryElement, xmlContext: xmlContext, attributeId: attributeId, asType: asType, bitmask: bitmask, bitShift: bitShift))
    }

    init?(forEthereumEventElement eventElement: XMLElement, sourceContractElement: XMLElement, xmlContext: XmlContext) {
        //hhh should check filter and select matches what is available in sourceContractElement
        //hhh need asType?
        //guard let asType = eventElement["as"].flatMap({ OriginAsType(rawValue: $0) }) else { return nil }
        //hhh populate. Maybe the entire event structure definition which is from another part of the XML file? too not needed?
        guard let eventParameterName = XMLHandler.getEventParameterName(fromEthereumEventElement: eventElement) else { return nil }
        guard let eventFilter = XMLHandler.getEventFilter(fromEthereumEventElement: eventElement) else { return nil }
        //hhh remove explicit type
        guard let definition: (contract: AlphaWallet.Address, name: String, parameters: [(name: String, type: String, isIndexed: Bool)]) = XMLHandler.getEventDefinition(fromContractElement: sourceContractElement, xmlContext: xmlContext) else { return nil }
        self = .event(.init(originElement: eventElement, xmlContext: xmlContext, contract: definition.contract, eventName: definition.name, eventParameters: definition.parameters, eventParameterName: eventParameterName, eventFilter: eventFilter))
    }

    ///Used to truncate bits to the right of the bitmask
    private static func bitShiftCount(forBitMask bitmask: BigUInt) -> Int {
        var count = 0
        repeat {
            count += 1
        } while bitmask % (1 << count) == 0
        return count - 1
    }

    //hhh make event: non-default (but still optional) and fix callers
    //hhhhhh caller has to know which event (instances) to pass in. Including using `filter` and `event` to check
    func extractValue(fromTokenId tokenId: TokenId, inWallet account: Wallet, server: RPCServer, callForAssetAttributeCoordinator: CallForAssetAttributeCoordinator, event: EventInstance? = nil, userEntryValues: [AttributeId: String], tokenLevelNonSubscribableAttributesAndValues: [AttributeId: AssetInternalValue]) -> AssetInternalValue? {
        switch self {
        case .tokenId(let origin):
            return origin.extractValue(fromTokenId: tokenId)
        case .function(let origin):
            //We don't pass in attributes with function-origins because the order is undefined at the moment
            return origin.extractValue(withTokenId: tokenId, account: account, server: server, attributeAndValues: tokenLevelNonSubscribableAttributesAndValues, callForAssetAttributeCoordinator: callForAssetAttributeCoordinator)
        case .userEntry(let origin):
            guard let input = userEntryValues[origin.attributeId] else { return nil }
            return origin.extractValue(fromUserEntry: input)
        case .event(let origin):
            if let event = event {
                return origin.extractValue(fromEvent: event)
            } else {
                return nil
            }
        }
    }

    func extractMapping() -> AssetAttributeMapping? {
        guard let element = XMLHandler.getMappingElement(fromOriginElement: originElement, xmlContext: xmlContext) else { return nil }
        return .init(mapping: element, xmlContext: xmlContext)
    }
}
