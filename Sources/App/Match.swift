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
                     "players":Node(players.map({ Node($0.id) })),
                     "dice_num":Node(diceNum),
                     "dice_materials": Node(diceMaterials.map({ Node($0) })) ])
    }
    
    // send to all in match
    func send(_ json: JSON) throws
    {
        for (idCon, socket) in Room.main.connections
        {
            for player in players
            {
                if player.id == idCon
                {
                    socket.send(json)
                    continue
                }
            }
        }
    }
    
    // send to all others in match
    func sendOthers(fromPlayerId: String, json: JSON) throws
    {
        for (conId, socket) in Room.main.connections
        {
            if conId == fromPlayerId
            {
                continue
            }
            for player in players
            {
                if player.id == conId
                {
                    socket.send(json)
                    continue
                }
            }
            
        }
    }
}
