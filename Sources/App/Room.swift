import Vapor
import Foundation
import Core

class Room
{
    static let main = Room()
    
    var connections: [String: WebSocket]
    var matches = [Match]()
    
    init() {
        connections = [:]
    }
    
    func clean()
    {
        // obriši mečeve sa disconnected igračima
        for (mIdx,m) in matches.enumerated()
        {
            var anyConnected = false
            for playerId in m.playerIds
            {
                if let p = Player.find(id: playerId), p.connected
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
        var activePlayers = Player.players.filter { (p) -> Bool in
            return p.connected
        }
        
        let matchesInfo = matches.map({ match -> Node in
            for pId in match.playerIds
            {
                // add also player which is not connected but still exists in match :(
                if !activePlayers.contains(where: { (p) -> Bool in
                    return p.id == pId
                }) {
                    if let mPlayer = Player.find(id: pId)
                    {
                        activePlayers.append(mPlayer)
                    }
                }
            }
            return match.node()
        })
        let playersInfo = activePlayers.map({ player in
            return player.node()
        })
        return ["msg_func": "room_info",
                "players": Node(playersInfo),
                "matches": Node(matchesInfo)]
    }
}
