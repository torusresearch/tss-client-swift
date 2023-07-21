import XCTest
import BigInt
import SwiftKeccak

@testable import tss_client_swift

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
      "5513438cd00c901ff362e25ae08aa723495bea89ab5a53ce165730bc1d9a0280"
    ];
    
    var session = ""
    var share = ""
    
    private func base64ToBase64url(base64: String) -> String {
        let base64url = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return base64url
    }
    
    private func keccak(message: String) -> String {
        return keccak256(message).hexString
    }
    
    private func getSignatures() throws -> [Any]
    {
        let tokenData: [String: Any] = [
            "exp": Date().addingTimeInterval(3000*60).timeIntervalSince1970,
            "temp_key_x": "test_key_x",
            "temp_key_y": "test_key_y",
            "verifier_name": "test_verifier_name",
            "verifier_id": "test_verifier_id"
        ]
        
        let token =  Data(try JSONSerialization.data(withJSONObject: tokenData)).base64EncodedString()
        
        var sigs: [Any] = []
        for item in privateKeys {
            let hash = keccak(message: token)
            let (serializedNodeSig, _) = SECP256K1.signForRecovery(hash: Data(hex: hash), privateKey: Data(hex: item))
            let unmarshaled = SECP256K1.unmarshalSignature(signatureData: serializedNodeSig!)!
            let sig = unmarshaled.r.hexString+unmarshaled.s.hexString+String(format:"%02X", unmarshaled.v)
            let msg: [String: Any]  = [
                "data": token,
                "sig": sig,
            ]
            let jsonData = try JSONSerialization.data(withJSONObject: msg, options: .prettyPrinted)
            sigs.append(jsonData)
        }
        
        return sigs
    }
    
    private func distributeShares(privKey: BigInt, parties: [Int32], endpoints: [String?], localClientIndex: Int32, session: String) throws {
        
        print("sk:" + privKey.serialize().toHexString())
        var additiveShares: [BigInt] = [];
        var shareSum = BigInt.zero
        for _ in (0..<(parties.count-1))
        {
            let share = SECP256K1.generatePrivateKey()!
            let share_bigint = BigInt(share).modulus(modulusValueSigned)
            print("share:" + share_bigint.serialize().toHexString())
            additiveShares.append(share_bigint)
            shareSum += share_bigint
        }
        
        let shareSumMod = shareSum.modulus(modulusValueSigned)
        let final_share = (privKey - shareSumMod).modulus(modulusValueSigned)
        additiveShares.append(final_share)
        
        print(additiveShares)
        
        let reduced = additiveShares.reduce(0) {
            ($0 + $1).modulus(modulusValueSigned)
        }
        if reduced.serialize().suffix(32).toHexString() != privKey.serialize().suffix(32).toHexString()
        {
            throw TSSClientError.errorWithMessage("Additive shares don't sum up to private key")
        }
        
        var shares: [BigInt] = []
        for (partyIndex,additiveShare) in additiveShares.enumerated()
        {
            let parties_bigint = parties.map({ BigInt($0) })
            let coeffs = getLagrangeCoeffs(parties_bigint, BigInt(partyIndex))
            let denormalizedShare = (additiveShare * coeffs.inverse(modulusValueSigned)!.modulus(modulusValueSigned))
            shares.append(denormalizedShare)
        }
        
        for i in (0..<parties.count)
        {
            let share = shares[i]
            if Int32(i) == localClientIndex {
                self.share = share.serialize().suffix(32).toHexString().toBase64()
                self.session = session
            } else {
                let urlSession = URLSession.shared
                let url = URL(string: endpoints[i]! + "/share")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("*", forHTTPHeaderField: "Access-Control-Allow-Origin")
                request.addValue("GET, POST", forHTTPHeaderField: "Access-Control-Allow-Methods")
                request.addValue("Content-Type", forHTTPHeaderField: "Access-Control-Allow-Headers")
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                let msg: [String: Any]  = [
                    "session": session,
                    "share": base64ToBase64url(base64: share.serialize().suffix(32).toHexString().toBase64())
                ]
                let jsonData = try JSONSerialization.data(withJSONObject: msg, options: .prettyPrinted)
                
                request.httpBody = jsonData
                
                let sem = DispatchSemaphore.init(value: 0)
                // data, response, error
                urlSession.dataTask(with: request) { _, _, error in
                    sem.signal()
                }.resume()
                sem.wait()
            }
        }
    }
    
    private func setupMockShares(endpoints: [String?], parties: [Int32], localClientIndex: Int32, session: String) throws -> (Data,Data)
    {
        let privKey = SECP256K1.generatePrivateKey()!
        let privKeyBigInt = BigInt(privKey).modulus(modulusValueSigned)
        let publicKey = SECP256K1.privateToPublic(privateKey: privKey, compressed: false)!
        try distributeShares(privKey: privKeyBigInt, parties: parties, endpoints: endpoints, localClientIndex: localClientIndex, session: session)
        return (privKey, publicKey)
    }
    
    private func generateEndpoints(parties: Int, clientIndex: Int32) -> ([String?],[String?],[Int32]) {
        var endPoints: [String?] = []
        var tssWSEndpoints: [String?] = []
        var partyIndexes: [Int32] = []
        var serverPortOffset = 0
        let basePort = 8000
        for i in (0..<parties)
        {
            partyIndexes.append(Int32(i))
            if Int32(i) == clientIndex {
                endPoints.append(nil)
                tssWSEndpoints.append(nil)
            } else {
                endPoints.append("http://localhost:"+String((basePort+serverPortOffset)))
                tssWSEndpoints.append("http://localhost:"+String((basePort+serverPortOffset)))
                serverPortOffset += 1
            }
        }
        return (endPoints, tssWSEndpoints, partyIndexes)
    }
    
    func testExample() throws {
        let parties = 4
        let msg = "hello world"
        let msgHash = keccak(message: msg)
        let clientIndex =  Int32(parties - 1);
        let testingRouteIdentifier = "testingShares";
        let random = BigInt(SECP256K1.generatePrivateKey()!) + BigInt(Date().timeIntervalSince1970)
        let randomNonce = keccak(message: String(random))
        let vid = "test_verifier_name" + Delimiters.Delimiter1 + "test_verifier_id"
        let session = testingRouteIdentifier + vid + Delimiters.Delimiter2 + "default" + Delimiters.Delimiter3 + "0" + Delimiters.Delimiter4 + randomNonce + testingRouteIdentifier
        let sigs = try getSignatures()
        
        let (endpoints, socketEndpoints, partyIndexes) = generateEndpoints(parties: parties, clientIndex: clientIndex)
        try setupMockShares(endpoints: endpoints, parties: partyIndexes, localClientIndex: clientIndex, session: session)
        
    }
}

/*
 import { Client, localStorageDB } from "@toruslabs/tss-client";
 import * as tss from "@toruslabs/tss-lib";
 import BN from "bn.js";
 import eccrypto, { generatePrivate } from "eccrypto";
 import { privateToAddress } from "ethereumjs-utils";
 import keccak256 from "keccak256";

 import { getEcCrypto } from "./utils";
 import { createSockets, distributeShares, getSignatures } from "./localUtils";


 const DELIMITERS = {
     Delimiter1: "\u001c",
     Delimiter2: "\u0015",
     Delimiter3: "\u0016",
     Delimiter4: "\u0017",
   };
 const servers = 4;
 const msg = "hello world";
 const msgHash = keccak256(msg);
 const clientIndex = servers - 1;
 const ec = getEcCrypto();


 const tssImportUrl = `${window.location.origin}/dkls_19.wasm`;

 const log = (...args: unknown[]) => {
     let msg = "";
     args.forEach((arg) => {
       msg += JSON.stringify(arg);
       msg += " ";
     });
     console.log(msg);
   };

 const runTest = async () => {
   // this identifier is only required for testing,
   // so that clients cannot override shares of actual users incase
   // share route is exposed in production, which is exposed only in development/testing
   // by default.
   const testingRouteIdentifier = "testingShares";
   const randomNonce = keccak256(generatePrivate().toString("hex") + Date.now());
   const vid = `test_verifier_name${DELIMITERS.Delimiter1}test_verifier_id`;
   const session = `${testingRouteIdentifier}${vid}${DELIMITERS.Delimiter2}default${DELIMITERS.Delimiter3}0${
     DELIMITERS.Delimiter4
     }${randomNonce.toString("hex")}${testingRouteIdentifier}`;
   
   // generate mock signatures.
   const signatures = getSignatures();

   // const session = `test:${Date.now()}`;

   const parties = 4;
   const clientIndex = parties - 1;

   // generate endpoints for servers
   const { endpoints, tssWSEndpoints, partyIndexes } = generateEndpoints(parties, clientIndex);

   // setup mock shares, sockets and tss wasm files.
   const [{ pubKey, privKey }, sockets] = await Promise.all([
     setupMockShares(endpoints, partyIndexes, session),
     setupSockets(tssWSEndpoints),
     tss.default(tssImportUrl),
   ]);

   const serverCoeffs = {};
   const participatingServerDKGIndexes = [1, 2, 3];

   for (let i = 0; i < participatingServerDKGIndexes.length; i++) {
     const serverIndex = participatingServerDKGIndexes[i];
     serverCoeffs[serverIndex] = new BN(1).toString("hex");
   }
   // get the shares.
   const share = await localStorageDB.get(`session-${session}:share`);
   const client = new Client(session, clientIndex, partyIndexes, endpoints, sockets, share, pubKey, true, tssImportUrl);
   client.log = log;
   // initiate precompute
   client.precompute(tss, { signatures, server_coeffs: serverCoeffs });
   await client.ready();

   // initiate signature.
   const signature = await client.sign(tss, msgHash.toString("base64"), true, msg, "keccak256", { signatures });

   const hexToDecimal = (x) => ec.keyFromPrivate(x, "hex").getPrivate().toString(10);
   const pubk = ec.recoverPubKey(hexToDecimal(msgHash), signature, signature.recoveryParam, "hex");

   client.log(`pubkey, ${JSON.stringify(pubKey)}`);
   client.log(`msgHash: 0x${msgHash.toString("hex")}`);
   client.log(`signature: 0x${signature.r.toString(16, 64)}${signature.s.toString(16, 64)}${new BN(27 + signature.recoveryParam).toString(16)}`);
   client.log(`address: 0x${Buffer.from(privateToAddress(`0x${privKey.toString(16, 64)}`)).toString("hex")}`);
   const passed = ec.verify(msgHash, signature, pubk);

   client.log(`passed: ${passed}`);
   client.log(`precompute time: ${client._endPrecomputeTime - client._startPrecomputeTime}`);
   client.log(`signing time: ${client._endSignTime - client._startSignTime}`);
   await client.cleanup(tss, { signatures });
   client.log("client cleaned up");
 };

 export const runLocalServerTest = async()=>{
   try {
     await runTest();
     console.log("test succeeded");
     document.title = "Test succeeded";
   } catch (error) {
     console.log("test failed", error);
     document.title = "Test failed";
   }
 };

 runLocalServerTest();
 
 
 */
