//
//  GroceryListItemsView.swift
//  Hungr
//
//  Created by Quin’darius Lyles-Woods on 11/6/22.
//

import SwiftUI

struct GroceryListItemsView: View {
    @Binding var list: GroceryList
    @State var items = [GroceryListItem]()
    var body: some View {
        List {
            ForEach($items) { $item in
                
                NavigationLink {
                    EdititemView(item: $item)
                } label: {
                    
                HStack {
                        Button {
                            print("Completed Item")
                        } label: {
                            Image(systemName: "squareshape")
                        }
                        Text(item.name)
                    Spacer()
                }
                }
            }
            .navigationTitle(list.name)
        }
        .task {
            items = await Network.shared.getItems(groceryList: list)
        }
    }
}

//struct GroceryListItemsView_Previews: PreviewProvider {
//    static var previews: some View {
//        GroceryListItemsView()
//    }
//}
