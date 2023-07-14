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
        print (result.serialize().hexString)
        let expected = Data(hexString: "f1c71c71c71c71c71c71c71c71c71c7093de09848919ecaa352a3cda52dde84d")
        XCTAssertEqual(result.serialize().suffix(32), expected)
    }
    
    func testGetAdditiveCoeff () throws {
        let result = getAdditiveCoeff(isUser: true, participatingServerIndexes: [BigInt(100), BigInt(200), BigInt(300)], userTSSIndex: BigInt(10))
        print(result.serialize().hexString)
        let expected = Data(hexString: "71c71c71c71c71c71c71c71c71c71c7136869b1131759c8c55410d93eac2c7ab>")
        XCTAssertEqual(result.serialize().suffix(32), expected)
    }
    
    
    func testGetDenormaliseCoeff () throws {
        let result = getDenormaliseCoeff(party: BigInt(100), parties: [BigInt(100), BigInt(200)])
        print (result)
        let expected = Data(hexString: "7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a1>")
        XCTAssertEqual(result.serialize().suffix(32), expected)
    }
    
    func testGetDKLSCoeff () throws {
        let result = getDKLSCoeff(isUser: true, participatingServerIndexes: [BigInt(100), BigInt(200)], userTSSIndex: BigInt(10))
        print (result)
        let expected = Data(hexString: "a57eb50295fad40a57eb50295fad40a4ac66b301bc4dfafaaa8d2b05b28fae1>")
        XCTAssertEqual(result.serialize().suffix(32), expected)
    }
    
    
    
}
