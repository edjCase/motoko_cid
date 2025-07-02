import CID "../src"; // Adjust path to your CID module
import Debug "mo:base/Debug";
import Blob "mo:new-base/Blob";
import { test } "mo:test";

func testCid(
  expectedText : Text,
  expectedBytes : Blob,
  cid : CID.CIDWithMultiBase,
) {
  testCidEncoding(cid, expectedBytes);
  testCidDecoding(expectedBytes, cid);
  testCidToText(cid, expectedText);
  testCidFromText(expectedText, cid);
};

func testCidToText(
  cid : CID.CIDWithMultiBase,
  expectedText : Text,
) {
  let actualText = CID.toTextAdvanced(cid);

  if (actualText != expectedText) {
    Debug.trap(
      "Text encoding mismatch for CID" #
      "\nExpected: " # debug_show (expectedText) #
      "\nActual:   " # debug_show (actualText)
    );
  };
};

func testCidFromText(
  expectedText : Text,
  expectedCid : CID.CIDWithMultiBase,
) {
  let actualCid = switch (CID.fromText(expectedText)) {
    case (#ok(cid)) cid;
    case (#err(e)) Debug.trap("fromText failed: " # debug_show (e));
  };

  if (actualCid != expectedCid) {
    Debug.trap(
      "Decoding mismatch for " #
      "\nExpected: " # debug_show (expectedCid) #
      "\nActual:   " # debug_show (actualCid)
    );
  };
};

// Test helper to verify encoding produces expected bytes
func testCidEncoding(cid : CID.CID, expectedBytes : Blob) {
  let actualBytes = Blob.fromArray(CID.toBytes(cid));

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
    case (#err(e)) Debug.trap("fromBytes failed: " # debug_show (e));
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
  "CIDv0",
  func() {

    testCid(
      "QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n",
      "\12\20\E3\B0\C4\42\98\FC\1C\14\9A\FB\F4\C8\99\6F\B9\24\27\AE\41\E4\64\9B\93\4C\A4\95\99\1B\78\52\B8\55",
      #v0({
        hash = "\E3\B0\C4\42\98\FC\1C\14\9A\FB\F4\C8\99\6F\B9\24\27\AE\41\E4\64\9B\93\4C\A4\95\99\1B\78\52\B8\55";
      }),
    );
  },
);

test(
  "CIDv1, DAG-PB, SHA2-256, Base32",
  func() {

    testCid(
      "bafybeihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku",
      "\01\70\12\20\E3\B0\C4\42\98\FC\1C\14\9A\FB\F4\C8\99\6F\B9\24\27\AE\41\E4\64\9B\93\4C\A4\95\99\1B\78\52\B8\55",
      #v1({
        codec = #dag_pb;
        hashAlgorithm = #sha2_256;
        hash = "\E3\B0\C4\42\98\FC\1C\14\9A\FB\F4\C8\99\6F\B9\24\27\AE\41\E4\64\9B\93\4C\A4\95\99\1B\78\52\B8\55";
        multibase = #base32;
      }),
    );
  },
);

test(
  "CIDv1, RAW, SHA2-256, Base58BTC",
  func() {

    testCid(
      "zb2rhe5P4gXftAwvA4eXQ5HJwsER2owDyS9sKaQRRVQPn93bA",
      "\01\55\12\20\6E\6F\F7\95\0A\36\18\7A\80\16\13\42\6E\85\8D\CE\68\6C\D7\D7\E3\C0\FC\42\EE\03\30\07\2D\24\5C\95",
      #v1({
        codec = #raw;
        hashAlgorithm = #sha2_256;
        hash = "\6E\6F\F7\95\0A\36\18\7A\80\16\13\42\6E\85\8D\CE\68\6C\D7\D7\E3\C0\FC\42\EE\03\30\07\2D\24\5C\95";
        multibase = #base58btc;
      }),
    );
  },
);
