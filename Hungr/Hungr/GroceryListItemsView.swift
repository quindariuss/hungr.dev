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
    @State var newItem = ""
    @State var searchTerm = ""
    var body: some View {
        List {
            HStack {
                TextField("New Item", text: $newItem)
                Spacer()
                Button("Add") {
                    Task {
                        await Network.shared.addItem(item: newItem , list: list)
                        items = await Network.shared.getItems(groceryList: list)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
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
            .onDelete(perform: { index in
                Task {
                    await Network.shared.deleteItem(id: items[index.first!].id)
                }
            })
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
