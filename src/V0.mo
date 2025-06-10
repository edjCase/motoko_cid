import Result "mo:new-base/Result";
import Nat "mo:new-base/Nat";
import Iter "mo:new-base/Iter";
import Blob "mo:new-base/Blob";
import Runtime "mo:new-base/Runtime";
import Text "mo:new-base/Text";
import Nat8 "mo:new-base/Nat8";
import Array "mo:new-base/Array";
import Buffer "mo:base/Buffer";
import BaseX "mo:base-x-encoder";

module {

    public type CID = {
        hash : Blob; // 32-byte SHA-256 hash
    };

    public func toText(cid : CID) : Text {
        if (cid.hash.size() != 32) {
            Runtime.trap("Invalid CIDv0 hash length: expected 32, got " # Nat.toText(cid.hash.size()));
        };
        var i = 0;
        let iter : Iter.Iter<Nat8> = {
            next = func() : ?Nat8 {
                i += 1;
                if (i == 1) return ?0x12; // SHA-256 code
                if (i == 2) return ?0x20; // 32 bytes
                let j : Nat = i - 3;
                if (j >= cid.hash.size()) return null; // No more bytes
                ?cid.hash[j];
            };
        };
        BaseX.toBase58(iter);
    };

    public func fromText(text : Text) : Result.Result<CID, Text> {
        let bytes = switch (BaseX.fromBase58(text)) {
            case (#ok(blob)) blob;
            case (#err(e)) return #err("Failed to decode CIDv0 base58: " # e);
        };
        if (bytes.size() != 34) {
            return #err("Invalid CIDv0 length: expected 34 bytes, got " # Nat.toText(bytes.size()));
        };
        let hashBlob = Blob.fromArray(Array.sliceToArray(bytes, 2, 34)); // Skip first 2 bytes (0x12, 0x20)
        return #ok({
            hash = hashBlob;
        });
    };

    public func toBytes(cid : CID) : [Nat8] {
        if (cid.hash.size() != 32) {
            Runtime.trap("Invalid CIDv0 hash length: expected 32, got " # Nat.toText(cid.hash.size()));
        };
        let buffer = Buffer.Buffer<Nat8>(32 + 2);

        // Multihash: [hash-code][hash-length][hash-digest]
        buffer.add(0x12); // SHA-256 code
        buffer.add(0x20); // 32 bytes
        for (byte in cid.hash.vals()) {
            buffer.add(byte);
        };
        Buffer.toArray(buffer);
    };

    public func fromBytes(iter : Iter.Iter<Nat8>) : Result.Result<CID, Text> {
        // Check for CIDv0 pattern (starts with 0x12, 0x20)
        let ?firstByte = iter.next() else return #err("Invalid CIDv0: not enough bytes");
        if (firstByte != 0x12) {
            return #err("Invalid CIDv0: expected first byte of 18, got " # Nat8.toText(firstByte));
        };
        let ?secondByte = iter.next() else return #err("Invalid CIDv0: not enough bytes");
        if (secondByte != 0x20) {
            return #err("Invalid CIDv0: expected second byte of 32, got " # Nat8.toText(secondByte));
        };

        // This looks like CIDv0 - consume the remaining 32 hash bytes
        let hashBlob = Blob.fromArray(Iter.toArray(iter));
        if (hashBlob.size() != 32) {
            return #err("Invalid CIDv0: expected 32-byte hash, got " # Nat.toText(hashBlob.size()));
        };
        return #ok({
            hash = hashBlob;
        });
    };
};
