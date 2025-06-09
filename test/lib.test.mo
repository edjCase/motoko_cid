import CID "../src"; // Adjust path to your CID module
import Debug "mo:base/Debug";
import Nat8 "mo:base/Nat8";
import Blob "mo:new-base/Blob";
import { test } "mo:test";

// Test helper to verify CID encoding/decoding round-trip
func testCidRoundTrip(cid : CID.CID, description : Text) {
  let encodedBytes = switch (CID.toBytes(cid)) {
    case (#ok(bytes)) bytes;
    case (#err(e)) Debug.trap("Encoding failed for " # description # ": " # debug_show (e));
  };

  let decodedCid = switch (CID.fromBytes(encodedBytes)) {
    case (#ok(decoded)) decoded;
    case (#err(e)) Debug.trap("Decoding failed for " # description # ": " # debug_show (e));
  };

  if (decodedCid != cid) {
    Debug.trap(
      "Round-trip failed for " # description #
      "\nOriginal: " # debug_show (cid) #
      "\nDecoded:  " # debug_show (decodedCid)
    );
  };
};

// Test helper to verify encoding produces expected bytes
func testCidEncoding(cid : CID.CID, expectedBytes : [Nat8], description : Text) {
  let actualBytes = switch (CID.toBytes(cid)) {
    case (#ok(bytes)) bytes;
    case (#err(e)) Debug.trap("Encoding failed for " # description # ": " # debug_show (e));
  };

  if (actualBytes != expectedBytes) {
    Debug.trap(
      "Encoding mismatch for " # description #
      "\nExpected: " # debug_show (expectedBytes) #
      "\nActual:   " # debug_show (actualBytes)
    );
  };
};

// Test helper to verify decoding produces expected CID
func testCidDecoding(bytes : [Nat8], expectedCid : CID.CID, description : Text) {
  let actualCid = switch (CID.fromBytes(bytes)) {
    case (#ok(cid)) cid;
    case (#err(e)) Debug.trap("Decoding failed for " # description # ": " # debug_show (e));
  };

  if (actualCid != expectedCid) {
    Debug.trap(
      "Decoding mismatch for " # description #
      "\nExpected: " # debug_show (expectedCid) #
      "\nActual:   " # debug_show (actualCid)
    );
  };
};

// Test helper for expected encoding failures
func testEncodingFailure(cid : CID.CID, expectedErrorType : Text, description : Text) {
  let result = CID.toBytes(cid);

  switch (result) {
    case (#ok(_)) {
      Debug.trap("Expected encoding failure for " # description # " but encoding succeeded");
    };
    case (#err(actualError)) {
      let errorMatches = switch (expectedErrorType, actualError) {
        case ("invalidCodec", #invalidCodec(_)) true;
        case ("invalidHashAlgorithm", #invalidHashAlgorithm(_)) true;
        case ("invalidHashLength", #invalidHashLength(_)) true;
        case (_, _) false;
      };

      if (not errorMatches) {
        Debug.trap(
          "Expected error type " # expectedErrorType # " for " # description #
          " but got " # debug_show (actualError)
        );
      };
    };
  };
};

// Test helper for expected decoding failures
func testDecodingFailure(bytes : [Nat8], expectedErrorType : Text, description : Text) {
  let result = CID.fromBytes(bytes);

  switch (result) {
    case (#ok(_)) {
      Debug.trap("Expected decoding failure for " # description # " but decoding succeeded");
    };
    case (#err(actualError)) {
      let errorMatches = switch (expectedErrorType, actualError) {
        case ("emptyBytes", #emptyBytes) true;
        case ("unsupportedVersion", #unsupportedVersion(_)) true;
        case ("unknownCodec", #unknownCodec(_)) true;
        case ("unknownHashAlgorithm", #unknownHashAlgorithm(_)) true;
        case ("hashLengthMismatch", #hashLengthMismatch(_)) true;
        case ("insufficientBytes", #insufficientBytes(_)) true;
        case ("invalidMultihash", #invalidMultihash) true;
        case (_, _) false;
      };

      if (not errorMatches) {
        Debug.trap(
          "Expected error type " # expectedErrorType # " for " # description #
          " but got " # debug_show (actualError)
        );
      };
    };
  };
};

test(
  "CIDv0 Encoding",
  func() {
    // Create a sample CIDv0 with SHA-256 hash
    let hash = Blob.fromArray([
      0x12,
      0x34,
      0x56,
      0x78,
      0x9a,
      0xbc,
      0xde,
      0xf0,
      0x12,
      0x34,
      0x56,
      0x78,
      0x9a,
      0xbc,
      0xde,
      0xf0,
      0x12,
      0x34,
      0x56,
      0x78,
      0x9a,
      0xbc,
      0xde,
      0xf0,
      0x12,
      0x34,
      0x56,
      0x78,
      0x9a,
      0xbc,
      0xde,
      0xf0,
    ]);

    let cidv0 : CID.CID = {
      version = #v0;
      codec = #dag_pb;
      hashAlgorithm = #sha2_256;
      hash = hash;
    };

    // Expected bytes: [0x12, 0x20, ...hash...]
    let expectedBytes : [Nat8] = [
      0x12,
      0x20, // Multihash header (SHA-256, 32 bytes)
      0x12,
      0x34,
      0x56,
      0x78,
      0x9a,
      0xbc,
      0xde,
      0xf0,
      0x12,
      0x34,
      0x56,
      0x78,
      0x9a,
      0xbc,
      0xde,
      0xf0,
      0x12,
      0x34,
      0x56,
      0x78,
      0x9a,
      0xbc,
      0xde,
      0xf0,
      0x12,
      0x34,
      0x56,
      0x78,
      0x9a,
      0xbc,
      0xde,
      0xf0,
    ];

    testCidEncoding(cidv0, expectedBytes, "CIDv0 with SHA-256");
    testCidRoundTrip(cidv0, "CIDv0 round-trip");
  },
);

test(
  "CIDv0 Decoding",
  func() {
    // Test decoding a valid CIDv0
    let bytes : [Nat8] = [
      0x12,
      0x20, // SHA-256, 32 bytes
      0xab,
      0xcd,
      0xef,
      0x01,
      0x23,
      0x45,
      0x67,
      0x89,
      0xab,
      0xcd,
      0xef,
      0x01,
      0x23,
      0x45,
      0x67,
      0x89,
      0xab,
      0xcd,
      0xef,
      0x01,
      0x23,
      0x45,
      0x67,
      0x89,
      0xab,
      0xcd,
      0xef,
      0x01,
      0x23,
      0x45,
      0x67,
      0x89,
    ];

    let expectedCid : CID.CID = {
      version = #v0;
      codec = #dag_pb;
      hashAlgorithm = #sha2_256;
      hash = Blob.fromArray([
        0xab,
        0xcd,
        0xef,
        0x01,
        0x23,
        0x45,
        0x67,
        0x89,
        0xab,
        0xcd,
        0xef,
        0x01,
        0x23,
        0x45,
        0x67,
        0x89,
        0xab,
        0xcd,
        0xef,
        0x01,
        0x23,
        0x45,
        0x67,
        0x89,
        0xab,
        0xcd,
        0xef,
        0x01,
        0x23,
        0x45,
        0x67,
        0x89,
      ]);
    };

    testCidDecoding(bytes, expectedCid, "valid CIDv0");
  },
);

test(
  "CIDv1 RAW Encoding",
  func() {
    let hash = Blob.fromArray([
      0xaa,
      0xbb,
      0xcc,
      0xdd,
      0xee,
      0xff,
      0x11,
      0x22,
      0xaa,
      0xbb,
      0xcc,
      0xdd,
      0xee,
      0xff,
      0x11,
      0x22,
      0xaa,
      0xbb,
      0xcc,
      0xdd,
      0xee,
      0xff,
      0x11,
      0x22,
      0xaa,
      0xbb,
      0xcc,
      0xdd,
      0xee,
      0xff,
      0x11,
      0x22,
    ]);

    let cidv1 : CID.CID = {
      version = #v1;
      codec = #raw;
      hashAlgorithm = #sha2_256;
      hash = hash;
    };

    // Expected: [0x01][0x55][0x12][0x20][...hash...]
    let expectedBytes : [Nat8] = [
      0x01, // Version 1
      0x55, // RAW codec
      0x12, // SHA-256 hash algorithm
      0x20, // Hash length (32 bytes)
      0xaa,
      0xbb,
      0xcc,
      0xdd,
      0xee,
      0xff,
      0x11,
      0x22,
      0xaa,
      0xbb,
      0xcc,
      0xdd,
      0xee,
      0xff,
      0x11,
      0x22,
      0xaa,
      0xbb,
      0xcc,
      0xdd,
      0xee,
      0xff,
      0x11,
      0x22,
      0xaa,
      0xbb,
      0xcc,
      0xdd,
      0xee,
      0xff,
      0x11,
      0x22,
    ];

    testCidEncoding(cidv1, expectedBytes, "CIDv1 RAW with SHA-256");
    testCidRoundTrip(cidv1, "CIDv1 RAW round-trip");
  },
);

test(
  "CIDv1 DAG-PB Encoding",
  func() {
    let hash = Blob.fromArray([
      0x01,
      0x02,
      0x03,
      0x04,
      0x05,
      0x06,
      0x07,
      0x08,
      0x01,
      0x02,
      0x03,
      0x04,
      0x05,
      0x06,
      0x07,
      0x08,
      0x01,
      0x02,
      0x03,
      0x04,
      0x05,
      0x06,
      0x07,
      0x08,
      0x01,
      0x02,
      0x03,
      0x04,
      0x05,
      0x06,
      0x07,
      0x08,
    ]);

    let cidv1 : CID.CID = {
      version = #v1;
      codec = #dag_pb;
      hashAlgorithm = #sha2_256;
      hash = hash;
    };

    // Expected: [0x01][0x70][0x12][0x20][...hash...]
    let expectedBytes : [Nat8] = [
      0x01, // Version 1
      0x70, // DAG-PB codec
      0x12, // SHA-256 hash algorithm
      0x20, // Hash length (32 bytes)
      0x01,
      0x02,
      0x03,
      0x04,
      0x05,
      0x06,
      0x07,
      0x08,
      0x01,
      0x02,
      0x03,
      0x04,
      0x05,
      0x06,
      0x07,
      0x08,
      0x01,
      0x02,
      0x03,
      0x04,
      0x05,
      0x06,
      0x07,
      0x08,
      0x01,
      0x02,
      0x03,
      0x04,
      0x05,
      0x06,
      0x07,
      0x08,
    ];

    testCidEncoding(cidv1, expectedBytes, "CIDv1 DAG-PB with SHA-256");
    testCidRoundTrip(cidv1, "CIDv1 DAG-PB round-trip");
  },
);

test(
  "CIDv1 DAG-CBOR Encoding",
  func() {
    let hash = Blob.fromArray([
      0xff,
      0xee,
      0xdd,
      0xcc,
      0xbb,
      0xaa,
      0x99,
      0x88,
      0xff,
      0xee,
      0xdd,
      0xcc,
      0xbb,
      0xaa,
      0x99,
      0x88,
      0xff,
      0xee,
      0xdd,
      0xcc,
      0xbb,
      0xaa,
      0x99,
      0x88,
      0xff,
      0xee,
      0xdd,
      0xcc,
      0xbb,
      0xaa,
      0x99,
      0x88,
    ]);

    let cidv1 : CID.CID = {
      version = #v1;
      codec = #dag_cbor;
      hashAlgorithm = #sha2_256;
      hash = hash;
    };

    // Expected: [0x01][0x71][0x12][0x20][...hash...]
    let expectedBytes : [Nat8] = [
      0x01, // Version 1
      0x71, // DAG-CBOR codec
      0x12, // SHA-256 hash algorithm
      0x20, // Hash length (32 bytes)
      0xff,
      0xee,
      0xdd,
      0xcc,
      0xbb,
      0xaa,
      0x99,
      0x88,
      0xff,
      0xee,
      0xdd,
      0xcc,
      0xbb,
      0xaa,
      0x99,
      0x88,
      0xff,
      0xee,
      0xdd,
      0xcc,
      0xbb,
      0xaa,
      0x99,
      0x88,
      0xff,
      0xee,
      0xdd,
      0xcc,
      0xbb,
      0xaa,
      0x99,
      0x88,
    ];

    testCidEncoding(cidv1, expectedBytes, "CIDv1 DAG-CBOR with SHA-256");
    testCidRoundTrip(cidv1, "CIDv1 DAG-CBOR round-trip");
  },
);

test(
  "CIDv1 DAG-JSON Encoding",
  func() {
    let hash = Blob.fromArray([
      0x11,
      0x22,
      0x33,
      0x44,
      0x55,
      0x66,
      0x77,
      0x88,
      0x11,
      0x22,
      0x33,
      0x44,
      0x55,
      0x66,
      0x77,
      0x88,
      0x11,
      0x22,
      0x33,
      0x44,
      0x55,
      0x66,
      0x77,
      0x88,
      0x11,
      0x22,
      0x33,
      0x44,
      0x55,
      0x66,
      0x77,
      0x88,
    ]);

    let cidv1 : CID.CID = {
      version = #v1;
      codec = #dag_json;
      hashAlgorithm = #sha2_256;
      hash = hash;
    };

    // Expected: [0x01][0x29, 0x01][0x12][0x20][...hash...]
    // Note: DAG-JSON codec is 0x0129, which encodes as varint [0x29, 0x01]
    let expectedBytes : [Nat8] = [
      0x01, // Version 1
      0xA9,
      0x02, // DAG-JSON codec (0x0129 as varint)
      0x12, // SHA-256 hash algorithm
      0x20, // Hash length (32 bytes)
      0x11,
      0x22,
      0x33,
      0x44,
      0x55,
      0x66,
      0x77,
      0x88,
      0x11,
      0x22,
      0x33,
      0x44,
      0x55,
      0x66,
      0x77,
      0x88,
      0x11,
      0x22,
      0x33,
      0x44,
      0x55,
      0x66,
      0x77,
      0x88,
      0x11,
      0x22,
      0x33,
      0x44,
      0x55,
      0x66,
      0x77,
      0x88,
    ];

    testCidEncoding(cidv1, expectedBytes, "CIDv1 DAG-JSON with SHA-256");
    testCidRoundTrip(cidv1, "CIDv1 DAG-JSON round-trip");
  },
);

test(
  "SHA-512 Hash Algorithm",
  func() {
    // Create 64-byte hash for SHA-512
    let hash = Blob.fromArray([
      0x01,
      0x02,
      0x03,
      0x04,
      0x05,
      0x06,
      0x07,
      0x08,
      0x09,
      0x0a,
      0x0b,
      0x0c,
      0x0d,
      0x0e,
      0x0f,
      0x10,
      0x11,
      0x12,
      0x13,
      0x14,
      0x15,
      0x16,
      0x17,
      0x18,
      0x19,
      0x1a,
      0x1b,
      0x1c,
      0x1d,
      0x1e,
      0x1f,
      0x20,
      0x21,
      0x22,
      0x23,
      0x24,
      0x25,
      0x26,
      0x27,
      0x28,
      0x29,
      0x2a,
      0x2b,
      0x2c,
      0x2d,
      0x2e,
      0x2f,
      0x30,
      0x31,
      0x32,
      0x33,
      0x34,
      0x35,
      0x36,
      0x37,
      0x38,
      0x39,
      0x3a,
      0x3b,
      0x3c,
      0x3d,
      0x3e,
      0x3f,
      0x40,
    ]);

    let cidv1 : CID.CID = {
      version = #v1;
      codec = #raw;
      hashAlgorithm = #sha2_512;
      hash = hash;
    };

    testCidRoundTrip(cidv1, "CIDv1 with SHA-512");
  },
);

test(
  "BLAKE2B-256 Hash Algorithm",
  func() {
    let hash = Blob.fromArray([
      0xa1,
      0xa2,
      0xa3,
      0xa4,
      0xa5,
      0xa6,
      0xa7,
      0xa8,
      0xa1,
      0xa2,
      0xa3,
      0xa4,
      0xa5,
      0xa6,
      0xa7,
      0xa8,
      0xa1,
      0xa2,
      0xa3,
      0xa4,
      0xa5,
      0xa6,
      0xa7,
      0xa8,
      0xa1,
      0xa2,
      0xa3,
      0xa4,
      0xa5,
      0xa6,
      0xa7,
      0xa8,
    ]);

    let cidv1 : CID.CID = {
      version = #v1;
      codec = #raw;
      hashAlgorithm = #blake2b_256;
      hash = hash;
    };

    testCidRoundTrip(cidv1, "CIDv1 with BLAKE2B-256");
  },
);

test(
  "Empty Bytes Error",
  func() {
    testDecodingFailure([], "emptyBytes", "empty byte array");
  },
);

test(
  "Unsupported Version Error",
  func() {
    // Test with version 2 (unsupported)
    testDecodingFailure([0x02, 0x55, 0x12, 0x20], "unsupportedVersion", "version 2");

    // Test with version 255
    testDecodingFailure([0xFF, 0x55, 0x12, 0x20], "unsupportedVersion", "version 255");
  },
);

test(
  "Unknown Codec Error",
  func() {
    // Test with unknown codec 0x99
    testDecodingFailure([0x01, 0x99, 0x12, 0x20], "unknownCodec", "unknown codec 0x99");
  },
);

test(
  "Unknown Hash Algorithm Error",
  func() {
    // Test with unknown hash algorithm 0x99
    testDecodingFailure([0x01, 0x55, 0x99, 0x20], "unknownHashAlgorithm", "unknown hash algorithm 0x99");
  },
);

test(
  "Hash Length Mismatch Error",
  func() {
    // Test SHA-256 with wrong length (should be 32, but claim 16)
    testDecodingFailure([0x01, 0x55, 0x12, 0x10], "hashLengthMismatch", "SHA-256 with wrong length");

    // Test SHA-512 with wrong length (should be 64, but claim 32)
    testDecodingFailure([0x01, 0x55, 0x13, 0x20], "hashLengthMismatch", "SHA-512 with wrong length");
  },
);

test(
  "Insufficient Bytes Error",
  func() {
    // Claim 32 bytes for hash but only provide 4
    let shortBytes : [Nat8] = [
      0x01,
      0x55,
      0x12,
      0x20, // Header claiming 32 bytes
      0x01,
      0x02,
      0x03,
      0x04 // But only 4 bytes provided
    ];
    testDecodingFailure(shortBytes, "insufficientBytes", "insufficient hash bytes");
  },
);

test(
  "CIDv0 Invalid Codec Error",
  func() {
    let hash = Blob.fromArray([
      0x12,
      0x34,
      0x56,
      0x78,
      0x9a,
      0xbc,
      0xde,
      0xf0,
      0x12,
      0x34,
      0x56,
      0x78,
      0x9a,
      0xbc,
      0xde,
      0xf0,
      0x12,
      0x34,
      0x56,
      0x78,
      0x9a,
      0xbc,
      0xde,
      0xf0,
      0x12,
      0x34,
      0x56,
      0x78,
      0x9a,
      0xbc,
      0xde,
      0xf0,
    ]);

    let invalidCidv0 : CID.CID = {
      version = #v0;
      codec = #raw; // CIDv0 must use dag_pb
      hashAlgorithm = #sha2_256;
      hash = hash;
    };

    testEncodingFailure(invalidCidv0, "invalidCodec", "CIDv0 with non-dag_pb codec");
  },
);

test(
  "CIDv0 Invalid Hash Algorithm Error",
  func() {
    let hash = Blob.fromArray([
      0x12,
      0x34,
      0x56,
      0x78,
      0x9a,
      0xbc,
      0xde,
      0xf0,
      0x12,
      0x34,
      0x56,
      0x78,
      0x9a,
      0xbc,
      0xde,
      0xf0,
      0x12,
      0x34,
      0x56,
      0x78,
      0x9a,
      0xbc,
      0xde,
      0xf0,
      0x12,
      0x34,
      0x56,
      0x78,
      0x9a,
      0xbc,
      0xde,
      0xf0,
    ]);

    let invalidCidv0 : CID.CID = {
      version = #v0;
      codec = #dag_pb;
      hashAlgorithm = #sha2_512; // CIDv0 must use sha2_256
      hash = hash;
    };

    testEncodingFailure(invalidCidv0, "invalidHashAlgorithm", "CIDv0 with non-SHA256 hash");
  },
);

test(
  "Invalid Hash Length Error",
  func() {
    // Test SHA-256 with wrong hash length
    let wrongLengthHash = Blob.fromArray([0x01, 0x02, 0x03, 0x04]); // Only 4 bytes instead of 32

    let invalidCid : CID.CID = {
      version = #v1;
      codec = #raw;
      hashAlgorithm = #sha2_256;
      hash = wrongLengthHash;
    };

    testEncodingFailure(invalidCid, "invalidHashLength", "SHA-256 with 4-byte hash");
  },
);

test(
  "CIDv0 Recognition",
  func() {
    // Test that 34-byte arrays starting with 0x1220 are recognized as CIDv0
    let cidv0Bytes : [Nat8] = [
      0x12,
      0x20, // SHA-256, 32 bytes
      0x00,
      0x01,
      0x02,
      0x03,
      0x04,
      0x05,
      0x06,
      0x07,
      0x08,
      0x09,
      0x0a,
      0x0b,
      0x0c,
      0x0d,
      0x0e,
      0x0f,
      0x10,
      0x11,
      0x12,
      0x13,
      0x14,
      0x15,
      0x16,
      0x17,
      0x18,
      0x19,
      0x1a,
      0x1b,
      0x1c,
      0x1d,
      0x1e,
      0x1f,
    ];

    let expectedCid : CID.CID = {
      version = #v0;
      codec = #dag_pb;
      hashAlgorithm = #sha2_256;
      hash = Blob.fromArray([
        0x00,
        0x01,
        0x02,
        0x03,
        0x04,
        0x05,
        0x06,
        0x07,
        0x08,
        0x09,
        0x0a,
        0x0b,
        0x0c,
        0x0d,
        0x0e,
        0x0f,
        0x10,
        0x11,
        0x12,
        0x13,
        0x14,
        0x15,
        0x16,
        0x17,
        0x18,
        0x19,
        0x1a,
        0x1b,
        0x1c,
        0x1d,
        0x1e,
        0x1f,
      ]);
    };

    testCidDecoding(cidv0Bytes, expectedCid, "CIDv0 recognition");
  },
);

test(
  "Large Varint Encoding",
  func() {
    // Test that DAG-JSON codec (0x0129) encodes correctly as varint
    let hash = Blob.fromArray([
      0x12,
      0x34,
      0x56,
      0x78,
      0x9a,
      0xbc,
      0xde,
      0xf0,
      0x12,
      0x34,
      0x56,
      0x78,
      0x9a,
      0xbc,
      0xde,
      0xf0,
      0x12,
      0x34,
      0x56,
      0x78,
      0x9a,
      0xbc,
      0xde,
      0xf0,
      0x12,
      0x34,
      0x56,
      0x78,
      0x9a,
      0xbc,
      0xde,
      0xf0,
    ]);

    let cidv1 : CID.CID = {
      version = #v1;
      codec = #dag_json;
      hashAlgorithm = #sha2_256;
      hash = hash;
    };

    testCidRoundTrip(cidv1, "large varint codec encoding");
  },
);

test(
  "Edge Case: Minimum Valid CIDv1",
  func() {
    let hash = Blob.fromArray([
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
    ]);

    let minCid : CID.CID = {
      version = #v1;
      codec = #raw;
      hashAlgorithm = #sha2_256;
      hash = hash;
    };

    testCidRoundTrip(minCid, "minimum valid CIDv1 (all zeros)");
  },
);

test(
  "Edge Case: Maximum Valid Hash",
  func() {
    let hash = Blob.fromArray([
      0xff,
      0xff,
      0xff,
      0xff,
      0xff,
      0xff,
      0xff,
      0xff,
      0xff,
      0xff,
      0xff,
      0xff,
      0xff,
      0xff,
      0xff,
      0xff,
      0xff,
      0xff,
      0xff,
      0xff,
      0xff,
      0xff,
      0xff,
      0xff,
      0xff,
      0xff,
      0xff,
      0xff,
      0xff,
      0xff,
      0xff,
      0xff,
    ]);

    let maxCid : CID.CID = {
      version = #v1;
      codec = #raw;
      hashAlgorithm = #sha2_256;
      hash = hash;
    };

    testCidRoundTrip(maxCid, "maximum valid hash (all 0xFF)");
  },
);

test(
  "Complex Round-trip Test",
  func() {
    // Test all combinations of supported codecs and hash algorithms
    let testCases : [(CID.Codec, CID.HashAlgorithm, [Nat8])] = [
      (
        #raw,
        #sha2_256,
        [
          0x01,
          0x02,
          0x03,
          0x04,
          0x05,
          0x06,
          0x07,
          0x08,
          0x09,
          0x0a,
          0x0b,
          0x0c,
          0x0d,
          0x0e,
          0x0f,
          0x10,
          0x11,
          0x12,
          0x13,
          0x14,
          0x15,
          0x16,
          0x17,
          0x18,
          0x19,
          0x1a,
          0x1b,
          0x1c,
          0x1d,
          0x1e,
          0x1f,
          0x20,
        ],
      ),
      (
        #dag_pb,
        #sha2_256,
        [
          0x21,
          0x22,
          0x23,
          0x24,
          0x25,
          0x26,
          0x27,
          0x28,
          0x29,
          0x2a,
          0x2b,
          0x2c,
          0x2d,
          0x2e,
          0x2f,
          0x30,
          0x31,
          0x32,
          0x33,
          0x34,
          0x35,
          0x36,
          0x37,
          0x38,
          0x39,
          0x3a,
          0x3b,
          0x3c,
          0x3d,
          0x3e,
          0x3f,
          0x40,
        ],
      ),
      (
        #dag_cbor,
        #sha2_256,
        [
          0x41,
          0x42,
          0x43,
          0x44,
          0x45,
          0x46,
          0x47,
          0x48,
          0x49,
          0x4a,
          0x4b,
          0x4c,
          0x4d,
          0x4e,
          0x4f,
          0x50,
          0x51,
          0x52,
          0x53,
          0x54,
          0x55,
          0x56,
          0x57,
          0x58,
          0x59,
          0x5a,
          0x5b,
          0x5c,
          0x5d,
          0x5e,
          0x5f,
          0x60,
        ],
      ),
      (
        #dag_json,
        #sha2_256,
        [
          0x61,
          0x62,
          0x63,
          0x64,
          0x65,
          0x66,
          0x67,
          0x68,
          0x69,
          0x6a,
          0x6b,
          0x6c,
          0x6d,
          0x6e,
          0x6f,
          0x70,
          0x71,
          0x72,
          0x73,
          0x74,
          0x75,
          0x76,
          0x77,
          0x78,
          0x79,
          0x7a,
          0x7b,
          0x7c,
          0x7d,
          0x7e,
          0x7f,
          0x80,
        ],
      ),
      (
        #raw,
        #blake2b_256,
        [
          0x81,
          0x82,
          0x83,
          0x84,
          0x85,
          0x86,
          0x87,
          0x88,
          0x89,
          0x8a,
          0x8b,
          0x8c,
          0x8d,
          0x8e,
          0x8f,
          0x90,
          0x91,
          0x92,
          0x93,
          0x94,
          0x95,
          0x96,
          0x97,
          0x98,
          0x99,
          0x9a,
          0x9b,
          0x9c,
          0x9d,
          0x9e,
          0x9f,
          0xa0,
        ],
      ),
    ];

    for ((codec, hashAlgo, hashBytes) in testCases.vals()) {
      let cid : CID.CID = {
        version = #v1;
        codec = codec;
        hashAlgorithm = hashAlgo;
        hash = Blob.fromArray(hashBytes);
      };

      testCidRoundTrip(cid, "codec " # debug_show (codec) # " with " # debug_show (hashAlgo));
    };
  },
);

test(
  "Invalid CIDv0 Length",
  func() {
    // Test bytes that start with 0x1220 but are not exactly 34 bytes
    testDecodingFailure([0x12, 0x20], "unsupportedVersion", "too short for CIDv0");

    let tooLong : [Nat8] = [
      0x12,
      0x20,
      0x00,
      0x01,
      0x02,
      0x03,
      0x04,
      0x05,
      0x06,
      0x07,
      0x08,
      0x09,
      0x0a,
      0x0b,
      0x0c,
      0x0d,
      0x0e,
      0x0f,
      0x10,
      0x11,
      0x12,
      0x13,
      0x14,
      0x15,
      0x16,
      0x17,
      0x18,
      0x19,
      0x1a,
      0x1b,
      0x1c,
      0x1d,
      0x1e,
      0x1f,
      0x20 // Extra byte
    ];
    testDecodingFailure(tooLong, "unsupportedVersion", "too long for CIDv0");
  },
);
