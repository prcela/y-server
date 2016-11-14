//
//  Score.swift
//  y-server
//
//  Created by Kresimir Prcela on 13/11/16.
//
//

import Foundation
import MongoKitten
import Vapor

class DiceScore
{
    var score: Int32
    var timestamp: Date
    var stars: Double
    var avg_score: Double
    
    init(json: JSON)
    {
        score = Int32(json["score"]!.int!)
        timestamp = Date()
        stars = json["stars"]!.double!
        avg_score = json["avg_score"]!.double!
    }
    
    func update(json: JSON)
    {
        let newScore = Int32(json["score"]!.int!)
        if newScore > score
        {
            timestamp = Date()
            score = newScore
        }
        stars = json["stars"]!.double!
        avg_score = json["avg_score"]!.double!
    }
    
    init?(value: Document?)
    {
        guard value != nil else {return nil}
        score = value!["score"].int32
        timestamp = value!["timestamp"].dateValue!
        stars = value!["stars"].double
        avg_score = value!["avg_score"].double
    }
    
    func value() -> Value
    {
        return [
            "score": .int32(score),
            "timestamp": .dateTime(timestamp),
            "stars": .double(stars),
            "avg_score": .double(avg_score)
        ]
    }
    
    
    
    func node() -> Node
    {
        return [
            "score": Node(Int(score)),
            "timestamp": Node(timestamp.timeIntervalSince1970),
            "stars": Node(stars),
            "avg_score": Node(avg_score)
        ]
    }
}

class PlayerScore
{
    static var allScores = [PlayerScore]()
    
    var player_id: String
    var alias: String
    var diamonds: Int32
    
    var dice5: DiceScore?
    var dice6: DiceScore?
    
    var ct_matches_sp = 0
    var ct_matches_mp = 0
    
    init(player_id: String, alias: String, diamonds: Int32)
    {
        self.player_id = player_id
        self.alias = alias
        self.diamonds = diamonds
    }
    
    
    
    init(scoreDocument: Document)
    {
        player_id = scoreDocument["player_id"].string
        alias = scoreDocument["alias"].string
        diamonds = scoreDocument["diamonds"].int32
        
        dice5 = DiceScore(value: scoreDocument["5"].documentValue)
        dice6 = DiceScore(value: scoreDocument["6"].documentValue)
        
        ct_matches_sp = scoreDocument["ct_matches_sp"].int
        ct_matches_mp = scoreDocument["ct_matches_mp"].int
    }
    
    func update(json: JSON)
    {
        alias = json["alias"]!.string!
        diamonds = Int32(json["diamonds"]!.int!)
        
        if let jsonDice5 = json["5"]
        {
            if dice5 == nil
            {
                dice5 = DiceScore(json: jsonDice5)
            }
            else
            {
                dice5?.update(json: jsonDice5)
            }
        }
        
        if let jsonDice6 = json["6"]
        {
            if dice6 == nil
            {
                dice6 = DiceScore(json: jsonDice6)
            }
            else
            {
                dice6?.update(json: jsonDice6)
            }
        }
    }
    
    func document() -> Document
    {
        var scoreDocument: Document = [
            "player_id": .string(player_id),
            "alias": .string(alias),
            "diamonds": .int32(Int32(diamonds))]
        
        if let dice5 = dice5
        {
            scoreDocument["5"] = dice5.value()
        }
        
        if let dice6 = dice6
        {
            scoreDocument["6"] = dice6.value()
        }
        
        return scoreDocument
    }
    
    class func loadScoresFromCollection()
    {
        allScores.removeAll()
        for scoreDocument in try! scoresCollection.find().array
        {
            allScores.append(PlayerScore(scoreDocument: scoreDocument))
        }
    }
    
    class func find(player_id: String) -> PlayerScore?
    {
        for score in allScores
        {
            if score.player_id == player_id
            {
                return score
            }
        }
        return nil
    }
    
    class func upsertScore(json: JSON) throws
    {
        guard let player_id = json["player_id"]?.string,
            let alias = json["alias"]?.string,
            let diamonds = json["diamonds"]?.int else {throw Abort.badRequest}
        
        if let score = find(player_id: player_id)
        {
            score.update(json: json)
            try scoresCollection.update(matching: ["player_id":.string(player_id)], to: score.document())
        }
        else
        {
            let score = PlayerScore(player_id: player_id, alias: alias, diamonds: Int32(diamonds))
            score.update(json: json)
            allScores.append(score)
            try scoresCollection.insert(score.document())
        }
    }
    
    func node() -> Node
    {
        var result = ["player_id": Node(player_id),
                      "alias": Node(alias),
                      "diamonds": Node(Int(diamonds))]
        
        if dice5 != nil
        {
            result["5"] = dice5!.node()
        }
        
        if dice6 != nil
        {
            result["6"] = dice6!.node()
        }
        
        return Node(result)
    }
    
}
