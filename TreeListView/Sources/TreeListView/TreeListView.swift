
import UIKit

public protocol TreeListViewDynamicDataSource: class {
	associatedtype Element: TreeElementProtocol
}

public protocol TreeListViewDelegate: class {
	var itemHeight: CGFloat { get }
	
	func treeListView<Cell: ListViewCellProtocol>(
		_ listView: TreeListStaticView<Cell>,
		didSelected element: Cell.Element,
		of cell: Cell
	)
}

public extension TreeListViewDelegate {
	var itemHeight: CGFloat { 44 }
}

public protocol ListViewCellProtocol: UIView {
	associatedtype Element: TreeElementProtocol
	
	init()
	
	func config(with element: Element)
}

/// 静态类型 数据源不变
public final class TreeListStaticView<ListCell: ListViewCellProtocol>: UIView, UITableViewDataSource, UITableViewDelegate {
	public typealias Element = ListCell.Element
	public weak var delegate: TreeListViewDelegate?
	
	// config
	public var stateToggledEnabled = false
	
	private let tableView = UITableView()
	private var didContructedSubView = false
	
	private typealias DataSource = TableSourceTree<Element>
    private var dataSourceTree: DataSource
//	private var sections: [DataSource.Section] { dataSourceTree.sections }
	lazy var sections = dataSourceTree.sections
	private var section: DataSource.Section?
	
	private typealias Cell = TreeListCell<ListCell>
	private typealias Header = TreeListHeader<ListCell>
	
	public init(elements: [Element]) {
		self.dataSourceTree = .init(source: elements)
		super.init(frame: .zero)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	public override func didMoveToWindow() {
		super.didMoveToWindow()
		
		guard !didContructedSubView else { return }
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
		cell.config(sections[indexPath.section].cellElements[indexPath.row])
		
		return cell
	}
	
	// MARK: - UITableViewDelegate
	public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		let header: Header = tableView.dequeueReusableHeaderFooter()

		let element = sections[section].element
		header.config(element)
		header.tappedClosure = { [weak self] in
			self?.triger(didSelected: element, of: $0)
            self?.dataSourceTree.toggle(sectionAt: section)
            self?.tableView.reloadData()
		}
		
		return header
	}
	
	public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		
		tableView.deselectRow(at: indexPath, animated: true)
		guard let cell = tableView.cellForRow(at: indexPath) as? Cell else { return }
		let element = sections[indexPath.section].cellElements[indexPath.row]
		triger(didSelected: element, of: cell.content)
	}
	
	private func triger(didSelected item: Element, of cell: ListCell) {
		delegate?.treeListView(self, didSelected: item, of: cell)
		
//		if stateToggledEnabled {
//			section = sections.removeLast()
//			tableView.deleteSections([sections.count], with: .fade)
//		} else {
//			if let section = section {
//				sections.append(section)
//				tableView.insertSections([sections.count - 1], with: .fade)
//			}
//		}
//
//		stateToggledEnabled.toggle()
	}
}
