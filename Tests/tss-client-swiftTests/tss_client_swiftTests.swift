import XCTest
import BigInt
import SwiftKeccak

@testable import tss_client_swift

final class tss_client_swiftTests: XCTestCase {
    
    // this will only work for local testing with local servers
    let privateKeys = [
      "da4841d60f47652584aea0ab578660b353dbcd6907940ed0a295c9d95aabadd0",
      "e7ef4a9dcc9c0305ec9e56c79128f5c12413b976309368c35c11f3297459994b",
      "31534072a75a1d8b7f07c1f29930533ae44166f44ce08a4a23126b6dcb8b6efe",
      "f2588097a5df3911e4826e13dce2b6f4afb798bb8756675b17d4195db900af20",
      "5513438cd00c901ff362e25ae08aa723495bea89ab5a53ce165730bc1d9a0280"
    ];
    
    private func base64ToBase64url(base64: String) -> String {
        let base64url = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return base64url
    }
    
    private func keccak(message: String) -> String {
        return keccak256(message).base64EncodedString()
    }
    
    private func getSignatures() throws -> [String]
    {
        let tokenData: [String: Any] = [
            "exp": Date().addingTimeInterval(3000*60),
            "temp_key_x": "test_key_x",
            "temp_key_y": "test_key_y",
            "verifier_name": "test_verifier_name",
            "verifier_id": "test_verifier_id"
        ]
        
        let token = base64ToBase64url(base64: Data(try JSONSerialization.data(withJSONObject: tokenData, options: .prettyPrinted)).base64EncodedString())
        
        var sigs: [String] = []
        for item in privateKeys {
            let hash = keccak(message: token)
            let nodeSig = SECP256K1.signForRecovery(hash: Data(hex: hash), privateKey: Data(hex: item))
            
        }
        
        /*
        const token = base64Url.encode(JSON.stringify(tokenData));
      
        const sigs = privKeys.map(i => {
          const msgHash = keccak256(token);
          const nodeSig = ecsign(msgHash, Buffer.from(i, "hex"));
          const sig = `${nodeSig.r.toString("hex")}${nodeSig.s.toString("hex")}${nodeSig.v.toString(16)}`;
          return JSON.stringify({
            data: token,
            sig
          });
        });
      
        return sigs;
         */
        return
    }
    
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        print(BigUInt(2) - BigUInt(2));
//        XCTAssertEqual(tss_client_swift().text, "Hello, World!")
    }
}

/*
 import { localStorageDB } from "@toruslabs/tss-client";
 import { ecsign } from "ethereumjs-util";
 import axios from "axios";
 import BN from "bn.js";
 import eccrypto from "eccrypto";
 import { io, Socket } from "socket.io-client";
 import base64Url from "base64url";
 import keccak256 from "keccak256";
 import { getEcCrypto } from "./utils";

   export const createSockets = async (wsEndpoints: string[]): Promise<Socket[]> => {
     return wsEndpoints.map((wsEndpoint) => {
       if (wsEndpoint === null || wsEndpoint === undefined) {
         return null as any;
       }
       return io(wsEndpoint, { transports: ["websocket", "polling"], withCredentials: true, reconnectionDelayMax: 10000, reconnectionAttempts: 10 });
     });
   };

   export const getLagrangeCoeff = (parties: number[], party: number): BN => {
     const ec = getEcCrypto();
     const partyIndex = new BN(party + 1);
     let upper = new BN(1);
     let lower = new BN(1);
     for (let i = 0; i < parties.length; i += 1) {
       const otherParty = parties[i];
       const otherPartyIndex = new BN(parties[i] + 1);
       if (party !== otherParty) {
         upper = upper.mul(otherPartyIndex.neg());
         upper = upper.umod(ec.curve.n);
         let temp = partyIndex.sub(otherPartyIndex);
         temp = temp.umod(ec.curve.n);
         lower = lower.mul(temp).umod(ec.curve.n);
       }
     }
   
     const delta = upper.mul(lower.invm(ec.curve.n)).umod(ec.curve.n);
     return delta;
   };
   export const distributeShares = async (privKey: any, parties: number[], endpoints: string[], localClientIndex: number, session: string) => {
     const additiveShares = [];
     const ec = getEcCrypto();
     let shareSum = new BN(0);
     for (let i = 0; i < parties.length - 1; i++) {
       const share = new BN(eccrypto.generatePrivate());
       additiveShares.push(share);
       shareSum = shareSum.add(share);
     }
   
     const finalShare = privKey.sub(shareSum.umod(ec.curve.n)).umod(ec.curve.n);
     additiveShares.push(finalShare);
     const reduced = additiveShares.reduce((acc, share) => acc.add(share).umod(ec.curve.n), new BN(0));
   
     if (reduced.toString(16) !== privKey.toString(16)) {
       throw new Error("additive shares dont sum up to private key");
     }
   
     // denormalise shares
     const shares = additiveShares.map((additiveShare, party) => {
       return additiveShare.mul(getLagrangeCoeff(parties, party).invm(ec.curve.n)).umod(ec.curve.n);
     });
   
     console.log(
       "shares",
       shares.map((s) => s.toString(16, 64))
     );
   
     const waiting = [];
     for (let i = 0; i < parties.length; i++) {
       const share = shares[i];
       if (i === localClientIndex) {

         waiting.push(localStorageDB.set(`session-${session}:share`, Buffer.from(share.toString(16, 64), "hex").toString("base64")));
         continue;
       }
       waiting.push(
         axios
           .post(`${endpoints[i]}/share`, {
             session,
             share: Buffer.from(share.toString(16, 64), "hex").toString("base64"),
           })
           .then((res) => res.data)
       );
     }
     await Promise.all(waiting);
   };
 
 ////////////////////////////////////////////////////////////////
 
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
   
 const setupMockShares = async (endpoints: string[], parties: number[], session: string) => {
   const privKey = new BN(eccrypto.generatePrivate());
   // (window as any).privKey = privKey;
   const pubKeyElliptic = ec.curve.g.mul(privKey);
   const pubKeyX = pubKeyElliptic.getX().toString(16, 64);
   const pubKeyY = pubKeyElliptic.getY().toString(16, 64);
   const pubKeyHex = `${pubKeyX}${pubKeyY}`;
   const pubKey = Buffer.from(pubKeyHex, "hex").toString("base64");

   // distribute shares to servers and local device
   await distributeShares(privKey, parties, endpoints, clientIndex, session);

   return { pubKey, privKey };
 };

 const setupSockets = async (tssWSEndpoints: string[]) => {
   const sockets = await createSockets(tssWSEndpoints);

   // wait for websockets to be connected
   await new Promise((resolve) => {
     const checkConnectionTimer = setInterval(() => {
       for (let i = 0; i < sockets.length; i++) {
         if (sockets[i] !== null && !sockets[i].connected) return;
       }
       clearInterval(checkConnectionTimer);
       resolve(true);
     }, 100);
   });

   console.log("sockets", tssWSEndpoints, sockets);
   return sockets;
 };

 const generateEndpoints = (parties: number, clientIndex: number) => {
   const endpoints: string[] = [];
   const tssWSEndpoints: string[] = [];
   const partyIndexes: number[] = [];
   let serverPortOffset = 0;
   const basePort = 8000;
   for (let i = 0; i < parties ; i++) {
     partyIndexes.push(i);
     if (i === clientIndex) {
       endpoints.push(null as any);
       tssWSEndpoints.push(null as any);
     } else {
       endpoints.push(`http://localhost:${basePort + serverPortOffset}`);
       tssWSEndpoints.push(`http://localhost:${basePort + serverPortOffset}`);
       serverPortOffset++;
     }
   }
   return { endpoints, tssWSEndpoints, partyIndexes };
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
