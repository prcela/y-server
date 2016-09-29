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
    
    
    init()
    {
        matchIdCounter += 1
        id = matchIdCounter
    }
    
    func node() -> Node
    {
        let playersInfo = players.map({ player in
            return player.node()
        })
        return Node(["id":Node(id),
                     "name":"proba",
                     "state":Node(state.rawValue),
                     "players":Node(playersInfo),
                     "dice_num":Node(diceNum),
                     "dice_materials": Node([Node(diceMaterials.first!),Node(diceMaterials.last!)])])
    }
    
    // send to all in match
    func send(_ json: JSON) throws
    {
        for (id, socket) in Room.main.connections
        {
            for player in players
            {
                if player.id == id
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
        for (id, socket) in Room.main.connections
        {
            if id == fromPlayerId
            {
                continue
            }
            for player in players
            {
                if player.id == id
                {
                    socket.send(json)
                    continue
                }
            }
            
        }
    }
}
