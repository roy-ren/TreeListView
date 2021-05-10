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

class TreeListViewController: UIViewController {
    
    private let listView: TreeListStaticView<Cell>
    
    static var elements: [Element] = [
        .init(id: 0, element: 0, level: 0, superIdentifier: nil, rank: 0, state: .expand),
        .init(id: 1, element: 1, level: 1, superIdentifier: 0, rank: 0, state: .expand),
        .init(id: 11, element: 11, level: 2, superIdentifier: 1, rank: 0, state: .expand),
        .init(id: 12, element: 12, level: 2, superIdentifier: 1, rank: 1, state: .expand),
        .init(id: 121, element: 121, level: 3, superIdentifier: 12, rank: 0, state: .expand),
        .init(id: 13, element: 13, level: 2, superIdentifier: 1, rank: 2, state: .expand),
        .init(id: 2, element: 2, level: 1, superIdentifier: 0, rank: 1, state: .expand),
        .init(id: 21, element: 21, level: 2, superIdentifier: 2, rank: 0, state: .expand),
        .init(id: 211, element: 211, level: 3, superIdentifier: 21, rank: 0, state: .expand),
        .init(id: 3, element: 3, level: 1, superIdentifier: 0, rank: 2, state: .expand),
        .init(id: 100, element: 100, level: 0, superIdentifier: nil, rank: 0, state: .expand)
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
        private let iconImageView = UIImageView()
        private let label = UILabel()
        private var iconLeadingConstraint: NSLayoutConstraint!
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            iconImageView.rl.added(to: self, andLayout: {
                $0.size == CGSize(width: 20, height: 20)
                $0.centerY == $1.centerY
            })
            
            iconLeadingConstraint = iconImageView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 15)
            iconLeadingConstraint.isActive = true
            
            label.rl.added(to: self) {
                $0.leading == iconImageView.rl.trailing + 8
                $0.trailing == -15
                $0.centerY == $1.centerY
            }
            
            label.font = .systemFont(ofSize: 14)
            backgroundColor = .systemBackground
        }
        
        required convenience init() {
            self.init(frame: .zero)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func config(with item: ListViewItem<Element>) {
            let element = item.element
            let leading = CGFloat(element.level) * 30
            iconLeadingConstraint.constant = 15 + leading
            
            switch item {
            case .cell:
                let imageConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .ultraLight, scale: .default)
                iconImageView.image = UIImage(systemName: "doc", withConfiguration: imageConfig)
            case .section:
                iconImageView.image = UIImage(systemName: "folder.fill")
            }
            
            label.text = "\(element.element)" + "  state: \(item.element.state)"
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
            .init(id: -1, element: -1, level: 0, superIdentifier: nil, rank: 0, state: .expand)
        }
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }
    }
}

extension TreeListViewController: TreeListViewDelegate {
    var itemHeight: CGFloat { 100 }
    
    func treeListView<Cell>(
        _ listView: TreeListStaticView<Cell>,
        didSelected element: ListViewItem<Cell.Element>,
        of cell: Cell
    ) where Cell : ListViewCellProtocol {
        print("tapped: \(element.element.element)")
    }
}
