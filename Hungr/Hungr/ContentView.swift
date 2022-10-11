//
//  ContentView.swift
//  Hungr
//
//  Created by Quin’darius Lyles-Woods on 8/23/22.
//

import SwiftUI

struct ContentView: View {
    @State var items = [ListItem]()
    @State var itemName = ""
    var body: some View {
        NavigationStack {
            
            VStack {
                TextField("Item Name",
                          text: $itemName
                )
                .onSubmit {
                    items.append(ListItem(name: itemName, price: 1, addedAt: Date())
                    )
                }
                .textFieldStyle(.roundedBorder)
                .padding()
                List(items) { item in
                    VStack {
                        HStack {
                            Text(item.name)
                            Spacer()
                            Text("$ \(item.price)")
                        }
                        HStack {
                            Text("Quin'darius")
                                .padding(.all, 3)
                                .background(Color.teal)
                                .cornerRadius(5)
                            Spacer()
                            Text(item.addedAt.formatted())
                        }
                    }
                }
            }
            .navigationTitle("Hungr")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing){
                    Button {
                        print("Add Item")
                    } label: {
                        Image(systemName: "cart.badge.plus")
                    }
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct ListItem: Codable, Identifiable {
    
    var id = UUID()
    let name: String
    let user: String
    let price: Int
    let store: String
    let addedAt: Date
}
