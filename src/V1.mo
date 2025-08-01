import Result "mo:core/Result";
import Iter "mo:core/Iter";
import Blob "mo:core/Blob";
import Text "mo:core/Text";
import Nat8 "mo:core/Nat8";
import List "mo:core/List";
import Buffer "mo:buffer";
import V0 "V0";
import MultiBaseModule "mo:multiformats/MultiBase";
import MultiCodec "mo:multiformats/MultiCodec";
import MultiHash "mo:multiformats/MultiHash";

module {

  /// Represents the data format/codec used in a CIDv1.
  ///
  /// ```motoko
  /// let codec : Codec = #dagPb; // For IPFS files
  /// let rawCodec : Codec = #raw; // For raw binary data
  /// ```
  public type Codec = MultiCodec.Codec;

  /// Represents the hash algorithm used in a CIDv1.
  ///
  /// ```motoko
  /// let hashAlg : HashAlgorithm = #sha2256; // Most common (32 bytes)
  /// let blakeAlg : HashAlgorithm = #blake2b_256; // Alternative (32 bytes)
  /// let sha512Alg : HashAlgorithm = #sha2_512; // Larger hash (64 bytes)
  /// ```
  public type HashAlgorithm = MultiHash.Algorithm;

  /// Represents a CIDv1 (Content Identifier version 1) with codec, hash algorithm, and hash digest.
  ///
  /// ```motoko
  /// let cid : V1.CID = {
  ///   codec = #dagPb;
  ///   hashAlgorithm = #sha2256;
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
  ///   codec = #dagPb;
  ///   hashAlgorithm = #sha2256;
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
  ///   codec = #dagPb;
  ///   hashAlgorithm = #sha2256;
  ///   hash = "\E3\B0\C4\42\98\FC\1C\14\9A\FB\F4\C8\99\6F\B9\24\27\AE\41\E4\64\9B\93\4C\A4\95\99\1B\78\52\B8\55";
  /// };
  /// let text = V1.toText(cid, #base32);
  /// // Returns: "bafybeihdwdcefgh4dqkjv67uzcmw7ojee6xedzdetojuzjevtenxquvyku"
  /// ```
  public func toText(cid : CID, multibase : MultiBase) : Text {
    let bytes = toBytes(cid);
    MultiBaseModule.toText(bytes.vals(), multibase);
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
    let (bytes, multibase) = switch (MultiBaseModule.fromText(text)) {
      case (#ok(v)) v;
      case (#err(e)) return #err("Failed to decode CID bytes: " # e);
    };
    Result.chain(
      fromBytes(bytes.vals()),
      func(cid : CID) : Result.Result<CIDWithMultiBase, Text> = #ok({
        cid with multibase = multibase
      }),
    );
  };

  /// Converts a CIDv1 to its binary byte representation.
  ///
  /// ```motoko
  /// let cid : V1.CID = {
  ///   codec = #dagPb;
  ///   hashAlgorithm = #sha2256;
  ///   hash = "\E3\B0\C4\42\98\FC\1C\14\9A\FB\F4\C8\99\6F\B9\24\27\AE\41\E4\64\9B\93\4C\A4\95\99\1B\78\52\B8\55";
  /// };
  /// let bytes = V1.toBytes(cid);
  /// // Returns: [0x01, 0x70, 0x12, 0x20, 0xE3, 0xB0, ...]
  /// ```
  public func toBytes(cid : CID) : [Nat8] {
    let buffer = List.empty<Nat8>();
    let _ = toBytesBuffer(Buffer.fromList(buffer), cid);
    List.toArray(buffer);
  };

  /// Converts a CIDv1 to its binary byte representation, writing directly to a buffer.
  /// This function is useful for streaming or when you want to manage buffer allocation yourself.
  ///
  /// ```motoko
  /// let list = List.empty<Nat8>();
  /// let cid : V1.CID = {
  ///   codec = #dagPb;
  ///   hashAlgorithm = #sha2256;
  ///   hash = "\E3\B0\C4\42\98\FC\1C\14\9A\FB\F4\C8\99\6F\B9\24\27\AE\41\E4\64\9B\93\4C\A4\95\99\1B\78\52\B8\55";
  /// };
  /// let buffer = Buffer.fromList<Nat8>(list);
  /// V1.toBytesBuffer(buffer, cid);
  /// ```
  public func toBytesBuffer(buffer : Buffer.Buffer<Nat8>, cid : CID) {
    // CIDv1: [version][codec][multihash]
    buffer.write(0x01); // Version 1

    // Encode codec
    MultiCodec.toBytesBuffer(buffer, cid.codec);

    MultiHash.toBytesBuffer(
      buffer,
      {
        algorithm = cid.hashAlgorithm;
        digest = cid.hash;
      },
    );
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

    let codec = switch (MultiCodec.fromBytes(iter)) {
      case (#ok(codec)) codec;
      case (#err(e)) return #err("Failed to decode codec: " # e);
    };

    let multiHash = switch (MultiHash.fromBytes(iter)) {
      case (#ok(mh)) mh;
      case (#err(e)) return #err("Failed to decode multihash: " # e);
    };

    #ok({
      codec = codec;
      hashAlgorithm = multiHash.algorithm;
      hash = multiHash.digest;
    });
  };

  /// Converts a CIDv0 to a CIDv1 using DAG-PB codec and SHA-256 hash algorithm.
  ///
  /// ```motoko
  /// let cidV0 : V0.CID = {
  ///   hash = "\E3\B0\C4\42\98\FC\1C\14\9A\FB\F4\C8\99\6F\B9\24\27\AE\41\E4\64\9B\93\4C\A4\95\99\1B\78\52\B8\55";
  /// };
  /// let cidV1 = V1.fromV0(cidV0);
  /// // Returns: { codec = #dagPb; hashAlgorithm = #sha2256; hash = cidV0.hash }
  /// ```
  public func fromV0(cid : V0.CID) : CID {
    {
      codec = #dagPb;
      hashAlgorithm = #sha2256;
      hash = cid.hash;
    };
  };

};
