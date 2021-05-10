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
	
	/// 父节点的 id, 最外层展示的数据的 superIdentifier 为 invisableRoot 的id
	var superIdentifier: ID { get }
	
	/// 在同级中的排序
	var rank: Int { get }
	
	/// 初始展开状态
	var state: BranchNodeState { get }
	
    /// 树根节点数据
	static var invisableRoot: Self { get }
}

public extension TreeElementProtocol {
    static var invisableRootIdentifier: ID {
        invisableRoot.id
    }
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
    public var state: BranchNodeState
	
	public var id: Element.ID { element.id }
	public var superSectionID: Element.ID { element.superIdentifier }
}

public class TableSourceTree<Element: TreeElementProtocol> {

	public typealias Node = TreeNode<Element>
	public var root: Node!
	
	public typealias Section = TreeSectionElement<Element>
	public private(set) var sections: [Section]
    
    private var _inToggleChangeCaculating = false
    private let queue = DispatchQueue(label: "com.royite.inToggleChangeCaculating.access")

	public init(source list: [Element]) {
		
		typealias ID = Element.ID
		// superID: subNodes
		var leafNodes = [ID: [Node]]()

        Dictionary(grouping: list, by: { $0.superIdentifier })
            .forEach { superID, elements in
                let nodes: [Node] = elements
                    .sorted { $0.rank < $1.rank }
                    .map { element -> Node in
                        Node.leaf(data: element)
                    }

                leafNodes.updateValue(nodes, forKey: superID)
            }
        
//        var stack = Stack<Node>()
//        if !list.isEmpty {
//            // 最外层数据的super id 为nil
//            stack.push(item: .leaf(data: .invisableRoot))
//        }
//
//        var constuctedSubNodes = [ID: [Node]]()
//
//        while let node = stack.top {
//            if nil == constuctedSubNodes[node.data.id], let sub = leafNodes[node.data.id] {
//                stack.push(items: sub)
//                continue
//            } else {
//                stack.pop()
//                var superConstructedNodes = constuctedSubNodes[node.data.superIdentifier] ?? []
//
//                if let nodes = constuctedSubNodes[node.data.id] {
//                    let constructedNode = Node.branch(
//                        data: node.data,
//                        subNodes: nodes.reversed(),
//                        state: node.data.state
//                    )
//                    superConstructedNodes.append(constructedNode)
//                } else {
//                    superConstructedNodes.append(node)
//                }
//
//                constuctedSubNodes.updateValue(superConstructedNodes, forKey: node.data.superIdentifier)
//            }
//        }
//
//        if let node = constuctedSubNodes[Element.invisableRoot.superIdentifier]?.first {
//            root = node
//        } else {
//            root = .leaf(data: .invisableRoot)
//        }
        
        func construct(node: Node) -> Node {
            guard let subNodes = leafNodes[node.data.id] else {
                return node
            }

            let constructedSubNodes = subNodes.map(construct(node:))

            return .branch(data: node.data, subNodes: constructedSubNodes, state: node.state)
        }

        if let nodes = leafNodes[Element.invisableRootIdentifier] {
            root = .branch(data: .invisableRoot, subNodes: nodes.map(construct(node:)), state: .expand)
		} else {
			root = .leaf(data: .invisableRoot)
		}
		
		sections = root.emptyRootSections(isOnlyExpand: true)
	}
}

public struct EditChange: Equatable {
	static let none = EditChange(
		insertIndexPaths: [],
		removeIndexPaths: [],
		insertIndexSet: .init(),
		removeIndexSet: .init()
	)

	let insertIndexPaths: [IndexPath]
	let removeIndexPaths: [IndexPath]
	let insertIndexSet: IndexSet
	let removeIndexSet: IndexSet
}

// MARK: - Toggle for expand
extension TableSourceTree {
    public typealias ToogleTreeResult = (change: EditChange, newState: BranchNodeState)
    public func toggle(
        section: Int,
        completion: @escaping (ToogleTreeResult) -> Void
    ) {
        
        func toggle() -> ToggleResult {
            // 1. search node
            // 每个section的superSection一定在它的前面
            let secitonInfos = Dictionary(grouping: sections[0..<section], by: { $0.id })
            
            var pathIdentifiers = [sections[section].id]
            var element: Element? = sections[section].element
            
            while let id = element?.superIdentifier, id != Element.invisableRootIdentifier {
                pathIdentifiers.append(id)
                element = secitonInfos[id]?.first?.element
            }
            
            return toggleNode(for: pathIdentifiers, in: root)
        }
        
        func caculateChange(of result: ToggleResult) -> EditChange {
            root = result.node
            
            switch result.destinationNode.state {
            case .expand:
                sections = root.emptyRootSections(isOnlyExpand: true)
                return generateChange(for: result.destinationNode, at: section)
            case .collapse:
                let change = generateChange(for: result.destinationNode, at: section)
                sections = root.emptyRootSections(isOnlyExpand: true)
                return change
            }
        }
        
        queue.async { [unowned self] in
            let result = toggle()
            let state = result.destinationNode.state
            
            guard !self._inToggleChangeCaculating else {
                completion((.none, state))
                return
            }

            completion((caculateChange(of: result), state))
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
            subNode.toggle()
            destinationNode = subNode
        } else {
            let result = toggleNode(for: currentPath, in: subNode)
            subNode = result.node
            destinationNode = result.destinationNode
        }
        
        node.replace(subNode: subNode, at: subNodeIndex)
        
        return (node, destinationNode)
    }

	/// 计算一个节点state发生改变后，产生的变动
	/// - Parameters:
	///   - node: state 发生变动的节点
	///   - section: 改节点位于
	/// - Returns: 该节点产生的变动（所有涉及到的索引）
	private func generateChange(
		for node: Node,
		at section: Int
	) -> EditChange {
		guard case .branch(_, _, let state) = node else {
			return .none
		}

		var node = node
		// 如果是闭合状态，则需要先展开，用以计算索引
		if .collapse == state { node.toggle() }

        // 该节点对应的sections
		let currentNodeSections = node.generateSections(isOnlyExpand: true)

		// 该节点的section对应的信息
		guard let currentSection = currentNodeSections.first else {
			return .none
		}

        // 该节点对应section中的索引
		var subIndexPaths = [IndexPath]()
        // 非该节点的需要发生改变的索引
		var extraIndexPaths = [IndexPath]()
        // 改节点的子section节点
		var subSectionIndexSet = IndexSet()

		// 第一个section中所有属于该section的Cell的indexPath
		subIndexPaths = currentSection.cellElements
			.enumerated()
			.map { offset, _ in IndexPath(row: offset, section: section) }

		switch currentNodeSections.count {
		case 1:
			guard !subIndexPaths.isEmpty else { return .none }
		default:
            let count = currentNodeSections.count
            let lastSectionBeforeChange = sections[section + count - 1]
            
            lastSectionBeforeChange.cellElements
                .filter { item in
                    let id = item.superIdentifier
                    return id != lastSectionBeforeChange.id && id != currentSection.id
                }
                .enumerated()
                .forEach { offset, element in
                    extraIndexPaths.append(.init(row: offset, section: section))
                }
            
            
            subSectionIndexSet = IndexSet((1..<currentNodeSections.count).map { $0 + section })
		}

		return .expand == state
			? .init(
				insertIndexPaths: subIndexPaths,
				removeIndexPaths: extraIndexPaths,
				insertIndexSet: subSectionIndexSet,
				removeIndexSet: .init()
			)
			: .init(
				insertIndexPaths: extraIndexPaths,
				removeIndexPaths: subIndexPaths,
				insertIndexSet: .init(),
				removeIndexSet: subSectionIndexSet
			)
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
		let sections = generateSections(isOnlyExpand: flag)
		guard sections.count > 1 else { return [] }
		return sections.suffix(sections.count - 1)
	}
	
	private enum NodeElementData {
        case section(element: Element, cellElements: [Element], state: BranchNodeState)
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
                    return [.section(element: element, cellElements: [], state: state)]
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
                        case let .section(element, subs, state):
                            let section = NodeElementData.section(
                                element: element,
                                cellElements: subs + Array(elements.reversed()),
                                state: state
                            )
                            elements.removeAll()
                            return section
                        }
                    }
                    .reversed()
                
                return [.section(element: element, cellElements: elements.reversed(), state: state)]
                    + subNodeSectionDatas
			}
		}
		
        return generate(node: self)
            .compactMap {
                if case let .section(element, elements, state) = $0 {
                    return Section(element: element, cellElements: elements, state: state)
                } else {
                    return nil
                }
            }
    }
}
