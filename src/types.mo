import Buffer "mo:base/Buffer";

module {

  public type Address = Nat64;
  public type Bytes = Nat64;

  // @todo: rename in MemoryInterface?
  public type Memory = {
    size: () -> Nat64;
    store: (Nat64, [Nat8]) -> ();
    load: (Nat64, Nat) -> [Nat8];
  };

  //////////////////////////////////////////////////////////////////////
  // The following functions easily creates a buffer from an arry of any type
  //////////////////////////////////////////////////////////////////////

  public func toBuffer<T>(x :[T]) : Buffer.Buffer<T>{
    let thisBuffer = Buffer.Buffer<T>(x.size());
    for(thisItem in x.vals()){
      thisBuffer.add(thisItem);
    };
    return thisBuffer;
  };

};