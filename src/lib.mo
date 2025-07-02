import Nat8 "mo:base/Nat8";
import Result "mo:base/Result";
import Iter "mo:base/Iter";
import PeekableIter "mo:itertools/PeekableIter";
import V0Module "V0";
import V1Module "V1";
import Text "mo:new-base/Text";

module {

    public let V0 = V0Module;
    public let V1 = V1Module;

    /// Represents a Content Identifier that can be either version 0 or version 1.
    ///
    /// ```motoko
    /// let cidV0 : CID = #v0({
    ///   hash = "\E3\B0\C4\42\98\FC\1C\14\9A\FB\F4\C8\99\6F\B9\24\27\AE\41\E4\64\9B\93\4C\A4\95\99\1B\78\52\B8\55";
    /// });
    /// let cidV1 : CID = #v1({
    ///   codec = #dag_pb;
    ///   hashAlgorithm = #sha2_256;
    ///   hash = "\E3\B0\C4\42\98\FC\1C\14\9A\FB\F4\C8\99\6F\B9\24\27\AE\41\E4\64\9B\93\4C\A4\95\99\1B\78\52\B8\55";
    /// });
    /// ```
    public type CID = {
        #v0 : V0.CID;
        #v1 : V1.CID;
    };

    /// Represents a Content Identifier with multibase encoding information for text representation.
    ///
    /// ```motoko
    /// let cidV0 : CIDWithMultiBase = #v0({
    ///   hash = "\E3\B0\C4\42\98\FC\1C\14\9A\FB\F4\C8\99\6F\B9\24\27\AE\41\E4\64\9B\93\4C\A4\95\99\1B\78\52\B8\55";
    /// });
    /// let cidV1 : CIDWithMultiBase = #v1({
    ///   codec = #dag_pb;
    ///   hashAlgorithm = #sha2_256;
    ///   hash = "\E3\B0\C4\42\98\FC\1C\14\9A\FB\F4\C8\99\6F\B9\24\27\AE\41\E4\64\9B\93\4C\A4\95\99\1B\78\52\B8\55";
    ///   multibase = #base32;
    /// });
    /// ```
    public type CIDWithMultiBase = {
        #v0 : V0.CID;
        #v1 : V1.CID and {
            multibase : V1.MultiBase;
        };
    };

    /// Converts a CID to its text representation.
    /// CIDv1 types will default to base32 encoding.
    ///
    /// ```motoko
    /// let cid : CIDWithMultiBase = #v1({
    ///   codec = #dag_pb;
    ///   hashAlgorithm = #sha2_256;
    ///   hash = "\E3\B0\C4\42\98\FC\1C\14\9A\FB\F4\C8\99\6F\B9\24\27\AE\41\E4\64\9B\93\4C\A4\95\99\1B\78\52\B8\55";
    /// });
    /// let text = CID.toText(cid);
    /// // Returns: "bafybeihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"
    /// ```
    public func toText(cid : CID) : Text {
        switch (cid) {
            case (#v0(v0)) V0.toText(v0);
            case (#v1(v1)) V1.toText(v1, #base32); // Default to base32 for v1
        };
    };

    /// Converts a CID to its text representation.
    ///
    /// ```motoko
    /// let cid : CIDWithMultiBase = #v1({
    ///   codec = #dag_pb;
    ///   hashAlgorithm = #sha2_256;
    ///   hash = "\E3\B0\C4\42\98\FC\1C\14\9A\FB\F4\C8\99\6F\B9\24\27\AE\41\E4\64\9B\93\4C\A4\95\99\1B\78\52\B8\55";
    ///   multibase = #base32;
    /// });
    /// let text = CID.toTextAdvanced(cid);
    /// // Returns: "bafybeihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"
    /// ```
    public func toTextAdvanced(cid : CIDWithMultiBase) : Text {
        switch (cid) {
            case (#v0(v0)) V0.toText(v0);
            case (#v1((v1))) V1.toText(v1, v1.multibase);
        };
    };

    /// Parses a text string into a CID with multibase encoding information.
    ///
    /// ```motoko
    /// let result = CID.fromText("bafybeihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku");
    /// switch (result) {
    ///   case (#ok(cid)) { /* Successfully parsed CID */ };
    ///   case (#err(error)) { /* Handle parsing error */ };
    /// };
    /// ```
    public func fromText(text : Text) : Result.Result<CIDWithMultiBase, Text> {
        let iter = PeekableIter.fromIter(text.chars());
        let ?firstChar = iter.peek() else return #err("Empty CID text");
        if (firstChar == 'Q') return Result.chain(
            V0.fromText(Text.fromIter(iter)),
            func(v0 : V0.CID) : Result.Result<CIDWithMultiBase, Text> = #ok(#v0(v0)),
        );
        Result.chain(
            V1.fromText(Text.fromIter(iter)),
            func(v1 : V1.CIDWithMultiBase) : Result.Result<CIDWithMultiBase, Text> = #ok(#v1(v1)),
        );
    };

    /// Converts a CID to its binary byte representation.
    ///
    /// ```motoko
    /// let cid : CID = #v1({
    ///   codec = #dag_pb;
    ///   hashAlgorithm = #sha2_256;
    ///   hash = "\E3\B0\C4\42\98\FC\1C\14\9A\FB\F4\C8\99\6F\B9\24\27\AE\41\E4\64\9B\93\4C\A4\95\99\1B\78\52\B8\55";
    /// });
    /// let bytes = CID.toBytes(cid);
    /// // Returns: [0x01, 0x70, 0x12, 0x20, 0xE3, 0xB0, ...]
    /// ```
    public func toBytes(cid : CID) : [Nat8] {
        switch (cid) {
            case (#v0(v0)) V0.toBytes(v0);
            case (#v1(v1)) V1.toBytes(v1);
        };
    };

    /// Parses a byte array into a CID.
    ///
    /// ```motoko
    /// let bytes : [Nat8] = [0x01, 0x70, 0x12, 0x20, 0xE3, 0xB0, /* ... */];
    /// let result = CID.fromBytes(bytes.vals());
    /// switch (result) {
    ///   case (#ok(cid)) { /* Successfully parsed CID */ };
    ///   case (#err(error)) { /* Handle parsing error */ };
    /// };
    /// ```
    public func fromBytes(iter : Iter.Iter<Nat8>) : Result.Result<CID, Text> {
        let peekableIter = PeekableIter.fromIter(iter);

        let ?firstByte = peekableIter.peek() else return #err("Empty input bytes");

        switch (firstByte) {
            case (0x12) Result.chain(
                V0.fromBytes(peekableIter),
                func(v0 : V0.CID) : Result.Result<CID, Text> = #ok(#v0(v0)),
            );
            case (0x01) Result.chain(
                V1.fromBytes(peekableIter),
                func(v1 : V1.CID) : Result.Result<CID, Text> = #ok(#v1(v1)),
            );
            case (_) return #err("Unsupported CID version: " # Nat8.toText(firstByte));
        };
    };

};
