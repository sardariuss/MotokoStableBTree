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
      // Traps on overflow.
      let offset = address + Nat64.fromNat(size);
      // Cannot read pass the memory buffer size.
      if (Nat64.toNat(offset) > buffer_.size()){
        Debug.trap("read: out of bounds");
      };
      // Copy the bytes from the memory buffer.
      let bytes = Buffer.Buffer<Nat8>(size);
      for (idx in Iter.range(Nat64.toNat(address), Nat64.toNat(offset) - 1)){
        bytes.add(buffer_.get(idx));
      };
      bytes.toArray();
    };

    public func store(address: Nat64, bytes: [Nat8]) {
      // Traps on overflow.
      let offset = address + Nat64.fromNat(bytes.size());
      // Compute the number of pages required.
      let pages = (offset + Constants.WASM_PAGE_SIZE) >> 16;
      // Grow the number of pages if necessary.
      if (pages > this.size()){
        if (grow(pages - this.size()) < 0){
          Debug.trap("Fail to grow memory.");
        };
      };
      // Copy the bytes in the buffer.
      for (idx in Array.keys(bytes)){
        buffer_.put(Nat64.toNat(address) + idx, bytes[idx]);
      };
    };

    func grow(pages: Nat64) : Int64 {
      let size = this.size();
      let num_pages = size + pages;
      // Number of pages cannot exceed defined MAX_PAGES.
      if (num_pages > MAX_PAGES) {
        return -1;
      };
      // Add the pages (initialized with zeros) to the memory buffer.
      let to_add = Array.freeze(Array.init<Nat8>(Nat64.toNat(pages * Constants.WASM_PAGE_SIZE), 0));
      buffer_.append(Utils.toBuffer(to_add));
      // Return the previous size.
      return Int64.fromIntWrap(Nat64.toNat(size));
    };

    public func toText() : Text {
      let text_buffer = Buffer.Buffer<Text>(0);
      text_buffer.add("Memory : [");
      for (byte in buffer_.vals()){
        text_buffer.add(Nat8.toText(byte) # ", ");
      };
      text_buffer.add("]");
      Text.join("", text_buffer.vals());
    };

  };

};