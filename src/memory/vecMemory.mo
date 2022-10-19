import Constants "../constants";
import Utils "../utils";

import Int64 "mo:base/Int64";
import Buffer "mo:base/Buffer";
import Nat64 "mo:base/Nat64";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Nat8 "mo:base/Nat8";

module {

  public class VecMemory() = this {

    // 2^64 - 1 = 18446744073709551615
    let MAX_PAGES : Nat64 = 18446744073709551615 / Constants.WASM_PAGE_SIZE;

    let buffer_ = Buffer.Buffer<Nat8>(0);

    public func size() : Nat64 {
      Nat64.fromNat(buffer_.size()) / Constants.WASM_PAGE_SIZE;
    };

    public func load(address: Nat64, size: Nat) : [Nat8] {
      // Traps on overflow
      let offset = address + Nat64.fromNat(size);
      
      if (Nat64.toNat(offset) > buffer_.size()){
        Debug.trap("read: out of bounds");
      };

      let bytes = Buffer.Buffer<Nat8>(size);
      for (idx in Iter.range(Nat64.toNat(address), Nat64.toNat(offset) - 1)){
        bytes.add(buffer_.get(idx));
      };
      bytes.toArray();
    };

    public func store(address: Nat64, bytes: [Nat8]) {
      // Traps on overflow
      let offset = address + Nat64.fromNat(bytes.size());

      // @todo: differ from rust implementation
      let pages = (offset + Constants.WASM_PAGE_SIZE) >> 16;
      if (pages > this.size()){
        if (grow(pages - this.size()) < 0){
          Debug.trap("Fail to grow memory.");
        };
      };
      for (idx in Array.keys(bytes)){
        buffer_.put(Nat64.toNat(address) + idx, bytes[idx]);
      };
    };

    func grow(pages: Nat64) : Int64 {
      let size = this.size();
      // @todo: if n overflows here, it traps, whereas in the rust impl, it returns -1
      let num_pages = size + pages;
      if (num_pages > MAX_PAGES) {
        return -1;
      };
      let to_add = Array.freeze(Array.init<Nat8>(Nat64.toNat(pages * Constants.WASM_PAGE_SIZE), 0));
      buffer_.append(Utils.toBuffer(to_add));
      // @todo: seems like that's what is done in rust (wrap)
      return Int64.fromIntWrap(Nat64.toNat(size));
    };

    public func print() {
      let text_buffer = Buffer.Buffer<Text>(0);
      text_buffer.add("Memory : [");
      for (byte in buffer_.vals()){
        text_buffer.add(Nat8.toText(byte) # ", ");
      };
      text_buffer.add("]");
      Debug.print(Text.join("", text_buffer.vals()));
    };

  };

};