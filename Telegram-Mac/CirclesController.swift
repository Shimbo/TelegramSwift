import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramApi
import MtProtoKit
import SyncCore

             
final class CirclesArguments {
    let context: AccountContext
    init(context: AccountContext) {
        self.context = context
    }
}

enum CirclesTableEntryStableId : Hashable {
    case group(PeerGroupId)
    case sectionId
    var hashValue: Int {
        switch self {
        case .group(let groupId):
            return groupId.hashValue
        case .sectionId:
            return -1
        }
    }
}

enum CirclesTableEntry : TableItemListNodeEntry {
    case group(groupId: PeerGroupId, title: String, settingsURL: String?, unread: Int32)
    case sectionId
    
    var stableId:CirclesTableEntryStableId {
        switch self {
        case .sectionId:
            return .sectionId
        case .group(let groupId, _, _, _):
            return .group(groupId)
        }
    }
    
    func item(_ arguments: CirclesArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .sectionId:
            return GeneralRowItem(initialSize, height: 0, stableId: stableId, backgroundColor: theme.colors.grayBackground)
        case let .group(groupId, title, settingsURL, unread):
            return CirclesRowItem(initialSize, stableId: stableId, groupId: groupId, title: title, settingsURL: settingsURL, unread: Int(unread))
            
        }
    }
}
        
func <(lhs:CirclesTableEntry, rhs:CirclesTableEntry) -> Bool {
    return lhs.stableId.hashValue < rhs.stableId.hashValue
}


private func circlesControllerEntries(settings: Circles,
                                      unreadStates: [PeerGroupId:PeerGroupUnreadCountersCombinedSummary],
                                      notificationSettings: InAppNotificationSettings) -> [CirclesTableEntry] {
    var entries: [CirclesTableEntry] = []
    
    let unreadCountDisplayCategory = notificationSettings.totalUnreadCountDisplayCategory
    
    let type: PeerGroupUnreadCountersCombinedSummary.MuteCategory
    switch notificationSettings.totalUnreadCountDisplayStyle {
        case .raw:
            type = .all
        case .filtered:
            type = .filtered
    }
    //type = .all

    func getUnread(_ groupId: PeerGroupId, type: PeerGroupUnreadCountersCombinedSummary.MuteCategory) -> Int32 {
        if let unread = unreadStates[groupId]?.count(countingCategory: unreadCountDisplayCategory == .chats ? .chats : .messages, mutedCategory: type) {
            return unread
        } else {
            return 0
        }
    }
    
    entries.append(.sectionId)
    entries.append(.group(
        groupId: .root,
        title: "Personal",
        settingsURL: nil,
        unread: getUnread(.root, type: type)
    ))
    
    if settings.groupNames.keys.sorted() == settings.index.keys.sorted() {
        for key in settings.groupNames.keys.sorted(by: {settings.index[$0]! < settings.index[$1]!})  {
            entries.append(.group(
                groupId: key,
                title: settings.groupNames[key]!,
                settingsURL: settings.groupSettingsURLs[key],
                unread: getUnread(key, type: type)
            ))
        }
    }

    
    entries.append(.group(groupId: Namespaces.PeerGroup.archive, title: "Archived", settingsURL: nil, unread: 0))
    if settings.botPeerId != nil {
        entries.append(.group(groupId: PeerGroupId(rawValue: 2), title: "New", settingsURL: nil, unread: 0))
    }
    return entries
}

class CirclesRowView: TableRowView {
    private let titleTextView:TextView
    private let iconView:ImageView
    private var badgeView:View?
    private var plus = CAShapeLayer()
    private var dottedBorder = CAShapeLayer()
    
    required init(frame frameRect: NSRect) {
        iconView = ImageView(frame: NSMakeRect(16, 10, 48, 48))
        iconView.layer?.contentsGravity = .resizeAspect
        titleTextView = TextView(frame: NSMakeRect(5, 65, 70, 20))
        
        super.init(frame: frameRect)
        addSubview(titleTextView)
        addSubview(iconView)
        iconView.layer?.cornerRadius = 10
        
        //iconView.layer?.borderColor = NSColor(red: 1, green: 1, blue: 1, alpha: 1).cgColor
        //iconView.wantsLayer = true
        titleTextView.isSelectable = false
        titleTextView.isEventLess = true
        titleTextView.userInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        return theme.colors.grayBackground
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        if let item = item as? CirclesRowItem {
            if case .group(2) = item.groupId {
                if let layer = iconView.layer  {
                    let origImage = #imageLiteral(resourceName: "Icon_AddCircle").precomposed()
                    
                    let maskLayer = CALayer()
                    maskLayer.frame = layer.bounds
                    maskLayer.contents = origImage
                    
                    plus.frame = iconView.bounds
                    plus.backgroundColor = theme.colors.text.cgColor
                    plus.mask = maskLayer
                    layer.addSublayer(plus)
                    
                    dottedBorder.strokeColor = theme.colors.grayIcon.cgColor
                    dottedBorder.lineDashPattern = [5, 5]
                    dottedBorder.frame = iconView.bounds
                    dottedBorder.fillColor = nil
                    dottedBorder.path = NSBezierPath(roundedRect: iconView.bounds, xRadius: 10.0, yRadius: 10.0).cgPath
                    layer.addSublayer(dottedBorder)
                }
                
                badgeView?.removeFromSuperview()
                badgeView = nil
                
                iconView.layer?.backgroundColor = NSColor.clear.cgColor
                iconView.image = nil
            } else {
                plus.removeFromSuperlayer()
                dottedBorder.removeFromSuperlayer()
                let icon:CGImage = {
                    switch item.groupId {

                    case .group(0),.root:
                        return #imageLiteral(resourceName: "Icon_CirclePersonal").precomposed()
                    case .group(1):
                        return #imageLiteral(resourceName: "Icon_CircleArchived").precomposed()
                    default:
                        return #imageLiteral(resourceName: "Icon_CircleCustom").precomposed()
                    }
                }()
                iconView.image = icon
                if item.isSelected {
                    iconView.layer?.backgroundColor = theme.colors.basicAccent.cgColor
                } else {
                    iconView.layer?.backgroundColor = theme.colors.grayIcon.cgColor
                }
                
                if let badgeNode = item.badgeNode {
                    if badgeView == nil {
                        badgeView = View()
                        addSubview(badgeView!)
                    }
                    badgeView?.setFrameSize(badgeNode.size)
                    badgeNode.view = badgeView
                    self.badgeView?.setFrameOrigin(47, 2)
                    badgeNode.setNeedDisplay()
                } else {
                    badgeView?.removeFromSuperview()
                    badgeView = nil
                }
            }
            titleTextView.update(item.title)
            
            needsLayout = true
        }
    }
    
    override func layout() {
        super.layout()
        if let item = item as? CirclesRowItem {
            titleTextView.update(item.title, origin: NSMakePoint(5, 65))
            titleTextView.centerX()
        }
        
    }
}

class CirclesRowItem: TableRowItem {
    public var title: TextViewLayout!
    public let groupId: PeerGroupId
    public let unread: Int
    public let settingsURL: String?
    public var badgeNode:BadgeNode? = nil
    
    fileprivate let _stableId:AnyHashable
    override var stableId: AnyHashable {
        return _stableId
    }
    
    init(_ initialSize:NSSize, stableId: CirclesTableEntryStableId, groupId: PeerGroupId, title:String, settingsURL:String?, unread: Int) {
        self.groupId = groupId
        self._stableId = stableId
        self.unread = unread
        self.settingsURL = settingsURL
        
        super.init(initialSize)
        
        var textColor = theme.colors.text
        if !isSelected {
            textColor = theme.colors.grayIcon
        } else {
            textColor = theme.colors.text
        }
        
        self.title = TextViewLayout(
            .initialize(
                string: title,
                color: textColor,
                font: .normal(.short)
            ),
            constrainedWidth: 70,
            maximumNumberOfLines: 1,
            alignment: .center
        )
        
        _ = makeSize(70, oldWidth: 0)
        
        if unread > 0 {
            var text = "\(unread)"
            if unread > 99 {
                text = "99+"
            }
            badgeNode = BadgeNode(.initialize(string: text, color: .white, font: .medium(.small)), theme.chatList.badgeBackgroundColor)
            
        }
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        title.measure(width: width)
        return true
    }
    
    override func viewClass() -> AnyClass {
        return CirclesRowView.self
    }
    override var height: CGFloat {
        return 80
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        if self.settingsURL == nil {
            return .single([])
        }
        
        let openSettings:()->Void = { [weak self] in
           self?.openSettings()
        }
        
        return .single([ContextMenuItem("Settings", handler: openSettings)])
    }
    
    func openSettings() {
        if let settingsURL = self.settingsURL, let url = URL(string: settingsURL) {
            NSWorkspace.shared.open(url)
        }
    }
}

class CirclesListView: View {
    var tableView = TableView(frame:NSZeroRect, drawBorder: true) {
       didSet {
           oldValue.removeFromSuperview()
           addSubview(tableView)
       }
    }

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        //autoresizesSubviews = false
        addSubview(tableView)
    }
    
    override func layout() {
        super.layout()
        setFrameOrigin(0,0)
        setFrameSize(frame.width, frame.height)
        tableView.setFrameSize(frame.width, frame.height)
        tableView.setFrameOrigin(0,0)
        
        wantsLayer = true
        layer?.backgroundColor = theme.colors.grayBackground.cgColor
        
        tableView.layer?.backgroundColor = .clear
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override var backgroundColor: NSColor {
        set {
            super.backgroundColor = theme.colors.grayBackground
        }
        get {
            return theme.colors.grayBackground
        }
    }
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<CirclesTableEntry>], right: [AppearanceWrapperEntry<CirclesTableEntry>], initialSize:NSSize, arguments: CirclesArguments) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

class CirclesController: TelegramGenericViewController<CirclesListView>, TableViewDelegate {
    
    private let disposable = MetaDisposable()
    var chatListNavigationController:NavigationViewController
    var tabController:TabBarController
    var settings:Circles
    
    init(context: AccountContext, chatListNavigationController: NavigationViewController, tabController: TabBarController, settings: Circles) {
        self.chatListNavigationController = chatListNavigationController
        self.tabController = tabController
        self.settings = settings
        super.init(context)
    }
    
    func resetCircleLastPeer() {
        var groupId:PeerGroupId?
        let signal = Circles.updateSettings(postbox: context.account.postbox) { entry in
            groupId = entry.currentCircle
            entry.lastCirclePeer[entry.currentCircle] = nil
            self.settings = entry
            return entry
        } |> deliverOnMainQueue |> map {
            if let groupId = groupId {
                self.select(groupId: groupId)
            }
        }
        _ = signal.start()
    }
    func follow(peerId: PeerId) {
        let signal = context.account.postbox.transaction { transaction -> PeerGroupId? in
            let inclusion = transaction.getPeerChatListInclusion(peerId)
            var nextCircle:PeerGroupId
            switch inclusion {
                case let .ifHasMessagesOrOneOf(currentGroupId, _, _):
                    nextCircle = currentGroupId
                case .notIncluded:
                    nextCircle = .root
            }

            var switchTo:PeerGroupId?
            Circles.updateSettings(transaction: transaction) { entry in
                if nextCircle != entry.currentCircle {
                    switchTo = nextCircle
                    entry.currentCircle = nextCircle
                }
                entry.lastCirclePeer[entry.currentCircle] = peerId
                self.settings = entry
                return entry
            }
            return switchTo
        } |> deliverOnMainQueue |> map { switchTo in
            self.select(groupId: self.settings.currentCircle, notify: false)
            if let switchTo = switchTo {
                let chatListController = ChatListController(self.context, modal: false, groupId: switchTo)
                self.chatListNavigationController.empty = chatListController
                self.chatListNavigationController.gotoEmpty(false)
                //self.chatListNavigationController.push(ChatListController(self.context, modal: false, groupId: switchTo), false, style: .none)
            }
        }
        _ = signal.start()
    }
    func select(groupId:PeerGroupId?, notify: Bool = false) {
        if let groupId = groupId {
            if let item = genericView.tableView.item(stableId: CirclesTableEntryStableId.group(groupId)) {
                genericView.tableView.select(item: item, notify: notify)
            }
        } else {
            if let item = genericView.tableView.item(stableId: CirclesTableEntryStableId.sectionId) {
                genericView.tableView.select(item: item, notify: notify)
            }
        }
    }
    func selectionDidChange(row: Int, item: TableRowItem, byClick: Bool, isNew: Bool) {
        if let item = item as? CirclesRowItem {
            (baseAppSettings(accountManager: context.sharedContext.accountManager) |> deliverOnMainQueue).start(next: { [weak self] baSettings in
                guard let `self` = self else {return}
                
                let chatTabIndex:Int
                if baSettings.showCallsTab {
                    chatTabIndex = 2
                } else {
                    chatTabIndex = 1
                }
                
                self.tabController.select(index: chatTabIndex)
                
                let signal = Circles.updateSettings(postbox: self.context.account.postbox) { entry in
                    entry.currentCircle = item.groupId
                    self.settings = entry
                    return entry
                } |> deliverOnMainQueue |> map {
                    self.select(groupId: item.groupId)

                    let chatListController = ChatListController(self.context, modal: false, groupId: item.groupId)
                    self.chatListNavigationController.empty = chatListController
                    self.chatListNavigationController.gotoEmpty(false)
                    //self.chatListNavigationController.push(ChatListController(self.context, modal: false, groupId: item.groupId), false, style: .none)
                    
                    if let peerId = self.settings.lastCirclePeer[item.groupId] {
                        self.context.sharedContext.bindings.rootNavigation().push(ChatController(context: self.context, chatLocation: .peer(peerId)))
                    } else {
                        self.context.sharedContext.bindings.rootNavigation().gotoEmpty(false)
                    }
                }
                _ = signal.start()
            })
        }
        return
    }
    
    func selectionWillChange(row: Int, item: TableRowItem, byClick: Bool) -> Bool {
        if let item = item as? CirclesRowItem {
            if item.groupId == PeerGroupId(rawValue: 2) {
                let modalController = NewCircleModalController(context)
                showModal(with: modalController, for: mainWindow)
                return false
            }
        }
        return true
    }
    
    func isSelectable(row: Int, item: TableRowItem) -> Bool {
        return true
    }
    
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return nil
    }
    
    deinit {
        disposable.dispose()
    }
    
    override func loadView() {
        super.loadView()
        backgroundColor = NSColor(red: 0x19/255, green: 0x13/255, blue: 0x3c/255, alpha: 1)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        genericView.tableView.delegate = self
        let context = self.context
        
        var previous:Atomic<[AppearanceWrapperEntry<CirclesTableEntry>]> = Atomic(value: [])
        let initialSize = atomicSize
        
        let arguments = CirclesArguments(context: context)
        
        let initialTransition: Signal<Void, NoError> = appearanceSignal |> map { appearance in
            if self.didSetReady {
                return
            }
            var entries: [CirclesTableEntry] = []
            entries.append(.sectionId)
            entries.append(.group(
                groupId: .root,
                title: "Personal",
                settingsURL: nil,
                unread: 0
            ))
            
            for key in self.settings.sortedCircles {
                entries.append(.group(
                    groupId: key,
                    title: self.settings.groupNames[key]!,
                    settingsURL: self.settings.groupSettingsURLs[key],
                    unread: 0
                ))
            }

            entries.append(.group(groupId: Namespaces.PeerGroup.archive, title: "Archived", settingsURL: nil, unread: 0))
            if self.settings.botPeerId != nil {
                entries.append(.group(groupId: PeerGroupId(rawValue: 2), title: "New Circle", settingsURL: nil, unread: 0))
            }

            let mappedEntries = entries.map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})
            previous = Atomic(value: mappedEntries)
            let initial:Atomic<[AppearanceWrapperEntry<CirclesTableEntry>]> = Atomic(value: [])
            
            let transition = prepareTransition(
                left: initial.swap(mappedEntries),
                right: mappedEntries,
                initialSize: initialSize.modify({$0}),
                arguments: arguments
            )

            self.genericView.tableView.merge(with: transition)
            self.readyOnce()
            //self.select(groupId: self.settings.currentCircle, notify: false)
            //self?.chatListNavigationController.callback?()
        } |> deliverOnMainQueue
        _ = initialTransition.start()
        
        let unreadCountsKey = PostboxViewKey.unreadCounts(items: [.total(nil)])
        let counterSignal: Signal<Void, NoError> = context.account.postbox.combinedView(keys: [unreadCountsKey])
        |> mapToSignal { _ in
            return context.account.postbox.transaction { transaction in
                transaction.recalculateChatListGroupStats(groupId: .root)
            }
        }
        
        let chatHistoryView: Signal<(ChatListView, ViewUpdateType), NoError> = context.account.viewTracker.tailChatListView(groupId: .root, count: 10)
        
        let transition: Signal<TableUpdateTransition, NoError> = combineLatest(
            Circles.settingsView(postbox: context.account.postbox),
            appearanceSignal,
            chatHistoryView,
            appNotificationSettings(accountManager: context.sharedContext.accountManager),
            counterSignal)
        |> map { settings, appearance, chatHistory, inAppSettings, _ in
            self.settings = settings
            var unreadStates:[PeerGroupId:PeerGroupUnreadCountersCombinedSummary] = [:]
            for group in chatHistory.0.groupEntries {
                unreadStates[group.groupId] = group.unreadState
            }
            
            unreadStates[.root] = context.account.postbox.groupStats(.root)
            
            let entries = circlesControllerEntries(settings: settings, unreadStates: unreadStates, notificationSettings: inAppSettings)
                .map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})
            
            return prepareTransition(
                left: previous.swap(entries),
                right: entries,
                initialSize: initialSize.modify({$0}),
                arguments: arguments
            )
            
        } |> deliverOnMainQueue
        
        transition.start(next: { [weak self] transition in
            self?.genericView.tableView.merge(with: transition)
            //self?.readyOnce()
        })
    }
}

private final class CirclesSettingsArguments {
    let toggleDev:() -> Void;
    
    init(toggleDev: @escaping() -> Void) {
        self.toggleDev = toggleDev;
    }
}

private let _development_mode = InputDataIdentifier("_development_mode")

private func circlesEntries(settings: Circles, arguments: CirclesSettingsArguments) -> [InputDataEntry] {
    
    var entries:[InputDataEntry] = []
    
    entries.append(.sectionId(0, type: .normal))
    
    entries.append(InputDataEntry.custom(sectionId: 1, index: 0, value: .none, identifier: _development_mode, equatable: nil, item: { initialSize, stableId in
        return GeneralInteractedRowItem(initialSize, stableId: stableId, name: "Development mode", type: .switchable(settings.dev), viewType: .singleItem, action: {
            arguments.toggleDev()
        })
    }))
    
    return entries
}

func CirclesSettingsController(_ context: AccountContext) -> ViewController {
    let arguments = CirclesSettingsArguments.init(toggleDev: {
        let signal = combineLatest(
            context.sharedContext.accountManager.currentAccountRecord(allocateIfNotExists: false),
            Circles.getSettings(postbox: context.account.postbox)
        ) |> map { record, settings in
            if let (recordId, _) = record {
                let pathName = accountRecordIdPathName(recordId)
                let appDelegate = NSApp.delegate as! AppDelegate
                let rootPath = appDelegate.containerUrl!
                let path = "\(rootPath)/\(pathName)"
                
                try! FileManager.default.removeItem(atPath: path)
                
                let appUrl = URL(fileURLWithPath: Bundle.main.resourcePath!)
                let appPath = appUrl.deletingLastPathComponent().deletingLastPathComponent().absoluteString
                let task = Process()
                task.launchPath = "/usr/bin/open"
                task.arguments = [appPath, "--args", "-circles-env", settings.dev ? "prod" : "dev"]
                task.launch()
                exit(0)
            }
        } |> deliverOnMainQueue
        _ = signal.start()
    })
    
    let entriesSignal = Circles.settingsView(postbox: context.account.postbox)
    |> map { circlesSettings -> [InputDataEntry] in
        return circlesEntries(settings: circlesSettings, arguments: arguments)
    } |> deliverOn(prepareQueue)

    
    return InputDataController(dataSignal: entriesSignal |> map { InputDataSignalValue(entries: $0) }, title: "Circles", hasDone: false, identifier: "circles-settings")
    
}



private let _id_circle_name = InputDataIdentifier("_id_circle_name")
private func newCircleModalEntries() -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("CIRCLE NAME"), data: InputDataGeneralTextData(color: theme.colors.text, detectBold: true, viewType: .textBottomItem)))
    index += 1
    
    entries.append(
        InputDataEntry.input(
            sectionId: sectionId,
            index: index,
            value: .none,
            error: nil,
            identifier: _id_circle_name,
            mode: .plain,
            data: InputDataRowData(viewType: .singleItem),
            placeholder: nil,
            inputPlaceholder: "",
            filter: { $0 },
            limit: 255)
    )
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    return entries
}
func NewCircleModalController(_ context: AccountContext) -> InputDataModalController {

    var name:String = ""
    
    let signal = Signal<[InputDataEntry], NoError> { subscriber in
        subscriber.putNext(newCircleModalEntries())
        subscriber.putCompletion()
        return EmptyDisposable
    }
    
    let controller = InputDataController(
        dataSignal: signal |> map { InputDataSignalValue(entries: $0) },
        title: "New circle",
        validateData: { data in
            return .none
        }, updateDatas: { data in
            if let value = data[_id_circle_name]?.stringValue {
                name = value
            }
            return .none
        }, returnKeyInvocation: { identifier, event in
            let signal:Signal<Void, NoError> = Circles.getSettings(postbox: context.account.postbox) |> mapToSignal { settings in
                if let botId = settings.botPeerId, name != "" {
                    defer { name = "" }
                    return standaloneSendMessage(account: context.account, peerId: botId, text: "/create "+name, attributes: [], media: nil, replyToMessageId: nil) |> `catch` {_ in return .complete()} |> map {_ in return Void()}
                } else {
                    return .single(Void())
                }
            }
            _ = signal.start()
            return .default
        }
    )
    
    var close: (() -> Void)? = nil
    
    let modalInteractions = ModalInteractions(acceptTitle: "Create", accept: { [weak controller] in
        if name != "" {
            _ = controller?.returnKeyAction()
            close?()
        }
    }, cancelTitle: L10n.modalCancel, drawBorder: true, height: 50)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}

