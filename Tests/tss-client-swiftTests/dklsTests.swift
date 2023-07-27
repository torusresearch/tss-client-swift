@testable import tss_client_swift
import XCTest

final class dklsTests: XCTestCase {
    func testRng() throws {
        let _ = try ChaChaRng()
    }

    func testCounterparties() throws {
        let parties = "1,2"
        let counterparties = try Counterparties(parties: parties)
        let export = try counterparties.export()
        XCTAssertEqual(parties, export)
    }

    func testSignatureFragments() throws {
        let input = "JLphVR9bO7pNnmL6dRQARixCwk3P07tsWu7TETIXNF0=,fcMuarM6YL0MR5j1kDxFw+q6OyKigW8n5sZnBGvzRZo=,BBJdnq8dFqFCXaiJZSiUzGANUDxlP8UXAenW9gfKLvk="
        let fragments = try SignatureFragments(input: input)
        let export = try fragments.export()
        XCTAssertEqual(input, export)
    }

    func testUtilities() throws {
        let hashed = try Utilities.hashEncode(message: "Hello World")
        XCTAssertEqual(hashed, "pZGm1Av0IEBKARczz7exkNYsZb8LzaMrV7J32a2fFG4=")

        let batchSize = try Utilities.batchSize()
        XCTAssertGreaterThan(batchSize, 0)

        let hashOnly = true
        var hash = "pZGm1Av0IEBKARczz7exkNYsZb8LzaMrV7J32a2fFG4="
        var precompute = try Precompute(precompute: "TSbPQiau1tJoG6b2flNKXXb8EIGqgaAZ7PkuWJaNcKEGp8NkxS4XSrAF4gZlRmj4E+L9SOZ828DsusCUjUh8DA==#Q+aH50RJf1Aw2YHHyLc924drM8gqW9/lwxP5JTcejvM=#rkq/wFk2XPl3zv0XkHGyt4Duru9ao8zbmt6I4zorEXc=#vyx89I4ypkFtqi062u7xOCq35DZgwp6Gfo2VFoQpFzc=")
        let signature_fragment = try Utilities.localSign(message: hash, hashOnly: hashOnly, precompute: precompute)
        XCTAssertEqual(signature_fragment, "JLphVR9bO7pNnmL6dRQARixCwk3P07tsWu7TETIXNF0=")

        hash = "pZGm1Av0IEBKARczz7exkNYsZb8LzaMrV7J32a2fFG4="
        precompute = try Precompute(precompute: "TSbPQiau1tJoG6b2flNKXXb8EIGqgaAZ7PkuWJaNcKEGp8NkxS4XSrAF4gZlRmj4E+L9SOZ828DsusCUjUh8DA==#Q+aH50RJf1Aw2YHHyLc924drM8gqW9/lwxP5JTcejvM=#rkq/wFk2XPl3zv0XkHGyt4Duru9ao8zbmt6I4zorEXc=#vyx89I4ypkFtqi062u7xOCq35DZgwp6Gfo2VFoQpFzc=")
        let fragments = try SignatureFragments(input: "JLphVR9bO7pNnmL6dRQARixCwk3P07tsWu7TETIXNF0=,fcMuarM6YL0MR5j1kDxFw+q6OyKigW8n5sZnBGvzRZo=,BBJdnq8dFqFCXaiJZSiUzGANUDxlP8UXAenW9gfKLvk=")
        let pubKey = "mbkxU1rQ0QkUzcFBUSSGh8TSaO2ndoHBXiIJexxa26DK430ZcOQIkYyWYgeRaIvyZo7oQliNd6PquEcIE2daUw=="
        let sig = try Utilities.localVerify(message: hash, hashOnly: hashOnly, precompute: precompute, signatureFragments: fragments, pubKey: pubKey)
        XCTAssertEqual(sig, "TSbPQiau1tJoG6b2flNKXXb8EIGqgaAZ7PkuWJaNcKGmj+1egbKzGJxDpHlqeNrWdwpNrNeU76tDnxELpdSo8A==")
    }

    func testPrecompute() throws {
        let input = "TSbPQiau1tJoG6b2flNKXXb8EIGqgaAZ7PkuWJaNcKEGp8NkxS4XSrAF4gZlRmj4E+L9SOZ828DsusCUjUh8DA==#Q+aH50RJf1Aw2YHHyLc924drM8gqW9/lwxP5JTcejvM=#rkq/wFk2XPl3zv0XkHGyt4Duru9ao8zbmt6I4zorEXc=#vyx89I4ypkFtqi062u7xOCq35DZgwp6Gfo2VFoQpFzc="
        let precompute = try Precompute(precompute: input)
        let r = try precompute.getR()
        XCTAssertEqual(r, "TSbPQiau1tJoG6b2flNKXXb8EIGqgaAZ7PkuWJaNcKEGp8NkxS4XSrAF4gZlRmj4E+L9SOZ828DsusCUjUh8DA==")
        let export = try precompute.export()
        XCTAssertEqual(input, export)
    }

    func testThresholdSignerInit() throws {
        let session = "testingSharestest_verifier_name\u{1c}test_verifier_id\u{15}default\u{16}0\u{17}577f8e058813e31d332c920ace5298b563c36d8d02d5c8cbce5b91621b7ef63etestingShares"
        let parties: Int32 = 2
        let threshold: Int32 = 2
        let index: Int32 = 0
        let share = "jLot8K2VTTJARiS7XCOuyYGE+rwsfNFFCq6CCyCdqSw="
        let publicKey = "+AHtxLzwIRuzGFj/PZlgPpupyzqBvCn63nXjrWd6B9djE4NZL5b/HaHW/fGTxlfCa871n+FrkUnQhnSd3+ND7A=="
        let _ = try ThresholdSigner(session: session, playerIndex: index, parties: parties, threshold: threshold, share: share, publicKey: publicKey)
    }
}
