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
        NavigationView {
            GroceryListView()
                .navigationTitle("Grocery Lists")
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
