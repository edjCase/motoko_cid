import Result "mo:new-base/Result";
import Nat "mo:new-base/Nat";
import Iter "mo:new-base/Iter";
import Blob "mo:new-base/Blob";
import Runtime "mo:new-base/Runtime";
import Text "mo:new-base/Text";
import Nat8 "mo:new-base/Nat8";
import Buffer "mo:base/Buffer";
import VarInt "VarInt";
import BaseX "mo:base-x-encoder";
import V0 "V0";

module {

    /// Represents the data format/codec used in a CIDv1.
    ///
    /// ```motoko
    /// let codec : Codec = #dag_pb; // For IPFS files
    /// let rawCodec : Codec = #raw; // For raw binary data
    /// ```
    public type Codec = { #raw; #dag_pb; #dag_cbor; #dag_json };

    /// Represents the hash algorithm used in a CIDv1.
    ///
    /// ```motoko
    /// let hashAlg : HashAlgorithm = #sha2_256; // Most common (32 bytes)
    /// let blakeAlg : HashAlgorithm = #blake2b_256; // Alternative (32 bytes)
    /// let sha512Alg : HashAlgorithm = #sha2_512; // Larger hash (64 bytes)
    /// ```
    public type HashAlgorithm = { #sha2_256; #sha2_512; #blake2b_256 };

    /// Represents a CIDv1 (Content Identifier version 1) with codec, hash algorithm, and hash digest.
    ///
    /// ```motoko
    /// let cid : V1.CID = {
    ///   codec = #dag_pb;
    ///   hashAlgorithm = #sha2_256;
    ///   hash = "\E3\B0\C4\42\98\FC\1C\14\9A\FB\F4\C8\99\6F\B9\24\27\AE\41\E4\64\9B\93\4C\A4\95\99\1B\78\52\B8\55";
    /// };
    /// ```
    public type CID = {
        codec : Codec;
        hashAlgorithm : HashAlgorithm;
        hash : Blob;
    };

    /// Represents a CIDv1 with multibase encoding information for text representation.
    ///
    /// ```motoko
    /// let cidWithEncoding : CIDWithMultiBase = {
    ///   codec = #dag_pb;
    ///   hashAlgorithm = #sha2_256;
    ///   hash = "\E3\B0\C4\42\98\FC\1C\14\9A\FB\F4\C8\99\6F\B9\24\27\AE\41\E4\64\9B\93\4C\A4\95\99\1B\78\52\B8\55";
    ///   multibase = #base32;
    /// };
    /// ```
    public type CIDWithMultiBase = CID and {
        multibase : MultiBase;
    };

    /// Represents the multibase encoding format for text representation of CIDv1.
    ///
    /// ```motoko
    /// let encoding : MultiBase = #base32; // Most common for CIDv1 (prefix: "b")
    /// let base58Encoding : MultiBase = #base58btc; // Base58 format (prefix: "z")
    /// let hexEncoding : MultiBase = #base16; // Hexadecimal format (prefix: "f")
    /// ```
    public type MultiBase = {
        #base58btc;
        #base32;
        #base32Upper;
        #base64;
        #base64Url;
        #base64UrlPad;
        #base16;
        #base16Upper;
    };

    /// Converts a CIDv1 to its text representation using the specified multibase encoding.
    ///
    /// ```motoko
    /// let cid : V1.CID = {
    ///   codec = #dag_pb;
    ///   hashAlgorithm = #sha2_256;
    ///   hash = "\E3\B0\C4\42\98\FC\1C\14\9A\FB\F4\C8\99\6F\B9\24\27\AE\41\E4\64\9B\93\4C\A4\95\99\1B\78\52\B8\55";
    /// };
    /// let text = V1.toText(cid, #base32);
    /// // Returns: "bafybeihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"
    /// ```
    public func toText(cid : CID, multibase : MultiBase) : Text {
        let bytes = toBytes(cid);
        switch (multibase) {
            case (#base58btc) "z" # BaseX.toBase58(bytes.vals());
            case (#base32) "b" # BaseX.toBase32(bytes.vals(), #standard({ isUpper = false; includePadding = false }));
            case (#base32Upper) "B" # BaseX.toBase32(bytes.vals(), #standard({ isUpper = true; includePadding = false }));
            case (#base64) "m" # BaseX.toBase64(bytes.vals(), #standard({ includePadding = false }));
            case (#base64Url) "u" # BaseX.toBase64(bytes.vals(), #url({ includePadding = false }));
            case (#base64UrlPad) "U" # BaseX.toBase64(bytes.vals(), #url({ includePadding = true }));
            case (#base16) "f" # BaseX.toBase16(bytes.vals(), { isUpper = false; prefix = #none });
            case (#base16Upper) "F" # BaseX.toBase16(bytes.vals(), { isUpper = false; prefix = #none });
        };
    };

    /// Parses a text string into a CIDv1 with multibase encoding information.
    ///
    /// ```motoko
    /// let result = V1.fromText("bafybeihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku");
    /// switch (result) {
    ///   case (#ok(cidWithMultiBase)) { /* Successfully parsed */ };
    ///   case (#err(error)) { /* Handle parsing error */ };
    /// };
    /// ```
    public func fromText(text : Text) : Result.Result<CIDWithMultiBase, Text> {
        let iter = text.chars();
        let ?firstChar = iter.next() else return #err("Empty CID text");
        let bytesText = Text.fromIter(iter);
        let (bytesResult, multibase) : (Result.Result<[Nat8], Text>, MultiBase) = switch (firstChar) {
            case ('z') (BaseX.fromBase58(bytesText), #base58btc);
            case ('b') (BaseX.fromBase32(bytesText, #standard), #base32);
            case ('B') (BaseX.fromBase32(bytesText, #standard), #base32Upper);
            case ('m') (BaseX.fromBase64(bytesText), #base64);
            case ('u') (BaseX.fromBase64(bytesText), #base64Url);
            case ('U') (BaseX.fromBase64(bytesText), #base64UrlPad);
            case ('f') (BaseX.fromBase16(bytesText, { prefix = #none }), #base16);
            case ('F') (BaseX.fromBase16(bytesText, { prefix = #none }), #base16Upper);
            case (_) return #err("Unsupported CID multibase format: " # text);
        };
        let bytes = switch (bytesResult) {
            case (#ok(bytes)) bytes;
            case (#err(e)) return #err("Failed to decode CID bytes: " # e);
        };
        Result.chain(
            fromBytes(Iter.fromArray(bytes)),
            func(cid : CID) : Result.Result<CIDWithMultiBase, Text> = #ok({
                cid with multibase = multibase
            }),
        );
    };

    /// Converts a CIDv1 to its binary byte representation.
    ///
    /// ```motoko
    /// let cid : V1.CID = {
    ///   codec = #dag_pb;
    ///   hashAlgorithm = #sha2_256;
    ///   hash = "\E3\B0\C4\42\98\FC\1C\14\9A\FB\F4\C8\99\6F\B9\24\27\AE\41\E4\64\9B\93\4C\A4\95\99\1B\78\52\B8\55";
    /// };
    /// let bytes = V1.toBytes(cid);
    /// // Returns: [0x01, 0x70, 0x12, 0x20, 0xE3, 0xB0, ...]
    /// ```
    public func toBytes(cid : CID) : [Nat8] {
        // Validate hash length
        let expectedLength = getHashLength(cid.hashAlgorithm);
        if (cid.hash.size() != expectedLength) {
            Runtime.trap("Invalid hash length: expected " # Nat.toText(expectedLength) # ", got " # Nat.toText(cid.hash.size()));
        };

        let buffer = Buffer.Buffer<Nat8>(cid.hash.size() + 10); // 10 bytes for version, codec, hash code, and length

        // CIDv1: [version][codec][multihash]
        buffer.add(0x01); // Version 1

        // Encode codec
        let codecBytes = VarInt.encode(codecToCode(cid.codec));
        for (byte in codecBytes.vals()) {
            buffer.add(byte);
        };

        // Encode multihash
        let hashCode = hashAlgorithmToCode(cid.hashAlgorithm);
        let hashCodeBytes = VarInt.encode(hashCode);
        for (byte in hashCodeBytes.vals()) {
            buffer.add(byte);
        };

        let hashLength = cid.hash.size();
        let hashLengthBytes = VarInt.encode(hashLength);
        for (byte in hashLengthBytes.vals()) {
            buffer.add(byte);
        };

        // Hash digest
        for (byte in cid.hash.vals()) {
            buffer.add(byte);
        };

        Buffer.toArray(buffer);
    };

    /// Parses a byte iterator into a CIDv1.
    ///
    /// ```motoko
    /// let bytes : [Nat8] = [0x01, 0x70, 0x12, 0x20, 0xE3, 0xB0, /* ... */];
    /// let result = V1.fromBytes(bytes.vals());
    /// switch (result) {
    ///   case (#ok(cid)) { /* Successfully parsed CIDv1 */ };
    ///   case (#err(error)) { /* Handle parsing error */ };
    /// };
    /// ```
    public func fromBytes(iter : Iter.Iter<Nat8>) : Result.Result<CID, Text> {
        let ?version = iter.next() else return #err("Unexpected end of bytes when parsing CID version");
        if (version != 0x01) {
            return #err("Expected CID version 1, got " # Nat8.toText(version));
        };

        // Decode codec
        let ?codecCode = VarInt.decode(iter) else return #err("Unexpected end of bytes when parsing codec");
        let ?codec = codeToCodec(codecCode) else return #err("Unsupported codec: " # Nat.toText(codecCode));

        // Decode multihash
        let ?hashCode = VarInt.decode(iter) else return #err("Unexpected end of bytes when parsing multihash");
        let ?hashAlgorithm = codeToHashAlgorithm(hashCode) else return #err("Unsupported hash algorithm: " # Nat.toText(hashCode));

        // Decode hash length
        let ?hashLength = VarInt.decode(iter) else return #err("Unexpected end of bytes when parsing hash length");
        let expectedLength = getHashLength(hashAlgorithm);
        if (hashLength != expectedLength) {
            return #err("Invalid hash length: expected " # Nat.toText(expectedLength) # ", got " # Nat.toText(hashLength));
        };

        // Consume hash bytes
        let hash = Blob.fromArray(Iter.toArray(iter));
        if (hash.size() != expectedLength) {
            return #err("Invalid hash length: expected " # Nat.toText(expectedLength) # ", got " # Nat.toText(hash.size()));
        };

        #ok({
            codec = codec;
            hashAlgorithm = hashAlgorithm;
            hash = hash;
        });
    };

    /// Converts a CIDv0 to a CIDv1 using DAG-PB codec and SHA-256 hash algorithm.
    ///
    /// ```motoko
    /// let cidV0 : V0.CID = {
    ///   hash = "\E3\B0\C4\42\98\FC\1C\14\9A\FB\F4\C8\99\6F\B9\24\27\AE\41\E4\64\9B\93\4C\A4\95\99\1B\78\52\B8\55";
    /// };
    /// let cidV1 = V1.fromV0(cidV0);
    /// // Returns: { codec = #dag_pb; hashAlgorithm = #sha2_256; hash = cidV0.hash }
    /// ```
    public func fromV0(cid : V0.CID) : CID {
        {
            codec = #dag_pb;
            hashAlgorithm = #sha2_256;
            hash = cid.hash;
        };
    };

    // Convert hash algorithm to multihash code
    private func hashAlgorithmToCode(algo : HashAlgorithm) : Nat {
        switch (algo) {
            case (#sha2_256) 0x12;
            case (#sha2_512) 0x13;
            case (#blake2b_256) 0xb220;
        };
    };

    // Convert multihash code to hash algorithm
    private func codeToHashAlgorithm(code : Nat) : ?HashAlgorithm {
        switch (code) {
            case (0x12) ?#sha2_256;
            case (0x13) ?#sha2_512;
            case (0xb220) ?#blake2b_256;
            case (_) null;
        };
    };

    // Convert codec to code
    private func codecToCode(codec : Codec) : Nat {
        switch (codec) {
            case (#raw) 0x55;
            case (#dag_pb) 0x70;
            case (#dag_cbor) 0x71;
            case (#dag_json) 0x0129;
        };
    };

    // Convert code to codec
    private func codeToCodec(code : Nat) : ?Codec {
        switch (code) {
            case (0x55) ?#raw;
            case (0x70) ?#dag_pb;
            case (0x71) ?#dag_cbor;
            case (0x0129) ?#dag_json;
            case (_) null;
        };
    };

    // Get expected hash length for algorithm
    private func getHashLength(algo : HashAlgorithm) : Nat {
        switch (algo) {
            case (#sha2_256) 32;
            case (#sha2_512) 64;
            case (#blake2b_256) 32;
        };
    };
};
