//
//  StatItem.swift
//  y-server
//
//  Created by Kresimir Prcela on 15/11/16.
//
//

import Foundation
import MongoKitten
import Vapor

class StatItem
{
    static var allStatItems = [StatItem]()
    
    let player_id: String
    let match_type: String
    let dice_num: Int32
    let score: Int32
    let result: Int32
    let bet: Int32
    let timestamp: Date
    
    init(json: JSON)
    {
        player_id = json["player_id"]!.string!
        match_type = json["match_type"]!.string!
        dice_num = Int32(json["dice_num"]!.int!)
        score = Int32(json["score"]!.int!)
        result = Int32(json["result"]!.int!)
        bet = Int32(json["bet"]!.int!)
        timestamp = Date()
    }
    
    init(document: Document)
    {
        player_id = document["player_id"].string
        match_type = document["match_type"].string
        dice_num = document["dice_num"].int32
        score = document["score"].int32
        result = document["result"].int32
        bet = document["bet"].int32
        timestamp = document["timestamp"].dateValue!
    }
    
    func document() -> Document
    {
        let doc: Document = [
            "player_id": .string(player_id),
            "match_type": .string(match_type),
            "dice_num": .int32(dice_num),
            "score": .int32(score),
            "result": .int32(result),
            "bet": .int32(bet),
            "timestamp": .dateTime(timestamp)
        ]
        
        return doc
    }
    
    func node() -> Node
    {
        let timeInterval = timestamp.timeIntervalSince1970
        let dic: [String:Node] = [
            "player_id": Node(player_id),
            "match_type": Node(match_type),
            "dice_num": Node(Int(dice_num)),
            "score": Node(Int(score)),
            "result": Node(Int(result)),
            "bet": Node(Int(bet)),
            "timestamp": Node(timeInterval)
            ]
        return Node(dic)
    }
    
    class func loadStats()
    {
        allStatItems.removeAll()
        if let array = try? statItemsCollection.find().array
        {
            for document in array
            {
                allStatItems.append(StatItem(document: document))
            }
        }
    }
    
    class func insert(json: JSON) throws
    {
        let statItem = StatItem(json: json)
        allStatItems.append(statItem)
        try statItemsCollection.insert(statItem.document())
    }
}
