//
//  Network.swift
//  Hungr
//
//  Created by Quin’darius Lyles-Woods on 11/6/22.
//

import Foundation

class Network {
    let shared = Network()
    let decoder = JSONDecoder()
    
    func getList() async -> [GroceryList] {
        do {
            
            let (data, response) = try await  URLSession.shared.data(from: URL.listURL)
            let jsonData = try decoder.decode([GroceryList].self, from: data)
            return jsonData
        } catch {
            print(error)
            return [GroceryList]()
        }
        
    }
}

extension URL {
    static let baseURL = URL(string:"http://api.hungr.dev:5000")!
    static let itemsURL = baseURL.appending(path: "items")
    static let listURL = baseURL.appending(path: "groceryList")
    static let loginURL = baseURL.appending(path: "login")
    static let signUpURL = baseURL.appending(path: "signup")
}


// Models

struct GroceryList: Codable {
    let name: String
}
