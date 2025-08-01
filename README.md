# Motoko CID Library

[![MOPS](https://img.shields.io/badge/MOPS-cid-blue)](https://mops.one/cid)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/edjcase/motoko_cid/blob/main/LICENSE)

A Motoko library for working with Content Identifiers (CIDs) used in IPFS and IPLD. Supports both CIDv0 and CIDv1 formats with multiple encodings, codecs, and hash algorithms.

## Package

### MOPS

```bash
mops add cid
```

To set up MOPS package manager, follow the instructions from the [MOPS Site](https://mops.one)

## Quick Start

### Import

```motoko
import CID "mo:cid"
```

### Example 1: Auto-Detecting CID Versions

```motoko
// Parse any CID - the library auto-detects the version
let cidText = "bafybeihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku";

switch (CID.fromText(cidText)) { // or CID.fromBytes(...)
  case (#ok(#v0(cidV0))) {
    Debug.print("Parsed CIDv0: " # CID.V0.toText(cidv1));
  };
  case (#ok(#v1(cidV1))) {
    Debug.print("Parsed CIDv1: " # CID.V1.toText(cidv1, cidv1.multibase));
  };
  case (#err(error)) Debug.print("Error: " # error);
};

```

### Example 2: Working with Specific CID Versions

#### V0

```motoko
let cidV0Text = "QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n";
switch (CID.V0.fromText(cidV0Text)) { // Or CID.V0.fromBytes(...)
  case (#ok(cidV0)) Debug.print("CIDv0: " # debug_show(cidV0));
  case (#err(error)) Debug.print("Error: " # error);
}
```

#### V1

````motoko
let cidV1Text = "bafybeihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku";

switch (CID.V1.fromText(cidV1Text)) { // Or CID.V1.fromBytes(...)
  case (#ok(cidV1)) Debug.print("CIDv1: " # debug_show(cidV1));
  case (#err(error)) Debug.print("Error: " # error);
};


### Example 3: Converting Between CID Versions

```motoko
// Start with a V0
let cidv0 = {
  hash = "\E3\B0\C4\42\98\FC\1C\14\9A\FB\F4\C8\99\6F\B9\24\27\AE\41\E4\64\9B\93\4C\A4\95\99\1B\78\52\B8\55";
};

// Convert to V1
let cidv1 = CID.V1.fromV0(cidv0);

Debug.print("CIDv0: " # CID.V0.toText(cidv0)); // "QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n"
Debug.print("CIDv1: " # CID.V1.toText(cidv1, #base32)); // "bafybeihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"
````

## Features

### CID Versions

- **CIDv0**: Legacy format, Base58-encoded, SHA-256 only, starts with "Qm"
- **CIDv1**: Modern format with multibase prefix, multiple codecs and hash algorithms

### Supported Codecs

- `#raw`: Raw binary data
- `#dagPb`: DAG-PB (Protocol Buffers)
- `#dagCbor`: DAG-CBOR

### Supported Hash Algorithms

- `#sha2256`: SHA-256 (32 bytes)
- `#sha2512`: SHA-512 (64 bytes)

### Supported Multibase Encodings

- `#base58btc`: Base58 Bitcoin (prefix: 'z')
- `#base32`: Base32 lowercase (prefix: 'b')
- `#base32Upper`: Base32 uppercase (prefix: 'B')
- `#base64`: Base64 (prefix: 'm')
- `#base64Url`: Base64 URL-safe (prefix: 'u')
- `#base64UrlPad`: Base64 URL-safe with padding (prefix: 'U')
- `#base16`: Base16 lowercase (prefix: 'f')
- `#base16Upper`: Base16 uppercase (prefix: 'F')

## API Reference

### Types

```motoko
// Generic CID type (version-agnostic)
public type CID = {
    #v0 : V0.CID;
    #v1 : V1.CID;
};

// CID with multibase encoding info
public type CIDWithMultiBase = {
    #v0 : V0.CID;
    #v1 : V1.CID and {
        multibase : V1.MultiBase;
    };
};

// CIDv0 structure
public type V0.CID = {
    hash : Blob; // 32-byte SHA-256 hash
};

// CIDv1 structure
public type V1.CID = {
    codec : Codec;
    hashAlgorithm : HashAlgorithm;
    hash : Blob;
};
```

### Main Functions

```motoko
// Convert CID to text representation
public func toText(cid : CIDWithMultiBase) : Text;

// Parse CID from text representation (auto-detects version)
public func fromText(text : Text) : Result.Result<CIDWithMultiBase, Text>;

// Convert CID to binary format
public func toBytes(cid : CID) : [Nat8];

// Convert CID to binary format, writing directly to a buffer
// Returns the number of bytes written
public func toBytesBuffer(buffer : Buffer.Buffer<Nat8>, cid : CID);

// Parse CID from binary format (auto-detects version)
public func fromBytes(iter : Iter.Iter<Nat8>) : Result.Result<CID, Text>;
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
