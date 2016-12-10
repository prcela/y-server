import Foundation
import MongoKitten
import SwiftyJSON
import Vapor

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

private let minRequiredVersion = 6

drop.get { req in
    let lang = req.headers["Accept-Language"]?.string ?? "en"
    return try drop.view.make("welcome", [
    	"message": Node.string(drop.localization[lang, "welcome", "title"])
    ])
}

drop.get("info") { request in
    return SwiftyJSON.JSON([
        "min_required_version": minRequiredVersion,
        "room_main_ct": Room.main.connections.count,
        "room_main_free_ct": 0
        ]).rawString()!
}


drop.get("players") { request in
    
    return SwiftyJSON.JSON(Player.all.map({ (id,player) -> [String:Any] in
        return player.dic()
    })).rawString()!
}

drop.get("statItems") { request in
    
    return SwiftyJSON.JSON(StatItem.allStatItems.map({ (item) -> [String:Any] in
        return item.dic()
    })).rawString()!
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
    guard let bytes = request.body.bytes
        else {
            throw Abort.badRequest
    }
    
    let json = try SwiftyJSON.JSON.parse(string: String(bytes: bytes))
    
    let id = json["id"].stringValue
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
    var player: Player? = nil
    
    // ping the socket to keep it open
    try background {
        while ws.state == .open {
            try? ws.ping()
            drop.console.wait(seconds: 10) // every 10 seconds
        }
    }
    
    func process(json: SwiftyJSON.JSON) throws
    {
        if let msgId = json["ack"].uInt
        {
            if let msgIdx = player?.sentMessages.index(where: { (msg) -> Bool in
                return msg.id == msgId
            })
            {
                print("message \(msgId) removed")
                player?.sentMessages.remove(at: msgIdx)
            }
        }
        else if let msgFuncName = json["msg_func"].string,
            let msgFunc = MessageFunc(rawValue: msgFuncName)
        {
            switch msgFunc {
            case .Join:
                player = try Room.main.join(json: json, ws: ws)
                
            case .CreateMatch:
                guard player != nil else {return}
                Room.main.createMatch(json: json, player: player!)
                
                
            case .JoinMatch:
                guard player != nil else {return}
                Room.main.joinMatch(json: json, player: player!)
                
            case .LeaveMatch:
                guard player != nil else {return}
                Room.main.leaveMatch(json: json, player: player!)
                
            case .InvitePlayer:
                
                let recipientId = json["recipient"].stringValue
                Room.main.connections[recipientId]?.send(json)
                
            case .IgnoreInvitation:
                
                let senderId = json["sender"].stringValue
                Room.main.connections[senderId]?.send(json)
                
            case .TextMessage:
                let recipientId = json["recipient"].stringValue
                Room.main.connections[recipientId]?.send(json)
                
            case .UpdatePlayer:
                guard player != nil else {return}
                try Room.main.updatePlayer(json: json, player: player!)
                
            case .Turn:
                Room.main.turn(json: json)
                
            default:
                print("Not implemented on yet")
                break
            }
        }

    }
    
    ws.onText = {ws, text in
        print(Date())
        let json = SwiftyJSON.JSON.parse(string: text)
        try process(json: json)
        print(text)
    }
    
    ws.onBinary = {ws, bytes in
        print(Date())
        let json = try SwiftyJSON.JSON.parse(string: String(bytes: bytes))
        try process(json: json)
        print(json)
    }
    
    ws.onClose = { ws, code, reason, clean in
        print("onClose code: \(code) reason: \(reason) \(clean)")
        
        guard player != nil else {return}
        Room.main.onClose(player: player!)
    }
    
    ws.onPing = {ws, _ in
        print("onPing")
    }

}


//try background {
//    
//    // Player can return to game even after he has been disconnected.
//    
//    while true {
//        print(Date())
//        print("room matches background check")
//        drop.console.wait(seconds: 3) // every n seconds
//        Room.main.clean()
//    }
//}


drop.run()
