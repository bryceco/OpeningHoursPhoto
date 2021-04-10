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

extension Scanner {
	static let letterSet = CharacterSet.uppercaseLetters.union(CharacterSet.lowercaseLetters)

	func scanWord(_ word: String) -> String? {
		let index = self.currentIndex
		if scanString(word) != nil {
			let skipped = self.charactersToBeSkipped
			self.charactersToBeSkipped = nil
			if scanCharacters(from: Scanner.letterSet) == nil {
				self.charactersToBeSkipped = skipped
				return word
			}
			self.charactersToBeSkipped = skipped
			self.currentIndex = index
		}
		return nil
	}
	func scanAnyWord(_ words: [String]) -> String? {
		for word in words {
			if scanWord(word) != nil {
				return word
			}
		}
		return nil
	}
	func remainder() -> String {
		let index = self.currentIndex
		let r = self.scanCharacters(from: CharacterSet(charactersIn: "").inverted)
		self.currentIndex = index
		return r ?? ""
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

	init?(_ text: String) {
		let scanner = Scanner(string: text)
		scanner.caseSensitive = true
		if let (day,_) = Day.scan(scanner: scanner),
		   scanner.isAtEnd
		{
			self = day
		} else {
			return nil
		}
	}

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

	static func scan(scanner:Scanner) -> (day:Self, confidence:Float)? {
		let dict = english
		for (day,strings) in dict {
			if let s = scanner.scanAnyWord(strings) {
				return (day,Float(s.count))
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

	static func scan(scanner: Scanner) -> (time:Self, confidence:Float)? {
		let index = scanner.currentIndex
		if let hour = scanner.scanInt(),
		   hour >= 0 && hour <= 24
		{
			let index2 = scanner.currentIndex
			if scanner.scanString(":") != nil || scanner.scanString(".") != nil,
			   let minute = scanner.scanCharacters(from: CharacterSet.decimalDigits),
			   minute.count == 2,
			   minute >= "00" && minute < "60"
			{
				if scanner.scanString("AM") != nil {
					return (Time(hour: hour%12, minute: Int(minute)!), 8.0)
				}
				if scanner.scanString("PM") != nil {
					return (Time(hour: (hour%12)+12, minute: Int(minute)!), 8.0)
				}
				return (Time(hour: hour, minute: Int(minute)!), 6.0)
			}
			scanner.currentIndex = index2
			if scanner.scanString("AM") != nil {
				return (Time(hour: hour%12, minute: 0), 4.0)
			}
			if scanner.scanString("PM") != nil {
				return (Time(hour: (hour%12)+12, minute: 0), 4.0)
			}
			return (Time(hour: hour, minute: 0), 2.0)
		}
		scanner.currentIndex = index
		return nil
	}
}

struct Dash {
	static func scan(scanner: Scanner) -> (Self,Float)? {
		if let s = scanner.scanString("-") ?? scanner.scanWord("to") {
			return (Dash(), Float(s.count))
		}
		return nil
	}
}

typealias TextConfidence = (text:String, confidence:Float)
typealias TokenConfidence = (token:Token, confidence:Float)

enum Token {
	case time(Time)
	case day(Day)
	case dash(Dash)
	case endOfText

	static func scan(scanner: Scanner) -> TokenConfidence? {
		if let (day,confidence) = Day.scan(scanner: scanner) {
			return (.day(day),confidence)
		}
		if let (time,confidence) = Time.scan(scanner: scanner) {
			return (.time(time),confidence)
		}
		if let (dash,confidence) = Dash.scan(scanner: scanner) {
			return (.dash(dash),confidence)
		}
		return nil
	}
}

class HoursRecognizer {

	init() {
	}

	func hoursForImage(image: CGImage) -> String {
		// get list of text strings in image
		let textFragments = HoursRecognizer.getImageText(from: image)

		#if false
		for frag in textFragments {
			print("  \(Int(100.0*frag.confidence))%: \(frag.text)")
		}
		#endif

		// get list of tokens from the list of strings
		let tokensList = HoursRecognizer.getTokensFromFragments(textFragments)

		// extract hours string from the tokens
		let text = HoursRecognizer.getHoursFromTokens(tokensList)
		return text
	}

	// Returns an array of string arrays.
	// Each inner array is a possible interpretation of the text.
	fileprivate class func getImageText(from image: CGImage) -> [TextConfidence] {
		var list = [TextConfidence]()
		let request = VNRecognizeTextRequest(completionHandler: { (request, error) in
			guard error == nil,
				  let observations = request.results as? [VNRecognizedTextObservation] else { return }
			for observation in observations {
				if let candidate = observation.topCandidates(1).first {
					list.append(TextConfidence(candidate.string, candidate.confidence))
				}
			}
		})
		request.recognitionLevel = .accurate
//		request.customWords = ["AM","PM"]
//		request.usesLanguageCorrection = false
		let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])
		try? requestHandler.perform([request])
		return list
	}

	fileprivate class func getTokensForString(_ string: String) -> [TokenConfidence] {
		let scanner = Scanner(string: string)
		scanner.caseSensitive = false
		scanner.charactersToBeSkipped = CharacterSet.whitespacesAndNewlines
		var list = [TokenConfidence]()
		while !scanner.isAtEnd {
			if let token = Token.scan(scanner: scanner) {
				list.append( token )
			} else {
				// skip to next token
				_ = scanner.scanUpToCharacters(from: CharacterSet.whitespacesAndNewlines)
			}
		}
		return list
	}

	fileprivate class func getTokensFromFragments(_ fragmentList: [TextConfidence]) -> [TokenConfidence] {
		var tokenList = [TokenConfidence]()
		for fragment in fragmentList {
			let tokens = getTokensForString(fragment.text)
			tokenList += tokens.map({ ($0.token, $0.confidence * fragment.confidence) })
		}
		return tokenList
	}

	fileprivate class func bestTwo(_ list: [TokenConfidence] ) -> [TokenConfidence] {
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

	fileprivate class func getHoursFromTokens(_ tokenList: [TokenConfidence]) -> String {
		var days = [TokenConfidence]()
		var times = [TokenConfidence]()
		var result = ""

		for token in tokenList + [(.endOfText,0.0)] {
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
