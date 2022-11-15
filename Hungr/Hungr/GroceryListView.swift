//
//  GroceryListView.swift
//  Hungr
//
//  Created by Quin’darius Lyles-Woods on 11/6/22.
//

import SwiftUI

struct GroceryListView: View {
    @State var lists = [GroceryList]()
    @State var search = ""
    @State var searchingList = [GroceryList]()
    var filteredList: [GroceryList] {
        if search.isEmpty {
            return lists
        } else {
            return lists.filter { $0.name.localizedCaseInsensitiveContains(search) }
        }
    }
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
        .searchable(text: $search) {
            ForEach($searchingList) { $list in

                NavigationLink(list.name) {
                    GroceryListItemsView(list: $list)
                }
            }
        }
        .onChange(of: search) { newValue in
            
            searchingList = lists.filter({ GroceryList in
                if newValue.isEmpty {
                    return true
                }
                return GroceryList.name.contains(newValue)
            })
            }
    }
}

struct GroceryListView_Previews: PreviewProvider {
    static var previews: some View {
        GroceryListView()
    }
}
