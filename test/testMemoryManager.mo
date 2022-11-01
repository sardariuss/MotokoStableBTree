import MemoryManager "../src/memoryManager";
import VecMemory "../src/memory/vecMemory";
import Constants "../src/constants";

import Suite "mo:matchers/Suite";

import Iter "mo:base/Iter";
import Nat64 "mo:base/Nat64";
import Nat16 "mo:base/Nat16";
import Nat8 "mo:base/Nat8";
import Int "mo:base/Int";
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

  /// @todo: uncomment the tests on grow, or find a way to perform the same tests on current memory
  public class TestMemoryManager() = {

    func canGetMemory() {
      let mem_mgr = MemoryManager.init(VecMemory.VecMemory());
      let memory = mem_mgr.get(0 : MemoryId);
      assert(memory.size() == 0);
    };

    func canAllocateAndUseMemory() {
      let mem_mgr = MemoryManager.init(VecMemory.VecMemory());
      let memory = mem_mgr.get(0 : MemoryId);
      //assert(memory.grow(1) == 0);
      assert(memory.size() == 1);

      memory.write(0, [1, 2, 3]);

      let bytes = memory.read(0, 3);
      assert(bytes == [1, 2, 3]);

      assert(equal(mem_mgr.inner_.memory_buckets_.get(0 : MemoryId), [0 : BucketId], Nat16.equal));
    };

    func canAllocateAndUseMultipleMemories() {
      let mem = VecMemory.VecMemory();
      let mem_mgr = MemoryManager.init(mem);
      let memory_0 = mem_mgr.get(0 : MemoryId);
      let memory_1 = mem_mgr.get(1 : MemoryId);

      //assert(memory_0.grow(1) == 0);
      //assert(memory_1.grow(1) == 0);

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
      assert(mem.size() == 2 * MemoryManager.BUCKET_SIZE_IN_PAGES + 1);
    };

    func canBeReinitializedFromMemory() {
      let mem = VecMemory.VecMemory();
      var mem_mgr = MemoryManager.init(mem);
      var memory_0 = mem_mgr.get(0 : MemoryId);
      var memory_1 = mem_mgr.get(1 : MemoryId);

      //assert(memory_0.grow(1) == 0);
      //assert(memory_1.grow(1) == 0);

      memory_0.write(0, [1, 2, 3]);
      memory_1.write(0, [4, 5, 6]);

      mem_mgr := MemoryManager.init(mem);
      memory_0 := mem_mgr.get(0 : MemoryId);
      memory_1 := mem_mgr.get(1 : MemoryId);

      var bytes = memory_0.read(0, 3);
      assert(bytes == [1, 2, 3]);

      bytes := memory_1.read(0, 3);
      assert(bytes == [4, 5, 6]);
    };

    func growingSameMemoryMultipleTimesDoesntIncreaseUnderlyingAllocation() {
      let mem = VecMemory.VecMemory();
      let mem_mgr = MemoryManager.init(mem);
      let memory_0 = mem_mgr.get(0 : MemoryId);

      // Grow the memory by 1 page. This should increase the underlying allocation
      // by `BUCKET_SIZE_IN_PAGES` pages.
      //assert(memory_0.grow(1) == 0);
      assert(mem.size() == 1 + MemoryManager.BUCKET_SIZE_IN_PAGES);

      // Grow the memory again. This should NOT increase the underlying allocation.
      //assert(memory_0.grow(1) == 1);
      assert(memory_0.size() == 2);
      assert(mem.size() == 1 + MemoryManager.BUCKET_SIZE_IN_PAGES);

      // Grow the memory up to the BUCKET_SIZE_IN_PAGES. This should NOT increase the underlying
      // allocation.
      //assert(memory_0.grow(MemoryManager.BUCKET_SIZE_IN_PAGES - 2) == 2);
      assert(memory_0.size() == MemoryManager.BUCKET_SIZE_IN_PAGES);
      assert(mem.size() == 1 + MemoryManager.BUCKET_SIZE_IN_PAGES);

      // Grow the memory by one more page. This should increase the underlying allocation.
      //assert(memory_0.grow(1) == Int64.fromNat64(MemoryManager.BUCKET_SIZE_IN_PAGES));
      assert(memory_0.size() == MemoryManager.BUCKET_SIZE_IN_PAGES + 1);
      assert(mem.size() == 1 + 2 * MemoryManager.BUCKET_SIZE_IN_PAGES);
    };

    func doesNotGrowMemoryUnnecessarily() {
      let mem = VecMemory.VecMemory();
      let initial_size = MemoryManager.BUCKET_SIZE_IN_PAGES * 2;

      // Grow the memory manually before passing it into the memory manager.
      //mem.grow(initial_size);

      let mem_mgr = MemoryManager.init(mem);
      let memory_0 = mem_mgr.get(0 : MemoryId);

      // Grow the memory by 1 page.
      //assert(memory_0.grow(1) == 0);
      assert(mem.size() == initial_size);

      // Grow the memory by BUCKET_SIZE_IN_PAGES more pages, which will cause the underlying
      // allocation to increase.
      //assert(memory_0.grow(MemoryManager.BUCKET_SIZE_IN_PAGES) == 1);
      assert(mem.size() == 1 + MemoryManager.BUCKET_SIZE_IN_PAGES * 2);
    };

    func growingBeyondCapacityFails() {
      let MAX_MEMORY_IN_PAGES: Nat64 = MemoryManager.MAX_NUM_BUCKETS * MemoryManager.BUCKET_SIZE_IN_PAGES;

      let mem = VecMemory.VecMemory();
      let mem_mgr = MemoryManager.init(mem);
      let memory_0 = mem_mgr.get(0 : MemoryId);

      //assert(memory_0.grow(MAX_MEMORY_IN_PAGES + 1) == -1);

      // Try to grow the memory by MAX_MEMORY_IN_PAGES + 1.
      //assert(memory_0.grow(1) == 0); // should succeed
      //assert(memory_0.grow(MAX_MEMORY_IN_PAGES) == -1); // should fail.
    };

    func canWriteAcrossBucketBoundaries() {
      let mem = VecMemory.VecMemory();
      let mem_mgr = MemoryManager.init(mem);
      let memory_0 = mem_mgr.get(0 : MemoryId);

      //assert(memory_0.grow(MemoryManager.BUCKET_SIZE_IN_PAGES + 1) == 0);

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
      let mem = VecMemory.VecMemory();
      let mem_mgr = MemoryManager.init(mem);
      let memory_0 = mem_mgr.get(0 : MemoryId);
      let memory_1 = mem_mgr.get(1 : MemoryId);

      //assert(memory_0.grow(MemoryManager.BUCKET_SIZE_IN_PAGES) == 0);
      //assert(memory_1.grow(1) == 0);
      //assert(memory_0.grow(1) == Int64.fromNat64(MemoryManager.BUCKET_SIZE_IN_PAGES));

      memory_0.write(
        mem_mgr.inner_.bucketSizeInBytes() - 1,
        [1, 2, 3],
      );
      memory_1.write(0, [4, 5, 6]);

      var bytes = memory_0.read(Constants.WASM_PAGE_SIZE * MemoryManager.BUCKET_SIZE_IN_PAGES - 1, 3);
      assert(bytes == [1, 2, 3]);

      bytes := memory_1.read(0, 3);
      assert(bytes == [4, 5, 6]);
    };

    // @todo: should trap!
    func readingOutOfBoundsShouldPanic() {
      let mem = VecMemory.VecMemory();
      let mem_mgr = MemoryManager.init(mem);
      let memory_0 = mem_mgr.get(0 : MemoryId);
      let memory_1 = mem_mgr.get(1 : MemoryId);

      //assert(memory_0.grow(1) == 0);
      //assert(memory_1.grow(1) == 0);

      let bytes = memory_0.read(0, Nat64.toNat(Constants.WASM_PAGE_SIZE) + 1);
    };

    // @todo: should trap!
    func writingOutOfBoundsShouldPanic() {
      let mem = VecMemory.VecMemory();
      let mem_mgr = MemoryManager.init(mem);
      let memory_0 = mem_mgr.get(0 : MemoryId);
      let memory_1 = mem_mgr.get(1 : MemoryId);

      //assert(memory_0.grow(1) == 0);
      //assert(memory_1.grow(1) == 0);

      let bytes = Array.freeze(Array.init<Nat8>(Nat64.toNat(Constants.WASM_PAGE_SIZE) + 1, 0));
      memory_0.write(0, bytes);
    };

    func readingZeroBytesFromEmptyMemoryShouldNotPanic() {
      let mem = VecMemory.VecMemory();
      let mem_mgr = MemoryManager.init(mem);
      let memory_0 = mem_mgr.get(0 : MemoryId);

      assert(memory_0.size() == 0);
      let bytes = memory_0.read(0, 0);
    };

    func writingZeroBytesToEmptyMemoryShouldNotPanic() {
      let mem = VecMemory.VecMemory();
      let mem_mgr = MemoryManager.init(mem);
      let memory_0 = mem_mgr.get(0 : MemoryId);

      assert(memory_0.size() == 0);
      memory_0.write(0, []);
    };

    func writeAndReadRandomBytes() {
      let mem = VecMemory.VecMemory();
      let mem_mgr = MemoryManager.initWithBuckets(mem, 1); // very small bucket size.

      let max_num_memories = Nat8.toNat(MemoryManager.MAX_NUM_MEMORIES);
      let memories = Buffer.Buffer<MemoryManager.VirtualMemory>(max_num_memories);
      for (idx in Iter.range(0, max_num_memories - 1)){
        memories.add(mem_mgr.get(Nat8.fromNat(idx) : MemoryId));
      };

      for (num_memories in Iter.range(0, max_num_memories - 1)){
      };

      // @todo: use random module
  //    proptest!(|(
  //      num_memories in 0..255usize,
  //      data in proptest::collection::vec(0..u8::MAX, 0..2*WASM_PAGE_SIZE as usize),
  //      offset in 0..10*WASM_PAGE_SIZE
  //    )| {
  //      for memory in memories.iter().take(num_memories) {
  //        // Write a random blob into the memory, growing the memory as it needs to.
  //        write(memory, offset, &data);
  //
  //        // Verify the blob can be read back.
  //        let bytes = memory.read(offset, data.len());
  //        assert(bytes == data);
  //      };
  //    };);
    };

    public func getSuite() : Suite.Suite {

      // @todo: make tests work
      //canGetMemory();
      //canAllocateAndUseMemory();
      //canAllocateAndUseMultipleMemories();
      //canBeReinitializedFromMemory();
      //growingSameMemoryMultipleTimesDoesntIncreaseUnderlyingAllocation();
      //doesNotGrowMemoryUnnecessarily();
      //growingBeyondCapacityFails();
      //canWriteAcrossBucketBoundaries();
      //canWriteAcrossBucketBoundariesWithInterleavingMemories();
      //readingOutOfBoundsShouldPanic();
      //writingOutOfBoundsShouldPanic();
      //readingZeroBytesFromEmptyMemoryShouldNotPanic();
      //writingZeroBytesToEmptyMemoryShouldNotPanic();
      //writeAndReadRandomBytes();

      suite("Test memory manager module", []);

    };

  };

};