import Iter "mo:new-base/Iter";
import Nat64 "mo:new-base/Nat64";
import Nat8 "mo:new-base/Nat8";
import Buffer "mo:base/Buffer";

module {

    public func decode(bytes : Iter.Iter<Nat8>) : ?Nat {
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

    public func encode(n : Nat) : [Nat8] {
        let buffer = Buffer.Buffer<Nat8>(5);
        var value = n;

        while (value >= 128) {
            buffer.add(Nat8.fromNat((value % 128) + 128));
            value := value / 128;
        };
        buffer.add(Nat8.fromNat(value));

        Buffer.toArray(buffer);
    };
};
