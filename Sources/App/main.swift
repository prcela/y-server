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


drop.get("players") { request in
    
    return try JSON(node:Node(Player.all.map({ (id,player) -> Node in
        return player.node()
    })))
}

drop.get("statItems") { request in
    
    return try JSON(node:Node(StatItem.allStatItems.map({ (item) -> Node in
        return item.node()
    })))
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
    if let player = Player.all[id]
    {
        player.update(json: json)
        try playersCollection.update(matching: ["_id": .string(id)], to: player.document())
    }
    else
    {
        // instantiate new player
        let player = Player(json: json)
        Player.all[player.id] = player
        try playersCollection.insert(player.document())
    }
    
    
    return "ok"
}

drop.socket("chat") { req, ws in
    var id: String? = nil
    
    ws.onBinary = {ws, bytes in
        print("onBinary")
        
        let json = try JSON(bytes: bytes)
        
        print(json.object!)
        
        if let msgFuncName = json["msg_func"]?.string,
            let msgFunc = MessageFunc(rawValue: msgFuncName)
        {
            switch msgFunc {
            case .Join:
                id = try Room.main.join(json: json, ws: ws)
                
            case .CreateMatch:
                guard id != nil else {return}
                Room.main.createMatch(json: json, playerId: id!)
                
                
            case .JoinMatch:
                guard id != nil else {return}
                Room.main.joinMatch(json: json, playerId: id!)
                
                
            case .LeaveMatch:
                guard id != nil else {return}
                Room.main.leaveMatch(json: json, playerId: id!)
                
            case .InvitePlayer:
                
                let recipientId = json["recipient"]!.string!
                Room.main.connections[recipientId]?.send(json)
                
            case .IgnoreInvitation:
                
                let senderId = json["sender"]!.string!
                Room.main.connections[senderId]?.send(json)
                
            case .UpdatePlayer:
                guard id != nil else {return}
                try Room.main.updatePlayer(json: json, playerId: id!)
                
            case .Turn:
                Room.main.turn(json: json)
                
            default:
                print("Not implemented on yet")
                break
            }
        }
        
    }
    
    ws.onClose = { ws, _, _, _ in
        print("onClose")
        
        guard id != nil else {return}
        Room.main.onClose(playerId: id!)
    }
    
    ws.onPing = {ws, _ in
        print("onPing")
    }

}

drop.run()
