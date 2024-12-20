import XCTest
import BigInt
@testable import tssClientSwift

final class helpersTests: XCTestCase {
    func testGetLangrange () throws {
        let result = try! TSSHelpers.getLagrangeCoefficient(parties: [BigInt(50), BigInt(100)], party:  BigInt(10)).serialize().suffix(32).hexString
        let expected = "f1c71c71c71c71c71c71c71c71c71c7093de09848919ecaa352a3cda52dde84d".addLeading0sForLength64()
        XCTAssertEqual(result, expected)
    }
    
    func testGetAdditiveCoefficient () throws {
        let result = try TSSHelpers.getAdditiveCoefficient(isUser: true, participatingServerIndexes: [BigInt(100), BigInt(200), BigInt(300)], userTSSIndex: BigInt(10), serverIndex: nil)
        let expected = "71c71c71c71c71c71c71c71c71c71c7136869b1131759c8c55410d93eac2c7ab".addLeading0sForLength64()
        XCTAssertEqual(result.serialize().suffix(32).hexString, expected)
        
        let coeff = try TSSHelpers.getAdditiveCoefficient(isUser: false, participatingServerIndexes: [BigInt(1), BigInt(4), BigInt(5)], userTSSIndex: BigInt(3), serverIndex: BigInt(1))
        let compare = BigInt("7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a3", radix: 16)
        XCTAssert(coeff == compare)
    }
    
    func testGetDenormaliseCoefficient () throws {
        let result = try TSSHelpers.getDenormalizedCoefficient(party: BigInt(100), parties: [BigInt(100), BigInt(200)])
        let expected = "7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a1".addLeading0sForLength64()
        XCTAssertEqual(result.serialize().suffix(32).hexString, expected)
    }

    func testGetDKLSCoeff () throws {
        let result = try TSSHelpers.getDKLSCoefficient(isUser: true, participatingServerIndexes:  [BigInt(100), BigInt(200)], userTssIndex: BigInt(100), serverIndex: nil)
        let expected = "a57eb50295fad40a57eb50295fad40a4ac66b301bc4dfafaaa8d2b05b28fae1".addLeading0sForLength64()
        XCTAssertEqual(result.serialize().suffix(32).hexString, expected)
        
        let dklsCoeff = try TSSHelpers.getDKLSCoefficient(isUser: true, participatingServerIndexes: [BigInt(1), BigInt(4), BigInt(5)], userTssIndex: BigInt(3), serverIndex: nil)
        let compare = BigInt("7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a1", radix: 16)
        XCTAssert(dklsCoeff == compare)
        
        let coeff2 = try TSSHelpers.getDKLSCoefficient(isUser: false, participatingServerIndexes: [1, 2, 5], userTssIndex: BigInt(3), serverIndex: 2)
        let comp = BigInt("955555555555555555555555555555549790ab8690ea5d782fe561d2241fa611", radix: 16)
        XCTAssert(coeff2 == comp)
        
        // example related test
        let coeff01 = try TSSHelpers.getDKLSCoefficient(isUser: false, participatingServerIndexes: [BigInt(1), BigInt(2), BigInt(3)], userTssIndex: BigInt(3), serverIndex: 1)
        let coeff02 = try TSSHelpers.getDKLSCoefficient(isUser: false, participatingServerIndexes: [1, 2, 3], userTssIndex: BigInt(3), serverIndex: 2)
        let coeff03 = try TSSHelpers.getDKLSCoefficient(isUser: false, participatingServerIndexes: [1, 2, 3], userTssIndex: BigInt(3), serverIndex: 3)
        XCTAssert(coeff01 == BigInt("00dffffffffffffffffffffffffffffffee3590149d95f8c3447d812bb362f791a", radix: 16))
        XCTAssert(coeff02 == BigInt("003fffffffffffffffffffffffffffffffaeabb739abd2280eeff497a3340d9051", radix: 16))
        XCTAssert(coeff03 == BigInt("009fffffffffffffffffffffffffffffff34ad4a102d8d642557e37b180221e8c9", radix: 16))
        
        let userCoeff2 = try TSSHelpers.getDKLSCoefficient(isUser: true, participatingServerIndexes: [1, 2, 3], userTssIndex: BigInt(2), serverIndex: nil)
        let userCoeff3 = try TSSHelpers.getDKLSCoefficient(isUser: true, participatingServerIndexes: [1, 2, 3], userTssIndex: BigInt(3), serverIndex: nil)
        XCTAssert(userCoeff2 == BigInt("1", radix: 16))
        XCTAssert(userCoeff3 == BigInt("007fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a1", radix: 16))
        
        let userCoeff22 = try TSSHelpers.getClientCoefficients(participatingServerDKGIndexes: [BigInt(1), BigInt(2), BigInt(3)], userTssIndex: BigInt(2))
        let userCoeff23 = try TSSHelpers.getClientCoefficients(participatingServerDKGIndexes: [BigInt(1), BigInt(2), BigInt(3)], userTssIndex: BigInt(3))
        XCTAssert(userCoeff22.removeLeadingZeros() == "1")
        XCTAssert(userCoeff23.removeLeadingZeros() == "7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a1")
        
    }
    
    func testDenormalizeShare () throws {
        let share = BigUInt(Data(hexString:  "18db3574e4217154769ad9cd88900e7f1c198aa60a1379f3869ba8a7699e6b53")!)
        let denormalize2 = try TSSHelpers.denormalizeShare(participatingServerDKGIndexes: [BigInt(1), BigInt(2), BigInt(3) ], userTssIndex: BigInt(2), userTssShare: BigInt(sign: .plus, magnitude: share))
        let denormalize3 = try TSSHelpers.denormalizeShare(participatingServerDKGIndexes: [BigInt(1), BigInt(2), BigInt(3) ], userTssIndex: BigInt(3), userTssShare: BigInt(sign: .plus, magnitude: share))

        XCTAssert(denormalize2 == BigInt("18db3574e4217154769ad9cd88900e7f1c198aa60a1379f3869ba8a7699e6b53", radix: 16))
        XCTAssert(denormalize3 == BigInt("008c6d9aba7210b8aa3b4d6ce6c448073eeb6433c65cae0d17a337039a1cea564a", radix: 16))
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
        
        XCTAssertEqual(tssPub.hexString, "04dd1619c7e99eb665e37c74828762e6a677511d4c52656ddc6499a57d486bddb8c0dc63b229ec9a31f4216138c3fbb67ac2630831135aecbaf0aafa095e439c61")
    }
    
    func testRemoveZeroTest() throws{
        let string = "000010"
        let result = string.removeLeadingZeros()
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
    
    func testGetServerCoefficients() throws {
        let coefficients_index3: [String: String] = [
            "1": "1",
            "2": "7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a1",
            "4": "dffffffffffffffffffffffffffffffee3590149d95f8c3447d812bb362f7919",
        ]
        
        let coeffs_index3 = try TSSHelpers.getServerCoefficients(participatingServerDKGIndexes: [BigInt(1),BigInt(2),BigInt(4)], userTssIndex: BigInt(3))
        
        XCTAssert(coeffs_index3 == coefficients_index3)
        
        let coefficients_index2: [String: String] = [
            "1": "7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a2",
            "2": "1",
            "3": "7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a1",
        ]
        
        let coeffs_index2 = try TSSHelpers.getServerCoefficients(participatingServerDKGIndexes: [BigInt(1),BigInt(2),BigInt(3)], userTssIndex: BigInt(2))
        XCTAssert(coeffs_index2 == coefficients_index2)
    }
}

