//
//  TreeListViewController.swift
//  TreeList
//
//  Created by roy on 2020/11/3.
//

import UIKit
import TreeListView
import RLayoutKit
import SwiftUI

struct ListViewControllerWrapper: UIViewControllerRepresentable {
    typealias UIViewControllerType = TreeListViewController

    func makeUIViewController(context: UIViewControllerRepresentableContext<ListViewControllerWrapper>) -> ListViewControllerWrapper.UIViewControllerType {
        .init()
    }

    func updateUIViewController(_ uiViewController: ListViewControllerWrapper.UIViewControllerType, context: UIViewControllerRepresentableContext<ListViewControllerWrapper>) {
        //
    }
}

class TreeListViewController: UIViewController {
    
    private let listView: TreeListStaticView<Cell>
    
    static var elements: [Element] = [
        .init(id: 0, element: 0, level: 0, superIdentifier: nil, rank: 0, state: .expand),
        .init(id: 1, element: 1, level: 1, superIdentifier: 0, rank: 0, state: .expand),
        .init(id: 2, element: 2, level: 1, superIdentifier: 0, rank: 1, state: .expand),
        .init(id: 3, element: 3, level: 2, superIdentifier: 1, rank: 0, state: .expand),
        .init(id: 4, element: 4, level: 2, superIdentifier: 1, rank: 1, state: .expand),
        .init(id: 5, element: 5, level: 3, superIdentifier: 2, rank: 0, state: .expand),
        .init(id: 6, element: 6, level: 4, superIdentifier: 4, rank: 0, state: .expand),
        .init(id: 7, element: 7, level: 4, superIdentifier: 5, rank: 0, state: .expand)
    ]
        
    init() {
        listView = .init(elements: Self.elements)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
        listView.delegate = self
        listView.rl.added(to: view) {
            $0.edges == $1.edges
        }
    }
}

extension TreeListViewController {
    class Cell: UIView, ListViewCellProtocol {
        
        private let label = UILabel()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            label.rl.added(to: self) {
                $0.leading == 15
                $0.trailing == -15
                $0.centerY == $1.centerY
            }
            
            label.font = .systemFont(ofSize: 14)
//            backgroundColor = .systemBackground
        }
        
        required convenience init() {
            self.init(frame: .zero)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func config(with element: Element) {
            let spacing = (0...element.level).reduce("") { result, _ in
                result + "-="
            }
            
            label.text = spacing + "\(element.element)" + "state: \(element.state)"
        }
    }
    
    struct Element: TreeElementProtocol {
        let id: Int
        var element: Int
        var level: Int
        var superIdentifier: Int?
        var rank: Int
        var state: BranchNodeState
        
        static var emptyRootElement: Element {
            .init(id: 0, element: 0, level: 0, superIdentifier: nil, rank: 0, state: .expand)
        }
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }
    }
}

extension TreeListViewController: TreeListViewDelegate {
    
    var itemHeight: CGFloat { 50 }
    
    func treeListView<Cell>(
        _ listView: TreeListStaticView<Cell>,
        didSelected element: Cell.Element,
        of cell: Cell
    ) where Cell : ListViewCellProtocol {
        print("tapped: \(element.element)")
    }
}

extension Sequence {
    func des() {
        var iterator = makeIterator()
        
        var index = 0
        
        while let element = iterator.next() {
            print("index: \(index), element == \(element)")
            index += 1
        }
    }
}
