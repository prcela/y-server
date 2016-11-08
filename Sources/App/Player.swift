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
    var avgScore6: Double
    var diamonds: Int
    var connected = true
    var disconnectedAt: Date?
    
    
    init(id: String, alias: String, avgScore6: Double, diamonds: Int)
    {
        self.id = id
        self.alias = alias
        self.avgScore6 = avgScore6
        self.diamonds = diamonds
    }
    
    func node() -> Node
    {
        return Node([
            "id":Node(id),
            "alias":Node(alias),
            "avg_score_6":Node(avgScore6),
            "diamonds":Node(diamonds),
            "connected": Node(connected)])
    }
}
