import XCTest
@testable import TreeListView

final class TreeListViewTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
    }

    static var allTests = [
        ("testExample", testExample),
    ]
    
    func testNode() {
        typealias Node = TreeNode<Int>
        
        let nodeLeaf = Node(data: 1)
        let nodeLeaf2 = Node(data: 2)
        let nodeBranch = Node(data: 1, subNodes: [.init(data: 2)])
        
        // init
        XCTAssertEqual(nodeLeaf, Node.leaf(data: 1))
        XCTAssertEqual(nodeBranch, Node.branch(data: 1, subNodes: [.leaf(data: 2)], state: .expand))
        
        // data
        XCTAssertTrue(1 == nodeLeaf.data)
        XCTAssertTrue(1 == nodeBranch.data)
        
        // hasSubNodes
        XCTAssertFalse(nodeLeaf.hasSubNodes)
        XCTAssertTrue(nodeBranch.hasSubNodes)
        
        // subNodes
        XCTAssertNil(nodeLeaf.subNodes)
        XCTAssertEqual([nodeLeaf2], nodeBranch.subNodes)
        
        // subNodeCount
        XCTAssertEqual(1, nodeBranch.subNodeCount)
        
        let count = Int.random(in: (4...8))
        let nodes = (0..<count).map { Node(data: $0) }
        XCTAssertEqual(count, Node(data: 0, subNodes: nodes).subNodeCount)
        
        // toggle
        var branchNodeT = Node(data: 10, subNodes: [nodeLeaf], state: .collapse)
        branchNodeT.toggle()
        XCTAssertEqual(branchNodeT, Node(data: 10, subNodes: [nodeLeaf], state: .expand))
        
        // update
        var originNode = nodeLeaf
        originNode.update(element: 3)
        var originNode1 = nodeBranch
        originNode1.update(element: 3)
        
        XCTAssertEqual(originNode, Node.leaf(data: 3))
        XCTAssertEqual(originNode1, Node.branch(data: 3, subNodes: [nodeLeaf2], state: .expand))

        // append
        originNode.append(subNodes: nodeLeaf)
        XCTAssertEqual(originNode, Node.branch(data: 3, subNodes: [nodeLeaf], state: .expand))
        originNode1.append(subNodes: nodeLeaf)
        XCTAssertEqual(originNode1, Node.branch(data: 3, subNodes: [nodeLeaf2, nodeLeaf], state: .expand))
        
        // replace
        originNode.replace(subNodes: [nodeLeaf2])
        XCTAssertEqual(originNode, Node(data: 3, subNodes: [nodeLeaf2]))
        originNode1.replace(subNodes: [nodeLeaf2])
        XCTAssertEqual(originNode1, Node(data: 3, subNodes: [nodeLeaf2]))
        
        var leafNodeReplace = Node(data: 2)
        XCTAssertFalse(leafNodeReplace.replace(subNode: nodeLeaf, at: 1))
        var branchNodeReplace = Node(data: 5, subNodes: nodes)
        XCTAssertTrue(branchNodeReplace.replace(subNode: nodeLeaf, at: 0))
        
        // insert
        let newLeafNode = Node.leaf(data: 4)
        XCTAssertFalse(originNode.insert(subNode: newLeafNode, at: 2))
        XCTAssertTrue(originNode.insert(subNode: newLeafNode, at: 0))
        XCTAssertEqual(originNode, Node(data: 3, subNodes: [newLeafNode, nodeLeaf2]))
        
        // remove
        XCTAssertNil(originNode.remove(at: 2))
        XCTAssertEqual(originNode.remove(at: 0), newLeafNode)
        XCTAssertEqual(originNode, Node.branch(data: 3, subNodes: [nodeLeaf2], state: .expand))
        
        // remove all
        var branchNode2 = Node(data: 5, subNodes: nodes)
        var leafNode2 = Node(data: 5)
        XCTAssertEqual(branchNode2.removeAllSubNodes(), nodes)
        XCTAssertEqual(branchNode2, leafNode2)
        XCTAssertNil(leafNode2.removeAllSubNodes())
        
        print(leafNode2)
    }
    
    func testTableSourceTree() {
        struct Element: TreeElementProtocol {
            static func == (lhs: Element, rhs: Element) -> Bool {
                lhs.id == rhs.id
            }
            
            let id: Int
            var element: Int
            var level: Int
            var superIdentifier: Int?
            var rank: Int
            var state: TreeNodeState
            
            static var emptyRootElement: Element {
                .init(id: 0, element: 0, level: 0, superIdentifier: nil, rank: 0, state: .expand)
            }
        }
        
        let element0 = Element(id: 0, element: 0, level: 0, superIdentifier: nil, rank: 0, state: .expand)
        let element1 = Element(id: 1, element: 1, level: 1, superIdentifier: 0, rank: 0, state: .expand)
        var element2 = Element(id: 2, element: 2, level: 1, superIdentifier: 0, rank: 1, state: .expand)
        let element3 = Element(id: 3, element: 3, level: 2, superIdentifier: 1, rank: 0, state: .expand)
        var element4 = Element(id: 4, element: 4, level: 2, superIdentifier: 1, rank: 1, state: .expand)
        let element5 = Element(id: 5, element: 5, level: 3, superIdentifier: 2, rank: 0, state: .expand)
        let element6 = Element(id: 6, element: 6, level: 4, superIdentifier: 4, rank: 0, state: .expand)
        let element7 = Element(id: 7, element: 7, level: 4, superIdentifier: 5, rank: 0, state: .expand)
        
        var elements: [Element] {
            [element0,
             element1,
             element2,
             element3,
             element4,
             element5,
             element6,
             element7]
        }
        
        let source = TableSourceTree(source: elements)
        
        typealias SectionElement = TreeSectionElement<Element>
        let sections: [SectionElement] = [
            SectionElement(element: element0, cellElements: []),
            SectionElement(element: element1, cellElements: [element3]),
            SectionElement(element: element4, cellElements: [element6]),
            SectionElement(element: element2, cellElements: []),
            SectionElement(element: element5, cellElements: [element7]),
        ]
        
        XCTAssertEqual(sections, source.sections)
        
        // toggle
        element2 = Element(id: 2, element: 2, level: 1, superIdentifier: 0, rank: 1, state: .collapse)
        element4 = Element(id: 4, element: 4, level: 2, superIdentifier: 1, rank: 1, state: .collapse)
        
        let source2 = TableSourceTree(source: elements)
        let sections2: [SectionElement] = [
            SectionElement(element: element0, cellElements: []),
            SectionElement(element: element1, cellElements: [element3]),
            SectionElement(element: element4, cellElements: []),
            SectionElement(element: element2, cellElements: [])
        ]
        
        XCTAssertEqual(sections2, source2.sections)
    }
}
