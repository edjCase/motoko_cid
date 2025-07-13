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

    /// Represents a CIDv0 (Content Identifier version 0) which contains only a SHA-256 hash.
    /// CIDv0 always uses SHA-256 hashing and Base58 encoding for text representation.
    ///
    /// ```motoko
    /// let cid : V0.CID = {
    ///   hash = "\E3\B0\C4\42\98\FC\1C\14\9A\FB\F4\C8\99\6F\B9\24\27\AE\41\E4\64\9B\93\4C\A4\95\99\1B\78\52\B8\55";
    /// };
    /// ```
    public type CID = {
        hash : Blob; // 32-byte SHA-256 hash
    };

    /// Converts a CIDv0 to its Base58 text representation.
    ///
    /// ```motoko
    /// let cid : V0.CID = {
    ///   hash = "\E3\B0\C4\42\98\FC\1C\14\9A\FB\F4\C8\99\6F\B9\24\27\AE\41\E4\64\9B\93\4C\A4\95\99\1B\78\52\B8\55";
    /// };
    /// let text = V0.toText(cid);
    /// // Returns: "QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n"
    /// ```
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

    /// Parses a Base58-encoded text string into a CIDv0.
    ///
    /// ```motoko
    /// let result = V0.fromText("QmdfTbBqBPQ7VNxZEYEj14VmRuZBkqFbiwReogJgS1zR1n");
    /// switch (result) {
    ///   case (#ok(cid)) { /* Successfully parsed CIDv0 */ };
    ///   case (#err(error)) { /* Handle parsing error */ };
    /// };
    /// ```
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

    /// Converts a CIDv0 to its binary byte representation (multihash format).
    ///
    /// ```motoko
    /// let cid : V0.CID = {
    ///   hash = "\E3\B0\C4\42\98\FC\1C\14\9A\FB\F4\C8\99\6F\B9\24\27\AE\41\E4\64\9B\93\4C\A4\95\99\1B\78\52\B8\55";
    /// };
    /// let bytes = V0.toBytes(cid);
    /// // Returns: [0x12, 0x20, 0xE3, 0xB0, ...] (34 bytes total)
    /// ```
    public func toBytes(cid : CID) : [Nat8] {
        let buffer = Buffer.Buffer<Nat8>(34);
        let _ = toBytesBuffer(buffer, cid);
        Buffer.toArray(buffer);
    };

    /// Converts a CIDv0 to its binary byte representation, writing directly to a buffer.
    /// This function is useful for streaming or when you want to manage buffer allocation yourself.
    /// It returns the number of bytes written to the buffer.
    ///
    /// ```motoko
    /// let buffer = Buffer.Buffer<Nat8>(100);
    /// let cid : V0.CID = {
    ///   hash = "\E3\B0\C4\42\98\FC\1C\14\9A\FB\F4\C8\99\6F\B9\24\27\AE\41\E4\64\9B\93\4C\A4\95\99\1B\78\52\B8\55";
    /// };
    /// let bytesWritten = V0.toBytesBuffer(buffer, cid);
    /// // Returns: 34 (2 bytes for multihash prefix + 32 bytes for hash)
    /// ```
    public func toBytesBuffer(buffer : Buffer.Buffer<Nat8>, cid : CID) : Nat {
        if (cid.hash.size() != 32) {
            Runtime.trap("Invalid CIDv0 hash length: expected 32, got " # Nat.toText(cid.hash.size()));
        };

        // Multihash: [hash-code][hash-length][hash-digest]
        buffer.add(0x12); // SHA-256 code
        buffer.add(0x20); // 32 bytes
        for (byte in cid.hash.vals()) {
            buffer.add(byte);
        };
        34; // 2 bytes for multihash prefix + 32 bytes for hash
    };

    /// Parses a byte iterator into a CIDv0.
    ///
    /// ```motoko
    /// let bytes : [Nat8] = [0x12, 0x20, 0xE3, 0xB0, /* ... 32 more hash bytes */];
    /// let result = V0.fromBytes(bytes.vals());
    /// switch (result) {
    ///   case (#ok(cid)) { /* Successfully parsed CIDv0 */ };
    ///   case (#err(error)) { /* Handle parsing error */ };
    /// };
    /// ```
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
        let digestBytes = Iter.toArray(Iter.take(iter, 32));
        if (digestBytes.size() != 32) {
            return #err("Invalid CIDv0: expected 32-byte hash, got " # Nat.toText(digestBytes.size()));
        };

        return #ok({
            hash = Blob.fromArray(digestBytes);
        });
    };

};
