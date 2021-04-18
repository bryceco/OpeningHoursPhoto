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

typealias SubstringRectf = (string:Substring,rect:(Range<String.Index>)->CGRect)
typealias StringRect = (string:Substring,rect:CGRect)

// A version of Scanner that returns a rect for each string
fileprivate class RectScanner {

	let substring: Substring
	let scanner: Scanner
	let rectf:(Range<String.Index>)->CGRect

	init(substring: Substring, rect:@escaping (Range<String.Index>)->CGRect) {
		self.substring = substring
		self.scanner = Scanner(string: String(substring))
		self.scanner.caseSensitive = false
		self.scanner.charactersToBeSkipped = nil
		self.rectf = rect
	}

	static let allLetters = CharacterSet.uppercaseLetters.union(CharacterSet.lowercaseLetters)

	var currentIndex: String.Index {
		get { scanner.currentIndex }
		set { scanner.currentIndex = newValue }
	}

	var isAtEnd: Bool {
		get { scanner.isAtEnd }
	}

	func result(_ sub:Substring) -> (Substring,CGRect) {
		let d1 = sub.distance(from: sub.startIndex, to: sub.base.startIndex)
		let d2 = sub.distance(from: sub.endIndex, to: sub.base.startIndex)
		let p1 = substring.index(substring.startIndex, offsetBy: d1)
		let p2 = substring.index(substring.startIndex, offsetBy: d2)
		let rect = rectf(p1..<p2)
		return (sub,rect)
	}

	func scanString(_ string: String) -> StringRect? {
		let index = scanner.currentIndex
		if let _ = scanner.scanString(string) {
			return result(scanner.string[index..<scanner.currentIndex])
		}
		return nil
	}

	func scanWhitespace() -> StringRect? {
		let index = scanner.currentIndex
		if let _ = scanner.scanCharacters(from: CharacterSet.whitespacesAndNewlines) {
			return result(scanner.string[index..<scanner.currentIndex])
		}
		return nil
	}

	func scanUpToWhitespace() -> StringRect? {
		let index = scanner.currentIndex
		if let _ = scanner.scanUpToCharacters(from: CharacterSet.whitespacesAndNewlines) {
			return result(scanner.string[index..<scanner.currentIndex])
		}
		return nil
	}

	func scanInt() -> StringRect? {
		let index = scanner.currentIndex
		if let _ = scanner.scanInt() {
			return result(scanner.string[index..<scanner.currentIndex])
		}
		return nil
	}

	func scanWord(_ word: String) -> StringRect? {
		if let sub = scanString(word) {
			if sub.string.endIndex < scanner.string.endIndex {
				let c = scanner.string[sub.string.endIndex]
				if SubScanner.allLetters.contains(character: c) {
					// it's part of a larger word
					scanner.currentIndex = sub.string.startIndex
					return nil
				}
			}
			return sub
		}
		return nil
	}

	func scanAnyWord(_ words: [String]) -> StringRect? {
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

// A version of Scanner that accepts an array of substrings and can extract rectangles for them
fileprivate class MultiScanner {

	let strings: [SubstringRectf]
	let scanners: [RectScanner]
	var scannerIndex: Int

	init(strings: [SubstringRectf]) {
		self.strings = strings
		self.scanners = strings.map { RectScanner(substring: $0.string, rect:$0.rect) }
		self.scannerIndex = 0
	}

	var currentIndex: (scanner:Int, index:String.Index) {
		get { (scannerIndex, scanners[scannerIndex].currentIndex) }
		set { scannerIndex = newValue.0
			scanners[scannerIndex].currentIndex = newValue.1 }
	}

	var scanner:RectScanner {
		get {
			while scanners[scannerIndex].isAtEnd && scannerIndex+1 < scanners.count {
				scannerIndex += 1
			}
			return scanners[scannerIndex]
		}
	}

	var isAtEnd: Bool {
		get {
			return scanner.isAtEnd
		}
	}

	func scanString(_ string: String) -> StringRect? {
		if let sub = scanner.scanString(string) {
			return sub
		}
		return nil
	}

	func scanWhitespace() -> StringRect? {
		if let sub = scanner.scanWhitespace() {
			return sub
		}
		return nil
	}

	func scanUpToWhitespace() -> StringRect? {
		if let sub = scanner.scanUpToWhitespace() {
			return sub
		}
		return nil
	}

	func scanInt() -> StringRect? {
		if let sub = scanner.scanInt() {
			return sub
		}
		return nil
	}

	func scanWord(_ word: String) -> StringRect? {
		if let sub = scanner.scanWord( word ) {
			return sub
		}
		return nil
	}

	func scanAnyWord(_ words: [String]) -> StringRect? {
		if let sub = scanner.scanAnyWord(words) {
			return sub
		}
		return nil
	}

	func remainder() -> String {
		return scanner.remainder() + scanners[scannerIndex...].map({$0.remainder()}).joined(separator: " ")
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

fileprivate typealias SubstringRectConfidence = (substring:Substring, rect:CGRect, confidence:Float)
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

	private var resultHistory = [String:Int]()

	@Published var text = "" {
		willSet {
			objectWillChange.send()
		}
	}

	init() {
	}

	private class func tokensForString(_ string: String) -> [TokenSubstringConfidence] {
		var list = [TokenSubstringConfidence]()

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
	private class func getStringLines( _ allStrings: [SubstringRectConfidence] ) -> [[SubstringRectConfidence]] {
		var lines = [[SubstringRectConfidence]]()

		// sort with highest confidence first
		var stack = [ ArraySlice(allStrings) ]

		while let list = stack.popLast() {

			if list.count == 0 {
				continue
			}

			// get highest confidence string
			let bestIndex = list.indices.max(by: {list[$0].confidence < list[$1].confidence})!

			// find all other tokens on the same line
			let lower = (list.startIndex..<bestIndex).reversed().first(where: {
				let prevRect = list[$0+1].rect
				let thisRect = list[$0].rect
				return !(thisRect.maxX <= prevRect.minX && (prevRect.minY...prevRect.maxY).contains( thisRect.midY ))
			})?.advanced(by: 1) ?? list.startIndex
			let upper = (bestIndex+1..<list.endIndex).first(where: {
				let prevRect = list[$0-1].rect
				let thisRect = list[$0].rect
				return !(thisRect.minX >= prevRect.maxX && (prevRect.minY...prevRect.maxY).contains( thisRect.midY ))
			}) ?? list.endIndex

			// save the line of strings
			lines.append( Array( list[lower..<upper] ) )

			stack.append( list[..<lower] )
			stack.append( list[upper...] )
		}

		// sort lines top-to-bottom
		lines.sort(by: {$0.first!.rect.minY < $1.first!.rect.minY} )

		return lines
	}

	private class func stringsForImage(observations: [VNRecognizedTextObservation], transform:CGAffineTransform) -> [SubstringRectConfidence] {
		var wordList = [(Substring,CGRect,Float)]()
		for observation in observations {
			guard let candidate = observation.topCandidates(1).first else { continue }
			// Each observation can contain text in disconnected parts of the screen,
			// so we tokenize the string and extract the screen location of each token
			let words = candidate.string.split(separator: " ")
			let words2 = words.map({ word -> (Substring,CGRect,Float) in
				// Previous call returns tokens with substrings, which we can pass to candidate to get the rect
				let range = word.startIndex ..< word.endIndex
				let rect = try! candidate.boundingBox(for: range)!.boundingBox
				let rect2 = rect.applying(transform)
				return (word, rect2, candidate.confidence)
			})
			wordList += words2
		}
		return wordList
	}

	private func updateWithObservations(observations: [VNRecognizedTextObservation],
										transform: CGAffineTransform,
										camera: CameraView?)
	{
		#if true
		let raw = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
		Swift.print("\"\(raw)\"")
		#endif

		// get strings and locations
		let strings = HoursRecognizer.stringsForImage(observations: observations, transform: transform)

		// split into lines of text
		let stringLines = HoursRecognizer.getStringLines( strings )

		// convert lines of strings to lines of tokens
		let tokenLines = stringLines.compactMap { line -> [TokenRectConfidence]? in
			let string = line.map({ $0.substring }).joined(separator: " ")
			let tokens = HoursRecognizer.tokensForString( string )
			let tokens2 = tokens.filter({ $0.token.isDay() || $0.token.isTime() })
			let tokens3 = tokens2.map({ ($0.token, CGRect(), $0.confidence) })
			return tokens3.count > 0 ? tokens3 : nil
		}

		print("")
		print("lines:")
		for s in tokenLines.map({ $0.map({return "\($0.token)"}).joined(separator: " ")}) {
			print("\(s)")
		}

		// split the lines into discrete days/times sequences
		var tokenSets = [[TokenRectConfidence]]()
		for line in tokenLines {
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
		tokenSets = tokenSets.filter { $0.count > 0 }

		// if a sequence has multiple days then take only the best 2
		tokenSets = tokenSets.map( { return $0.first!.token.isDay() ? $0.bestTwo( {$0.confidence > $1.confidence} ) : $0 })

		// if a sequence has multiple times then take only the best 2 that are reasonably close together
		tokenSets = tokenSets.compactMap( {
			if !$0.first!.token.isTime() || $0.count < 2 { return $0 }	// anything not a time sequence return as-is
			let best = $0.bestTwo( {$0.confidence > $1.confidence} )
			if best.count == 1 {
				// don't permit an uncoupled time
				return nil
			}
			print("\(best[1].token)")
			if "\(best[1].token)" == "10:00" {
				print("bad")
			}
			return best
		})

		#if false
		print("")
		for line in tokenSets {
			let s1 = line.map( { "\($0.token)" }).joined(separator: " ")
			let s2 = line.map( { "\(Float(Int(100.0*$0.confidence))/100.0)" }).joined(separator: " ")
			print("\(s1): \(s2)")
		}
		#endif

		print("")
		print("sequences:")
		for s in tokenSets.map({ $0.map({return "\($0.token)"}).joined(separator: " ")}) {
			print("\(s)")
		}

		let invertedTransform = transform.inverted()
		let tokenBoxes = tokenSets.joined().map({$0.rect.applying(invertedTransform)})
		camera?.addBoxes(boxes: tokenBoxes, color: UIColor.green)

		let text = HoursRecognizer.hoursStringForTokens( tokenSets )

		print("\(text)")

		if text.contains("10:00-10:00") {
			print("bad")
		}

		let count = resultHistory[text] ?? 0
		resultHistory[text] = count+1

		let best = resultHistory.max { $0.value < $1.value }?.key ?? ""

		if Thread.isMainThread {
			self.text = best
		} else {
			DispatchQueue.main.async {
				self.text = best
			}
		}
	}

	func updateWithLiveObservations(observations: [VNRecognizedTextObservation], camera: CameraView?) {
		self.updateWithObservations(observations: observations,
									transform: CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: 1),
									   camera: camera)
	}

	func setImage(image: CGImage, isRotated: Bool) {
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
