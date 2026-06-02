//
//  Typography.swift
//  SwiftIMEStarter
//
//  Created by miwa on 2024/03/18.
//

import Foundation

extension UnicodeScalar {
    /// Whether it is an uppercase Roman letter.
    @inlinable
    var isRomanUppercased: Bool {
        ("A"..."Z").contains(self)
    }
    /// Whether it is a lowercase Roman letter.
    @inlinable
    var isRomanLowercased: Bool {
        ("a"..."z").contains(self)
    }
    /// Whether it is a Roman digit.
    @inlinable
    var isRomanNumber: Bool {
        ("0"..."9").contains(self)
    }
}

struct TypographyCandidate {
    /// Returns conversion results as decorative characters.
    /// - parameters:
    ///   - text: Target string.
    /// - note:
    ///    Currently supports only Latin letters. Greek letters and digits still need support.
    static func typographicalCandidates(_ string: String) -> [String] {
        let strings = Self.typographicalLetters(from: string)
        return strings
    }

    /// The part that actually creates decorative characters.
    /// - parameters:
    ///   - text: Target string.
    private static func typographicalLetters(from text: String) -> [String] {
        var strings: [String] = []
        /// 𝐁𝐎𝐋𝐃
        do {
            let bold = text.unicodeScalars.map {
                if $0.isRomanUppercased {
                    let scalar = UnicodeScalar($0.value + 119743)!
                    return String(scalar)
                }
                if $0.isRomanLowercased {
                    let scalar = UnicodeScalar($0.value + 119737)!
                    return String(scalar)
                }
                if $0.isRomanNumber {
                    let scalar = UnicodeScalar($0.value + 120734)!
                    return String(scalar)
                }
                return String($0)

            }.joined()
            strings.append(bold)
        }
        /// 𝐼𝑇𝐴𝐿𝐼𝐶
        do {
            let italic = text.unicodeScalars.map {
                if $0.isRomanUppercased {
                    let scalar = UnicodeScalar($0.value + 119795)!
                    return String(scalar)
                }
                if $0.isRomanLowercased {
                    if $0 == "h"{
                        return "ℎ"
                    }
                    let scalar = UnicodeScalar($0.value + 119789)!
                    return String(scalar)
                }
                return String($0)
            }.joined()
            strings.append(italic)
        }
        /// 𝑩𝑶𝑳𝑫𝑰𝑻𝑨𝑳𝑰𝑪
        do {
            let boldItalic = text.unicodeScalars.map {
                if $0.isRomanUppercased {
                    let scalar = UnicodeScalar($0.value + 119847)!
                    return String(scalar)
                }
                if $0.isRomanLowercased {
                    let scalar = UnicodeScalar($0.value + 119841)!
                    return String(scalar)
                }
                return String($0)
            }.joined()
            strings.append(boldItalic)
        }

        /// 𝒮𝒸𝓇𝒾𝓅𝓉
        do {
            let script = text.unicodeScalars.map {
                if $0.isRomanUppercased {
                    switch $0 {
                    case "B":
                        return "ℬ"
                    case "E":
                        return "ℰ"
                    case "F":
                        return "ℱ"
                    case "H":
                        return "ℋ"
                    case "I":
                        return "ℐ"
                    case "L":
                        return "ℒ"
                    case "M":
                        return "ℳ"
                    case "R":
                        return "ℛ"
                    default:
                        break
                    }

                    let scalar = UnicodeScalar($0.value + 119899)!
                    return String(scalar)
                }
                if $0.isRomanLowercased {
                    switch $0 {
                    case "e":
                        return "ℯ"
                    case "g":
                        return "ℊ"
                    case "o":
                        return "ℴ"
                    default: break
                    }
                    let scalar = UnicodeScalar($0.value + 119893)!
                    return String(scalar)
                }
                return String($0)
            }.joined()
            strings.append(script)
        }

        /// 𝓑𝓸𝓵𝓭𝓢𝓬𝓻𝓲𝓹𝓽
        do {
            let boldScript = text.unicodeScalars.map {
                if $0.isRomanUppercased {
                    let scalar = UnicodeScalar($0.value + 119951)!
                    return String(scalar)
                }
                if $0.isRomanLowercased {
                    let scalar = UnicodeScalar($0.value + 119945)!
                    return String(scalar)
                }
                return String($0)
            }.joined()
            strings.append(boldScript)
        }
        /// 𝔉𝔯𝔞𝔨𝔱𝔲𝔯
        do {
            let fraktur = text.unicodeScalars.map {
                if $0.isRomanUppercased {
                    switch $0 {
                    case "C":
                        return "ℭ"
                    case "H":
                        return "ℌ"
                    case "I":
                        return "ℑ"
                    case "R":
                        return "ℜ"
                    case "Z":
                        return "ℨ"
                    default: break
                    }
                    let scalar = UnicodeScalar($0.value + 120003)!
                    return String(scalar)
                }
                if $0.isRomanLowercased {
                    let scalar = UnicodeScalar($0.value + 119997)!
                    return String(scalar)
                }
                return String($0)
            }.joined()
            strings.append(fraktur)
        }

        /// 𝕕𝕠𝕦𝕓𝕝𝕖𝕊𝕥𝕣𝕦𝕔𝕜
        do {
            let doubleStruck = text.unicodeScalars.map {
                if $0.isRomanUppercased {
                    switch $0 {
                    case "C":
                        return "ℂ"
                    case "H":
                        return "ℍ"
                    case "N":
                        return "ℕ"
                    case "P":
                        return "ℙ"
                    case "Q":
                        return "ℚ"
                    case "R":
                        return "ℝ"
                    case "Z":
                        return "ℤ"
                    default: break
                    }
                    let scalar = UnicodeScalar($0.value + 120055)!
                    return String(scalar)
                }
                if $0.isRomanLowercased {
                    let scalar = UnicodeScalar($0.value + 120049)!
                    return String(scalar)
                }
                if $0.isRomanNumber {
                    let scalar = UnicodeScalar($0.value + 120744)!
                    return String(scalar)
                }
                return String($0)
            }.joined()
            strings.append(doubleStruck)
        }

        /// 𝕭𝖔𝖑𝖉𝕱𝖗𝖆𝖐𝖙𝖚𝖗
        do {
            let boldFraktur = text.unicodeScalars.map {
                if $0.isRomanUppercased {
                    let scalar = UnicodeScalar($0.value + 120107)!
                    return String(scalar)
                }
                if $0.isRomanLowercased {
                    let scalar = UnicodeScalar($0.value + 120101)!
                    return String(scalar)
                }
                return String($0)
            }.joined()

            strings.append(boldFraktur)
        }

        /// 𝖲𝖺𝗇𝗌𝖲𝖾𝗋𝗂𝖿
        do {
            let sansSerif = text.unicodeScalars.map {
                if $0.isRomanUppercased {
                    let scalar = UnicodeScalar($0.value + 120159)!
                    return String(scalar)
                }
                if $0.isRomanLowercased {
                    let scalar = UnicodeScalar($0.value + 120153)!
                    return String(scalar)
                }
                if $0.isRomanNumber {
                    let scalar = UnicodeScalar($0.value + 120754)!
                    return String(scalar)
                }
                return String($0)
            }.joined()
            strings.append(sansSerif)
        }

        /// 𝗦𝗮𝗻𝘀𝗦𝗲𝗿𝗶𝗳𝗕𝗼𝗹𝗱
        do {
            let sansSerifBold = text.unicodeScalars.map {
                if $0.isRomanUppercased {
                    let scalar = UnicodeScalar($0.value + 120211)!
                    return String(scalar)
                }
                if $0.isRomanLowercased {
                    let scalar = UnicodeScalar($0.value + 120205)!
                    return String(scalar)
                }
                if $0.isRomanNumber {
                    let scalar = UnicodeScalar($0.value + 120764)!
                    return String(scalar)
                }
                return String($0)
            }.joined()

            strings.append(sansSerifBold)
        }

        /// 𝘚𝘢𝘯𝘴𝘚𝘦𝘳𝘪𝘧𝘐𝘵𝘢𝘭𝘪𝘤
        do {
            let sansSerifItalic = text.unicodeScalars.map {
                if $0.isRomanUppercased {
                    let scalar = UnicodeScalar($0.value + 120263)!
                    return String(scalar)
                }
                if $0.isRomanLowercased {
                    let scalar = UnicodeScalar($0.value + 120257)!
                    return String(scalar)
                }
                return String($0)
            }.joined()

            strings.append(sansSerifItalic)
        }

        /// 𝙎𝙖𝙣𝙨𝙎𝙚𝙧𝙞𝙛𝘽𝙤𝙡𝙙𝙄𝙩𝙖𝙡𝙞𝙘
        do {
            let sansSerifBoldItalic = text.unicodeScalars.map {
                if $0.isRomanUppercased {
                    let scalar = UnicodeScalar($0.value + 120315)!
                    return String(scalar)
                }
                if $0.isRomanLowercased {
                    let scalar = UnicodeScalar($0.value + 120309)!
                    return String(scalar)
                }
                return String($0)
            }.joined()

            strings.append(sansSerifBoldItalic)
        }

        /// 𝙼𝚘𝚗𝚘𝚜𝚙𝚊𝚌𝚎
        do {
            let monospace = text.unicodeScalars.map {
                if $0.isRomanUppercased {
                    let scalar = UnicodeScalar($0.value + 120367)!
                    return String(scalar)
                }
                if $0.isRomanLowercased {
                    let scalar = UnicodeScalar($0.value + 120361)!
                    return String(scalar)
                }
                if $0.isRomanNumber {
                    let scalar = UnicodeScalar($0.value + 120774)!
                    return String(scalar)
                }
                return String($0)
            }.joined()

            strings.append(monospace)
        }

        return strings
    }
}
