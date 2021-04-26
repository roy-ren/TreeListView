
import UIKit

public protocol TreeListViewDynamicDataSource: class {
	associatedtype Element: TreeElementProtocol
}

public protocol TreeListViewDelegate: class {
	var itemHeight: CGFloat { get }
	
	func treeListView<Cell: ListViewCellProtocol>(
		_ listView: TreeListStaticView<Cell>,
        didSelected element: ListViewItem<Cell.Element>,
		of cell: Cell
	)
}

public extension TreeListViewDelegate {
	var itemHeight: CGFloat { 44 }
}

public protocol ListViewCellProtocol: UIView {
	associatedtype Element: TreeElementProtocol
	
	init()
	
	func config(with element: ListViewItem<Element>)
}

public enum ListViewItem<Element: TreeElementProtocol> {
    case cell(_ element: Element)
    case section(_ element: Element)
    
    public var element: Element {
        switch self {
        case .cell(let element):
            return element
        case .section(let element):
            return element
        }
    }
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
	private var sections: [DataSource.Section] { dataSourceTree.sections }
	
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
        cell.config(.cell(sections[indexPath.section].cellElements[indexPath.row]))
		
		return cell
	}
	
	// MARK: - UITableViewDelegate
	public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		let header: Header = tableView.dequeueReusableHeaderFooter()

		let element = sections[section].element
        header.config(.section(element))
		header.tappedClosure = { [weak self] cell in
            guard let self = self else { return }
            
            self.toggle(section: section) { [weak self] in
                guard let self = self else { return }
                
                if $0 { self.triger(didSelected: .section(element), of: cell) }
            }
		}
		
		return header
	}
    
    private func toggle(section: Int, completion: @escaping (Bool) -> Void) {
		func update(_ editChange: EditChange) {
			print("start performBatchUpdates" + "section: \(self.sections.count)")

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
                }

				print("after performBatchUpdates" + "section: \(self.sections.count)")
				self.sections.forEach {
					let spacing = (0...$0.element.level).reduce("") { r, _ in r + "    " }

					print(spacing + "section: \($0.element.element)")

					$0.cellElements.forEach { element in
						print(spacing + "cell: \(element.element)")
					}
				}
			}
		}
        
        dataSourceTree.toggle(section: section) { change in
            if case .none = change {
                completion(false)
                return
            }
            
            DispatchQueue.main.async {
                update(change)
                completion(true)
            }
        }
    }
	
	public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		
		tableView.deselectRow(at: indexPath, animated: true)
		guard let cell = tableView.cellForRow(at: indexPath) as? Cell else { return }
		let element = sections[indexPath.section].cellElements[indexPath.row]
        triger(didSelected: .cell(element), of: cell.content)
	}
	
	private func triger(didSelected item: ListViewItem<Element>, of cell: ListCell) {
		delegate?.treeListView(self, didSelected: item, of: cell)
	}
}
