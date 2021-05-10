//
//  Stack.swift
//
//
//  Created by roy on 2021/4/22.
//

import Foundation

public struct Stack<Element> {
    private var elements: [Element]
    
    public init() {
        elements = .init()
    }
}

extension Stack {
    var isEmpty: Bool {
        elements.isEmpty
    }
    
    var top: Element? {
        elements.last
    }
    
    mutating func push(item: Element) {
        elements.append(item)
    }
    
    mutating func push(items: [Element]) {
        elements.append(contentsOf: items)
    }
    
    mutating func push(items: Element...) {
        elements.append(contentsOf: items)
    }
    
    @discardableResult
    mutating func pop() -> Element? {
        guard !elements.isEmpty else {
            return nil
        }
        
        return elements.removeLast()
    }
}
