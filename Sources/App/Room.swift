import Foundation
import Core
import WebSockets
import Vapor

class Room
{
    static let main = Room()
    
    var connections: [String: WebSocket]
    var matches = [Match]()
    
    init() {
        connections = [:]
    }
    
    func join(json: JSON, ws: WebSocket) throws -> Player?
    {
        guard let id = json["id"]?.string,
            let _ = json["alias"]?.string
            else { return nil }
            
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
        
        player?.deleteExpiredMessages()
        player?.sendUnsentMessages()
        
        // send room info to all
        sendInfo()
        return player
    }

    func createMatch(json: JSON, player: Player)
    {
        let match = Match()
        match.diceMaterials = (json["dice_materials"]!.array as! [JSON]).map({ json in
            return json.node.string!
        })
        match.diceNum = json["dice_num"]!.int!
        match.bet = json["bet"]?.int ?? 0
        match.isPrivate = json["private"]?.bool ?? false
        
        
        match.players.append(player)
        matches.append(match)
        
        // send room info to all
        sendInfo()
    }
    
    func joinMatch(json: JSON, player: Player)
    {
        guard
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
        print("info sent")
        
        let jsonJoined = try! JSON(["msg_func":"join_match", "isOK":true, "match_id":Node(matchId)])
        match.send(jsonJoined)
        
    }
    
    func leaveMatch(json: JSON, player: Player) {
        let matchId = json["match_id"]!.uint!
        
        if let idx = matches.index(where: {$0.id == matchId})
        {
            let match = matches[idx]
            matches.remove(at: idx)
            match.sendOthers(fromPlayerId: player.id, json: json)
        }
        
        // send room info to all
        sendInfo()
    }
    
    func updatePlayer(json: JSON, player: Player) throws
    {
        
        player.update(json: json)
        try playersCollection.update(matching: ["_id":.string(player.id)], to: player.document())
        
        sendInfo()
        
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
    
    func onClose(player: Player)
    {
        connections.removeValue(forKey: player.id)
        
        player.connected = false
        player.disconnectedAt = Date()
        
        // send info to all players
        sendInfo()
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
            
            print("Match id: \(match.id)")
            for player in match.players
            {
                print("player id \(player.id)")
                // add also player which is not connected but still exists in match :(
                if connections[player.id] == nil
                {
                    playersInfo.append(player.node())
                }
            }
            return match.node()
        })
        print("return room dic")
        return ["msg_func": "room_info",
                "players": Node(playersInfo),
                "matches": Node(matchesInfo)]
    }
    
    func clean()
    {
        var ctCleaned = 0
        for (mIdx,m) in matches.enumerated().reversed()
        {
            if m.clean()
            {
                ctCleaned += 1
                matches.remove(at: mIdx)
            }
        }
        
        if ctCleaned > 0
        {
            sendInfo()
        }
    }
}
