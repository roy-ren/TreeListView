
import UIKit

public protocol ListViewCellProtocol: UIView {
    associatedtype Element: TreeElementProtocol
    
    init()
    
    func config(with element: ListViewItem<Element>)
}

public enum ListViewItem<Element: TreeElementProtocol> {
    case cell(_ element: Element)
    case section(_ element: Element, state: BranchNodeState)
    
    public var element: Element {
        switch self {
        case .cell(let element):
            return element
        case .section(let element, _):
            return element
        }
    }
}

public protocol TreeListViewDelegate: AnyObject {
    associatedtype Cell: ListViewCellProtocol
    typealias Element = Cell.Element
    
    var elements: [Element] { get }
    var itemHeight: CGFloat { get }
    
    func treeListView(didSelected element: ListViewItem<Element>, of cell: Cell)
}

public extension TreeListViewDelegate {
	var itemHeight: CGFloat { 44 }
}

/// 静态类型 数据源不变
public final class TreeListStaticView<Delegate: TreeListViewDelegate>: UIView, UITableViewDataSource, UITableViewDelegate {
    
	public typealias Element = Delegate.Element
	public weak var delegate: Delegate?
    
	// config
	public var stateToggledEnabled = false
    
    private var didContructedSubView = false
    
    private typealias Cell = TreeListCell<Delegate.Cell>
    private typealias Header = TreeListHeader<Delegate.Cell>
    
    private let tableView = UITableView()
	
	private typealias TreeSource = TableSourceTree<Element>
    private var treeSource: TreeSource = .init(source: [])
	private var sections: [TreeSource.Section] { treeSource.sections }
	
    private var _isNotInToggle = true
    private let fetchToggleStateQeuue = DispatchQueue(label: "com.TreeListStaticView.fetch")
    private var isNotInToggle: Bool {
        get { fetchToggleStateQeuue.sync { _isNotInToggle } }
        set { fetchToggleStateQeuue.async { self._isNotInToggle = newValue } }
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
    }
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	public override func didMoveToWindow() {
		super.didMoveToWindow()
		
		guard !didContructedSubView else { return }
        
        if let delegate = delegate {
            treeSource = .init(source: delegate.elements)
        }
        
		constractViewHierarchyAndConstraint()
	}
	
	private func constractViewHierarchyAndConstraint() {
		addSubview(tableView)
		
		tableView.dataSource = self
		tableView.delegate = self
		tableView.register(cell: Cell.self)
		tableView.register(headerFooter: Header.self)
		tableView.addedAsContent(toSuper: self)
		tableView.tableFooterView = .init()
        
		if let height = delegate?.itemHeight {
			tableView.rowHeight = height
			tableView.sectionHeaderHeight = height
		}
		
		didContructedSubView = true
	}
	
	// MARK: - UITableViewDataSource
	public func numberOfSections(in tableView: UITableView) -> Int {
		sections.count
	}
	
	public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		sections[section].cellElements.count
	}
	
	public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell: Cell = tableView.dequeueReusableCell(forRowAt: indexPath)
        cell.config(.cell(sections[indexPath.section].cellElements[indexPath.row]))
		
		return cell
	}
	
	// MARK: - UITableViewDelegate
	public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		let header: Header = tableView.dequeueReusableHeaderFooter()

		let sectionItem = sections[section]
        header.config(.section(sectionItem.element, state: sectionItem.state))
        
		header.tappedClosure = { [weak self] cell in
            guard let self = self else { return }
            
            self.toggle(section: section) { [weak self] in
                guard let self = self else { return }
                self.triger(didSelected: .section(sectionItem.element, state: $0), of: cell)
            }
		}
		
		return header
	}
    
    private func toggle(section: Int, completion: @escaping (BranchNodeState) -> Void) {
        func update(_ editChange: EditChange) {
            tableView.isUserInteractionEnabled = false
            
			tableView.performBatchUpdates {
                if !editChange.removeIndexPaths.isEmpty {
                    tableView.deleteRows(at: editChange.removeIndexPaths, with: .fade)
                }
                
                if !editChange.removeIndexSet.isEmpty {
                    tableView.deleteSections(editChange.removeIndexSet, with: .fade)
                }
                
                if !editChange.insertIndexPaths.isEmpty {
                    tableView.insertRows(at: editChange.insertIndexPaths, with: .fade)
                }
                
                if !editChange.insertIndexSet.isEmpty {
                    tableView.insertSections(editChange.insertIndexSet, with: .fade)
                }
                
			} completion: { isFinished in
                if isFinished {
                    self.tableView.reloadData()
                    self.tableView.isUserInteractionEnabled = true
                    self.isNotInToggle = true
                }
			}
		}
        
        guard isNotInToggle else {
            return
        }
        
        isNotInToggle = false
        
        treeSource.toggle(section: section) { (change, newState) in
            if case .none = change {
                completion(newState)
                return
            }
            
            DispatchQueue.main.async {
                update(change)
                completion(newState)
            }
        }
    }
	
	public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		
		tableView.deselectRow(at: indexPath, animated: true)
		guard let cell = tableView.cellForRow(at: indexPath) as? Cell else { return }
		let element = sections[indexPath.section].cellElements[indexPath.row]
        triger(didSelected: .cell(element), of: cell.content)
    }
	
	private func triger(didSelected item: ListViewItem<Element>, of cell: Delegate.Cell) {
        delegate?.treeListView(didSelected: item, of: cell)
	}
}
