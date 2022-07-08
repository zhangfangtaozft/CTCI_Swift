import Foundation

public extension Dictionary {
    mutating func addEntries<S: Sequence>(sequence: S) where S.Iterator.Element == (Key, Value) {
        sequence.forEach { self[$0.0] = $0.1 }
    }
    
    func addingEntries(from d: [Key: Value]) -> [Key: Value] {
        var dictionary = self
        d.forEach { dictionary[$0.0] = $0.1 }
        return dictionary
    }
    
    func addingEntries<S: Sequence>(from sequence: S) -> Dictionary<Key, Value> where S.Iterator.Element == (Key, Value) {
        var dictionary = self
        sequence.forEach { dictionary[$0.0] = $0.1 }
        return dictionary
    }
}

public extension Dictionary where Key: Comparable {
    var valuesSortedByKey: [Value] {
        return keys.sorted().map{ self[$0]! }
    }
}

public extension Sequence {
    func element(where predicate: (_ element: Iterator.Element) -> Bool) -> Iterator.Element?  {
        for element in self {
            if predicate(element) {
                return element
            }
        }
        return nil
    }
    
    func element<T>(where predicate: (_ element: Iterator.Element) -> T?) -> T? {
        for element in self {
            if let x = predicate(element) {
                return x
            }
        }
        return nil
    }
    
    func accumulate<T>(initial: T? = nil, combine: ([T], Iterator.Element) -> T) -> [T] {
        var elements: [T] = []
        if let initial = initial {
            elements.append(initial)
        }
        forEach { element in
            let transformed = combine(elements, element)
            elements.append(transformed)
        }
        return elements
    }
    
    func reduceWhile<T>(_ initial: T, combine: (T, Iterator.Element) -> T?) -> T {
        var combined = initial
        for element in self {
            guard let result = combine(combined, element) else {
                return combined
            }
            combined = result
        }
        return combined
    }
    
    func slice(where predicate: @escaping (Iterator.Element) -> Bool) -> [Iterator.Element] {
        let droped = drop { !predicate($0) }
        return droped.prefix { predicate($0) }
    }
    
}

public extension Collection {
    func lastIndex(where predicate: (Iterator.Element) -> Bool) -> Index? {
        let reverse = reversed()
        return reverse.firstIndex(where: predicate).map {
            let distance = reverse.distance(from: reverse.startIndex, to: $0)
            return self.index(endIndex, offsetBy: numericCast(distance))
        }
    }
    
    func takeWhile<T>(predicate: (Index, Iterator.Element) -> T?) -> [T]? {
        var elements: [T] = []
        var index = startIndex
        for el in self {
            guard let element = predicate(index, el) else {
                break
            }
            elements.append(element)
            index = self.index(after: index)
        }
        return elements.isEmpty ? nil : elements
    }
}

public extension Collection where SubSequence: Collection, SubSequence.Indices.Iterator.Element == Index {
    func range(where predicate: @escaping (Iterator.Element) -> Bool) -> ClosedRange<Index>? {
        guard let first = firstIndex(where: predicate) else { return nil }
        let slice = self[index(after: first)..<endIndex]
        let last = slice.indices.reduceWhile(nil as Index?) {
            predicate(self[$1]) ? $1 : nil
        }
        return last.map { first...$0 } ?? first...first
    }
}

public extension String {
    func replacingOccurrences(of replacementMap: [Character: Character]) -> String {
        return String(map { character in replacementMap[character] ?? character })
    }
    
    mutating func replaceOccurences(of replacementMap: [Character: Character]) {
        for i in indices {
            if let rep = replacementMap[self[i]] {
                self.replaceSubrange(i...i, with: [rep])
            }
        }
    }
    
    func appending(string: String?) -> String {
        return self + (string ?? "")
    }
    
    var nonEmpty: String? {
        return self.isEmpty ? nil : self
    }
    
    init?(toJion: [String?], separator: String = " ") {
        var string = ""
        toJion.forEach { s in
            guard let s = s else {
                return
            }
            string += s + separator
        }
        guard !string.isEmpty else { return nil }
        string.dropLast()
        self = string
    }
    
    // Bridge an objective-c range
    
    func substring(at range: NSRange) -> Substring {
        let start = index(startIndex, offsetBy: range.location)
        let end = index(start, offsetBy: range.length)
        return self[start..<end]
    }
    
    var nsRange: NSRange {
        return NSRange(location: 0, length: utf16.count)
    }
    
    func nsRangeOf(range: Range<Index>) -> NSRange {
        let location = distance(from: startIndex, to: range.lowerBound)
        let length = distance(from: range.lowerBound, to: range.upperBound)
        return NSRange(location: location, length: length)
    }
    
    func distanceTo(character: Character) -> IndexDistance? {
        var distance = 0
        for c in self {
            if c == character {
                return distance
            }
            distance += 1
        }
        return nil
    }
    
    func rangeOf(range: NSRange) ->Range<Index> {
        let start = index(startIndex, offsetBy: range.location)
        let end = index(start, offsetBy: range.length)
        return start..<end
    }
    
    func replacingMatches(of regExPattern: String, options: NSRegularExpression.Options = [], replacement: @escaping (_ match: String) -> String?) -> String? {
        return replacingMatches(of: regExPattern, options: options, range: startIndex..<endIndex) { match, _, _ in
                replacement(match)
        }
    }
    
    func replacingMatches(of pattern: String, options: NSRegularExpression.Options = [], range: Range<Index>, replacement: @escaping (_ match: String, _ result: NSTextCheckingResult, _ stop: UnsafeMutablePointer<ObjCBool>) -> String?) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        var selfCopy = self
        let nsRange = self.nsRangeOf(range: range)
        
        regex.enumerateMatches(in: self, options: [], range: nsRange) { checkingResult, _, stop in
            guard let checkingResult = checkingResult else {
                return
            }
            let match = substring(at: checkingResult.range)
            guard let  replacement = replacement(String(match), checkingResult, stop) else { return }
            
            let minLength = min(replacement.count, match.count)
            var replacementString = replacement[..<replacement.index(startIndex, offsetBy: minLength)]
            
            let offset = selfCopy.count - count
            let start = selfCopy.index(startIndex, offsetBy: checkingResult.range.location + offset)
            let end = selfCopy.index(start, offsetBy: checkingResult.range.length)
            selfCopy.replaceSubrange(start..<end, with: replacementString)
            
            if replacement.count < replacement.count {
                replacementString = replacement[replacementString.endIndex...]
                selfCopy.insert(contentsOf: replacementString, at: end)
            }
        }
        return selfCopy
    }
    
    // Drop the last character
    mutating func dropLast() {
        let start = index(before: endIndex)
        replaceSubrange(start..<endIndex, with: [])
    }
    
    mutating func replaceAtIndex(i: Index, c: Character) {
        guard i < endIndex else { return }
        replaceSubrange(i...i, with: [c])
    }
    
    func rangeDistanceOfString(string: String) -> Range<IndexDistance>? {
        guard let range = range(of: string) else { return nil }
        let start = distance(from: startIndex, to: range.lowerBound)
        let end = start + distance(from: range.lowerBound, to: range.upperBound)
        return start..<end
    }
    
    func distance(to predicate: (_: Character) -> Bool) -> IndexDistance? {
        return reduceWhile(0) { distance, c -> Int? in
            guard !predicate(c) else { return nil }
            return distance + 1
        }
    }
}

public extension Date {
    var startOfTheDay: Date {
        return Calendar.autoupdatingCurrent.startOfDay(for: self)
    }
    
    var startOfTheHour: Date {
        let second = Calendar.autoupdatingCurrent.component(.hour, from: self) * 3600
        return Calendar.autoupdatingCurrent.startOfDay(for: self) + TimeInterval(second)
    }
    
    var startOfTheMinute: Date {
        let second = TimeInterval(Calendar.autoupdatingCurrent.component(.second, from: self))
        let nanoSeconds = timeIntervalSince1970 - TimeInterval(Int(timeIntervalSince1970))
        return self - second - nanoSeconds
    }
    
    var isSameHourAsNow: Bool {
        guard Calendar.autoupdatingCurrent.isDateInToday(self) else { return false }
        let selfHour = Calendar.autoupdatingCurrent.component(.hour, from: self)
        let nowHour = Calendar.autoupdatingCurrent.component(.hour, from: Date())
        return selfHour == nowHour
    }
    
    var shortStyle: String {
        return DateFormatter.localizedString(from: self, dateStyle: .short, timeStyle: .short)
    }
}

@available(iOS 10.0, *)
public extension ISO8601DateFormatter {
    convenience init(timeZone: TimeZone) {
        self.init()
        self.timeZone = timeZone
    }
}

public extension DateFormatter {
    convenience init(dateFormat: String?, timeZone: TimeZone?) {
        self.init()
        self.dateFormat = dateFormat
        self.timeZone = timeZone
    }
}

public extension TimeZone {
    var hourOfTheDay: Int {
        var calender = Calendar.autoupdatingCurrent
        calender.timeZone = self
        return calender.component(.hour, from: Date())
    }
    
    var hoursRemainingInToday: Int {
        return 23 - hourOfTheDay
    }
    
    static func timeZoneFor(iso8601OrRFC822TimeZone dateString: String) -> TimeZone? {
        let iso8601OrRFC822TimeZonePattern = "([+-])(0\\d|1[0-4]):?([0-5]\\d)$"
        let regex = try! NSRegularExpression(pattern: iso8601OrRFC822TimeZonePattern, options: .anchorsMatchLines)
        guard let match = regex.firstMatch(in: dateString, options: [], range: NSRange(location: 0, length: dateString.utf16.count)),
              match.numberOfRanges == 4 else { return nil }
        
        let substrings = match.substrings(of: dateString)
        guard let sign = Int(substrings[1] + "1"), let hours = Int(substrings[2]), let minutes = Int(substrings[3]) else { return nil }
        let offset = (hours * 3600 + minutes * 60) * sign
        return TimeZone(secondsFromGMT: offset)
    }
    
    static func hoursRemainingInDay(of dateString: String) -> Int? {
        guard let timeZone = timeZoneFor(iso8601OrRFC822TimeZone: dateString) else {
            return nil
        }
        return timeZone.hoursRemainingInToday
    }
    
    static func hourOfTheDay(of dateString: String) -> Int? {
        guard let timeZone = timeZoneFor(iso8601OrRFC822TimeZone: dateString) else {
            return nil
        }
        return timeZone.hourOfTheDay
    }
}

public extension NSTextCheckingResult {
    func substrings(of checkedString: String) -> [Substring] {
        return (0..<numberOfRanges).map {
            checkedString.substring(at: range(at: $0))
        }
    }
    
    func substrings(of checkedString: String, captureGroup: CountableRange<Int>) -> [Substring] {
        return captureGroup.map { index in
            checkedString.substring(at: range(at: index))
        }
    }
}

public extension OperationQueue {
    convenience init(qualityOfService: QualityOfService) {
        self.init()
        self.qualityOfService = qualityOfService
    }
    
    func addOperations(operations: [Operation], completionOperation: Operation) {
        operations.forEach {
            completionOperation.addDependency($0)
            addOperation($0)
        }
        addOperation(completionOperation)
    }
    
    func add(_ block: @escaping () -> ()) {
        addOperation(block)
    }
}

// MARK: - Shortened NSLocalizedString
func NSLocalizedString(key: String) -> String {
    return NSLocalizedString(key, comment: "")
}

public extension Array {
    var dropFirst: Array {
        return Array(dropFirst())
    }
}

var minQueue: OperationQueue { return OperationQueue.main }
