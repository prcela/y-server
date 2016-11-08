import Vapor
import Foundation
import Core

class Room
{
    static let main = Room()
    
    var connections: [String: WebSocket]
    var players = [Player]()
    var matches = [Match]()
    
    init() {
        connections = [:]
    }
    
    func findPlayer(id: String) -> Player?
    {
        for p in players
        {
            if p.id == id
            {
                return p
            }
        }
        return nil
    }
    
    func removeFreePlayer(id: String)
    {
        for m in matches
        {
            if m.playerIds.contains(id)
            {
                return
            }
        }
        if let idx = players.index(where: { (p) -> Bool in
            return p.id == id
        })
        {
            players.remove(at: idx)
        }
    }
    
    func clean()
    {
        // obriši mečeve sa disconnected igračima
        for (mIdx,m) in matches.enumerated()
        {
            var anyConnected = false
            for playerId in m.playerIds
            {
                if let p = findPlayer(id: playerId), p.connected
                {
                    anyConnected = true
                    break
                }
            }
            
            if !anyConnected
            {
                matches.remove(at: mIdx)
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
        let playersInfo = players.map({ player in
            return player.node()
        })
        let matchesInfo = matches.map({ match in
            return match.node()
        })
        return ["msg_func": "room_info",
                "players": Node(playersInfo),
                "matches": Node(matchesInfo)]
    }
}
