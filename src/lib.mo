import Nat8 "mo:base/Nat8";
import Buffer "mo:base/Buffer";
import Result "mo:base/Result";
import Blob "mo:new-base/Blob";
import Nat64 "mo:new-base/Nat64";
import Nat "mo:new-base/Nat";
import Iter "mo:base/Iter";
import PeekableIter "mo:itertools/PeekableIter";

module {
    public type Version = { #v0; #v1 };
    public type Codec = { #raw; #dag_pb; #dag_cbor; #dag_json };
    public type HashAlgorithm = { #sha2_256; #sha2_512; #blake2b_256 };

    public type CID = {
        version : Version;
        codec : Codec;
        hashAlgorithm : HashAlgorithm;
        hash : Blob;
    };

    public func fromBytes(iter : Iter.Iter<Nat8>) : Result.Result<CID, Text> {
        let peekableIter = PeekableIter.fromIter(iter);

        let ?firstByte = peekableIter.next() else return #err("Empty input bytes");

        // Check for CIDv0 pattern (starts with 0x12, 0x20)
        if (firstByte == 0x12 and peekableIter.peek() == ?0x20) {
            ignore peekableIter.next(); // consume second byte

            // This looks like CIDv0 - consume the remaining 32 hash bytes
            let ?hashBlob = consumeBytes(peekableIter, 32) else return #err("Unexpected end of bytes when parsing CIDv0 hash");
            // Verify we've consumed all bytes (CIDv0 should be exactly 34 bytes)
            if (PeekableIter.hasNext(peekableIter)) {
                // More bytes remaining, this is invalid for CIDv0
                return #err("Invalid CIDv0: too many bytes");
            };
            return #ok({
                version = #v0;
                codec = #dag_pb;
                hashAlgorithm = #sha2_256;
                hash = hashBlob;
            });
        };

        // Parse CIDv1 - expect version byte 0x01
        let version = switch (firstByte) {
            case (0x01) #v1;
            case (_) return #err("Unsupported CID version: " # Nat8.toText(firstByte));
        };

        // Decode codec
        let ?codecCode = decodeVarint(peekableIter) else return #err("Unexpected end of bytes when parsing codec");
        let ?codec = codeToCodec(codecCode) else return #err("Unsupported codec: " # Nat.toText(codecCode));

        // Decode multihash
        let ?hashCode = decodeVarint(peekableIter) else return #err("Unexpected end of bytes when parsing multihash");
        let ?hashAlgorithm = codeToHashAlgorithm(hashCode) else return #err("Unsupported hash algorithm: " # Nat.toText(hashCode));

        // Decode hash length
        let ?hashLength = decodeVarint(peekableIter) else return #err("Unexpected end of bytes when parsing hash length");
        let expectedLength = getHashLength(hashAlgorithm);
        if (hashLength != expectedLength) {
            return #err("Invalid hash length: expected " # Nat.toText(expectedLength) # ", got " # Nat.toText(hashLength));
        };

        // Consume hash bytes
        let ?hash = consumeBytes(peekableIter, hashLength) else return #err("Unexpected end of bytes when parsing hash");

        #ok({
            version = version;
            codec = codec;
            hashAlgorithm = hashAlgorithm;
            hash = hash;
        });
    };

    // Efficiently consume exactly n bytes into a Blob
    private func consumeBytes(iter : PeekableIter.PeekableIter<Nat8>, n : Nat) : ?Blob {
        let buffer = Buffer.Buffer<Nat8>(n);
        for (i in Iter.range(0, n - 1)) {
            switch (iter.next()) {
                case (?byte) buffer.add(byte);
                case (null) return null; // Not enough bytes
            };
        };
        ?Blob.fromArray(Buffer.toArray(buffer));
    };

    private func decodeVarint(bytes : PeekableIter.PeekableIter<Nat8>) : ?Nat {
        // TODO result should be Nat, not Nat64
        var result : Nat64 = 0;
        var shift : Nat64 = 0;
        var bytesRead = 0;

        for (byte in bytes) {
            // Prevent infinite loop
            let byte32 = Nat64.fromNat(Nat8.toNat(byte));
            result := result + ((byte32 % 128) << shift);
            bytesRead += 1;

            if (byte32 < 128) {
                return ?Nat64.toNat(result);
            };
            shift += 7;
        };
        null; // Not enough bytes to complete varint
    };

    // Helper function to encode varint (unchanged)
    private func encodeVarint(n : Nat) : [Nat8] {
        let buffer = Buffer.Buffer<Nat8>(5);
        var value = n;

        while (value >= 128) {
            buffer.add(Nat8.fromNat((value % 128) + 128));
            value := value / 128;
        };
        buffer.add(Nat8.fromNat(value));

        Buffer.toArray(buffer);
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

    // Rest of the functions (toBytes, toBytesV1, toBytesV0) remain unchanged
    public func toBytes(cid : CID) : Result.Result<[Nat8], Text> {
        switch (cid.version) {
            case (#v0) {
                // CIDv0 is just a multihash
                if (cid.codec != #dag_pb) {
                    return #err("CIDv0 must use dag-pb codec");
                };
                if (cid.hashAlgorithm != #sha2_256) {
                    return #err("CIDv0 must use sha2-256");
                };
                toBytesV0(cid.hash);
            };
            case (#v1) toBytesV1(cid);
        };
    };

    func toBytesV1(cid : CID) : Result.Result<[Nat8], Text> {
        // Validate hash length
        let expectedLength = getHashLength(cid.hashAlgorithm);
        if (cid.hash.size() != expectedLength) {
            return #err("Invalid hash length: expected " # Nat.toText(expectedLength) # ", got " # Nat.toText(cid.hash.size()));
        };

        let buffer = Buffer.Buffer<Nat8>(cid.hash.size() + 10); // 10 bytes for version, codec, hash code, and length

        // CIDv1: [version][codec][multihash]
        buffer.add(0x01); // Version 1

        // Encode codec
        let codecBytes = encodeVarint(codecToCode(cid.codec));
        for (byte in codecBytes.vals()) {
            buffer.add(byte);
        };

        // Encode multihash
        let hashCode = hashAlgorithmToCode(cid.hashAlgorithm);
        let hashCodeBytes = encodeVarint(hashCode);
        for (byte in hashCodeBytes.vals()) {
            buffer.add(byte);
        };

        let hashLength = cid.hash.size();
        let hashLengthBytes = encodeVarint(hashLength);
        for (byte in hashLengthBytes.vals()) {
            buffer.add(byte);
        };

        // Hash digest
        for (byte in cid.hash.vals()) {
            buffer.add(byte);
        };

        #ok(Buffer.toArray(buffer));
    };

    func toBytesV0(hash : Blob) : Result.Result<[Nat8], Text> {
        let expectedLength = getHashLength(#sha2_256);
        if (hash.size() != expectedLength) {
            return #err("Invalid hash length: expected " # Nat.toText(expectedLength) # ", got " # Nat.toText(hash.size()));
        };
        let buffer = Buffer.Buffer<Nat8>(expectedLength + 2);

        // Multihash: [hash-code][hash-length][hash-digest]
        buffer.add(0x12); // SHA-256 code
        buffer.add(0x20); // 32 bytes
        for (byte in hash.vals()) {
            buffer.add(byte);
        };
        #ok(Buffer.toArray(buffer));
    };
};
