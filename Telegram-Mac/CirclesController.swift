import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac

/*fileprivate func prepareEntries() -> Signal<TableUpdateTransition, NoError>{
    return Signal { subscriber in
        
    }
}*/

class UpdatedNavigationViewController: NavigationViewController {
    var callback:(() -> Void)?
    override func currentControllerDidChange() {
        callback?()
    }
}
             
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
    case group(groupId: PeerGroupId, title: String, unread: Int32)
    case sectionId
    
    var stableId:CirclesTableEntryStableId {
        switch self {
        case .sectionId:
            return .sectionId
        case .group(let groupId, _, _):
            return .group(groupId)
        }
    }
    
    func item(_ arguments: CirclesArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .sectionId:
            return GeneralRowItem(initialSize, height: 10, stableId: stableId)
        case let .group(groupId, title, unread):
            return CirclesRowItem(initialSize, stableId: stableId, groupId: groupId, title: title, unread: Int(unread))
            
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
        unread: getUnread(.root, type: type)
    ))
    
    for key in settings.groupNames.keys.sorted(by: {settings.index[$0]! < settings.index[$1]!})  {
        entries.append(.group(
            groupId: key,
            title: settings.groupNames[key]!,
            unread: getUnread(key, type: type)
        ))
    }

    
    entries.append(.group(groupId: Namespaces.PeerGroup.archive, title: "Archived", unread: 0))
    return entries
}

class CirclesRowView: TableRowView {
    private let titleTextView:TextView
    private let iconView:ImageView
    private var badgeView:View?
    
    required init(frame frameRect: NSRect) {
        iconView = ImageView(frame: NSMakeRect(16, 10, 48, 48))
        iconView.layer?.contentsGravity = .resizeAspect
        titleTextView = TextView(frame: NSMakeRect(5, 65, 70, 20))
        
        super.init(frame: frameRect)
        addSubview(titleTextView)
        addSubview(iconView)
        iconView.layer?.cornerRadius = 10
        
        iconView.layer?.borderColor = NSColor(red: 1, green: 1, blue: 1, alpha: 1).cgColor
        //iconView.wantsLayer = true
        titleTextView.isSelectable = false
        titleTextView.isEventLess = true
        titleTextView.userInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        return NSColor(red: 0x21/255, green: 0x27/255, blue: 0x4d/255, alpha: 1)
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        if let item = item as? CirclesRowItem {
            let icon:CGImage = {
                switch item.groupId {
                case .group(0),.group(2),.root:
                    return #imageLiteral(resourceName: "Icon_CirclePersonal").precomposed()
                case .group(1):
                    return #imageLiteral(resourceName: "Icon_CircleArchived").precomposed()
                default:
                    return #imageLiteral(resourceName: "Icon_CircleCustom").precomposed()
                }
            }()
            iconView.image = icon
            if item.isSelected {
                iconView.layer?.backgroundColor = NSColor(red: 0x1d/255, green: 0xa5/255, blue: 0xe9/255, alpha: 1).cgColor
                iconView.layer?.borderWidth = 2
            } else {
                iconView.layer?.backgroundColor = NSColor(red: 0x7a/255, green: 0x7d/255, blue: 0x94/255, alpha: 1).cgColor
                iconView.layer?.borderWidth = 0
            }
            titleTextView.update(item.title)
            
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
    //let groupId: PeerGroupId
    public let title: TextViewLayout
    public let groupId: PeerGroupId
    public let unread: Int
    public var badgeNode:BadgeNode? = nil
    
    fileprivate let _stableId:AnyHashable
    override var stableId: AnyHashable {
        return _stableId
    }
    
    init(_ initialSize:NSSize, stableId: CirclesTableEntryStableId, groupId: PeerGroupId, title:String, unread: Int) {
        self.groupId = groupId
        self._stableId = stableId
        self.unread = unread
        self.title = TextViewLayout(
            .initialize(
                string: title,
                color: .white,
                font: .normal(.short)
            ),
            constrainedWidth: 70,
            maximumNumberOfLines: 1,
            alignment: .center
        )
        super.init(initialSize)
        _ = makeSize(70, oldWidth: 0)
        
        if unread > 0 {
            var text = "\(unread)"
            if unread > 99 {
                text = "99+"
            }
            badgeNode = BadgeNode(.initialize(string: text, color: .white, font: .medium(.small)), NSColor(red: 0xeb/255, green: 0x4b/255, blue: 0x44/255, alpha: 1))
            
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
    
    
}

class ScrollLessTableView: TableView {
    open override func scrollWheel(with event: NSEvent) {
        guard let window = window as? Window else {
            super.scrollWheel(with: event)
            return
        }
        if !window.inLiveSwiping, super.responds(to: #selector(scrollWheel(with:))) {
            super.scrollWheel(with: event)
        }
        //
    }

}
class CirclesListView: View {
    var tableView = ScrollLessTableView(frame:NSZeroRect, drawBorder: true) {
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
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        needsLayout = true
    }
    override func layout() {
        super.layout()
        setFrameOrigin(0,0)
        setFrameSize(frame.width, frame.height)
        tableView.setFrameSize(frame.width, frame.height)
        tableView.setFrameOrigin(0,0)
        
        wantsLayer = true
        layer?.backgroundColor = NSColor(red: 0x21/255, green: 0x27/255, blue: 0x4d/255, alpha: 1).cgColor
        
        tableView.layer?.backgroundColor = .clear
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
    var chatListNavigationController:UpdatedNavigationViewController
    var tabController:TabBarController
    
    init(context: AccountContext, chatListNavigationController: UpdatedNavigationViewController, tabController: TabBarController) {
        self.chatListNavigationController = chatListNavigationController
        self.tabController = tabController
        super.init(context)
        
        backgroundColor = NSColor(red: 0x19/255, green: 0x13/255, blue: 0x3c/255, alpha: 1)

    }
    
    func select(groupId:PeerGroupId?) {
        if let groupId = groupId {
            if let item = genericView.tableView.item(stableId: CirclesTableEntryStableId.group(groupId)) {
                genericView.tableView.select(item: item, notify: false)
            }
        } else {
            if let item = genericView.tableView.item(stableId: CirclesTableEntryStableId.sectionId) {
                genericView.tableView.select(item: item, notify: false)
            }
        }
    }
    func selectionDidChange(row: Int, item: TableRowItem, byClick: Bool, isNew: Bool) {
        if let item = item as? CirclesRowItem {
            let controller = ChatListController(context, modal: false, groupId: item.groupId)
            //self.chatListNavigationController.stackInsert(controller, at: 0)
            self.tabController.select(index: 2)
            self.chatListNavigationController.empty = controller
            self.chatListNavigationController.gotoEmpty(true)

        }
        return
    }
    
    func selectionWillChange(row: Int, item: TableRowItem, byClick: Bool) -> Bool {
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

    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        genericView.tableView.delegate = self
        let context = self.context
        
        let previous:Atomic<[AppearanceWrapperEntry<CirclesTableEntry>]> = Atomic(value: [])
        let initialSize = atomicSize
        
        let arguments = CirclesArguments(context: context)
        
        let chatHistoryView: Signal<(ChatListView, ViewUpdateType), NoError> = context.account.viewTracker.tailChatListView(groupId: .root, count: 500)
        
        
        let transition: Signal<TableUpdateTransition, NoError> = combineLatest(
            Circles.settingsView(postbox: context.account.postbox),
            appearanceSignal,
            chatHistoryView,
            appNotificationSettings(accountManager: context.sharedContext.accountManager))
            
        |> map { settings, appearance, chatHistory, inAppSettings in
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
        
        disposable.set(transition.start(next: { [weak self] transition in
            self?.genericView.tableView.merge(with: transition)
            self?.readyOnce()
            self?.chatListNavigationController.callback?()
        }))
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
    
    entries.append(InputDataEntry.general(sectionId: 1, index: 0, value: .none, error: nil, identifier: _development_mode, data: InputDataGeneralData(name: "Development mode", color: theme.colors.text, type: .switchable(settings.dev), action: {
        arguments.toggleDev()
    })))

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

