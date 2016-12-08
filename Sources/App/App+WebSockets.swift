import SwiftyJSON
import Foundation
import WebSockets

extension WebSocket {
    func send(_ json: JSON) {
        do {
            try send(json.rawString()!)
        } catch {
            // TODO: Vjerojatno za ovo treba neki retry mehanizam ili slično??? Šta ako se npr. turn ne pošalje?
            print("\(Date()) error: greška pri slanju json-a na ws")
        }
    }
}
