import Foundation

public extension String {
    func addLeading0sForLength64() -> String {
        if count < 64 {
            let toAdd = String(repeating: "0", count: 64 - count)
            return toAdd + self
        } else {
            return self
        }
        // String(format: "%064d", self)
    }
    
    func removeLeadingZeros() -> String {
        let found = self.firstIndex(where: { $0 != "0" })
        if let found = found {
            return String(self[found...])
        }
        if self.isEmpty {
            return self
        } else {
            return "0"
        }
    }
    
    func padLeft(padChar: Character, count: Int) -> String {
            let str = self
            if str.count >= count {
                return str
            }
            var resultStr = ""
            while str.count < count - str.count {
                resultStr.append(padChar)
            }
            resultStr.append(str)
            return resultStr
        }
}
