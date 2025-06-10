import CID "../src"; // Adjust path to your CID module
import Debug "mo:base/Debug";
import Nat8 "mo:base/Nat8";
import Blob "mo:new-base/Blob";
import { test } "mo:test";

func testCid(
  expectedText : Text,
  expectedBytes : Blob,
  cid : CID.CID,
) {
  testCidEncoding(cid, expectedBytes);
  testCidDecoding(expectedBytes, cid);
  // testCidToText(cid, expectedText, description);
  // testCidFromText(expectedText, cid, description);
};

// func testCidToText(
//   cid : CID.CID,
//   expectedText : Text,
//   description : Text,
// ) {
//   let actualText = switch (CID.toText(cid)) {
//     case (#ok(text)) text;
//     case (#err(e)) Debug.trap("Encoding to text failed for " # description # ": " # debug_show (e));
//   };

//   if (actualText != expectedText) {
//     Debug.trap(
//       "Text encoding mismatch for " # description #
//       "\nExpected: " # debug_show (expectedText) #
//       "\nActual:   " # debug_show (actualText)
//     );
//   };
// };

// Test helper to verify encoding produces expected bytes
func testCidEncoding(cid : CID.CID, expectedBytes : Blob) {
  let actualBytes = switch (CID.toBytes(cid)) {
    case (#ok(bytes)) Blob.fromArray(bytes);
    case (#err(e)) Debug.trap("Encoding failed: " # debug_show (e));
  };

  if (actualBytes != expectedBytes) {
    Debug.trap(
      "Encoding mismatch" #
      "\nExpected: " # debug_show (expectedBytes) #
      "\nActual:   " # debug_show (actualBytes)
    );
  };
};

// Test helper to verify decoding produces expected CID
func testCidDecoding(bytes : Blob, expectedCid : CID.CID) {
  let actualCid = switch (CID.fromBytes(bytes.vals())) {
    case (#ok(cid)) cid;
    case (#err(e)) Debug.trap("Decoding failed: " # debug_show (e));
  };

  if (actualCid != expectedCid) {
    Debug.trap(
      "Decoding mismatch" #
      "\nExpected: " # debug_show (expectedCid) #
      "\nActual:   " # debug_show (actualCid)
    );
  };
};

test(
  "CIDv0 Encoding",
  func() {

    testCid(
      "QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n",
      "\12\20\E3\B0\C4\42\98\FC\1C\14\9A\FB\F4\C8\99\6F\B9\24\27\AE\41\E4\64\9B\93\4C\A4\95\99\1B\78\52\B8\55",
      {
        version = #v0;
        codec = #dag_pb;
        hashAlgorithm = #sha2_256;
        hash = "\E3\B0\C4\42\98\FC\1C\14\9A\FB\F4\C8\99\6F\B9\24\27\AE\41\E4\64\9B\93\4C\A4\95\99\1B\78\52\B8\55";
      },
    );
  },
);

test(
  "CIDv1 Encoding, DAG-PB, SHA2-256",
  func() {

    testCid(
      "bafybeihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku",
      "\01\70\12\20\E3\B0\C4\42\98\FC\1C\14\9A\FB\F4\C8\99\6F\B9\24\27\AE\41\E4\64\9B\93\4C\A4\95\99\1B\78\52\B8\55",
      {
        version = #v1;
        codec = #dag_pb;
        hashAlgorithm = #sha2_256;
        hash = "\E3\B0\C4\42\98\FC\1C\14\9A\FB\F4\C8\99\6F\B9\24\27\AE\41\E4\64\9B\93\4C\A4\95\99\1B\78\52\B8\55";
      },
    );
  },
);

test(
  "CIDv1 Encoding, RAW, SHA2-256",
  func() {

    testCid(
      "zb2rhe5P4gXftAwvA4eXQ5HJwsER2owDyS9sKaQRRVQPn93bA",
      "\01\55\12\20\6E\6F\F7\95\0A\36\18\7A\80\16\13\42\6E\85\8D\CE\68\6C\D7\D7\E3\C0\FC\42\EE\03\30\07\2D\24\5C\95",
      {
        version = #v1;
        codec = #raw;
        hashAlgorithm = #sha2_256;
        hash = "\6E\6F\F7\95\0A\36\18\7A\80\16\13\42\6E\85\8D\CE\68\6C\D7\D7\E3\C0\FC\42\EE\03\30\07\2D\24\5C\95";
      },
    );
  },
);
