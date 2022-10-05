import Conversion "conversion";

module {

  public type Storable<T> = {
    fromBytes: ([Nat8]) -> T;
    toBytes: (T) -> [Nat8];
  };

  let STORABLE_NAT64 : Storable<Nat64> = {
    fromBytes = func(bytes: [Nat8]) : Nat64 { Conversion.bytesToNat64(bytes); };
    toBytes = func(x: Nat64) : [Nat8] { Conversion.nat64ToBytes(x); };
  };

};