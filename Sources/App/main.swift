import Vapor
import Foundation

let drop = Droplet()

private let minRequiredVersion = 2

drop.get { req in
    let lang = req.headers["Accept-Language"]?.string ?? "en"
    return try drop.view.make("welcome", [
    	"message": Node.string(drop.localization[lang, "welcome", "title"])
    ])
}

drop.get("info") { request in
    return try JSON(node: [
        "min_required_version": minRequiredVersion,
        "room_main_ct": Room.main.connections.count,
        "room_main_free_ct": Room.main.freePlayers.count
        ])
}


drop.resource("posts", PostController())

drop.socket("chat") { req, ws in
    var id: String? = nil
    
    ws.onBinary = {ws, bytes in
        print("onBinary")
        
        let jsonBytes = try JSON(bytes: bytes)
        let json = jsonBytes.object!
        
        print(json)
        
        if let msgFuncName = json["msg_func"]?.string,
            let msgFunc = MessageFunc(rawValue: msgFuncName)
        {
            switch msgFunc {
            case .Join:
                if let newId = json["id"]?.string,
                    let alias = json["alias"]?.string
                {
                    id = newId
                    
                    var player = Room.main.findPlayer(id: newId)
                    
                    if player == nil
                    {
                        // instantiate new player
                        player = Player(id: newId, alias: alias)
                        Room.main.freePlayers.append(player!)
                    }
                    player?.connected = true
                    
                    Room.main.connections[newId] = ws
                    
                    // send room info to all
                    Room.main.sendInfo()
                    
                }
                
            case .CreateMatch:
                let match = Match()
                match.diceMaterials = (json["dice_materials"]!.array as! [JSON]).map({ json in
                    return json.node.string!
                })
                match.diceNum = json["dice_num"]!.int!
                match.bet = json["bet"]?.int ?? 0
                let player = Room.main.findPlayer(id: id!)
                if let idx = Room.main.freePlayers.index(where: { (p) -> Bool in
                    return p.id == id!
                })
                {
                    Room.main.freePlayers.remove(at: idx)
                }
                match.players.append(player!)
                Room.main.matches.append(match)
                
                // send room info to all
                Room.main.sendInfo()
                
            case .JoinMatch:
                if let player = Room.main.findPlayer(id: id!),
                    let matchId = json["match_id"]?.uint,
                    let match = Room.main.findMatch(id: matchId)
                {
                    if let idx = Room.main.freePlayers.index(where: { (p) -> Bool in
                        return p.id == id!
                    })
                    {
                        Room.main.freePlayers.remove(at: idx)
                    }
                    match.players.append(player)
                    match.state = .Playing
                    
                    // send room info to all
                    Room.main.sendInfo()
                    
                    try match.send(JSON(node:["msg_func":msgFuncName, "isOK":true, "match_id":matchId]))
                }
                
            case .LeaveMatch:
                let matchId = json["match_id"]!.uint
                
                if let idx = Room.main.matches.index(where: {$0.id == matchId})
                {
                    let match = Room.main.matches[idx]
                    Room.main.matches.remove(at: idx)
                    try match.sendOthers(fromPlayerId: id!, json: jsonBytes)
                    for player in match.players
                    {
                        Room.main.freePlayers.append(player)
                    }
                }
                
                // send room info to all
                Room.main.sendInfo()
                
            case .InvitePlayer:
                
                let recipientId = json["recipient"]!.string!
                Room.main.connections[recipientId]?.send(jsonBytes)
                
            case .IgnoreInvitation:
                
                let senderId = json["sender"]!.string!
                Room.main.connections[senderId]?.send(jsonBytes)
                
            case .Turn:
                if let matchId = json["match_id"]?.uint,
                    let match = Room.main.findMatch(id: matchId)
                {
                    // forward message to other participants in match
                    try match.sendOthers(fromPlayerId: id!, json: jsonBytes)
                }
                
            default:
                print("Not implemented on yet")
                break
            }
        }
        
    }
    
    ws.onClose = { ws, _, _, _ in
        print("onClose")
        
        guard id != nil else {return}
        
        Room.main.connections.removeValue(forKey: id!)
        
        if let player = Room.main.findPlayer(id: id!)
        {
            player.connected = false
        }
        
        // send to all that player has been disconnected
        let jsonResponse = try JSON(node: ["msg_func":"disconnected", "id":id!])
        Room.main.send(jsonResponse)
        
        // remove player
        Room.main.removePlayer(id: id!)
        
        // send info to all players
        Room.main.sendInfo()
    }
    
    ws.onPing = {ws, _ in
        print("onPing")
    }

}

drop.run()
