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

module {

    public type Codec = { #raw; #dag_pb; #dag_cbor; #dag_json };
    public type HashAlgorithm = { #sha2_256; #sha2_512; #blake2b_256 };

    public type CID = {
        codec : Codec;
        hashAlgorithm : HashAlgorithm;
        hash : Blob;
    };

    public type CIDWithMultiBase = CID and {
        multibase : MultiBase;
    };

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
