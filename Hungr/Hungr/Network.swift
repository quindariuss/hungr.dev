//
//  Network.swift
//  Hungr
//
//  Created by Quin’darius Lyles-Woods on 11/6/22.
//

import Foundation

class Network {
    static let shared = Network()
    let decoder = JSONDecoder()
    
    func deleteList(name: String) async {
        do {
            var components = URLComponents(url: URL.listURL, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "name", value: name)
            ]
            
            var request = URLRequest(url: components.url!)
            request.httpMethod = "DELETE"
            
            let (data, response) = try await URLSession.shared.data(for: request)
            print(String(data: data, encoding: .utf8), response)
        } catch {
            print(error)
        }
    }
    
    func deleteItem(id: Int) async {
        do {
            var components = URLComponents(url: URL.itemsURL, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "id", value: id.formatted(.number)),
            ]
            
            var request = URLRequest(url: components.url!)
            request.httpMethod = "DELETE"
            
            let (data, response) = try await URLSession.shared.data(for: request)
            print(String(data: data, encoding: .utf8), response)
        } catch {
            print(error)
        }
    }
    
    func addItem(item: String, list: GroceryList) async {
        do {
            var components = URLComponents(url: URL.itemsURL, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "name", value: item),
                URLQueryItem(name: "count", value: "1"),
                URLQueryItem(name: "groceryList", value: list.name)
            ]
            
            var request = URLRequest(url: components.url!)
            request.httpMethod = "POST"
            
            let (data, response) = try await URLSession.shared.data(for: request)
            print(String(data: data, encoding: .utf8), response)
        } catch {
            print(error)
        }
    }
    
    func updateItem(item: GroceryListItem) async {
        do {
            var components = URLComponents(url: URL.itemsURL, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "name", value: item.name),
                URLQueryItem(name: "count", value: item.count.formatted(.number)),
                URLQueryItem(name: "note", value: item.note),
                URLQueryItem(name: "id", value: item.id.formatted(.number))
            ]
            
            var request = URLRequest(url: components.url!)
            request.httpMethod = "PATCH"
            
            let (data, response) = try await URLSession.shared.data(for: request)
            print(String(data: data, encoding: .utf8), response)
            
        } catch {
            print(error)
        }
    }
    func getItems(groceryList: GroceryList) async -> [GroceryListItem] {
        do {
            var components = URLComponents(url: URL.itemsURL, resolvingAgainstBaseURL: false)
            components?.queryItems = [
                URLQueryItem(name: "groceryList", value: groceryList.name)
            ]
            var request = URLRequest(url: components!.url!)
            request.httpMethod = "GET"
            
            let (data , _ ) = try await URLSession.shared.data(for: request)
            print((String(data: data, encoding: .utf8) ?? ""))
            let jsonData = try decoder.decode([GroceryListItem].self, from: data)
            return jsonData
        } catch {
            print(error)
            return [GroceryListItem]()
        }
    }
    func getList() async -> [GroceryList] {
        do {
            
            let (data, _ ) = try await  URLSession.shared.data(from: URL.listURL)
            print(String(data: data, encoding: .utf8) ?? "")
            let jsonData = try decoder.decode([GroceryList].self, from: data)
            return jsonData
        } catch {
            print(error)
            return [GroceryList]()
        }
        
    }
}

extension URL {
    static let baseURL = URL(string:"https://api.hungr.dev")!
    static let itemsURL = baseURL.appending(path: "items")
    static let listURL = baseURL.appending(path: "groceryList")
    static let loginURL = baseURL.appending(path: "login")
    static let signUpURL = baseURL.appending(path: "signup")
}


// Models

struct GroceryList: Codable, Identifiable, Equatable {
    var id = UUID()
    let name: String
    
    enum CodingKeys: CodingKey {
        case name
    }
}

struct GroceryListItem: Codable, Identifiable, Equatable {
    var id: Int
    var name: String
    var count: Int
    var note: String?
    var groceryList: String
}
