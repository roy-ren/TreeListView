//
//  TreeNode.swift
//  
//
//  Created by roy on 2020/10/29.
//

import Foundation

public enum BranchNodeState {
	/// 展开状态
	case expand
	/// 闭合状态
	case collapse
	
	mutating func toggle() {
		self = .expand == self ? .collapse : .expand
	}
}

public indirect enum TreeNode<Element> {
	case leaf(data: Element)
	case branch(data: Element, subNodes: [Self], state: BranchNodeState)
	
	public init(data: Element, subNodes: [Self]? = nil, state: BranchNodeState = .expand) {
		if let nodes = subNodes {
			self = .branch(data: data, subNodes: nodes, state: state)
		} else {
			self = .leaf(data: data)
		}
	}
	
	public var data: Element {
		switch self {
		case .leaf(let data):
			return data
		case .branch(let data, _, _):
			return data
		}
	}
	
	public var hasSubNodes: Bool {
		nil != subNodes
	}
	
	public var subNodes: [TreeNode]? {
		switch self {
		case .leaf:
			return nil
		case .branch(_, let nodes, _):
			return nodes
		}
	}
	
	public var subNodeCount: Int {
		subNodes?.count ?? 0
	}
	
	public mutating func toggle() {
		guard case .branch(let data, let subNodes, var state) = self else { return }
		state.toggle()
		self = .branch(data: data, subNodes: subNodes, state: state)
	}
	
	public mutating func update(element: Element) {
		switch self {
		case let .branch(_, subNodes, state):
			self = .branch(data: element, subNodes: subNodes, state: state)
		default:
			self = .leaf(data: element)
		}
	}

	public mutating func append(subNodes nodes: TreeNode...) {
		switch self {
		case let .branch(data, subNodes, state):
			self = .branch(data: data, subNodes: subNodes + nodes, state: state)
		default:
			self = .branch(data: data, subNodes: nodes, state: .expand)
		}
	}
	
	public mutating func append(subNodes nodes: [TreeNode]) {
		switch self {
		case let .branch(data, subNodes, state):
			self = .branch(data: data, subNodes: subNodes + nodes, state: state)
		default:
			self = .branch(data: data, subNodes: nodes, state: .expand)
		}
	}
	
	public mutating func replace(subNodes nodes: [TreeNode]) {
		switch self {
		case let .branch(data, _, state):
			self = .branch(data: data, subNodes: nodes, state: state)
		default:
			self = .branch(data: data, subNodes: nodes, state: .expand)
		}
	}
    
    @discardableResult
    public mutating func replace(subNode node: TreeNode, at index: Int) -> Bool {
        switch self {
        case .branch(_, var nodes, _):
            guard index >= 0 && index < nodes.count else { return false }
            nodes.replaceSubrange((index...index), with: [node])
            replace(subNodes: nodes)
            
            return true
        default:
            return false
        }
    }
	
	@discardableResult
	public mutating func insert(subNode node: TreeNode, at index: Int) -> Bool {
		guard index >= 0 && index <= subNodeCount else { return false }
		
		switch self {
		case .branch(let data, var subNodes, let state):
			subNodes.insert(node, at: index)
			self = .branch(data: data, subNodes: subNodes, state: state)
		default:
			self = .branch(data: data, subNodes: [node], state: .expand)
		}
		
		return true
	}
	
	@discardableResult
	public mutating func remove(at index: Int) -> TreeNode? {
		guard index >= 0 && index <= subNodeCount - 1 else { return nil }
		
		var nodes = subNodes ?? []
		let removed = nodes.remove(at: index)
		
		if nodes.isEmpty {
			self = .leaf(data: data)
		} else {
			replace(subNodes: nodes)
		}
		
		return removed
	}
	
	public mutating func removeAllSubNodes() -> [TreeNode]? {
		let removedNodes = subNodes
		self = .leaf(data: data)
		return removedNodes
	}
}

extension TreeNode: Equatable where Element: Equatable {}
