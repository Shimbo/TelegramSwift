////
////  WalletUtils.swift
////  Telegram
////
////  Created by Mikhail Filimonov on 29/09/2019.
////  Copyright © 2019 Telegram. All rights reserved.
////
//
//import Cocoa
//
//let walletAddressLength: Int = 48
//
//func formatAddress(_ address: String) -> String {
//    var address = address
//  //  address.insert("\n", at: address.index(address.startIndex, offsetBy: address.count / 2))
//    return address
//}
//
//func formatBalanceText(_ value: Int64, decimalSeparator: String = Formatter.withSeparator.decimalSeparator) -> String {
//    var balanceText = "\(abs(value))"
//    while balanceText.count < 10 {
//        balanceText.insert("0", at: balanceText.startIndex)
//    }
//    balanceText.insert(contentsOf: decimalSeparator, at: balanceText.index(balanceText.endIndex, offsetBy: -9))
//    while true {
//        if balanceText.hasSuffix("0") {
//            if balanceText.hasSuffix("\(decimalSeparator)0") {
//                break
//            } else {
//                balanceText.removeLast()
//            }
//        } else {
//            break
//        }
//    }
//    return balanceText
//}
//
//let invalidAmountCharacters = CharacterSet(charactersIn: "01234567890.,").inverted
//func isValidAmount(_ amount: String) -> Bool {
//    let amount = normalizeArabicNumeralString(amount, type: .western)
//    if amount.rangeOfCharacter(from: invalidAmountCharacters) != nil {
//        return false
//    }
//    var hasDecimalSeparator = false
//    var hasLeadingZero = false
//    var index = 0
//    for c in amount {
//        if c == "." || c == "," || c == Formatter.withSeparator.decimalSeparator.first {
//            if !hasDecimalSeparator {
//                hasDecimalSeparator = true
//            } else {
//                return false
//            }
//        }
//        index += 1
//    }
//    
//    var decimalIndex: String.Index?
//    if let index = amount.firstIndex(of: ".") {
//        decimalIndex = index
//    } else if let index = amount.firstIndex(of: ",") {
//        decimalIndex = index
//    } else if let index = amount.firstIndex(of: Formatter.withSeparator.decimalSeparator.first!) {
//        decimalIndex = index
//    }
//    
//    if let decimalIndex = decimalIndex, amount.distance(from: decimalIndex, to: amount.endIndex) > 10 {
//        return false
//    }
//    
//    let string = amount.replacingOccurrences(of: ",", with: Formatter.withSeparator.decimalSeparator)
//    if let range = string.range(of: Formatter.withSeparator.decimalSeparator) {
//        let integralPart = String(string[..<range.lowerBound])
//        let fractionalPart = String(string[range.upperBound...])
//        let string = integralPart + fractionalPart + String(repeating: "0", count: max(0, 9 - fractionalPart.count))
//        if let _ = Int64(string) {
//        } else {
//            return false
//        }
//    } else if !string.isEmpty {
//        if let integral = Int64(string), integral <= maxIntegral {
//        } else {
//            return false
//        }
//    }
//    
//    return true
//}
//
//private let maxIntegral: Int64 = Int64.max / 1000000000
//
//func amountValue(_ string: String) -> Int64 {
//    let string = string.replacingOccurrences(of: ",", with: Formatter.withSeparator.decimalSeparator)
//    if let range = string.range(of: Formatter.withSeparator.decimalSeparator) {
//        let integralPart = String(string[..<range.lowerBound])
//        let fractionalPart = String(string[range.upperBound...])
//        let string = integralPart + fractionalPart + String(repeating: "0", count: max(0, 9 - fractionalPart.count))
//        return Int64(string) ?? 0
//    } else if let integral = Int64(string) {
//        if integral > maxIntegral {
//            return 0
//        }
//        return integral * 1000000000
//    }
//    return 0
//}
//
//func normalizedStringForGramsString(_ string: String, decimalSeparator: String = Formatter.withSeparator.decimalSeparator) -> String {
//    return formatBalanceText(amountValue(string), decimalSeparator: decimalSeparator)
//}
//
//func formatAmountText(_ text: String, decimalSeparator: String = Formatter.withSeparator.decimalSeparator) -> String {
//    var text = normalizeArabicNumeralString(text, type: .western)
//    if text == "." || text == "," || text == Formatter.withSeparator.decimalSeparator {
//        text = "0\(decimalSeparator)"
//    } else if text == "0" {
//        text = "0\(decimalSeparator)"
//    } else if text.hasPrefix("0") && text.firstIndex(of: ".") == nil && text.firstIndex(of: ",") == nil && text.firstIndex(of: Formatter.withSeparator.decimalSeparator.first!) == nil {
//        var trimmedText = text
//        while trimmedText.first == "0" {
//            trimmedText.removeFirst()
//        }
//        text = trimmedText
//    }
//    return text
//}
//
//let invalidAddressCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_=").inverted
//
//func isValidAddress(_ address: String, exactLength: Bool = false) -> Bool {
//    if address.count > walletAddressLength || address.rangeOfCharacter(from: invalidAddressCharacters) != nil {
//        return false
//    }
//    if exactLength && address.count != walletAddressLength {
//        return false
//    }
//    return true
//}
//
//
//
//public enum ArabicNumeralStringType {
//    case western
//    case arabic
//    case persian
//}
//
//public func normalizeArabicNumeralString(_ string: String, type: ArabicNumeralStringType) -> String {
//    var string = string
//    
//    let numerals = [
//        ("0", "٠", "۰"),
//        ("1", "١", "۱"),
//        ("2", "٢", "۲"),
//        ("3", "٣", "۳"),
//        ("4", "٤", "۴"),
//        ("5", "٥", "۵"),
//        ("6", "٦", "۶"),
//        ("7", "٧", "۷"),
//        ("8", "٨", "۸"),
//        ("9", "٩", "۹"),
//        (",", "٫", "٫")
//    ]
//    for (western, arabic, persian) in numerals {
//        switch type {
//        case .western:
//            string = string.replacingOccurrences(of: arabic, with: western)
//            string = string.replacingOccurrences(of: persian, with: western)
//        case .arabic:
//            string = string.replacingOccurrences(of: western, with: arabic)
//            string = string.replacingOccurrences(of: persian, with: arabic)
//        case .persian:
//            string = string.replacingOccurrences(of: western, with: persian)
//            string = string.replacingOccurrences(of: arabic, with: persian)
//        }
//        
//    }
//    return string
//}
