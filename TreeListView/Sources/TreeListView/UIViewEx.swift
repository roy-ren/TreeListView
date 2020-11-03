//
//  File.swift
//  
//
//  Created by roy on 2020/11/3.
//

import UIKit

extension UIView {
	func addedAsContent(toSuper view: UIView) {
		translatesAutoresizingMaskIntoConstraints = false
		
		view.addSubview(self)
		
		NSLayoutConstraint.activate([
			leadingAnchor.constraint(equalTo: view.leadingAnchor),
			topAnchor.constraint(equalTo: view.topAnchor),
			trailingAnchor.constraint(equalTo: view.trailingAnchor),
			bottomAnchor.constraint(equalTo: view.bottomAnchor)
		])
	}
}

extension UITableView {
	func register<Cell: UITableViewCell>(
		cell type: Cell.Type
	) where Cell: Registrable {
		register(Cell.self, forCellReuseIdentifier: Cell.identifier)
	}
	
	func register<HeaderFooter: UITableViewHeaderFooterView>(
		headerFooter type: HeaderFooter.Type
	) where HeaderFooter: Registrable {
		register(HeaderFooter.self, forHeaderFooterViewReuseIdentifier: HeaderFooter.identifier)
	}
	
	func dequeueReusableCell<Cell>(forRowAt indexPath: IndexPath? = nil) -> Cell where Cell: Registrable {
		if let index = indexPath {
			return dequeueReusableCell(withIdentifier: Cell.identifier, for: index) as! Cell
		} else {
			return dequeueReusableCell(withIdentifier: Cell.identifier) as! Cell
		}
	}
	
	func dequeueReusableHeaderFooter<HeaderFooter: UITableViewHeaderFooterView>() -> HeaderFooter where HeaderFooter: Registrable {
		dequeueReusableHeaderFooterView(withIdentifier: HeaderFooter.identifier) as! HeaderFooter
	}
}
