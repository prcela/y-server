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
    
    func join(json: JSON, ws: WebSocket) throws -> String?
    {
        if let id = json["id"]?.string,
            let _ = json["alias"]?.string
        {
            
            var player = Player.all[id]
            
            if player == nil
            {
                // instantiate new player
                player = Player(json: json)
                Player.all[player!.id] = player!
                try playersCollection.insert(player!.document())
            }
            player?.connected = true
            player?.disconnectedAt = nil
            
            connections[id] = ws
            
            // send room info to all
            sendInfo()
            return id
        }
        return nil
    }
    
    func createMatch(json: JSON, playerId: String)
    {
        let match = Match()
        match.diceMaterials = (json["dice_materials"]!.array as! [JSON]).map({ json in
            return json.node.string!
        })
        match.diceNum = json["dice_num"]!.int!
        match.bet = json["bet"]?.int ?? 0
        match.isPrivate = json["private"]?.bool ?? false
        
        if let player = Player.all[playerId]
        {
            match.players.append(player)
            matches.append(match)
        }
        
        // send room info to all
        sendInfo()
    }
    
    func joinMatch(json: JSON, playerId: String)
    {
        guard let player = Player.all[playerId],
            let matchId = json["match_id"]?.uint,
            let match = findMatch(id: matchId) else
        {
            return
        }
        
        // forbid 2 same players in match
        if match.players.contains(where: { (p) -> Bool in
            return p.id == player.id
        }) {
            return
        }
        
        match.players.append(player)
        match.state = .Playing
        
        if let diceMat = json["dice_mat"]?.string
        {
            match.diceMaterials[1] = diceMat
        }
        
        // send room info to all
        sendInfo()
        
        let jsonJoined = try! JSON(node:["msg_func":"join_match", "isOK":true, "match_id":matchId])
        match.send(jsonJoined)
        
    }
    
    func leaveMatch(json: JSON, playerId: String) {
        let matchId = json["match_id"]!.uint
        
        if let idx = matches.index(where: {$0.id == matchId})
        {
            let match = matches[idx]
            matches.remove(at: idx)
            match.sendOthers(fromPlayerId: playerId, json: json)
        }
        
        // send room info to all
        sendInfo()
    }
    
    func updatePlayer(json: JSON, playerId: String) throws
    {
        if let player = Player.all[playerId]
        {
            player.update(json: json)
            try playersCollection.update(matching: ["_id":.string(playerId)], to: player.document())
            
            sendInfo()
        }
    }
    
    func turn(json: JSON)
    {
        if let id = json["id"]?.string,
            let matchId = json["match_id"]?.uint,
            let match = findMatch(id: matchId)
        {
            // forward message to other participants in match
            match.sendOthers(fromPlayerId: id, json: json)
        }
    }
    
    func onClose(playerId: String)
    {
        connections.removeValue(forKey: playerId)
        
        if let p = Player.all[playerId]
        {
            p.connected = false
            p.disconnectedAt = Date()
        }
        
        // send to all that player has been disconnected
        let jsonResponse = try! JSON(node: ["msg_func":"disconnected", "id":playerId])
        send(jsonResponse)
        
        clean()
        
        // send info to all players
        sendInfo()
    }

    // obriši mečeve sa disconnected igračima
    func clean()
    {
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
        var playersInfo = connections.map({(key, ws) -> Node in
            return Player.all[key]!.node()
        })
        
        let matchesInfo = matches.map({ match -> Node in
            
            for player in match.players
            {
                // add also player which is not connected but still exists in match :(
                if connections[player.id] == nil
                {
                    playersInfo.append(player.node())
                }
            }
            return match.node()
        })
        return ["msg_func": "room_info",
                "players": Node(playersInfo),
                "matches": Node(matchesInfo)]
    }
}
