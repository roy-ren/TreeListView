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
	var state: TreeNodeState { get }
	
	static var emptyRootElement: Self { get }
}

public struct TreeSectionElement<Element: TreeElementProtocol>: Identifiable, Equatable {
	public static func == (lhs: TreeSectionElement<Element>, rhs: TreeSectionElement<Element>) -> Bool {
		lhs.id == rhs.id
			&& lhs.element == rhs.element
			&& lhs.cellElements == rhs.cellElements
	}
	
	public var element: Element
	public var cellElements: [Element]
	
	public var id: Element.ID { element.id }
	public var superSectionID: Element.ID? { element.superIdentifier }
}

public struct TableSourceTree<Element: TreeElementProtocol> {

	public typealias Node = TreeNode<Element>
	public var root: Node!
	
	public typealias Section = TreeSectionElement<Element>
	public private(set) var sections: [Section]
	
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
						
						print("nodes: \(nodes.map { $0.data.element }) superID: \(String(describing: superID))")
						subNodesInfo.updateValue(nodes, forKey: superID)
					}
			}
		
		if let node = subNodesInfo[.none]?.first {
			root = .branch(data: .emptyRootElement, subNodes: [node], state: .expand)
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
		case insert(change: Change)
		case delete(change: Change)
			
        public enum Change {
			case cell(indexPathes: [IndexPath])
			case section(indexSet: IndexSet)
		}
	}
	
	public mutating func toggle(sectionAt index: Int) -> EditChange? {
		// 1. search node
        // 每个section的superSection一定在它的前面
		let secitonInfos = Dictionary(grouping: sections[0..<index], by: { $0.id })
		
		var pathIdentifiers = [sections[index].id]
		var element: Element? = sections[index].element
		
		while let id = element?.superIdentifier {
			pathIdentifiers.append(id)
			element = secitonInfos[id]?.first?.element
		}
		
        root = toggleNode(for: pathIdentifiers, in: root)
        sections = root.emptyRootSections(isOnlyExpand: false)
//        guard
//            !pathIdentifiers.isEmpty,
//            var toggleNode = searchNode(for: pathIdentifiers, in: root)
//        else {
//			return nil
//		}
//
//        toggleNode.toggle()
		
		return nil
	}
    
    private func toggleNode(for path: [Element.ID], in node: Node) -> Node {
        print("toggleNode: \(node.data.element) path: \(path)")
        
        var currentPath = path
        let id = currentPath.removeLast()
        var node = node
        
        guard
            let subNodeIndex = node.subNodes?.firstIndex(where: { $0.data.id == id }),
            var subNode = node.subNodes?[subNodeIndex]
        else {
            fatalError("code not found")
        }
        
        if currentPath.isEmpty {
            subNode.toggle()
        } else {
            subNode = toggleNode(for: currentPath, in: subNode)
        }
        
        node.replace(subNode: subNode, at: subNodeIndex)
        
        return node
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
                
                print("\(element.element) state: \(state)")
				
				var elements = [Element]()
					
				let subNodeSectionDatas: [NodeElementData] = subNodes
					.flatMap(generate(node:))
					.compactMap {
						if case let .cell(element) = $0 {
							elements.append(element)
							return nil
						} else {
							return $0
						}
					}
				
				return [.section(element: element, cellElements: elements)] + subNodeSectionDatas
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
