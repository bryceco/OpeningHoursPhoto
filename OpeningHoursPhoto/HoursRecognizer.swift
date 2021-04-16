//
//  HoursImage.swift
//
//  Created by Bryce Cogswell on 4/5/21.
//

import VisionKit
import Vision

extension String.StringInterpolation {
	fileprivate mutating func appendInterpolation(_ time: Time) {
		appendLiteral(time.text)
	}
	fileprivate mutating func appendInterpolation(_ dash: Dash) {
		appendLiteral("-")
	}
	fileprivate mutating func appendInterpolation(_ token: Token) {
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

extension CGRect {
	// 0..1 depending on the amount of overlap
	fileprivate func overlap(_ rect: CGRect) -> Float {
		let overlap = max(0.0, min(self.maxX,rect.maxX) - max(self.minX,rect.minX))
					* max(0.0, min(self.maxY,rect.maxY) - max(self.minY,rect.minY))
		let size1 = self.width * self.height
		let size2 = rect.width * rect.height
		return Float(overlap / (size1+size2-overlap))
	}
}

extension CharacterSet {
	fileprivate func contains(character: Character) -> Bool {
		for scaler in character.unicodeScalars {
			if self.contains(scaler) {
				return true
			}
		}
		return false
	}
}

extension Substring {
	fileprivate static func from(_ start: Substring, to: Substring) -> Substring {
		return start.base[ start.startIndex..<to.endIndex ]
	}
}

// return a list where all items are removed except the two with highest confidence (preserving their order)
extension Array {
	func bestTwo(_ isBetter: (_ lhs: Self.Element, _ rhs: Self.Element) -> Bool) -> [Self.Element] {
		if self.count <= 2 {
			return self
		}
		var b0 = 0
		var b1 = 1
		for i in 2..<self.count {
			if isBetter( self[i], self[b0] ) {
				b0 = i
			} else if isBetter( self[i], self[b1]) {
				b1 = i
			}
		}
		if b0 < b1 {
			return [self[b0], self[b1]]
		} else {
			return [self[b1], self[b0]]
		}
	}
}

// A version of Scanner that returns Substring instead of String
fileprivate class SubScanner {

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

fileprivate enum Day: String {
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

fileprivate struct Time {
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
					1.0)
		}
		scanner.currentIndex = hour.startIndex
		return nil
	}
}

fileprivate struct Dash {
	static func scan(scanner: SubScanner) -> (Self,Substring,Float)? {
		if let s = scanner.scanString("-") ?? scanner.scanWord("to") {
			return (Dash(), s, Float(s.count))
		}
		return nil
	}
}

fileprivate typealias TokenSubstringConfidence = (token:Token, substring:Substring, confidence:Float)
fileprivate typealias TokenRectConfidence = (token:Token, rect:CGRect, confidence:Float)

fileprivate enum Token : Equatable {
	case time(Time)
	case day(Day)
	case dash(Dash)
	case endOfText

	static func == (lhs: Token, rhs: Token) -> Bool {
		return "\(lhs)" == "\(rhs)"
	}

	func isDay() -> Bool {
		switch self {
		case .day:
			return true
		default:
			return false
		}
	}
	func isTime() -> Bool {
		switch self {
		case .time:
			return true
		default:
			return false
		}
	}

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

class HoursRecognizer: ObservableObject {

	private var allTokens = [TokenRectConfidence]()

	@Published var text = "" {
		willSet {
			objectWillChange.send()
		}
	}

	init() {
	}

	private class func tokensForString(_ string: String) -> [TokenSubstringConfidence] {
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

	// split the list of sorted tokens into lines of text
	private class func getTokenLines( _ allTokens: [TokenRectConfidence] ) -> [[TokenRectConfidence]] {
		var lines = [[TokenRectConfidence]]()

		let overlapCutoff:Float = 0.3

		// sort with highest confidence first
		var allTokens = allTokens.sorted(by: {$0.confidence > $1.confidence})

		while !allTokens.isEmpty {
			// get highest confidence token
			let best = allTokens.first!
			// find all other tokens on the same line
			let lineY = best.rect.minY...best.rect.maxY
			var lineTokens = allTokens.filter { lineY.contains( $0.rect.midY ) }
			allTokens.removeAll(where: { 		lineY.contains( $0.rect.midY ) })
			// remove overlapping tokens
			var index = 0
			while index < lineTokens.endIndex {
				let token = lineTokens[index]
				lineTokens.removeAll(where: { $0.token != token.token && $0.rect.overlap(token.rect) > overlapCutoff })
				index = index + 1
			}
			// sort tokens on the line left-to-right
			lineTokens.sort(by: { $0.rect.minX < $1.rect.minX })
			// save the line of tokens
			lines.append( lineTokens )
		}

		// sort lines top-to-bottom
		lines.sort(by: {$0.first!.rect.minY < $1.first!.rect.minY} )

		return lines
	}

	private class func tokensForImage(observations: [VNRecognizedTextObservation], transform:CGAffineTransform) -> [TokenRectConfidence] {
		var list = [TokenRectConfidence]()
		for observation in observations {
			guard let candidate = observation.topCandidates(1).first else { continue }
			// Each observation can contain text in disconnected parts of the screen,
			// so we tokenize the string and extract the screen location of each token
			let tokens = tokensForString(candidate.string)
			let tokens2 = tokens.map({ item -> (token:Token,rect:CGRect,confidence:Float) in
				// Previous call returns tokens with substrings, which we can pass to candidate to get the rect
				let range = item.substring.startIndex ..< item.substring.endIndex
				let rect = try! candidate.boundingBox(for: range)!.boundingBox
				let rect2 = rect.applying(transform)
				// we also adjust the confidence of the tokenizer based on the confidence of the candidate
				return (item.token,
						rect2,
						item.confidence * candidate.confidence)
			})

			#if false
			// print the mapping of string to tokens
			let t = tokens2.map { "\($0.token)" }.joined(separator: " ")
			print("\(candidate.confidence) \(candidate.string) -> \(t)")
			#endif

			list += tokens2
		}

		#if false
		for t in list {
			print("\(t.confidence)% (\(t.rect.origin.x),\(t.rect.origin.y)): \(t.token)")
		}
		#endif

		return list
	}

	private func updateWithObservations(observations: [VNRecognizedTextObservation],
										transform: CGAffineTransform,
										camera: CameraView?)
	{
		#if false
		let raw = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
		print("\(raw)")
		#endif

		let tokens = HoursRecognizer.tokensForImage(observations: observations, transform: transform)
			.filter({ $0.token.isDay() || $0.token.isTime() })

		if allTokens.isEmpty {
			allTokens = tokens
		} else {
			// degrade all confidences
			allTokens = allTokens
				.map({ ($0.token, $0.rect, $0.confidence * 0.7) })
				.filter({ $0.confidence > 0.85 })

			for token in tokens {
				// scan for existing occurance
				if let index = allTokens.firstIndex(where: { token.rect.overlap($0.rect) > 0.6 }) {
					let overlap = allTokens[index]
					if overlap.token == token.token {
						// same token text, so increase it's confidence
						allTokens[index] = (token.token, token.rect, min(token.confidence + overlap.confidence,12.0))
					} else {
						allTokens.append(token)
					}
				} else {

					allTokens.append(token)
				}
			}
		}

		#if false
		let string = allTokens.map { "\($0.token)" }.joined(separator: " ")
		print("\(string)")
		#endif

		let lines = HoursRecognizer.getTokenLines( allTokens )

		// split the lines into discrete days/times sequences
		var tokenSets = [[TokenRectConfidence]]()
		for line in lines {
			tokenSets.append( [line.first!] )
			for token in line[1...] {
				if token.token.isDay() == tokenSets.last?.first?.token.isDay() ||
					token.token.isTime() == tokenSets.last?.first?.token.isTime()
				{
					tokenSets[tokenSets.count-1].append(token)
				} else {
					tokenSets.append([token])
				}
			}
			tokenSets.append([])
		}

		// if a set has multiple hours or multiple days then take only the best 2
		tokenSets = tokenSets.map( { return $0.bestTwo( {$0.confidence > $1.confidence} ) })

		let invertedTransform = transform.inverted()
		let tokenBoxes = lines.joined().map({$0.rect.applying(invertedTransform)})
		camera?.addBoxes(boxes: tokenBoxes, color: UIColor.green)

		#if false
		print("")
		for line in tokenSets {
			let s1 = line.map( { "\($0.token)" }).joined(separator: " ")
			let s2 = line.map( { "\(Float(Int(100.0*$0.confidence))/100.0)" }).joined(separator: " ")
			print("\(s1): \(s2)")
		}
		#endif

		let text = HoursRecognizer.hoursStringForTokens( tokenSets )
		if Thread.isMainThread {
			self.text = text
		} else {
			DispatchQueue.main.async {
				self.text = text
			}
		}
	}

	func updateWithLiveObservations(observations: [VNRecognizedTextObservation], camera: CameraView?) {
		self.updateWithObservations(observations: observations,
									transform: CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: 1),
									   camera: camera)
	}

	func setImage(image: CGImage, isRotated: Bool) {
		allTokens = []
		self.text = ""

//		let rotationTransform = CGAffineTransform(translationX: 0, y: 1).rotated(by: -CGFloat.pi / 2)

		let transform = isRotated ? CGAffineTransform(scaleX: 1.0, y: -1.0).rotated(by: -CGFloat.pi / 2)
									: CGAffineTransform.identity

		let request = VNRecognizeTextRequest(completionHandler: { (request, error) in
			guard error == nil,
				  let observations = request.results as? [VNRecognizedTextObservation] else { return }
			self.updateWithObservations(observations: observations, transform: transform, camera:nil)
		})
		request.recognitionLevel = .accurate
//		request.customWords = ["AM","PM"]
//		request.usesLanguageCorrection = true
		let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])
		try? requestHandler.perform([request])
	}


	private class func hoursStringForTokens(_ tokenLines: [[TokenRectConfidence]]) -> String {
		var days = [TokenRectConfidence]()
		var times = [TokenRectConfidence]()
		var result = ""

		for line in tokenLines + [[(.endOfText,CGRect(),0.0)]] {
			// each line should be 1 or more days, then 2 or more hours
			for token in line  {
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
						times = times.bestTwo { $0.confidence > $1.confidence }

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
		}
		if result.hasSuffix(", ") {
			result = String(result.dropLast(2))
		}
		return result
	}

}

#if targetEnvironment(macCatalyst)
class BulkProcess {
	init() {
	}

	func processFolder(path:String) {
		do {
			let userDirectory = try FileManager.default.url(for: FileManager.SearchPathDirectory.downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
			let imageDirectory = userDirectory.appendingPathComponent(path)
			let fileList = try FileManager.default.contentsOfDirectory(at: imageDirectory, includingPropertiesForKeys: nil, options: [])
			let recognizer = HoursRecognizer()
			for fileName in fileList {
//				print("\(fileName.lastPathComponent):")
				guard let image = UIImage(contentsOfFile: fileName.path),
					  let cgImage = image.cgImage else { continue }
				recognizer.setImage(image: cgImage, isRotated: true)
				print("\"\(fileName.lastPathComponent)\" => \"\(recognizer.text)\"")
			}
		} catch {
			print(error.localizedDescription)
		}
	}
}
#endif
