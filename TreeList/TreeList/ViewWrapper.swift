//
//  ViewWrapper.swift
//  TreeList
//
//  Created by roy on 2020/11/4.
//

import UIKit
import SwiftUI

struct ViewWrapper<Controller: UIViewController>: UIViewControllerRepresentable {
    typealias UIViewControllerType = Controller

    func makeUIViewController(
        context: UIViewControllerRepresentableContext<Self>
    ) -> Self.UIViewControllerType {
        .init()
    }

    func updateUIViewController(
        _ uiViewController: Self.UIViewControllerType,
        context: UIViewControllerRepresentableContext<Self>
    ) {}
}
