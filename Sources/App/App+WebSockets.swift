import Vapor

extension WebSocket {
    func send(_ json: JSON) {
        do {
            let js = try json.makeBytes()
            try send(js.string)
        } catch {
            print(error)
        }
    }
}
