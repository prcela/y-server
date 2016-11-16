import Vapor
import Foundation
import MongoKitten

let server: Server
do {
    server = try Server(mongoURL: "mongodb://localhost:27017", automatically: true)
} catch {
    // Unable to connect
    fatalError("MongoDB is not available on the given host and port")
}

let database = server["yamb"]
let statItemsCollection = database["statItems"]
let playersCollection = database["players"]

StatItem.loadStats()
Player.loadPlayers()


let drop = Droplet()

private let minRequiredVersion = 4

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
        "room_main_free_ct": 0 // deprecated
        ])
}

drop.post("statItem") { request in
    guard let json = request.json
        else {
            throw Abort.badRequest
    }
    
    try StatItem.insert(json: json)
    return "ok"
}

drop.post("updatePlayer") { request in
    guard let json = request.json
        else {
            throw Abort.badRequest
    }
    
    let id = json["id"]!.string!
    if let player = Player.find(id: id)
    {
        player.update(json: json)
        try playersCollection.update(matching: ["_id": .string(id)], to: player.document())
    }
    else
    {
        // instantiate new player
        let player = Player(json: json)
        Player.players.append(player)
        try playersCollection.insert(player.document())
    }
    
    
    return "ok"
}

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
                    
                    var player = Player.find(id: newId)
                    
                    if player == nil
                    {
                        // instantiate new player
                        player = Player(json: jsonBytes)
                        Player.players.append(player!)
                        try playersCollection.insert(player!.document())
                    }
                    player?.connected = true
                    player?.disconnectedAt = nil
                    
                    Room.main.connections[newId] = ws
                    Room.main.connectedPlayers.append(player!)
                    
                    // send room info to all
                    Room.main.sendInfo()
                    
                }
                
            case .CreateMatch:
                guard id != nil else {return}
                let match = Match()
                match.diceMaterials = (json["dice_materials"]!.array as! [JSON]).map({ json in
                    return json.node.string!
                })
                match.diceNum = json["dice_num"]!.int!
                match.bet = json["bet"]?.int ?? 0
                if let player = Player.find(id: id!)
                {
                    match.players.append(player)
                    Room.main.matches.append(match)
                }
                
                // send room info to all
                Room.main.sendInfo()
                
            case .JoinMatch:
                guard id != nil else {return}
                if let player = Player.find(id: id!),
                    let matchId = json["match_id"]?.uint,
                    let match = Room.main.findMatch(id: matchId)
                {
                    match.players.append(player)
                    match.state = .Playing
                    
                    if let diceMat = json["dice_mat"]?.string
                    {
                        match.diceMaterials[1] = diceMat
                    }
                    
                    // send room info to all
                    Room.main.sendInfo()
                    
                    try match.send(JSON(node:["msg_func":msgFuncName, "isOK":true, "match_id":matchId]))
                }
                
            case .LeaveMatch:
                guard id != nil else {return}
                let matchId = json["match_id"]!.uint
                
                if let idx = Room.main.matches.index(where: {$0.id == matchId})
                {
                    let match = Room.main.matches[idx]
                    Room.main.matches.remove(at: idx)
                    try match.sendOthers(fromPlayerId: id!, json: jsonBytes)
                }
                
                // send room info to all
                Room.main.sendInfo()
                
            case .InvitePlayer:
                
                let recipientId = json["recipient"]!.string!
                Room.main.connections[recipientId]?.send(jsonBytes)
                
            case .IgnoreInvitation:
                
                let senderId = json["sender"]!.string!
                Room.main.connections[senderId]?.send(jsonBytes)
                
            case .UpdatePlayer:
                guard id != nil else {return}
                if let player = Player.find(id: id!)
                {
                    player.update(json: jsonBytes)
                    try playersCollection.update(matching: ["_id":.string(id!)], to: player.document())
                    
                    Room.main.sendInfo()
                }
                
            case .Turn:
                if let id = json["id"]?.string,
                    let matchId = json["match_id"]?.uint,
                    let match = Room.main.findMatch(id: matchId)
                {
                    // forward message to other participants in match
                    try match.sendOthers(fromPlayerId: id, json: jsonBytes)
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
        if let idx = Room.main.connectedPlayers.index(where: { (p) -> Bool in
            return p.id == id
        }) {
            let p = Room.main.connectedPlayers[idx]
            p.connected = false
            p.disconnectedAt = Date()
            Room.main.connectedPlayers.remove(at: idx)
        }
        
        // send to all that player has been disconnected
        let jsonResponse = try JSON(node: ["msg_func":"disconnected", "id":id!])
        Room.main.send(jsonResponse)
        
        Room.main.clean()
        
        // send info to all players
        Room.main.sendInfo()
    }
    
    ws.onPing = {ws, _ in
        print("onPing")
    }

}

drop.run()
