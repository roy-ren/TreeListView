//
//  ContentView.swift
//  TreeList
//
//  Created by roy on 2020/11/3.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            List(Feature.allCases) { feature in
                NavigationLink(destination: ViewWrapper<TreeListViewController>()) {
                    Text(feature.rawValue)
                        .fontWeight(.bold)
                }
            }
        }
    }
}

enum Feature: String, CaseIterable, Identifiable {
    case treeListView = "Tree list view."
    
    var id: String { rawValue }
    
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
