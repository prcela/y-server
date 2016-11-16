import Vapor
import Foundation
import Core

class Room
{
    static let main = Room()
    
    var connections: [String: WebSocket]
    var matches = [Match]()
    var connectedPlayers = [Player]()
    
    init() {
        connections = [:]
    }
    
    func clean()
    {
        // obriši mečeve sa disconnected igračima
        for (mIdx,m) in matches.enumerated()
        {
            let anyConnected = m.players.contains(where: { (p) -> Bool in
                return p.connected
            })
            
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
        var activePlayers = connectedPlayers
        
        let matchesInfo = matches.map({ match -> Node in
            for player in match.players
            {
                // add also player which is not connected but still exists in match :(
                if activePlayers.contains(where: { (p) -> Bool in
                    return p === player
                })
                {
                    activePlayers.append(player)
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
