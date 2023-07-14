import XCTest
import BigInt
@testable import tss_client_swift


final class helpersTests: XCTestCase {
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        print(BigUInt(4) - BigUInt(2));
//        XCTAssertEqual(tss_client_swift().text, "Hello, World!")
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
        let result = try! getDenormaliseCoeff(party: BigInt(100), parties: [BigInt(100), BigInt(200)])
        let expected = "7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a1".addLeading0sForLength64()
        XCTAssertEqual(result.serialize().suffix(32).toHexString(), expected)
    }
    
    func testGetDKLSCoeff () throws {
        let result = getDKLSCoeff(isUser: true, participatingServerIndexes: [BigInt(100), BigInt(200)], userTSSIndex: BigInt(100))
        let expected = "a57eb50295fad40a57eb50295fad40a4ac66b301bc4dfafaaa8d2b05b28fae1".addLeading0sForLength64()
        print(expected)
        XCTAssertEqual(result.serialize().suffix(32).toHexString(), expected)
    }
    
    func testGetTSSPubkey() throws{
        let key1: Point = Point(x: "18db3574e4217154769ad9cd88900e7f1c198aa60a1379f3869ba8a7699e6b53", y: "d4f7d578667c38003f881f262e21655a38241401d9fc029c9a6fcbca8ac97713");
        
        let key2: Point = Point(x: "b4259bffab844a5255ba0c8f278b7fd857c094460b9051c95f04b29f9792368c", y: "790eb133df835aa22fd087d5e33b26f2d2e046b6670ac7603500bc1227216247");
        
        let key1pub = publicKey(x: key1.x, y: key1.y);
        let key2pub = publicKey(x: key2.x, y: key2.y);
        let tsspub = try! getTSSPubKey(dkgPubKey: key1pub, userSharePubKey: key2pub, userTSSIndex: BigInt(2));
        XCTAssertEqual(tsspub.toHexString(), "04dd1619c7e99eb665e37c74828762e6a677511d4c52656ddc6499a57d486bddb8c0dc63b229ec9a31f4216138c3fbb67ac2630831135aecbaf0aafa095e439c61")
    }
    
    
    
}
