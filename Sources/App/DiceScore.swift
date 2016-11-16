//
//  DiceScore.swift
//  y-server
//
//  Created by Kresimir Prcela on 14/11/16.
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
