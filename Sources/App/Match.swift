//
//  TimedMatch.swift
//  VaporApp
//
//  Created by Kresimir Prcela on 07/09/16.
//
//

import Foundation
import Vapor

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
    
    func node() -> Node
    {
        return Node(["id":Node(id),
                     "name":"proba",
                     "state":Node(state.rawValue),
                     "bet":Node(bet),
                     "private":Node(isPrivate),
                     "players":Node(players.map({ Node($0.id) })),
                     "dice_num":Node(diceNum),
                     "dice_materials": Node(diceMaterials.map({ Node($0) })) ])
    }
    
    // send to all in match
    func send(_ json: JSON, ttl: TimeInterval = 15)
    {
        print("match send")
        for player in players
        {
            print("pplayer send json ttl")
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
    
    func clean() -> Bool
    {
        let now = Date()
        var anyDumped = false
        
        func dump(_ p: Player)
        {
            // dump the player
            print("Player dumped")
            let jsonResponse = try! JSON(node: ["msg_func":"dump", "id":Node(p.id), "match_id":Node(id)])
            send(jsonResponse, ttl: 3600) // one hour
            anyDumped = true
        }
        
        func willBeDumped(_ p: Player)
        {
            // send to all that player may be dumped soon
            print("Player will be dumped soon")
            let jsonResponse = try! JSON(node:["msg_func":"maybe_someone_will_dump", "id":Node(p.id), "match_id":Node(id)])
            sendOthers(fromPlayerId: p.id, json: jsonResponse)
        }
        
        for p in players
        {
            if !p.sentMessages.isEmpty || !p.connected
            {
                
                if let lastShortMsg = p.sentMessages.filter({ (msg) -> Bool in
                    return msg.ttl < 20
                }).last
                {
                    if lastShortMsg.timestamp.addingTimeInterval(20) < now
                    {
                        print("player last message older than 20s")
                        dump(p)
                    }
                    else if lastShortMsg.timestamp.addingTimeInterval(10) < now
                    {
                        print("player last message older than 10s")
                        willBeDumped(p)
                    }
                }
                
                if let disconnectedAt = p.disconnectedAt
                {
                    if disconnectedAt.addingTimeInterval(20) < now
                    {
                        print("player disconnected longer than 20s")
                        dump(p)
                    }
                    else if disconnectedAt.addingTimeInterval(5) < now
                    {
                        print("player disconnected longer than 5s")
                        willBeDumped(p)
                    }
                }
            }
            
            p.deleteExpiredMessages()
        }
        return anyDumped
    }
}
