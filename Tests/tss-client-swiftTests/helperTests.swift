import XCTest
import BigInt
import tss_client_swift


final class helpersTests: XCTestCase {
    func testGetLangrange () throws {
        let result = try! TSSHelpers.getLagrangeCoefficient(parties: [BigInt(50), BigInt(100)], party:  BigInt(10)).serialize().suffix(32).toHexString()
        let expected = "f1c71c71c71c71c71c71c71c71c71c7093de09848919ecaa352a3cda52dde84d".addLeading0sForLength64()
        XCTAssertEqual(result, expected)
    }
    
    func testGetAdditiveCoefficient () throws {
        let result = try TSSHelpers.getAdditiveCoefficient(isUser: true, participatingServerIndexes: [BigInt(100), BigInt(200), BigInt(300)], userTSSIndex: BigInt(10), serverIndex: nil)
        let expected = "71c71c71c71c71c71c71c71c71c71c7136869b1131759c8c55410d93eac2c7ab".addLeading0sForLength64()
        XCTAssertEqual(result.serialize().suffix(32).toHexString(), expected)
        
        let coeff = try TSSHelpers.getAdditiveCoefficient(isUser: false, participatingServerIndexes: [BigInt(1), BigInt(4), BigInt(5)], userTSSIndex: BigInt(3), serverIndex: BigInt(1))
        let compare = BigInt("7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a3", radix: 16)
        XCTAssert(coeff == compare)
    }
    
    func testGetDenormaliseCoefficient () throws {
        let result = try TSSHelpers.getDenormalizedCoefficient(party: BigInt(100), parties: [BigInt(100), BigInt(200)])
        let expected = "7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a1".addLeading0sForLength64()
        XCTAssertEqual(result.serialize().suffix(32).toHexString(), expected)
    }
    
    func testGetDKLSCoeff () throws {
        let result = try TSSHelpers.getDKLSCoefficient(isUser: true, participatingServerIndexes:  [BigInt(100), BigInt(200)], userTssIndex: BigInt(100), serverIndex: nil)
        let expected = "a57eb50295fad40a57eb50295fad40a4ac66b301bc4dfafaaa8d2b05b28fae1".addLeading0sForLength64()
        print(expected)
        XCTAssertEqual(result.serialize().suffix(32).toHexString(), expected)
        
        let dklsCoeff = try TSSHelpers.getDKLSCoefficient(isUser: true, participatingServerIndexes: [BigInt(1), BigInt(4), BigInt(5)], userTssIndex: BigInt(3), serverIndex: nil)
        let compare = BigInt("7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a1", radix: 16)
        XCTAssert(dklsCoeff == compare)
        
        let coeff2 = try TSSHelpers.getDKLSCoefficient(isUser: false, participatingServerIndexes: [1, 2, 5], userTssIndex: BigInt(3), serverIndex: 2)
        let comp = BigInt("955555555555555555555555555555549790ab8690ea5d782fe561d2241fa611", radix: 16)
        XCTAssert(coeff2 == comp)
    }

    func testFinalGetTSSPubkey() throws{
        var dkgpub = Data()
        dkgpub.append(0x04) // Uncompressed key prefix
        dkgpub.append(Data(hexString: "18db3574e4217154769ad9cd88900e7f1c198aa60a1379f3869ba8a7699e6b53".padLeft(padChar: "0", count: 64))!)
        dkgpub.append(Data(hexString: "d4f7d578667c38003f881f262e21655a38241401d9fc029c9a6fcbca8ac97713".padLeft(padChar: "0", count: 64))!)
        
        var userpub = Data()
        userpub.append(0x04) // Uncompressed key prefix
        userpub.append(Data(hexString: "b4259bffab844a5255ba0c8f278b7fd857c094460b9051c95f04b29f9792368c".padLeft(padChar: "0", count: 64))!)
        userpub.append(Data(hexString: "790eb133df835aa22fd087d5e33b26f2d2e046b6670ac7603500bc1227216247".padLeft(padChar: "0", count: 64))!)
        
        let tssPub = try TSSHelpers.getFinalTssPublicKey(dkgPubKey: dkgpub, userSharePubKey: userpub, userTssIndex: BigInt(2))
        
        XCTAssertEqual(tssPub.toHexString(), "04dd1619c7e99eb665e37c74828762e6a677511d4c52656ddc6499a57d486bddb8c0dc63b229ec9a31f4216138c3fbb67ac2630831135aecbaf0aafa095e439c61")
    }
    
    func testRemoveZeroTest() throws{
        var string = "000010"
        var result = string.removeLeadingZeros()
        XCTAssert("10" == result)
        
        var str = "10"
        var res = str.removeLeadingZeros()
        XCTAssert(str == res)
        
        str = "0100056"
        res = str.removeLeadingZeros()
        XCTAssert("100056" == res)
        
        str = ""
        res = str.removeLeadingZeros()
        XCTAssert("" == res)
        
        str = "000000"
        res = str.removeLeadingZeros()
        XCTAssert("0" == res)
    }
}

