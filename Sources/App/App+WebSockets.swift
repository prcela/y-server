import SwiftyJSON
import Foundation
import WebSockets

extension WebSocket {
    func send(_ json: JSON) {
        do {
            if let str = json.rawString()
            {
                try send(str)
            }
            else
            {
                print("str is nil")
            }
        } catch {
            // TODO: Vjerojatno za ovo treba neki retry mehanizam ili slično??? Šta ako se npr. turn ne pošalje?
            print("\(Date()) error: greška pri slanju json-a na ws")
        }
    }
}
