//
//  HoursImage.swift
//
//  Created by Bryce Cogswell on 4/5/21.
//

import SwiftUI
import VisionKit
import Vision

extension String.StringInterpolation {
	mutating func appendInterpolation(_ time: Time) {
		appendLiteral(time.text)
	}
	mutating func appendInterpolation(_ dash: Dash) {
		appendLiteral("-")
	}
	mutating func appendInterpolation(_ token: Token) {
		switch token {
		case let .day(day):
			appendInterpolation(day)
		case let .time(time):
			appendInterpolation(time)
		case let .dash(dash):
			appendInterpolation(dash)
		case .endOfText:
			appendLiteral("")
		}
	}
}

extension CharacterSet {
	func contains(character: Character) -> Bool {
		for scaler in character.unicodeScalars {
			if self.contains(scaler) {
				return true
			}
		}
		return false
	}
}

extension Substring {
	static func from(_ start: Substring, to: Substring) -> Substring {
		return start.base[ start.startIndex..<to.endIndex ]
	}
}

// A version of Scanner that returns Substring instead of String
class SubScanner {

	let scanner: Scanner

	init(string: String) {
		self.scanner = Scanner(string: string)
		self.scanner.caseSensitive = false
		self.scanner.charactersToBeSkipped = nil
	}

	static let allLetters = CharacterSet.uppercaseLetters.union(CharacterSet.lowercaseLetters)

	var currentIndex: String.Index {
		get { scanner.currentIndex }
		set { scanner.currentIndex = newValue }
	}

	var isAtEnd: Bool {
		get { scanner.isAtEnd }
	}

	func scanString(_ string: String) -> Substring? {
		let index = scanner.currentIndex
		if let _ = scanner.scanString(string) {
			return scanner.string[index..<scanner.currentIndex]
		}
		return nil
	}

	func scanWhitespace() -> Substring? {
		let index = scanner.currentIndex
		if let _ = scanner.scanCharacters(from: CharacterSet.whitespacesAndNewlines) {
			return scanner.string[index..<scanner.currentIndex]
		}
		return nil
	}

	func scanUpToWhitespace() -> Substring? {
		let index = scanner.currentIndex
		if let _ = scanner.scanUpToCharacters(from: CharacterSet.whitespacesAndNewlines) {
			return scanner.string[index..<scanner.currentIndex]
		}
		return nil
	}

	func scanInt() -> Substring? {
		let index = scanner.currentIndex
		if let _ = scanner.scanInt() {
			return scanner.string[index..<scanner.currentIndex]
		}
		return nil
	}

	func scanWord(_ word: String) -> Substring? {
		if let sub = scanString(word) {
			if sub.endIndex < scanner.string.endIndex {
				let c = scanner.string[sub.endIndex]
				if SubScanner.allLetters.contains(character: c) {
					// it's part of a larger word
					scanner.currentIndex = sub.startIndex
					return nil
				}
			}
			return sub
		}
		return nil
	}
	func scanAnyWord(_ words: [String]) -> Substring? {
		for word in words {
			if let sub = scanWord(word) {
				return sub
			}
		}
		return nil
	}
	func remainder() -> String {
		return String(scanner.string[scanner.currentIndex...])
	}
}

enum Day: String {
	case Mo = "Mo"
	case Tu = "Tu"
	case We = "We"
	case Th = "Th"
	case Fr = "Fr"
	case Sa = "Sa"
	case Su = "Su"

	static let english = [	Day.Mo: ["monday", 		"mo", "mon"],
							Day.Tu: ["tuesday", 	"tu", "tue"],
							Day.We: ["wednesday",	"we", "wed"],
							Day.Th: ["thursday", 	"th", "thu", "thur"],
							Day.Fr: ["friday", 		"fr", "fri"],
							Day.Sa: ["saturday", 	"sa", "sat"],
							Day.Su: ["sunday", 		"su", "sun"]
	]
	static let german = [	Day.Mo: ["montag", 		"mo", "mon"],
							Day.Tu: ["dienstag", 	"di"],
							Day.We: ["mittwoch",	"mi"],
							Day.Th: ["donnerstag", 	"do", "don"],
							Day.Fr: ["freitag", 	"fr"],
							Day.Sa: ["samstag", 	"sa", "sam"],
							Day.Su: ["sonntag",		"so", "son"]
	]

	static func scan(scanner:SubScanner) -> (day:Self, substring:Substring, confidence:Float)? {
		let dict = english
		for (day,strings) in dict {
			if let s = scanner.scanAnyWord(strings) {
				return (day,s,Float(s.count))
			}
		}
		return nil
	}
}

struct Time {
	let text: String

	init(hour: Int, minute:Int) {
		self.text = String(format: "%02d:%02d", hour, minute)
	}

	static func scan(scanner: SubScanner) -> (time:Self, substring:Substring, confidence:Float)? {
		guard let hour = scanner.scanInt() else { return nil }
		if let iHour = Int(hour),
		   iHour >= 0 && iHour <= 24
		{
			if scanner.scanString(":") != nil || scanner.scanString(".") != nil,
			   let minute = scanner.scanInt(),
			   minute.count == 2,
			   minute >= "00" && minute < "60"
			{
				_ = scanner.scanWhitespace()
				if let am = scanner.scanString("AM") {
					return (Time(hour: iHour%12, minute: Int(minute)!),
							Substring.from(hour, to:am),
							8.0)
				}
				if let pm = scanner.scanString("PM") {
					return (Time(hour: (iHour%12)+12, minute: Int(minute)!),
							Substring.from(hour, to:pm),
							8.0)
				}
				return (Time(hour: iHour, minute: Int(minute)!),
						Substring.from(hour, to:minute),
						6.0)
			}
			_ = scanner.scanWhitespace()
			if let am = scanner.scanString("AM") {
				return (Time(hour: iHour%12, minute: 0),
						Substring.from(hour, to:am),
						4.0)
			}
			if let pm = scanner.scanString("PM") {
				return (Time(hour: (iHour%12)+12, minute: 0),
						Substring.from(hour, to:pm),
						4.0)
			}
			return (Time(hour: iHour, minute: 0),
					hour,
					2.0)
		}
		scanner.currentIndex = hour.startIndex
		return nil
	}
}

struct Dash {
	static func scan(scanner: SubScanner) -> (Self,Substring,Float)? {
		if let s = scanner.scanString("-") ?? scanner.scanWord("to") {
			return (Dash(), s, Float(s.count))
		}
		return nil
	}
}

typealias TokenSubstringConfidence = (token:Token, substring:Substring, confidence:Float)
typealias TokenRectConfidence = (token:Token, rect:CGRect, confidence:Float)

enum Token {
	case time(Time)
	case day(Day)
	case dash(Dash)
	case endOfText

	static func scan(scanner: SubScanner) -> TokenSubstringConfidence? {
		if let (day,substring,confidence) = Day.scan(scanner: scanner) {
			return (.day(day),substring,confidence)
		}
		if let (time,substring,confidence) = Time.scan(scanner: scanner) {
			return (.time(time),substring,confidence)
		}
		if let (dash,substring,confidence) = Dash.scan(scanner: scanner) {
			return (.dash(dash),substring,confidence)
		}
		return nil
	}
}

class HoursRecognizer {

	var bbox: ((Range<String.Index>) -> (CGRect?))? = nil

	init() {
	}

	func hoursForImage(image: CGImage) -> String {
		// get list of text strings in image
		let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])
		let tokensList =  HoursRecognizer.getImageTokens(fromRequest: requestHandler)

		// extract hours string from the tokens
		let text = HoursRecognizer.getHoursFromTokens(tokensList)
		return text
	}

	// Returns an array of string arrays.
	// Each inner array is a possible interpretation of the text.
	fileprivate class func getImageTokens(fromRequest requestHandler: VNImageRequestHandler) -> [TokenRectConfidence] {
		var list = [TokenRectConfidence]()
		print("")
		print("")
		print("")
		let request = VNRecognizeTextRequest(completionHandler: { (request, error) in
			guard error == nil,
				  let observations = request.results as? [VNRecognizedTextObservation] else { return }
			for observation in observations {
				if let candidate = observation.topCandidates(1).first {
					let tokens = getTokensForString(candidate.string)
					let tokens2 = tokens.map({ item -> (token:Token,rect:CGRect,confidence:Float) in
						let range = item.substring.startIndex..<item.substring.endIndex
						let rect = try? candidate.boundingBox(for: range)?.boundingBox
						return (item.token,
								rect!,
								item.confidence * candidate.confidence)
					})
					let t = tokens2.map { "\($0.token)" }.joined(separator: " ")
					print("\(candidate.string) -> \(t)")

					list += tokens2
				}
			}
		})

		request.recognitionLevel = .accurate
//		request.customWords = ["AM","PM"]
		request.usesLanguageCorrection = true
		try? requestHandler.perform([request])

		print("")
		var allTokens = list.map { "\($0.token)" }.joined(separator: " ")
		print("\(allTokens)")

		// sort tokens left to right, then top to bottom
		list.sort {
			if $0.rect.origin.y + $0.rect.size.height/2 < $1.rect.origin.y {
				return true
			}
			return $0.rect.origin.x < $1.rect.origin.x
		}

		allTokens = list.map { "\($0.token)" }.joined(separator: " ")
		print("\(allTokens)")

		return list
	}

	fileprivate class func getTokensForString(_ string: String) -> [(token:Token,substring:Substring,confidence:Float)] {
		var list = [(Token,Substring,Float)]()
		let scanner = SubScanner(string: string)
		_ = scanner.scanWhitespace()
		while !scanner.isAtEnd {
			if let token = Token.scan(scanner: scanner) {
				list.append( token )
			} else {
				// skip to next token
				_ = scanner.scanUpToWhitespace()
			}
			_ = scanner.scanWhitespace()
		}
		return list
	}

	fileprivate class func bestTwo(_ list: [TokenRectConfidence] ) -> [TokenRectConfidence] {
		if list.count <= 2 {
			return list
		}
		var b0 = 0
		var b1 = 1
		for i in 2..<list.count {
			if list[i].confidence > list[b0].confidence {
				b0 = i
			} else if list[i].confidence > list[b1].confidence {
				b1 = i
			}
		}
		if b0 < b1 {
			return [list[b0], list[b1]]
		} else {
			return [list[b1], list[b0]]
		}
	}

	fileprivate class func getHoursFromTokens(_ tokenList: [TokenRectConfidence]) -> String {
		var days = [TokenRectConfidence]()
		var times = [TokenRectConfidence]()
		var result = ""

		for token in tokenList + [(.endOfText,CGRect(),0.0)] {
			switch token.token {
			case .day, .endOfText:
				if times.count >= 2 {
					// output preceding days/times
					if days.count > 0 {
						if days.count == 2 {
							// treat as a range of days
							result += "\(days[0].token)-\(days[1].token)"
						} else {
							// treat as a list of days
							result += days.reduce("", { result, next in
								return result == "" ? "\(next.token)" : result + "," + "\(next.token)"
							})
						}
						result += " "
					}
					times = bestTwo(times)
					result += "\(times[0].token)-\(times[1].token)"
					result += ", "
				}
				if times.count > 0 {
					times = []
					days = []
				}
				days.append(token)

			case .time:
				times.append(token)
				break
			case .dash:
				break
			}
		}
		if result.hasSuffix(", ") {
			result = String(result.dropLast(2))
		}
		return result
	}

}

class BulkProcess {
	init(path:String) {
		do {
			let userDirectory = try FileManager.default.url(for: FileManager.SearchPathDirectory.downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
			let imageDirectory = userDirectory.appendingPathComponent(path)
			let fileList = try FileManager.default.contentsOfDirectory(at: imageDirectory, includingPropertiesForKeys: nil, options: [])
			let recognizer = HoursRecognizer()
			for fileName in fileList {
//				print("\(fileName.lastPathComponent):")
				guard let image = UIImage(contentsOfFile: fileName.path),
					  let cgImage = image.cgImage else { continue }
				let hours = recognizer.hoursForImage(image: cgImage)
				print("\"\(fileName.lastPathComponent)\" => \"\(hours)\"")
			}
		} catch {
			print(error.localizedDescription)
		}
	}
}
