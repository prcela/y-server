//
//  Player.swift
//  VaporApp
//
//  Created by Kresimir Prcela on 08/09/16.
//
//

import Foundation
import Vapor
import MongoKitten

class Player
{
    static var players = [Player]()
    
    var id: String
    var alias: String
    var diamonds: Int64
    
    // izračunato
    var avgScore5: Double = 0
    var avgScore6: Double = 0
    var connected = true
    var disconnectedAt: Date?
    
    
    init(json: JSON)
    {
        id = json["id"]!.string!
        alias = json["alias"]!.string!
        avgScore6 = json["avg_score_6"]!.double!
        diamonds = Int64(json["diamonds"]!.int!)
    }
    
    init(document: Document)
    {
        id = document["_id"].string
        alias = document["alias"].string
        diamonds = document["diamonds"].int64
    }
    
    func update(json: JSON)
    {
        alias = json["alias"]!.string!
        diamonds = Int64(json["diamonds"]!.int!)
        avgScore6 = json["avg_score_6"]!.double!
    }
    
    
    func node() -> Node
    {
        return Node([
            "id":Node(id),
            "alias":Node(alias),
            "avg_score_6":Node(avgScore6),
            "diamonds":Node(Int(diamonds)),
            "connected": Node(connected)])
    }
    
    func document() -> Document
    {
        let doc: Document = [
            "_id": .string(id),
            "alias": .string(alias),
            "diamonds": .int64(diamonds)
        ]
        return doc
    }
    
    class func loadPlayers()
    {
        players.removeAll()
        if let array = try? playersCollection.find().array
        {
            for document in array
            {
                players.append(Player(document: document))
            }
        }
    }
    
    class func find(id: String) -> Player?
    {
        for p in players
        {
            if p.id == id
            {
                return p
            }
        }
        return nil
    }
}
