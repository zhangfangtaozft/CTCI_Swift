/*:
 1.2 Determine if a string is a permutation of another
 */

//: [Previous](@previous)
extension String {
    func characterCounts() -> [Character: Int] {
        var characterCounts = [Character: Int]()
        for char in self {
            characterCounts[char] = (characterCounts[char] ?? 0) + 1
        }
        return characterCounts
    }
    
    func isPermutation(s: String) -> Bool {
        return characterCounts() == s.characterCounts()
    }
}

let s1 = "elvis"
let s2 = "lives"

assert(s2.isPermutation(s: s1))
//: [Next](@next)
