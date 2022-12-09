//
//  EdititemView.swift
//  Hungr
//
//  Created by Quin’darius Lyles-Woods on 11/7/22.
//

import SwiftUI

struct EdititemView: View {
    @Binding var item: GroceryListItem
    var body: some View {
        Form {
            Section("Name") {
                
            TextField("Name", text: $item.name)
            }
                Section("Count") {
            Stepper(value: $item.count, step: 1) {
                    Text(item.count, format: .number)
                }
            }
            Section("Notes") {
                TextEditor(text: Binding(
                    get: { item.note ?? ""} ,
                    set: { item.note = $0 }))
                .frame(minHeight: 100)
            }
            
        }
        .navigationTitle(item.name)
        .onChange(of: item) { newValue in
            Task {
                await Network.shared.updateItem(item: item)
            }
        }
        }
    }
    
    //struct EdititemView_Previews: PreviewProvider {
    //    static var previews: some View {
    //        EdititemView()
    //    }
    //}
