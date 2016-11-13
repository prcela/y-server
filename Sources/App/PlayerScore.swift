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


class PlayerScore
{
    static var allScores = [PlayerScore]()
    
    var client_id: String
    var alias: String
    var diamonds: Int32
    
    var score_5: Int32?
    var timestamp_5: Date?
    var stars_5: Double?
    var avg_score_5: Double?
    
    var score_6: Int32?
    var timestamp_6: Date?
    var stars_6: Double?
    var avg_score_6: Double?
    
    var ct_matches_sp = 0
    var ct_matches_mp = 0
    
    init(client_id: String, alias: String, diamonds: Int32)
    {
        self.client_id = client_id
        self.alias = alias
        self.diamonds = diamonds
    }
    
    init(scoreDocument: Document)
    {
        client_id = scoreDocument["client_id"].string
        alias = scoreDocument["alias"].string
        diamonds = scoreDocument["diamonds"].int32
        
        score_5 = scoreDocument["score_5"].int32Value
        timestamp_5 = scoreDocument["timestamp_5"].dateValue
        stars_5 = scoreDocument["stars_5"].doubleValue
        avg_score_5 = scoreDocument["avg_score_5"].doubleValue
        
        score_6 = scoreDocument["score_6"].int32Value
        timestamp_6 = scoreDocument["timestamp_6"].dateValue
        stars_6 = scoreDocument["stars_6"].doubleValue
        avg_score_6 = scoreDocument["avg_score_6"].doubleValue
        
        ct_matches_sp = scoreDocument["ct_matches_sp"].int
        ct_matches_mp = scoreDocument["ct_matches_mp"].int
    }
    
    func update(json: JSON)
    {
        alias = json["alias"]!.string!
        diamonds = Int32(json["diamonds"]!.int!)
        
        if let score_5 = json["score_5"]?.int,
            let stars_5 = json["stars_5"]?.double,
            let avg_score_5 = json["avg_score_5"]?.double
        {
            self.stars_5 = stars_5
            self.avg_score_5 = avg_score_5
            
            if self.score_5 == nil || Int32(score_5) > self.score_5!
            {
                self.score_5 = Int32(score_5)
                self.timestamp_5 = Date()
            }
        }
        
        if let score_6 = json["score_6"]?.int,
            let stars_6 = json["stars_6"]?.double,
            let avg_score_6 = json["avg_score_6"]?.double
        {
            self.stars_6 = stars_6
            self.avg_score_6 = avg_score_6
            
            if self.score_6 == nil || Int32(score_6) > self.score_6!
            {
                self.score_6 = Int32(score_6)
                self.timestamp_6 = Date()
            }
        }
    }
    
    func document() -> Document
    {
        var scoreDocument: Document = [
            "client_id": .string(client_id),
            "alias": .string(alias),
            "diamonds": .int32(Int32(diamonds))]
        
        if let score_5 = score_5,
            let stars_5 = stars_5,
            let avg_score_5 = avg_score_5
        {
            scoreDocument["score_5"] = .int32(score_5)
            scoreDocument["timestamp_5"] = .dateTime(timestamp_5!)
            scoreDocument["stars_5"] = .double(stars_5)
            scoreDocument["avg_score_5"] = .double(avg_score_5)
        }
        
        if let score_6 = score_6,
            let stars_6 = stars_6,
            let avg_score_6 = avg_score_6
        {
            scoreDocument["score_6"] = .int32(score_6)
            scoreDocument["timestamp_6"] = .dateTime(timestamp_6!)
            scoreDocument["stars_6"] = .double(stars_6)
            scoreDocument["avg_score_6"] = .double(avg_score_6)
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
    
    class func find(client_id: String) -> PlayerScore?
    {
        for score in allScores
        {
            if score.client_id == client_id
            {
                return score
            }
        }
        return nil
    }
    
    class func upsertScore(json: JSON) throws
    {
        guard let client_id = json["client_id"]?.string,
            let alias = json["alias"]?.string,
            let diamonds = json["diamonds"]?.int else {throw Abort.badRequest}
        
        if let score = find(client_id: client_id)
        {
            score.update(json: json)
            
            try scoresCollection.update(matching: ["client_id":.string(client_id)], to: score.document())
        }
        else
        {
            let score = PlayerScore(client_id: client_id, alias: alias, diamonds: Int32(diamonds))
            score.update(json: json)
            
            try scoresCollection.insert(score.document())
        }
    }
    
    func node() -> Node
    {
        var result = ["client_id": Node(client_id),
                      "alias": Node(alias),
                      "diamonds": Node(Int(diamonds))]
        
        if score_5 != nil
        {
            result["score_5"] = Node(Int(score_5!))
            result["timestamp_5"] = Node(timestamp_5!.timeIntervalSince1970)
            result["stars_5"] = Node(stars_5!)
            result["avg_score_5"] = Node(avg_score_5!)
        }
        
        if score_6 != nil
        {
            result["score_6"] = Node(Int(score_6!))
            result["timestamp_6"] = Node(timestamp_6!.timeIntervalSince1970)
            result["stars_6"] = Node(stars_6!)
            result["avg_score_6"] = Node(avg_score_6!)
        }
        
        return Node(result)
    }
    
}
