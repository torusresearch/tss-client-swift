import XCTest
import BigInt
@testable import tss_client_swift


final class helpersTests: XCTestCase {
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        print(BigUInt(4) - BigUInt(2));
        XCTAssertEqual(tss_client_swift().text, "Hello, World!")
    }
    
    func testGetLangrange () throws {
        let result = getLagrangeCoeffs([BigInt(50), BigInt(100)], BigInt(10))
        let expected = "f1c71c71c71c71c71c71c71c71c71c7093de09848919ecaa352a3cda52dde84d".addLeading0sForLength64()
        XCTAssertEqual(result.serialize().suffix(32).toHexString(), expected)
    }
    
    func testGetAdditiveCoeff () throws {
        let result = getAdditiveCoeff(isUser: true, participatingServerIndexes: [BigInt(100), BigInt(200), BigInt(300)], userTSSIndex: BigInt(10))
        let expected = "71c71c71c71c71c71c71c71c71c71c7136869b1131759c8c55410d93eac2c7ab".addLeading0sForLength64()
        XCTAssertEqual(result.serialize().suffix(32).toHexString(), expected)
    }
    
    func testGetDenormaliseCoeff () throws {
        let result = getDenormaliseCoeff(party: BigInt(100), parties: [BigInt(100), BigInt(200)])
        let expected = "7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a1".addLeading0sForLength64()
        XCTAssertEqual(result.serialize().suffix(32).toHexString(), expected)
    }
    
    func testGetDKLSCoeff () throws {
        let result = getDKLSCoeff(isUser: true, participatingServerIndexes: [BigInt(100), BigInt(200)], userTSSIndex: BigInt(100))
        let expected = "a57eb50295fad40a57eb50295fad40a4ac66b301bc4dfafaaa8d2b05b28fae1".addLeading0sForLength64()
        XCTAssertEqual(result.serialize().suffix(32).toHexString(), expected)
    }
    
    
    
}
