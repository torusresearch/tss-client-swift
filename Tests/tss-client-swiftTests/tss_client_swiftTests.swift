import BigInt
import tss_client_swift
import XCTest
import curvelib
import CryptoSwift

final class tss_client_swiftTests: XCTestCase {
    struct Delimiters {
        static let Delimiter1 = "\u{001c}"
        static let Delimiter2 = "\u{0015}"
        static let Delimiter3 = "\u{0016}"
        static let Delimiter4 = "\u{0017}"
    }

    // this will only work for local testing with local servers
    let privateKeys = [
        "da4841d60f47652584aea0ab578660b353dbcd6907940ed0a295c9d95aabadd0",
        "e7ef4a9dcc9c0305ec9e56c79128f5c12413b976309368c35c11f3297459994b",
        "31534072a75a1d8b7f07c1f29930533ae44166f44ce08a4a23126b6dcb8b6efe",
        "f2588097a5df3911e4826e13dce2b6f4afb798bb8756675b17d4195db900af20",
        "5513438cd00c901ff362e25ae08aa723495bea89ab5a53ce165730bc1d9a0280",
    ]

    var share: BigInt = BigInt.zero

    private func getSignatures() throws -> [String] {
        let tokenData: [String: Any] = [
            "exp": Date().addingTimeInterval(3000 * 60).timeIntervalSince1970,
            "temp_key_x": "test_key_x",
            "temp_key_y": "test_key_y",
            "verifier_name": "test_verifier_name",
            "verifier_id": "test_verifier_id",
        ]

        let token = Data(try JSONSerialization.data(withJSONObject: tokenData)).base64EncodedString()

        var sigs: [String] = []
        for item in privateKeys {
            let hash = TSSHelpers.hashMessage(message: token)
            let data = hash 
            let msgB64 = data
            
            let pkey = try curvelib.Secp256k1.PrivateKey(input: Data(hexString: item))
            let rSignature = try curvelib.Secp256k1.recoverableSign(privateKey: pkey, hash: msgB64)
            
            let sig = rSignature.signature + Data([rSignature.recoverId])
            
            let msg: [String: Any] = [
                "data": token,
                "sig": sig.toHexString(),
            ]
            let jsonData = String(decoding: try JSONSerialization.data(withJSONObject: msg), as: UTF8.self)
            sigs.append(jsonData)
        }

        return sigs
    }

    private func lagrange(parties: [BigInt], party: BigInt) -> BigInt {
        let partyIndex = party + 1
        var upper = BigInt(1)
        var lower = BigInt(1)
        for i in 0 ..< parties.count {
            let otherParty = parties[i]
            let otherPartyIndex = otherParty + 1
            if party != otherParty {
                var otherPartyIndexNeg = otherPartyIndex
                otherPartyIndexNeg.negate()
                upper = (upper * otherPartyIndexNeg).modulus(TSSClient.modulusValueSigned)
                let temp = (partyIndex - otherPartyIndex).modulus(TSSClient.modulusValueSigned)
                lower = (lower * temp).modulus(TSSClient.modulusValueSigned)
            }
        }
        let lowerInverse = lower.inverse(TSSClient.modulusValueSigned)
        XCTAssert(lowerInverse != nil)
        let delta = (upper * lowerInverse!).modulus(TSSClient.modulusValueSigned)
        return delta
    }

    private func distributeShares(privKey: BigInt, parties: [Int32], endpoints: [String?], localClientIndex: Int32, session: String) throws {
        var additiveShares: [BigInt] = []
        var shareSum = BigInt.zero
        for _ in 0 ..< (parties.count - 1) {
            
            let shareBigUint = try BigUInt(curvelib.Secp256k1.PrivateKey().rawData)
            
            let shareBigInt = BigInt(sign: .plus, magnitude: shareBigUint)
            additiveShares.append(shareBigInt)
            shareSum += shareBigInt
        }

        let finalShare = (privKey - shareSum.modulus(TSSClient.modulusValueSigned)).modulus(TSSClient.modulusValueSigned)
        additiveShares.append(finalShare)

        let reduced = additiveShares.reduce(0) {
            ($0 + $1).modulus(TSSClient.modulusValueSigned)
        }
        XCTAssert(reduced.serialize().toHexString() == privKey.serialize().toHexString())

        // denormalize shares
        var shares: [BigInt] = []
        print(shares)
        for (partyIndex, additiveShare) in additiveShares.enumerated() {
            let partiesBigInt = parties.map({ BigInt($0) })
            let coeffInverse = lagrange(parties: partiesBigInt, party: BigInt(partyIndex)).inverse(TSSClient.modulusValueSigned)!
            let denormalizedShare = (additiveShare * coeffInverse).modulus(TSSClient.modulusValueSigned)
            shares.append(denormalizedShare)
        }

        var error = 0
        for i in 0 ..< parties.count {
            let share = shares[i]
            if Int32(i) == localClientIndex {
                self.share = share
            } else {
                let urlSession = URLSession.shared
                let url = URL(string: endpoints[i]! + "/share")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("*", forHTTPHeaderField: "Access-Control-Allow-Origin")
                request.addValue("GET, POST", forHTTPHeaderField: "Access-Control-Allow-Methods")
                request.addValue("Content-Type", forHTTPHeaderField: "Access-Control-Allow-Headers")
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.addValue(try! TSSClient.sid(session: session), forHTTPHeaderField: "x-web3-session-id")
                let msg: [String: Any] = [
                    "session": session,
                    "share": TSSHelpers.base64ToBase64url(base64: try TSSHelpers.base64Share(share: share)),
                ]
                let jsonData = try JSONSerialization.data(withJSONObject: msg, options: [.sortedKeys, .withoutEscapingSlashes])
                request.httpBody = jsonData

                let sem = DispatchSemaphore(value: 0)
                // data, response, error
                urlSession.dataTask(with: request) { _, resp, _ in
                    defer {
                        sem.signal()
                    }
                    if let httpResponse = resp as? HTTPURLResponse {
                        if httpResponse.statusCode != 200 {
                            print("Failed share route (\(httpResponse.statusCode))  for " + url.absoluteString)
                            error = httpResponse.statusCode
                        }
                    }
                }.resume()
                sem.wait()
            }
            if error != 0 {
                throw TSSClientError("Party \(i) responded with error \(error)")
            }
        }
    }

    private func setupMockShares(endpoints: [String?], parties: [Int32], localClientIndex: Int32, session: String) throws -> (Data, Data)
    {
        let privKey = try curvelib.Secp256k1.PrivateKey()
        let privKeyBigUInt = BigUInt(privKey.rawData)
        let privKeyBigInt = BigInt(sign: .plus, magnitude: privKeyBigUInt)
        let publicKey = try privKey.getPublicKey()
        try distributeShares(privKey: privKeyBigInt, parties: parties, endpoints: endpoints, localClientIndex: localClientIndex, session: session)
        return try (privKey.rawData, Data(hex: publicKey.getRaw()) )
    }

    private func generateEndpoints(parties: Int, clientIndex: Int32) -> ([String?], [String?], [Int32]) {
        var endPoints: [String?] = []
        var tssWSEndpoints: [String?] = []
        var partyIndexes: [Int32] = []
        var serverPortOffset = 0
        let basePort = 8000
        for i in 0 ..< parties {
            partyIndexes.append(Int32(i))
            if Int32(i) == clientIndex {
                endPoints.append(nil)
                tssWSEndpoints.append(nil)
            } else {
                endPoints.append("http://localhost:" + String(basePort + serverPortOffset))
                tssWSEndpoints.append("http://localhost:" + String(basePort + serverPortOffset))
                serverPortOffset += 1
            }
        }
        return (endPoints, tssWSEndpoints, partyIndexes)
    }

    func testClientLocal() throws {
        let parties = 4
        let msg = "hello world"
        let msgHash = TSSHelpers.hashMessage(message: msg)
        let clientIndex = Int32(parties - 1)
        let randomKey = try BigUInt(curvelib.Secp256k1.PrivateKey().rawData)
        let random = BigInt(sign: .plus, magnitude: randomKey) + BigInt(Date().timeIntervalSince1970)
        
        let randomNonce = TSSHelpers.hashMessage(message: String(random)).base64EncodedString()
        
        let testingRouteIdentifier = "testingShares"
        let vid = "test_verifier_name" + Delimiters.Delimiter1 + "test_verifier_id"
        let session = testingRouteIdentifier +
        vid + Delimiters.Delimiter2 + "default" + Delimiters.Delimiter3 + "0" + Delimiters.Delimiter4 + randomNonce
            + testingRouteIdentifier
        let sigs = try getSignatures()
        let (endpoints, socketEndpoints, partyIndexes) = generateEndpoints(parties: parties, clientIndex: clientIndex)
        let (privateKey, publicKey) = try setupMockShares(endpoints: endpoints, parties: partyIndexes, localClientIndex: clientIndex, session: session)
        var coeffs: [String: String] = [:]
        let participatingServerDKGIndexes: [Int] = [1, 2, 3]
        for i in 0 ... participatingServerDKGIndexes.count {
            let coeff = BigInt(1).serialize().toHexString()
            coeffs.updateValue(coeff, forKey: String(i))
        }

        let client = try! TSSClient(session: session, index: clientIndex, parties: partyIndexes, endpoints: endpoints.map({ URL(string: $0 ?? "") }), tssSocketEndpoints: socketEndpoints.map({ URL(string: $0 ?? "") }), share: TSSHelpers.base64Share(share: share), pubKey: try TSSHelpers.base64PublicKey(pubKey: publicKey))
        XCTAssertTrue(try client.checkConnected())
        let precompute = try! client.precompute(serverCoeffs: coeffs, signatures: sigs)
        XCTAssertTrue(try client.isReady())

        let (s, r, v) = try! client.sign(message: msgHash.base64EncodedString(), hashOnly: true, original_message: msg, precompute: precompute, signatures: sigs)
        try! client.cleanup(signatures: sigs)
        XCTAssert(TSSHelpers.verifySignature(msgHash: msgHash, s: s, r: r, v: v, pubKey: publicKey))

        let pk = try! TSSHelpers.recoverPublicKey(msgHash: msgHash, s: s, r: r, v: v)
        _ = try! TSSHelpers.hexUncompressedPublicKey(pubKey: pk, return64Bytes: true)
        let pkHex65 = try! TSSHelpers.hexUncompressedPublicKey(pubKey: pk, return64Bytes: false)
        
        let skToPkHex = try curvelib.Secp256k1.PrivateKey(input: privateKey).getPublicKey().getSec1Full()
        XCTAssert(pkHex65 == skToPkHex)

        print(try! TSSHelpers.hexSignature(s: s, r: r, v: v))
    }
}
