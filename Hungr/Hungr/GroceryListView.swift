//
//  GroceryListView.swift
//  Hungr
//
//  Created by Quin’darius Lyles-Woods on 11/6/22.
//

import SwiftUI

struct GroceryListView: View {
    @State var lists = [GroceryList]()
    var body: some View {
        List {
            ForEach($lists) { $list in
                NavigationLink(list.name) {
                    GroceryListItemsView(list: $list)
                }
            }
        }
        .task {
            let gatheredList = await Network.shared.getList()
            if gatheredList != [] {
                lists = gatheredList
            }
        }
    }
}

struct GroceryListView_Previews: PreviewProvider {
    static var previews: some View {
        GroceryListView()
    }
}
