import Vapor
import Foundation
import Core

class Room
{
    static let main = Room()
    
    var connections: [String: WebSocket]
    var freePlayers = [Player]()
    var matches = [Match]()
    
    init() {
        connections = [:]
    }
    
    func findPlayer(id: String) -> Player?
    {
        for p in freePlayers
        {
            if p.id == id
            {
                return p
            }
        }
        
        for m in matches {
            for p in m.players
            {
                if p.id == id
                {
                    return p
                }
            }
        }
        return nil
    }
    
    func removePlayer(id: String)
    {
        if let idx = freePlayers.index(where: { (p) -> Bool in
            return p.id == id
        }) {
            freePlayers.remove(at: idx)
        }
        
        for (idxMatch,m) in matches.enumerated()
        {
            if let idx = m.players.index(where: { (p) -> Bool in
                return p.id == id
            }) {
                m.players.remove(at: idx)
                
                if m.players.isEmpty
                {
                    matches.remove(at: idxMatch)
                }
            }
        }
    }
    
    func findMatch(id: UInt) -> Match?
    {
        for m in matches
        {
            if m.id == id
            {
                return m
            }
        }
        return nil
    }
    
    
    
    // send to all in room
    func send(_ json: JSON) {
        
        for (_, socket) in connections
        {
            socket.send(json)
        }
    }
    
    // send info to all in room
    func sendInfo()
    {
        let json = try! JSON(node: node())
        send(json)
    }
    
    
    
    func node() -> Node
    {
        let playersInfo = freePlayers.map({ player in
            return player.node()
        })
        let matchesInfo = matches.map({ match in
            return match.node()
        })
        return ["msg_func":"room_info", "free_players":Node(playersInfo), "matches": Node(matchesInfo)]
    }
}
