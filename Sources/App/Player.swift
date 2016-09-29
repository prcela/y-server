//
//  Player.swift
//  VaporApp
//
//  Created by Kresimir Prcela on 08/09/16.
//
//

import Foundation
import Core
import Vapor

class Player
{
    var id: String
    var alias: String
    
    init(id: String, alias: String)
    {
        self.id = id
        self.alias = alias
    }
    
    func node() -> Node
    {
        return Node(["id":Node(id), "alias":Node(alias)])
    }
}
