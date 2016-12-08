//
//  TimedMatch.swift
//  VaporApp
//
//  Created by Kresimir Prcela on 07/09/16.
//
//

import Foundation
import SwiftyJSON

enum MatchState: String
{
    case WaitingForPlayers = "Waiting"
    case Playing = "Playing"
    case Finished = "Finished"
}

private var matchIdCounter: UInt = 0

class Match
{
    var id: UInt
    var state:MatchState = .WaitingForPlayers
    var players = [Player]()
    var diceMaterials: [String] = ["a","b"]
    var diceNum: Int = 6
    var bet: Int = 0
    var isPrivate = false
    
    init()
    {
        matchIdCounter += 1
        id = matchIdCounter
    }
    
    func dic() -> [String:Any]
    {
        return ["id":id,
                "name":"proba",
                "state":state.rawValue,
                "bet":bet,
                "private":isPrivate,
                "players":players.map({ $0.id }),
                "dice_num":diceNum,
                "dice_materials": diceMaterials ]
    }
    
    // send to all in match
    func send(_ json: JSON, ttl: TimeInterval = 15)
    {
        for player in players
        {
            player.send(json: json, ttl: ttl)
        }
    }
    
    // send to all others in match
    func sendOthers(fromPlayerId: String, json: JSON)
    {
        for player in players
        {
            if player.id != fromPlayerId
            {
                player.send(json: json)
            }
        }
    }
}
