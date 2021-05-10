//
//  File.swift
//  
//
//  Created by roy on 2020/11/3.
//

import UIKit

protocol Registrable {}

extension Registrable {
	public static var identifier: String {
		return "\(Self.self)"
	}
}

protocol TreeListViewReuseViewProtocol: Registrable {
	associatedtype ContentView: ListViewCellProtocol
	
	var content: ContentView { get }
}

extension TreeListViewReuseViewProtocol {
	func config(_ element: ListViewItem<ContentView.Element>) {
		content.config(with: element)
	}
}

class TreeListCell<Content: ListViewCellProtocol>: UITableViewCell, TreeListViewReuseViewProtocol {
	let content: Content
	
	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		content = .init()
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		content.addedAsContent(toSuper: contentView)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class TreeListHeader<
    Content: ListViewCellProtocol
>: UITableViewHeaderFooterView, TreeListViewReuseViewProtocol {
	let content: Content
	
	typealias TappedClosure = (Content) -> Void
	var tappedClosure: TappedClosure?
	
	override init(reuseIdentifier: String?) {
		content = .init()
		super.init(reuseIdentifier: reuseIdentifier)
		content.addedAsContent(toSuper: contentView)
		
		let gesture = UITapGestureRecognizer(target: self, action: #selector(didTappedHeader(_:)))
		contentView.addGestureRecognizer(gesture)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
    
    override func prepareForReuse() {
        super.prepareForReuse()
        tappedClosure = nil
    }
	
	@objc
    func didTappedHeader(_ gesture: UITapGestureRecognizer) {
		tappedClosure?(content)
    }
}

