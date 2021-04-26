//
//  TableSourceTree.swift
//  
//
//  Created by roy on 2020/10/29.
//

import Foundation

public protocol Identifiable {
	associatedtype ID : Hashable
	
	/// 唯一 id
	var id: Self.ID { get }
}

public protocol TreeElementProtocol: Identifiable, Equatable {
	associatedtype Element
	
	/// 数据
	var element: Self.Element { get }
	
	/// 层级深度：最外为 0
	var level: Int { get }
	
	/// 父节点的 id
	var superIdentifier: ID? { get }
	
	/// 在同级中的排序
	var rank: Int { get }
	
	/// 展开状态
	var state: BranchNodeState { get }
	
	static var emptyRootElement: Self { get }
}

public struct TreeSectionElement<Element: TreeElementProtocol>: Identifiable, Equatable {
	public static func == (
		lhs: TreeSectionElement<Element>,
		rhs: TreeSectionElement<Element>
	) -> Bool {
		lhs.id == rhs.id
			&& lhs.element == rhs.element
			&& lhs.cellElements == rhs.cellElements
	}
	
	public var element: Element
	public var cellElements: [Element]
	
	public var id: Element.ID { element.id }
	public var superSectionID: Element.ID? { element.superIdentifier }
}

public class TableSourceTree<Element: TreeElementProtocol> {

	public typealias Node = TreeNode<Element>
	public var root: Node!
	
	public typealias Section = TreeSectionElement<Element>
	public private(set) var sections: [Section]
    
    private var _inToggleChangeCaculating = false
    private let queue = DispatchQueue(label: "com.royite.inToggleChangeCaculating.access")
    
//    private var inToggleChangeCaculating: Bool {
//        set { queue.async { self._inToggleChangeCaculating = newValue } }
//        get { queue.sync { _inToggleChangeCaculating } }
//    }
	
	public init(source list: [Element]) {
		
		typealias ID = Element.ID
		// superID: subNodes
		var subNodesInfo = [ID?: [Node]]()
		
		Dictionary(grouping: list, by: { $0.level })
			.sorted { $0.key > $1.key }		// 先从level大的开始，即树的叶子开始
			.forEach{ _, elements in
				Dictionary(grouping: elements, by: { $0.superIdentifier })
					.forEach { superID, elements in
						let nodes: [Node] = elements
							.sorted { $0.rank < $1.rank }
							.map { element -> Node in
								if let subNodes = subNodesInfo.removeValue(forKey: element.id) {
									return Node.branch(data: element, subNodes: subNodes, state: element.state)
								} else {
									return Node.leaf(data: element)
								}
							}
						
						subNodesInfo.updateValue(nodes, forKey: superID)
					}
			}
		
		if let nodes = subNodesInfo[.none] {
			root = .branch(data: .emptyRootElement, subNodes: nodes, state: .expand)
		} else if let nodes = subNodesInfo.values.first {
			root = .branch(data: .emptyRootElement, subNodes: nodes, state: .expand)
		} else {
			root = .leaf(data: .emptyRootElement)
		}
		
		sections = root.emptyRootSections(isOnlyExpand: true)
	}
}

// MARK: - Toggle for expand
extension TableSourceTree {
    public enum EditChange {
        case none
		case insert(change: Change)
		case delete(change: Change)
			
        public enum Change {
			case cell(indexPaths: [IndexPath])
			case section(indexSet: IndexSet)
            case total(indexSet: IndexSet, indexPaths: [IndexPath])
            
            var changes: (indexSet: IndexSet, indexPaths: [IndexPath]) {
                switch self {
                case .cell(let indexPaths):
                    return (.init(), indexPaths)
                case .section(let indexSet):
                    return (indexSet, [])
                case let .total(indexSet, indexPaths):
                    return (indexSet, indexPaths)
                }
            }
		}
	}
	
    public func toggle(section: Int, completion: @escaping (EditChange) -> Void) {
        func caculateChange() -> EditChange {
            // 1. search node
            // 每个section的superSection一定在它的前面
            let secitonInfos = Dictionary(grouping: sections[0..<section], by: { $0.id })
            
            var pathIdentifiers = [sections[section].id]
            var element: Element? = sections[section].element
            
            while let id = element?.superIdentifier {
                pathIdentifiers.append(id)
                element = secitonInfos[id]?.first?.element
            }
            
            let result = toggleNode(for: pathIdentifiers, in: root)
            root = result.node
            sections = root.emptyRootSections(isOnlyExpand: true)

            return generateChange(for: result.destinationNode, at: section)
        }
        
        queue.async { [unowned self] in
            guard !self._inToggleChangeCaculating else {
                print("skip toggle section: \([sections[section].id]) count: \(sections.count)")
                completion(.none)
                return
            }
            
            print("toggle section: \([sections[section].id]) count: \(sections.count)")
            completion(caculateChange())
            print("toggleedd section: \([sections[section].id]) count: \(sections.count)")
            self._inToggleChangeCaculating = false
        }
	}
    
    /// node：根据path已执行切换后的node，destinationNode：执行切换状态的节点（切换之前）
    typealias ToggleResult = (node: Node, destinationNode: Node)
    
    /// 根据数据的 id 的数组对一个node中的某个指定node执行切换
    /// - Parameters:
    ///   - path: 数据的 id 数组，第一个id为最终需要切换状态的节点的id，最后一个id是参数node中的subnodes的某一个节点
    ///   - node: path需要在该node中查找需要切换的node
    /// - Returns:
    private func toggleNode(for path: [Element.ID], in node: Node) -> ToggleResult {
        var currentPath = path
        let id = currentPath.removeLast()
        var node = node
        
        guard
            let subNodeIndex = node.subNodes?.firstIndex(where: { $0.data.id == id }),
            var subNode = node.subNodes?[subNodeIndex]
        else {
            fatalError("code not found")
        }
        
        let destinationNode: Node
        if currentPath.isEmpty {
            destinationNode = subNode
            subNode.toggle()
        } else {
            let result = toggleNode(for: currentPath, in: subNode)
            subNode = result.node
            destinationNode = result.destinationNode
        }
        
        node.replace(subNode: subNode, at: subNodeIndex)
        
        return (node, destinationNode)
    }
    
    private func generateChange(for node: Node, at section: Int) -> EditChange {
        guard case .branch(_, _, let state) = node else {
            return .none
        }
        
        var node = node
        if .collapse == state { node.toggle() }
        
        let sections = node.generateSections(isOnlyExpand: true)
        
        guard let sectionElement = sections.first else {
            return .none
        }
        
        var change: EditChange.Change
        
        let indexPaths = (0..<sectionElement.cellElements.count).map {
            IndexPath(row: $0, section: section)
        }
        
        switch sections.count {
        case 1:
            guard !indexPaths.isEmpty else { return .none }
            change = .cell(indexPaths: indexPaths)
        default:
            let indexSet = IndexSet((1..<sections.count).map { $0 + section })
            if indexPaths.isEmpty {
                change = .section(indexSet: indexSet)
            } else {
                change = .total(indexSet: indexSet, indexPaths: indexPaths)
            }
        }
        
        return .collapse == state ? .insert(change: change) : .delete(change: change)
    }
	
	/// 在指定node中根据数据的特性superIdentifier的数组查找节点
	/// - Parameters:
	///   - path: element id  的列表，[node.id, ... rootNode.id]
	///   - node: root node
	/// - Returns: 结果节点
	private func searchNode(for path: [Element.ID], in node: Node) -> Node? {
		var currentPath = path
		let id = currentPath.removeLast()
		
		guard let node = node.subNodes?.first(where: { $0.data.id == id }) else {
			return nil
		}
		
		if currentPath.isEmpty {
			return node
		}
		
		return searchNode(for: currentPath, in: node)
	}
}

extension TreeNode where Element: TreeElementProtocol {
	public typealias Section = TreeSectionElement<Element>
	
	/// 根据根数据源树计算生产所有的 secitons
	/// 根节点的数据不记录入 sections
	/// - Parameter flag: 是否只计算展开项
	/// - Returns: 对应的 sections
	public func emptyRootSections(isOnlyExpand flag: Bool = false) -> [Section] {
//        generateSections(isOnlyExpand: flag)
		let sections = generateSections(isOnlyExpand: flag)
		guard sections.count > 1 else { return [] }
		return sections.suffix(sections.count - 1)
	}
	
	private enum NodeElementData {
		case section(element: Element, cellElements: [Element])
		case cell(element: Element)
	}
	
	/// 根据数据源树计算生产所有的 secitons
	/// - Parameter isOnlyExpand: 是否只计算展开项
	/// - Returns: 对应的 sections
	public func generateSections(isOnlyExpand: Bool = false) -> [Section] {
		
		func generate(node: Self) -> [NodeElementData] {
			switch node {
			case .leaf(let element):
				return [.cell(element: element)]
			case let .branch(element, subNodes, state):
                
				if isOnlyExpand, case .collapse = state {
					return [.section(element: element, cellElements: [])]
				}
                
				var elements = [Element]()
                
                let subNodeSectionDatas: [NodeElementData] = subNodes
                    .flatMap(generate(node:))
                    .reversed()
                    .compactMap {
                        switch $0 {
                        case .cell(let element):
                            elements.append(element)
                            return nil
                        case let .section(element, subs):
                            let section = NodeElementData.section(
                                element: element,
                                cellElements: subs + Array(elements.reversed())
                            )
                            elements.removeAll()
                            return section
                        }
                    }
                    .reversed()
                
                return [.section(element: element, cellElements: elements.reversed())]
                    + subNodeSectionDatas
			}
		}
		
		return generate(node: self).compactMap {
			if case let .section(element, elements) = $0 {
				return Section(element: element, cellElements: elements)
			} else {
				return nil
			}
		}
	}
}
