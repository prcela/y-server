//
//  MessageType.swift
//  VaporApp
//
//  Created by Kresimir Prcela on 08/09/16.
//
//

import Foundation

enum MessageFunc: String
{
    case Join = "join"
    case Disjoin = "disjoin"
    case Match = "match"
    case Message = "message"
    case CreateMatch = "create_match"
    case JoinMatch = "join_match"
    case LeaveMatch = "leave_match"
    case Turn = "turn"
}

enum Turn: String
{
    case RollDice = "roll_dice"
    case End = "end"
}
