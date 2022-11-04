import MemoryManager "../../src/memoryManager";
import Memory "../../src/memory";
import Constants "../../src/constants";

import Suite "mo:matchers/Suite";

import Iter "mo:base/Iter";
import Nat64 "mo:base/Nat64";
import Nat16 "mo:base/Nat16";
import Nat8 "mo:base/Nat8";
import Int "mo:base/Int";
import Int64 "mo:base/Int64";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";

module {

  // For convenience: from the memory manager module
  type MemoryId = MemoryManager.MemoryId;
  type BucketId = MemoryManager.BucketId;
  // For convenience: from matchers module
  let { run;test;suite; } = Suite;
  // For convenience: from base module
  type Buffer<T> = Buffer.Buffer<T>;

  /// Check if the given optional buffer is equal to the given array
  /// \returns True if the buffer is null and the array is empty
  /// or if the values from the buffer equal the values from the array,
  /// false otherwise
  public func equal<T>(buffer: ?Buffer<T>, array: [T], equal: (T, T) -> Bool) : Bool {
    switch(buffer){
      case(null) { array.size() == 0; };
      case(?buffer) { Array.equal(buffer.toArray(), array, equal); };
    };
  };

  public class TestMemoryManager() = {

    // To use less memory and avoid RTS error: Cannot grow memory
    let BUCKET_SIZE_IN_PAGES : Nat64 = 16;

    func canGetMemory() {
      let mem_mgr = MemoryManager.initWithBuckets(Memory.VecMemory(), Nat16.fromNat(Nat64.toNat(BUCKET_SIZE_IN_PAGES)));
      let memory = mem_mgr.get(0 : MemoryId);
      assert(memory.size() == 0);
    };

    func canAllocateAndUseMemory() {
      let mem = Memory.VecMemory();
      let mem_mgr = MemoryManager.initWithBuckets(mem, Nat16.fromNat(Nat64.toNat(BUCKET_SIZE_IN_PAGES)));
      let memory = mem_mgr.get(0 : MemoryId);

      assert(memory.grow(1) == 0);
      assert(memory.size() == 1);

      memory.write(0, [1, 2, 3]);

      let bytes = memory.read(0, 3);
      assert(bytes == [1, 2, 3]);

      assert(equal(mem_mgr.inner_.memory_buckets_.get(0 : MemoryId), [0 : BucketId], Nat16.equal));
    };

    func canAllocateAndUseMultipleMemories() {
      let mem = Memory.VecMemory();
      let mem_mgr = MemoryManager.initWithBuckets(mem, Nat16.fromNat(Nat64.toNat(BUCKET_SIZE_IN_PAGES)));
      let memory_0 = mem_mgr.get(0 : MemoryId);
      let memory_1 = mem_mgr.get(1 : MemoryId);

      assert(memory_0.grow(1) == 0);
      assert(memory_1.grow(1) == 0);

      assert(memory_0.size() == 1);
      assert(memory_1.size() == 1);

      assert(equal(mem_mgr.inner_.memory_buckets_.get(0 : MemoryId), [0 : BucketId], Nat16.equal));
      assert(equal(mem_mgr.inner_.memory_buckets_.get(1 : MemoryId), [1 : BucketId], Nat16.equal));

      memory_0.write(0, [1, 2, 3]);
      memory_0.write(0, [1, 2, 3]);
      memory_1.write(0, [4, 5, 6]);

      var bytes = memory_0.read(0, 3);
      assert(bytes == [1, 2, 3]);

      bytes := memory_1.read(0, 3);
      assert(bytes == [4, 5, 6]);

      // + 1 is for the header.
      assert(mem.size() == 2 * BUCKET_SIZE_IN_PAGES + 1);
    };

    func canBeReinitializedFromMemory() {
      let mem = Memory.VecMemory();
      var mem_mgr = MemoryManager.initWithBuckets(mem, Nat16.fromNat(Nat64.toNat(BUCKET_SIZE_IN_PAGES)));
      var memory_0 = mem_mgr.get(0 : MemoryId);
      var memory_1 = mem_mgr.get(1 : MemoryId);

      assert(memory_0.grow(1) == 0);
      assert(memory_1.grow(1) == 0);

      memory_0.write(0, [1, 2, 3]);
      memory_1.write(0, [4, 5, 6]);

      mem_mgr := MemoryManager.initWithBuckets(mem, Nat16.fromNat(Nat64.toNat(BUCKET_SIZE_IN_PAGES)));
      memory_0 := mem_mgr.get(0 : MemoryId);
      memory_1 := mem_mgr.get(1 : MemoryId);

      var bytes = memory_0.read(0, 3);
      assert(bytes == [1, 2, 3]);

      bytes := memory_1.read(0, 3);
      assert(bytes == [4, 5, 6]);
    };

    func growingSameMemoryMultipleTimesDoesntIncreaseUnderlyingAllocation() {
      let mem = Memory.VecMemory();
      let mem_mgr = MemoryManager.initWithBuckets(mem, Nat16.fromNat(Nat64.toNat(BUCKET_SIZE_IN_PAGES)));
      let memory_0 = mem_mgr.get(0 : MemoryId);

      // Grow the memory by 1 page. This should increase the underlying allocation
      // by `BUCKET_SIZE_IN_PAGES` pages.
      assert(memory_0.grow(1) == 0);
      assert(mem.size() == 1 + BUCKET_SIZE_IN_PAGES);

      // Grow the memory again. This should NOT increase the underlying allocation.
      assert(memory_0.grow(1) == 1);
      assert(memory_0.size() == 2);
      assert(mem.size() == 1 + BUCKET_SIZE_IN_PAGES);

      // Grow the memory up to the BUCKET_SIZE_IN_PAGES. This should NOT increase the underlying
      // allocation.
      assert(memory_0.grow(BUCKET_SIZE_IN_PAGES - 2) == 2);
      assert(memory_0.size() == BUCKET_SIZE_IN_PAGES);
      assert(mem.size() == 1 + BUCKET_SIZE_IN_PAGES);

      // Grow the memory by one more page. This should increase the underlying allocation.
      assert(memory_0.grow(1) == Int64.fromNat64(BUCKET_SIZE_IN_PAGES));
      assert(memory_0.size() == BUCKET_SIZE_IN_PAGES + 1);
      assert(mem.size() == 1 + 2 * BUCKET_SIZE_IN_PAGES);
    };

    func doesNotGrowMemoryUnnecessarily() {
      let mem = Memory.VecMemory();
      let initial_size = BUCKET_SIZE_IN_PAGES * 2;

      // Grow the memory manually before passing it into the memory manager.
      ignore mem.grow(initial_size);

      let mem_mgr = MemoryManager.initWithBuckets(mem, Nat16.fromNat(Nat64.toNat(BUCKET_SIZE_IN_PAGES)));
      let memory_0 = mem_mgr.get(0 : MemoryId);

      // Grow the memory by 1 page.
      assert(memory_0.grow(1) == 0);
      assert(mem.size() == initial_size);

      // Grow the memory by BUCKET_SIZE_IN_PAGES more pages, which will cause the underlying
      // allocation to increase.
      assert(memory_0.grow(BUCKET_SIZE_IN_PAGES) == 1);
      assert(mem.size() == 1 + BUCKET_SIZE_IN_PAGES * 2);
    };

    func growingBeyondCapacityFails() {
      let MAX_MEMORY_IN_PAGES: Nat64 = MemoryManager.MAX_NUM_BUCKETS * BUCKET_SIZE_IN_PAGES;

      let mem = Memory.VecMemory();
      let mem_mgr = MemoryManager.initWithBuckets(mem, Nat16.fromNat(Nat64.toNat(BUCKET_SIZE_IN_PAGES)));
      let memory_0 = mem_mgr.get(0 : MemoryId);

      assert(memory_0.grow(MAX_MEMORY_IN_PAGES + 1) == -1);

      // Try to grow the memory by MAX_MEMORY_IN_PAGES + 1.
      assert(memory_0.grow(1) == 0); // should succeed
      assert(memory_0.grow(MAX_MEMORY_IN_PAGES) == -1); // should fail.
    };

    func canWriteAcrossBucketBoundaries() {
      let mem = Memory.VecMemory();
      let mem_mgr = MemoryManager.initWithBuckets(mem, Nat16.fromNat(Nat64.toNat(BUCKET_SIZE_IN_PAGES)));
      let memory_0 = mem_mgr.get(0 : MemoryId);

      assert(memory_0.grow(BUCKET_SIZE_IN_PAGES + 1) == 0);

      memory_0.write(
        mem_mgr.inner_.bucketSizeInBytes() - 1,
        [1, 2, 3],
      );

      let bytes = memory_0.read(
        mem_mgr.inner_.bucketSizeInBytes() - 1,
        3
      );
      assert(bytes == [1, 2, 3]);
    };

    func canWriteAcrossBucketBoundariesWithInterleavingMemories() {
      let mem = Memory.VecMemory();
      let mem_mgr = MemoryManager.initWithBuckets(mem, Nat16.fromNat(Nat64.toNat(BUCKET_SIZE_IN_PAGES)));
      let memory_0 = mem_mgr.get(0 : MemoryId);
      let memory_1 = mem_mgr.get(1 : MemoryId);

      assert(memory_0.grow(BUCKET_SIZE_IN_PAGES) == 0);
      assert(memory_1.grow(1) == 0);
      assert(memory_0.grow(1) == Int64.fromNat64(BUCKET_SIZE_IN_PAGES));

      memory_0.write(
        mem_mgr.inner_.bucketSizeInBytes() - 1,
        [1, 2, 3],
      );
      memory_1.write(0, [4, 5, 6]);

      var bytes = memory_0.read(Constants.WASM_PAGE_SIZE * BUCKET_SIZE_IN_PAGES - 1, 3);
      assert(bytes == [1, 2, 3]);

      bytes := memory_1.read(0, 3);
      assert(bytes == [4, 5, 6]);
    };

    func readingOutOfBoundsShouldTrap() {
      let mem = Memory.VecMemory();
      let mem_mgr = MemoryManager.initWithBuckets(mem, Nat16.fromNat(Nat64.toNat(BUCKET_SIZE_IN_PAGES)));
      let memory_0 = mem_mgr.get(0 : MemoryId);
      let memory_1 = mem_mgr.get(1 : MemoryId);

      assert(memory_0.grow(1) == 0);
      assert(memory_1.grow(1) == 0);

      let bytes = memory_0.read(0, Nat64.toNat(Constants.WASM_PAGE_SIZE) + 1);
    };

    func writingOutOfBoundsShouldTrap() {
      let mem = Memory.VecMemory();
      let mem_mgr = MemoryManager.initWithBuckets(mem, Nat16.fromNat(Nat64.toNat(BUCKET_SIZE_IN_PAGES)));
      let memory_0 = mem_mgr.get(0 : MemoryId);
      let memory_1 = mem_mgr.get(1 : MemoryId);

      assert(memory_0.grow(1) == 0);
      assert(memory_1.grow(1) == 0);

      let bytes = Array.freeze(Array.init<Nat8>(Nat64.toNat(Constants.WASM_PAGE_SIZE) + 1, 0));
      memory_0.write(0, bytes);
    };

    func readingZeroBytesFromEmptyMemoryShouldNotTrap() {
      let mem = Memory.VecMemory();
      let mem_mgr = MemoryManager.initWithBuckets(mem, Nat16.fromNat(Nat64.toNat(BUCKET_SIZE_IN_PAGES)));
      let memory_0 = mem_mgr.get(0 : MemoryId);

      assert(memory_0.size() == 0);
      let bytes = memory_0.read(0, 0);
    };

    func writingZeroBytesToEmptyMemoryShouldNotTrap() {
      let mem = Memory.VecMemory();
      let mem_mgr = MemoryManager.initWithBuckets(mem, Nat16.fromNat(Nat64.toNat(BUCKET_SIZE_IN_PAGES)));
      let memory_0 = mem_mgr.get(0 : MemoryId);

      assert(memory_0.size() == 0);
      memory_0.write(0, []);
    };

    public func getSuite() : Suite.Suite {
      canGetMemory();
      canAllocateAndUseMemory();
      canAllocateAndUseMultipleMemories();
      canBeReinitializedFromMemory();
      growingSameMemoryMultipleTimesDoesntIncreaseUnderlyingAllocation();
      doesNotGrowMemoryUnnecessarily();
      growingBeyondCapacityFails();
      canWriteAcrossBucketBoundaries();
      canWriteAcrossBucketBoundariesWithInterleavingMemories();
      //readingOutOfBoundsShouldTrap(); // @todo: succeed on trap
      //writingOutOfBoundsShouldTrap(); // @todo: succeed on trap
      readingZeroBytesFromEmptyMemoryShouldNotTrap();
      writingZeroBytesToEmptyMemoryShouldNotTrap();

      suite("Test memory manager module", []);
    };

  };

};