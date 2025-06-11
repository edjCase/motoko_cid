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

    public type CID = {
        #v0 : V0.CID;
        #v1 : V1.CID;
    };

    public type CIDWithMultiBase = {
        #v0 : V0.CID;
        #v1 : V1.CID and {
            multibase : V1.MultiBase;
        };
    };

    public func toText(cid : CIDWithMultiBase) : Text {
        switch (cid) {
            case (#v0(v0)) V0.toText(v0);
            case (#v1((v1))) V1.toText(v1, v1.multibase);
        };
    };

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

    public func toBytes(cid : CID) : [Nat8] {
        switch (cid) {
            case (#v0(v0)) V0.toBytes(v0);
            case (#v1(v1)) V1.toBytes(v1);
        };
    };

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
