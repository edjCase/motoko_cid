import Nat8 "mo:base/Nat8";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Result "mo:base/Result";
import Blob "mo:new-base/Blob";

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

    public type ParseError = {
        #emptyBytes;
        #unsupportedVersion : Nat8;
        #unknownCodec : Nat;
        #unknownHashAlgorithm : Nat;
        #hashLengthMismatch : { expected : Nat; actual : Nat };
        #insufficientBytes : { needed : Nat; available : Nat };
        #invalidMultihash;
    };

    public type EncodeError = {
        #invalidCodec : Text;
        #invalidHashAlgorithm : Text;
        #invalidHashLength : {
            expected : Nat;
            actual : Nat;
        };
    };

    public func fromBytes(value : [Nat8]) : Result.Result<CID, ParseError> {
        if (value.size() == 0) {
            return #err(#emptyBytes);
        };

        // Check if it's CIDv0 (starts with multihash, typically 0x1220 for SHA-256)
        if (value.size() == 34 and value[0] == 0x12 and value[1] == 0x20) {
            return #ok({
                version = #v0;
                codec = #dag_pb; // CIDv0 always uses dag-pb
                hashAlgorithm = #sha2_256;
                hash = Blob.fromArray(Array.subArray(value, 2, 32)); // Skip multihash header
            });
        };

        // Parse CIDv1
        if (value[0] != 0x01) {
            return #err(#unsupportedVersion(value[0]));
        };

        // Decode codec
        let (codecCode, codecEnd) = decodeVarint(value, 1);
        let codec = switch (codeToCodec(codecCode)) {
            case (?c) c;
            case (null) return #err(#unknownCodec(codecCode));
        };

        // Decode multihash
        let (hashCode, hashCodeEnd) = decodeVarint(value, codecEnd);
        let hashAlgorithm = switch (codeToHashAlgorithm(hashCode)) {
            case (?algo) algo;
            case (null) return #err(#unknownHashAlgorithm(hashCode));
        };

        let (hashLength, hashLengthEnd) = decodeVarint(value, hashCodeEnd);
        let expectedLength = getHashLength(hashAlgorithm);

        if (hashLength != expectedLength) {
            return #err(#hashLengthMismatch({ expected = expectedLength; actual = hashLength }));
        };

        if (hashLengthEnd + hashLength > value.size()) {
            return #err(#insufficientBytes({ needed = hashLengthEnd + hashLength; available = value.size() }));
        };

        let hash = Array.subArray(value, hashLengthEnd, hashLength);

        #ok({
            version = #v1;
            codec = codec;
            hashAlgorithm = hashAlgorithm;
            hash = Blob.fromArray(hash);
        });
    };

    public func toBytes(cid : CID) : Result.Result<[Nat8], EncodeError> {
        switch (cid.version) {
            case (#v0) {
                // CIDv0 is just a multihash
                if (cid.codec != #dag_pb) {
                    return #err(#invalidCodec("CIDv0 must use dag-pb codec"));
                };
                if (cid.hashAlgorithm != #sha2_256) {
                    return #err(#invalidHashAlgorithm("CIDv0 must use sha2-256"));
                };
                toBytesV0(cid.hash);
            };
            case (#v1) toBytesV1(cid);
        };
    };

    func toBytesV1(cid : CID) : Result.Result<[Nat8], EncodeError> {
        // Validate hash length
        let expectedLength = getHashLength(cid.hashAlgorithm);
        if (cid.hash.size() != expectedLength) {
            return #err(#invalidHashLength({ expected = expectedLength; actual = cid.hash.size() }));
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

    func toBytesV0(hash : Blob) : Result.Result<[Nat8], EncodeError> {
        let expectedLength = getHashLength(#sha2_256);
        if (hash.size() != expectedLength) {
            return #err(#invalidHashLength({ expected = expectedLength; actual = hash.size() }));
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

    // Helper function to encode varint
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

    // Helper function to decode varint
    private func decodeVarint(bytes : [Nat8], start : Nat) : (Nat, Nat) {
        var result = 0;
        var shift = 0;
        var pos = start;

        while (pos < bytes.size()) {
            let byte = Nat8.toNat(bytes[pos]);
            result := result + ((byte % 128) * (2 ** shift));
            pos := pos + 1;

            if (byte < 128) {
                return (result, pos);
            };
            shift := shift + 7;
        };

        (result, pos);
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
