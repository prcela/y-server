import Vapor
import Foundation

extension WebSocket {
    func send(_ json: JSON) {
        do {
            let js = try json.makeBytes()
            try send(js.string)
        } catch {
            // TODO: Vjerojatno za ovo treba neki retry mehanizam ili slično??? Šta ako se npr. turn ne pošalje?
            print("\(Date()) error: \(error)")
        }
    }
}
