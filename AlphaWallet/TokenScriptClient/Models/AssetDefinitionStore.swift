// Copyright © 2018 Stormbird PTE. LTD.

import Alamofire
//hhh remove or not?
import PromiseKit
//hhh good sign we need to move the event sourcer code out of this class
import web3swift
//hhh remove?
import BigInt

protocol AssetDefinitionStoreDelegate: class {
    func listOfBadTokenScriptFilesChanged(in: AssetDefinitionStore )
}

/// Manage access to and cache asset definition XML files
class AssetDefinitionStore {
    enum Result {
        case cached
        case updated
        case unmodified
        case error
    }

    private var httpHeaders: HTTPHeaders = {
        guard let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else { return [:] }
        return [
            "Accept": "application/tokenscript+xml; charset=UTF-8",
            "X-Client-Name": TokenScript.repoClientName,
            "X-Client-Version": appVersion,
            "X-Platform-Name": TokenScript.repoPlatformName,
            "X-Platform-Version": UIDevice.current.systemVersion
        ]
    }()
    private var lastModifiedDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "E, dd MMM yyyy HH:mm:ss z"
        df.timeZone = TimeZone(secondsFromGMT: 0)
        return df
    }()
    private var lastContractInPasteboard: String?
    private var subscribers: [(AlphaWallet.Address) -> Void] = []
    private var backingStore: AssetDefinitionBackingStore

    lazy var assetAttributesCache: AssetAttributesCache = AssetAttributesCache(assetDefinitionStore: self)
    weak var delegate: AssetDefinitionStoreDelegate?
    var listOfBadTokenScriptFiles: [TokenScriptFileIndices.FileName] {
        return backingStore.badTokenScriptFileNames
    }
    var conflictingTokenScriptFileNames: (official: [TokenScriptFileIndices.FileName], overrides: [TokenScriptFileIndices.FileName], all: [TokenScriptFileIndices.FileName]) {
        return backingStore.conflictingTokenScriptFileNames
    }

    var contractsWithTokenScriptFileFromOfficialRepo: [AlphaWallet.Address] {
        return backingStore.contractsWithTokenScriptFileFromOfficialRepo
    }

    //TODO move
    static var standardTokenScriptStyles: String {
        return """
               <style type="text/css">
               @font-face {
               font-family: 'SourceSansPro';
               src: url('\(Constants.tokenScriptUrlSchemeForResources)SourceSansPro-Light.otf') format('opentype');
               font-weight: lighter;
               }
               @font-face {
               font-family: 'SourceSansPro';
               src: url('\(Constants.tokenScriptUrlSchemeForResources)SourceSansPro-Regular.otf') format('opentype');
               font-weight: normal;
               }
               @font-face {
               font-family: 'SourceSansPro';
               src: url('\(Constants.tokenScriptUrlSchemeForResources)SourceSansPro-Semibold.otf') format('opentype');
               font-weight: bolder;
               }
               @font-face {
               font-family: 'SourceSansPro';
               src: url('\(Constants.tokenScriptUrlSchemeForResources)SourceSansPro-Bold.otf') format('opentype');
               font-weight: bold;
               }
               .token-card {
               padding: 0pt;
               margin: 0pt;
               }
               </style>
               """
    }

    init(backingStore: AssetDefinitionBackingStore = AssetDefinitionDiskBackingStoreWithOverrides()) {
        self.backingStore = backingStore
        self.backingStore.delegate = self
    }
    //hhh remove
    func foo() {
        //hhh loop through all and see which has attributes with events and pull events. Only the changed ones!
        //hhh hardcode to just 1 contract here first. Have to do it per file/contract anyway. Need to know RPCServer
        let contract = AlphaWallet.Address(string: "0x57f1887a8BF19b14fC0dF6Fd9B2acc9Af147eA85")!
        let xmlHandler = XMLHandler(contract: contract, assetDefinitionStore: self)

        //hhh2
        //let eventSource = EventSource()
        //eventSource.foo(xmlHandler: xmlHandler)


        //hhh can there be more than 1 event? We can now since it's based on TokenId, but will break later or not?
        if xmlHandler.attributesWithEventSource.isEmpty {
            NSLog("xxx handler. No event-based attribute")
            //hhh no-op?
        } else {
            for each in xmlHandler.attributesWithEventSource {
                if let eventOrigin = each.eventOrigin {
                    //hhh need to sub tokenId?
                    let (filterName, filterValue) = eventOrigin.eventFilter

                    //hhh2 tokenId. So can only request when we see the values... i.e. when user tap?! Or actually we just do it when OpenSea or whoever refreshes and get a bunch of TokenId(s), for now?
                    //hhh2 form filter list. We assume all are indexed here, for now (and hardcoded label to index index=0)
                    //hhh2 need to delete all for the TokenScript file if full refresh (because file has changed)
                    //hhh change to var once TokenScript schema supports specifying if the field is indexed
                    let filterParam: [[EventFilterable]?] = eventOrigin.parameters
                            .filter { $0.isIndexed }
                            .map { each in
                        if each.name == filterName {
                            //hhh2 need tokenId and need to substitute them in `filterValue`!
                            //hhh replace each with $0 is readable
                            //hhh2 need to use each.type to generate the filter correctly?
                            //hhh2 for tokenId, when we substitude it in, is it a dec or hex string?
                            //hhh rename
                            if let parameterType = SolidityType(rawValue: each.type) {
                                let filterValueX: AssetAttributeValueUsableAsFunctionArguments?
                                //hhh2 support all the implicit types? Only tokenId and ownerAddress for now?
                                switch filterValue {
                                case "${tokenId}":
                                    //hhhhhhh2 hardcoded ID! Need to fetch a list of tokenIds from database and loop? Then in each promise, insert into database?
                                    let tokenId: BigUInt = BigUInt("113246541015140777609414905115468849050300863255299358927480302797592829236733")
                                    filterValueX = AssetAttributeValueUsableAsFunctionArguments(assetAttribute: .uint(tokenId))
                                default:
                                    //hhh2 still support substitution. But how to handle type conversions like tokenId?
                                    filterValueX = AssetAttributeValueUsableAsFunctionArguments(assetAttribute: .string(filterValue))
                                }
                                guard let filterValueY = filterValueX else { return nil }
                                //hhhhhhh2 Should only end up with a few types? specifically BigUInt, BigInt, Data, String, EthereumAddress. So must be mapped to those. Switch by solidity types?
                                //hhh we have to "cast" it to Data, etc which can then be cast to EventFilterable here. So have to handle this first
                                //hhh rename
                                let filterValue2 = filterValueY.coerce(toArgumentType: parameterType, forFunctionType: .eventFiltering) as? Data
                                NSLog("xxx filterValue2 coerced: \(filterValue2)")
                                //hhh2 clean up
                                if filterValue2 == nil {
                                    return nil
                                } else {
                                    //hhh2 good to return?
                                    let filterValue3 = filterValue2 as? EventFilterable
                                    NSLog("xxx filterValue3 coerced: \(filterValue3)")
                                    if filterValue3 != nil {
                                        //hhh forced unwrap
                                        return [filterValue3!]
                                    } else {
                                        return nil
                                    }
                                }
                            } else {
                                return nil
                            }
                        } else {
                            return nil
                        }
                    }
                    NSLog("xxx filterParam: \(filterParam)")

                    //hhh override
                    let filterParam_old = [(nil as [EventFilterable]?), ([EthereumAddress("0xbbce83173d5c1D122AE64856b4Af0D5AE07Fa362")!] as [EventFilterable])]
                    let eventFilter = EventFilter(fromBlock: .blockNumber(0), toBlock: .latest, addresses: [EthereumAddress(address: eventOrigin.contract)], parameterFilters: filterParam)
                    let server = RPCServer(chainID: 1)


                    //hhh also need to check which blocks to "resume"? cannot resume if when XML changed. Only for regular refreshes or when token is tapped (is it too late?)

                    NSLog("xxx handler. event-based attribute: \(each)")
                    //contract (for event)
                    //event name
                    //filter (key and value) - but that means we have to purge all the events for a TokenScript when the TokenScript file changes? because we don't know which events to delete selectively?

                    //hhh need to move out? This is for-each for attribute, or ok?
                    firstly {
                        getEventLogs(withServer: server, contract: eventOrigin.contract, eventName: eventOrigin.eventName, filter: eventFilter)
                    }.done { result in
                        NSLog("xxx events count: \(result.count)")
                        for each in result {
                            print(each)
                        }
                        //TODO make this consistent like this address has exactly one nameregistered from block a to block b
                        //if !result.description.contains("rejected") {
                        //}
                    }.catch { error in
                        NSLog("xxx error with event promise: \(error)")
                    }
                } else {
                    //hhh wrong?
                    NSLog("xxx handler. Has event-based attribute, but no event origin!")
                }
            }
        }
    }
    //hhh remove
    func bar2() {
        //let filterParam = [(nil as [EventFilterable]?), ([EthereumAddress("0xf8bf2546b61a4b7a277d118290dc9dcbb34d29a6")!] as [EventFilterable])]
        let filterParam = [(nil as [EventFilterable]?), ([EthereumAddress("0xbbce83173d5c1D122AE64856b4Af0D5AE07Fa362")!] as [EventFilterable])]
        let eventFilter = EventFilter(fromBlock: .blockNumber(0), toBlock: .latest, addresses: [EthereumAddress("0xF0AD5cAd05e10572EfcEB849f6Ff0c68f9700455")!], parameterFilters: filterParam)
        let getEventsPromise = getEventLogsOld(
                withServer: RPCServer(chainID: 1),
                contract: AlphaWallet.Address(string: "0xF0AD5cAd05e10572EfcEB849f6Ff0c68f9700455")!,
                eventName: "NameRegistered",
                // swiftlint:disable:next line_length
                abiString: "[{\"constant\":true,\"inputs\":[{\"name\":\"interfaceID\",\"type\":\"bytes4\"}],\"name\":\"supportsInterface\",\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"stateMutability\":\"pure\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[],\"name\":\"withdraw\",\"outputs\":[],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_prices\",\"type\":\"address\"}],\"name\":\"setPriceOracle\",\"outputs\":[],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[],\"name\":\"renounceOwnership\",\"outputs\":[],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_minCommitmentAge\",\"type\":\"uint256\"},{\"name\":\"_maxCommitmentAge\",\"type\":\"uint256\"}],\"name\":\"setCommitmentAges\",\"outputs\":[],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"\",\"type\":\"bytes32\"}],\"name\":\"commitments\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"name\",\"type\":\"string\"},{\"name\":\"duration\",\"type\":\"uint256\"}],\"name\":\"rentPrice\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"name\",\"type\":\"string\"},{\"name\":\"owner\",\"type\":\"address\"},{\"name\":\"duration\",\"type\":\"uint256\"},{\"name\":\"secret\",\"type\":\"bytes32\"}],\"name\":\"register\",\"outputs\":[],\"payable\":true,\"stateMutability\":\"payable\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"MIN_REGISTRATION_DURATION\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"minCommitmentAge\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"owner\",\"outputs\":[{\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"isOwner\",\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"name\",\"type\":\"string\"}],\"name\":\"valid\",\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"name\",\"type\":\"string\"},{\"name\":\"duration\",\"type\":\"uint256\"}],\"name\":\"renew\",\"outputs\":[],\"payable\":true,\"stateMutability\":\"payable\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"name\",\"type\":\"string\"}],\"name\":\"available\",\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"maxCommitmentAge\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"commitment\",\"type\":\"bytes32\"}],\"name\":\"commit\",\"outputs\":[],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"transferOwnership\",\"outputs\":[],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"name\",\"type\":\"string\"},{\"name\":\"owner\",\"type\":\"address\"},{\"name\":\"secret\",\"type\":\"bytes32\"}],\"name\":\"makeCommitment\",\"outputs\":[{\"name\":\"\",\"type\":\"bytes32\"}],\"payable\":false,\"stateMutability\":\"pure\",\"type\":\"function\"},{\"inputs\":[{\"name\":\"_base\",\"type\":\"address\"},{\"name\":\"_prices\",\"type\":\"address\"},{\"name\":\"_minCommitmentAge\",\"type\":\"uint256\"},{\"name\":\"_maxCommitmentAge\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"constructor\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"name\":\"name\",\"type\":\"string\"},{\"indexed\":true,\"name\":\"label\",\"type\":\"bytes32\"},{\"indexed\":true,\"name\":\"owner\",\"type\":\"address\"},{\"indexed\":false,\"name\":\"cost\",\"type\":\"uint256\"},{\"indexed\":false,\"name\":\"expires\",\"type\":\"uint256\"}],\"name\":\"NameRegistered\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"name\":\"name\",\"type\":\"string\"},{\"indexed\":true,\"name\":\"label\",\"type\":\"bytes32\"},{\"indexed\":false,\"name\":\"cost\",\"type\":\"uint256\"},{\"indexed\":false,\"name\":\"expires\",\"type\":\"uint256\"}],\"name\":\"NameRenewed\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"name\":\"oracle\",\"type\":\"address\"}],\"name\":\"NewPriceOracle\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"name\":\"previousOwner\",\"type\":\"address\"},{\"indexed\":true,\"name\":\"newOwner\",\"type\":\"address\"}],\"name\":\"OwnershipTransferred\",\"type\":\"event\"}]",
                filter: eventFilter
        )
        getEventsPromise.done { result in
            NSLog("xxx events count: \(result.count)")
            for each in result {
                print(each)
            }
            //TODO make this consistent like this address has exactly one nameregistered from block a to block b
            //if !result.description.contains("rejected") {
            //}
        }
    }

    func hasConflict(forContract contract: AlphaWallet.Address) -> Bool {
        return backingStore.hasConflictingFile(forContract: contract)
    }

    func hasOutdatedTokenScript(forContract contract: AlphaWallet.Address) -> Bool {
        return backingStore.hasOutdatedTokenScript(forContract: contract)
    }

    func enableFetchXMLForContractInPasteboard() {
        NotificationCenter.default.addObserver(self, selector: #selector(fetchXMLForContractInPasteboard), name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    func fetchXMLs(forContracts contracts: [AlphaWallet.Address]) {
        for each in contracts {
            fetchXML(forContract: each)
        }
    }

    subscript(contract: AlphaWallet.Address) -> String? {
        get {
            return backingStore[contract]
        }
        set(xml) {
            backingStore[contract] = xml
        }
    }

    func isOfficial(contract: AlphaWallet.Address) -> Bool {
        return backingStore.isOfficial(contract: contract)
    }

    func isCanonicalized(contract: AlphaWallet.Address) -> Bool {
        return backingStore.isCanonicalized(contract: contract)
    }

    func subscribe(_ subscribe: @escaping (_ contract: AlphaWallet.Address) -> Void) {
        subscribers.append(subscribe)
    }

    /// useCacheAndFetch: when true, the completionHandler will be called immediately and a second time if an updated XML is fetched. When false, the completionHandler will only be called up fetching an updated XML
    ///
    /// IMPLEMENTATION NOTE: Current implementation will fetch the same XML multiple times if this function is called again before the previous attempt has completed. A check (which requires tracking completion handlers) hasn't been implemented because this doesn't usually happen in practice
    func fetchXML(forContract contract: AlphaWallet.Address, useCacheAndFetch: Bool = false, completionHandler: ((Result) -> Void)? = nil) {
        if useCacheAndFetch && self[contract] != nil {
            completionHandler?(.cached)
        }
        guard let url = urlToFetch(contract: contract) else { return }
        Alamofire.request(
                url,
                method: .get,
                headers: httpHeadersWithLastModifiedTimestamp(forContract: contract)
        ).response { [weak self] response in
            guard let strongSelf = self else { return }
            if response.response?.statusCode == 304 {
                completionHandler?(.unmodified)
            } else if response.response?.statusCode == 406 {
                completionHandler?(.error)
            } else if response.response?.statusCode == 404 {
                completionHandler?(.error)
            } else if response.response?.statusCode == 200 {
                if let xml = response.data.flatMap({ String(data: $0, encoding: .utf8) }).nilIfEmpty {
                    //Note that Alamofire converts the 304 to a 200 if caching is enabled (which it is, by default). So we'll never get a 304 here. Checking against Charles proxy will show that a 304 is indeed returned by the server with an empty body. So we compare the contents instead. https://github.com/Alamofire/Alamofire/issues/615
                    if xml == strongSelf[contract] {
                        completionHandler?(.unmodified)
                    } else if strongSelf.isTruncatedXML(xml: xml) {
                        strongSelf.fetchXML(forContract: contract, useCacheAndFetch: false) { result in
                            completionHandler?(result)
                        }
                    } else {
                        strongSelf[contract] = xml
                        XMLHandler.invalidate(forContract: contract)
                        completionHandler?(.updated)
                        strongSelf.triggerSubscribers(forContract: contract)
                    }
                } else {
                    completionHandler?(.error)
                }
            }
        }
    }

    private func isTruncatedXML(xml: String) -> Bool {
        //Safety check against a truncated file download
        return !xml.trimmed.hasSuffix(">")
    }

    private func triggerSubscribers(forContract contract: AlphaWallet.Address) {
        subscribers.forEach { $0(contract) }
    }

    @objc private func fetchXMLForContractInPasteboard() {
        guard let contents = UIPasteboard.general.string?.trimmed else { return }
        guard lastContractInPasteboard != contents else { return }
        guard CryptoAddressValidator.isValidAddress(contents) else { return }
        guard let address = AlphaWallet.Address(string: contents) else { return }
        defer { lastContractInPasteboard = contents }
        fetchXML(forContract: address)
    }

    private func urlToFetch(contract: AlphaWallet.Address) -> URL? {
        let name = contract.eip55String
        return URL(string: TokenScript.repoServer)?.appendingPathComponent(name)
    }

    private func lastModifiedDateOfCachedAssetDefinitionFile(forContract contract: AlphaWallet.Address) -> Date? {
        return backingStore.lastModifiedDateOfCachedAssetDefinitionFile(forContract: contract)
    }

    private func httpHeadersWithLastModifiedTimestamp(forContract contract: AlphaWallet.Address) -> HTTPHeaders {
        var result = httpHeaders
        if let lastModified = lastModifiedDateOfCachedAssetDefinitionFile(forContract: contract) {
            result["IF-Modified-Since"] = string(fromLastModifiedDate: lastModified)
            return result
        } else {
            return result
        }
    }

    func string(fromLastModifiedDate date: Date) -> String {
        return lastModifiedDateFormatter.string(from: date)
    }

    func forEachContractWithXML(_ body: (AlphaWallet.Address) -> Void) {
        backingStore.forEachContractWithXML(body)
    }

    func invalidateSignatureStatus(forContract contract: AlphaWallet.Address) {
        triggerSubscribers(forContract: contract)
    }

    func getCacheTokenScriptSignatureVerificationType(forXmlString xmlString: String) -> TokenScriptSignatureVerificationType? {
        return backingStore.getCacheTokenScriptSignatureVerificationType(forXmlString: xmlString)
    }

    func writeCacheTokenScriptSignatureVerificationType(_ verificationType: TokenScriptSignatureVerificationType, forContract contract: AlphaWallet.Address, forXmlString xmlString: String) {
        return backingStore.writeCacheTokenScriptSignatureVerificationType(verificationType, forContract: contract, forXmlString: xmlString)
    }

    func contractDeleted(_ contract: AlphaWallet.Address) {
        XMLHandler.invalidate(forContract: contract)
        backingStore.deleteFileDownloadedFromOfficialRepoFor(contract: contract)
    }
}

extension AssetDefinitionStore: AssetDefinitionBackingStoreDelegate {
    func invalidateAssetDefinition(forContract contract: AlphaWallet.Address) {
        XMLHandler.invalidate(forContract: contract)
        triggerSubscribers(forContract: contract)
        fetchXML(forContract: contract)
    }

    func badTokenScriptFilesChanged(in: AssetDefinitionBackingStore) {
        //Careful to not fire immediately because even though we are on the main thread; while we are modifying the indices, we can't read from it or there'll be a crash
        DispatchQueue.main.async {
            self.delegate?.listOfBadTokenScriptFilesChanged(in: self)
        }
    }
}

//hhh move to separate file. Needs input from Realm database. Use contract to get a list of tokenIds
class EventSource {
    //hhh do we need this?
    private let tokensStorages: ServerDictionary<TokensDataStore>
    private let assetDefinitionStore: AssetDefinitionStore

    init(tokensStorages: ServerDictionary<TokensDataStore>, assetDefinitionStore: AssetDefinitionStore) {
        self.tokensStorages = tokensStorages
        self.assetDefinitionStore = assetDefinitionStore
    }

    //hhh2
    func foo(token: TokenObject, xmlHandler: XMLHandler, account: Wallet) {
        //hhh loop through all and see which has attributes with events and pull events. Only the changed ones!
        //hhh hardcode to just 1 contract here first. Have to do it per file/contract anyway. Need to know RPCServer
        //hhh can there be more than 1 event? We can now since it's based on TokenId, but will break later or not?
        if xmlHandler.attributesWithEventSource.isEmpty {
            NSLog("xxx handler. No event-based attribute")
            //hhh no-op?
        } else {
            for each in xmlHandler.attributesWithEventSource {
                if let eventOrigin = each.eventOrigin {
                    //hhh need to sub tokenId?
                    let (filterName, filterValue) = eventOrigin.eventFilter

                    //hhh2 tokenId. So can only request when we see the values... i.e. when user tap?! Or actually we just do it when OpenSea or whoever refreshes and get a bunch of TokenId(s), for now?
                    //hhh2 form filter list. We assume all are indexed here, for now (and hardcoded label to index index=0)
                    //hhh2 need to delete all for the TokenScript file if full refresh (because file has changed)
                    //hhh change to var once TokenScript schema supports specifying if the field is indexed
                    let filterParam: [[EventFilterable]?] = eventOrigin.parameters
                            .filter { $0.isIndexed }
                            .map { each in
                                if each.name == filterName {
                                    //hhh2 need tokenId and need to substitute them in `filterValue`!
                                    //hhh replace each with $0 is readable
                                    //hhh2 need to use each.type to generate the filter correctly?
                                    //hhh2 for tokenId, when we substitude it in, is it a dec or hex string?
                                    //hhh rename
                                    if let parameterType = SolidityType(rawValue: each.type) {
                                        let filterValueX: AssetAttributeValueUsableAsFunctionArguments?
                                        //hhh2 support all the implicit types? Only tokenId and ownerAddress for now?

                                        hhhhhhhhhhhhhh2 [] because no events in the first place. Should just get from the JSON for OpenSea only. How?
                                        let tokenHolders = TokenAdaptor(token: token, assetDefinitionStore: assetDefinitionStore).getTokenHolders(forWallet: account)
                                        NSLog("xxx tokenHolders: \(tokenHolders) for token: \(token.contract) server: \(token.server)")

                                        switch filterValue {
                                        case "${tokenId}":
                                            //hhhhhhh2 hardcoded ID! Need to fetch a list of tokenIds from database and loop? Then in each promise, insert into database?
                                            let tokenId: BigUInt = BigUInt("113246541015140777609414905115468849050300863255299358927480302797592829236733")
                                            filterValueX = AssetAttributeValueUsableAsFunctionArguments(assetAttribute: .uint(tokenId))
                                        default:
                                            //hhh2 still support substitution. But how to handle type conversions like tokenId?
                                            filterValueX = AssetAttributeValueUsableAsFunctionArguments(assetAttribute: .string(filterValue))
                                        }
                                        guard let filterValueY = filterValueX else { return nil }
                                        //hhhhhhh2 Should only end up with a few types? specifically BigUInt, BigInt, Data, String, EthereumAddress. So must be mapped to those. Switch by solidity types?
                                        //hhh we have to "cast" it to Data, etc which can then be cast to EventFilterable here. So have to handle this first
                                        //hhh rename
                                        let filterValue2 = filterValueY.coerce(toArgumentType: parameterType, forFunctionType: .eventFiltering) as? Data
                                        NSLog("xxx filterValue2 coerced: \(filterValue2)")
                                        //hhh2 clean up
                                        if filterValue2 == nil {
                                            return nil
                                        } else {
                                            //hhh2 good to return?
                                            let filterValue3 = filterValue2 as? EventFilterable
                                            NSLog("xxx filterValue3 coerced: \(filterValue3)")
                                            if filterValue3 != nil {
                                                //hhh forced unwrap
                                                return [filterValue3!]
                                            } else {
                                                return nil
                                            }
                                        }
                                    } else {
                                        return nil
                                    }
                                } else {
                                    return nil
                                }
                            }
                    NSLog("xxx filterParam: \(filterParam)")

                    //hhh override
                    let filterParam_old = [(nil as [EventFilterable]?), ([EthereumAddress("0xbbce83173d5c1D122AE64856b4Af0D5AE07Fa362")!] as [EventFilterable])]
                    let eventFilter = EventFilter(fromBlock: .blockNumber(0), toBlock: .latest, addresses: [EthereumAddress(address: eventOrigin.contract)], parameterFilters: filterParam)
                    let server = RPCServer(chainID: 1)


                    //hhh also need to check which blocks to "resume"? cannot resume if when XML changed. Only for regular refreshes or when token is tapped (is it too late?)

                    NSLog("xxx handler. event-based attribute: \(each)")
                    //contract (for event)
                    //event name
                    //filter (key and value) - but that means we have to purge all the events for a TokenScript when the TokenScript file changes? because we don't know which events to delete selectively?

                    //hhh need to move out? This is for-each for attribute, or ok?
                    firstly {
                        getEventLogs(withServer: server, contract: eventOrigin.contract, eventName: eventOrigin.eventName, filter: eventFilter)
                    }.done { result in
                        NSLog("xxx events count: \(result.count)")
                        for each in result {
                            print(each)
                        }
                        //TODO make this consistent like this address has exactly one nameregistered from block a to block b
                        //if !result.description.contains("rejected") {
                        //}
                    }.catch { error in
                        NSLog("xxx error with event promise: \(error)")
                    }
                } else {
                    //hhh wrong?
                    NSLog("xxx handler. Has event-based attribute, but no event origin!")
                }
            }
        }
    }
}
