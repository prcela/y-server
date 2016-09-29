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
    func send(_ json: JSON) throws {
        
        for (_, socket) in connections
        {
            socket.send(json)
        }
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
