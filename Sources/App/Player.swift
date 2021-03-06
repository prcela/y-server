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
    static var all = [String:Player]()
    
    var id: String
    var alias: String
    var diamonds: Int64
    
    // izračunato
    var avgScore5: Double?
    var avgScore6: Double?
    var connected = false
    var disconnectedAt: Date?
    
    var msgCounter: UInt = 0
    var sentMessages = [SentMsg]()
    
    init(json: JSON)
    {
        id = json["id"]!.string!
        alias = json["alias"]!.string!
        diamonds = Int64(json["diamonds"]!.int!)
        avgScore6 = json["avg_score_6"]?.double
        avgScore5 = json["avg_score_5"]?.double
    }
    
    init(document: Document)
    {
        id = document["_id"].string
        alias = document["alias"].string
        diamonds = document["diamonds"].int64
        avgScore5 = document["avg_score_5"].doubleValue
        avgScore6 = document["avg_score_6"].doubleValue
    }
    
    func update(json: JSON)
    {
        alias = json["alias"]!.string!
        diamonds = Int64(json["diamonds"]!.int!)
        avgScore6 = json["avg_score_6"]?.double
        avgScore5 = json["avg_score_5"]?.double
    }
    
    
    func node() -> Node
    {
        var dic: [String:Node] = [
            "id":Node(id),
            "alias":Node(alias),
            "diamonds":Node(Int(diamonds)),
            "connected": Node(connected)]
        
        if avgScore5 != nil
        {
            dic["avg_score_5"] = Node(avgScore5!)
        }
        
        if avgScore6 != nil
        {
            dic["avg_score_6"] = Node(avgScore6!)
        }
        
        return Node(dic)
    }
    
    func document() -> Document
    {
        var doc: Document = [
            "_id": .string(id),
            "alias": .string(alias),
            "diamonds": .int64(diamonds)
        ]
        
        if avgScore5 != nil
        {
            doc["avg_score_5"] = .double(avgScore5!)
        }
        
        if avgScore6 != nil
        {
            doc["avg_score_6"] = .double(avgScore6!)
        }
        
        return doc
    }
    
    func send(json: JSON, ttl: TimeInterval = 15)
    {
        msgCounter += 1
        // create a coy that is unique for player
        var json = json
        print("created copy")
        json["msg_id"] = JSON(Node(msgCounter))
        
        if let socket = Room.main.connections[id]
        {
            socket.send(json)
        }
        
        print("sentmessages.append")
        sentMessages.append(SentMsg(id: msgCounter, timestamp: Date(), ttl:ttl,  json: json))
    }
    
    func deleteExpiredMessages()
    {
        let now = Date()
        for (idx,sentMsg) in sentMessages.enumerated().reversed()
        {
            if sentMsg.timestamp.addingTimeInterval(sentMsg.ttl) < now
            {
                sentMessages.remove(at: idx)
            }
        }
    }
    
    func sendUnsentMessages()
    {
        if let socket = Room.main.connections[id]
        {
            print("sending again messages that are not acknowledged...")
            for sentMsg in sentMessages
            {
                print(id)
                socket.send(sentMsg.json)
            }
            print("finished")
        }
    }
    
    
    
    class func loadPlayers()
    {
        all.removeAll()
        if let array = try? playersCollection.find().array
        {
            for document in array
            {
                let id = document["_id"].string
                all[id] = Player(document: document)
            }
        }
    }
    
}

struct SentMsg
{
    let id: UInt
    let timestamp: Date
    let ttl: TimeInterval
    let json: JSON
}
