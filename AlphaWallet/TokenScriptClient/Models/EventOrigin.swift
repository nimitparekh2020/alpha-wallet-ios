// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import Kanna

//hhh this represents an event "instance", i.e with values
//hhhh name is not so good? But clash with Event in Event.swift
//hhh remove since we have it in Realm
//hhh move or not?
struct EventInstance_Old {
    //hhh do we need to store as original Solidity types? What is the type of Value? If AssetInternalValue, means we need to convert them from solidity types when we create these instances
    //hhh private
    var data: [String: AssetInternalValue] = .init()
}

struct EventOrigin {
    //hhh should have event name, filter, select, etc
    //hhh "as" comes from the "select"? So do we need to store it? I think so. It's not going to change unless the XML content changes
    //private let asType: OriginAsType

    let originElement: XMLElement
    let xmlContext: XmlContext
    let contract: AlphaWallet.Address
    let eventName: String
    let parameters: [(name: String, type: String, isIndexed: Bool)]
    let eventParameterName: String
    let eventFilter: (name: String, value: String)

    //hhh need asType: OriginAsType? We don't have it?
    //hhh should have as much information as args as possible. We don't use originElement in this type
    init(originElement: XMLElement, xmlContext: XmlContext, contract: AlphaWallet.Address, eventName: String, eventParameters: [(name: String, type: String, isIndexed: Bool)], eventParameterName: String, eventFilter: (name: String, value: String)) {
        self.originElement = originElement
        self.xmlContext = xmlContext
        self.contract = contract
        self.eventName = eventName
        self.parameters = eventParameters
        self.eventParameterName = eventParameterName
        self.eventFilter = eventFilter
    }

    //hhh this is probably used (and still has to changed) *after* we already get the event
    //hhh extract based on the "select" attribute. So we must be able to access the event (must store that event with the token ID, or be able to get it from the list of events). Is the latter slow?
    //hhhh event has to be changed to be a special type. An ordered dictionary of some sort? Maybe just an array of pairs
    func extractValue(fromEvent event: EventInstance) -> AssetInternalValue? {
        //hhh do we need asType in the schema?
        //hhh extract like TokenIdOrigin did
        //hhh do we need as="", or we can use the one in <asnx:module>?
        //hhh will not ever be subscribable, right? Always resolved already
        return event.data[eventParameterName]
    }

    //hhhh this is the one that is called by listener for event
    //func foo() {
    //}
}
