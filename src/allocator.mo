import Types "types";
import AlignedStruct "alignedStruct";

import Blob "mo:base/Blob";
import Text "mo:base/Text";
import Nat64 "mo:base/Nat64";
import Debug "mo:base/Debug";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";

module {

  // For convenience: from types module
  type Address = Types.Address;
  type Bytes = Types.Bytes;
  type Variant = Types.Variant;
  type AlignedStruct = Types.AlignedStruct;
  type AlignedStructDefinition = Types.AlignedStructDefinition;
  type Memory<M> = Types.Memory<M>;

  let ALLOCATOR_LAYOUT_VERSION: Nat8 = 1;
  let CHUNK_LAYOUT_VERSION: Nat8 = 1;

  let ALLOCATOR_MAGIC = "BTA";
  let CHUNK_MAGIC = "CHK";

  let NULL : Nat64 = 0;

  /// A free list constant-size chunk allocator.
  ///
  /// The allocator allocates chunks of size `allocation_size` from the given `memory`.
  ///
  /// # Properties
  ///
  /// * The allocator tries to minimize its memory footprint, growing the memory in
  ///   size only when all the available memory is allocated.
  ///
  /// * The allocator makes no assumptions on the size of the memory and will
  ///   continue growing so long as the provided `memory` allows it.
  ///
  /// The allocator divides the memory into "chunks" of equal size. Each chunk contains:
  ///     a) A `ChunkHeader` with metadata about the chunk.
  ///     b) A blob of length `allocation_size` that can be used freely by the user.
  ///
  /// # Assumptions:
  ///
  /// * The given memory is not being used by any other data structure.
  // @diff: no template type memory
  public type Allocator<M> = {
    // The address in memory where the `AllocatorHeader` is stored.
    header_addr: Address;

    // The size of the chunk to allocate in bytes.
    allocation_size: Bytes;

    // The number of chunks currently allocated.
    num_allocated_chunks: Nat64;

    // A linked list of unallocated chunks.
    free_list_head: Address;

    memory: Memory<M>;
  };

  type AllocatorHeader = {
    magic: Blob; // 3 bytes
    version: Nat8;
    // Empty space to memory-align the following fields.
    _alignment: Blob; // 3 bytes
    allocation_size: Bytes;
    num_allocated_chunks: Nat64;
    free_list_head: Address;
    // Additional space reserved to add new fields without breaking backward-compatibility.
    _buffer: Blob; // 16 bytes
  };

  let ALLOCATOR_HEADER_STRUCT_DEFINITION : AlignedStructDefinition = [
    #Blob(3),   // magic
    #Nat8,      // version
    #Blob(3),   // _alignment
    #Nat64,     // allocation_size
    #Nat64,     // num_allocated_chunks
    #Nat64,     // free_list_head
    #Blob(16),  // _buffer
  ];

  func sizeAllocatorHeader() : Nat64 {
    AlignedStruct.sizeDefinition(ALLOCATOR_HEADER_STRUCT_DEFINITION);
  };

  /// Initialize an allocator and store it in address `addr`.
  ///
  /// The allocator assumes that all memory from `addr` onwards is free.
  ///
  /// When initialized, the allocator has the following memory layout:
  ///
  /// [   AllocatorHeader       | ChunkHeader ]
  ///      ..   free_list_head  ↑      next
  ///                |__________|       |____ NULL
  ///
  public func initAllocator<M>(memory: Memory<M>, addr: Address, allocation_size: Bytes) : Allocator<M> {
    let free_list_head = addr + sizeAllocatorHeader();

    // Create the initial memory chunk and save it directly after the allocator's header.
    let chunk_header = initChunkHeader();
    let updated_memory = saveChunkHeader(chunk_header, free_list_head, memory);

    let allocator = {
      header_addr = addr;
      allocation_size;
      num_allocated_chunks: Nat64 = 0;
      free_list_head;
      memory = updated_memory;
    };

    saveAllocator(allocator);
  };

  /// Load an allocator from memory at the given `addr`.
  public func loadAllocator<M>(memory: Memory<M>, addr: Address) : Allocator<M> {
    let header = structToAllocatorHeader(memory.load(memory, addr, ALLOCATOR_HEADER_STRUCT_DEFINITION));
    if (header.magic != Text.encodeUtf8(ALLOCATOR_MAGIC)) { Debug.trap("Bad magic."); };
    if (header.version != ALLOCATOR_LAYOUT_VERSION) { Debug.trap("Unsupported version."); };
    
    {
      header_addr = addr;
      allocation_size = header.allocation_size;
      num_allocated_chunks = header.num_allocated_chunks;
      free_list_head = header.free_list_head;
      memory = memory;
    };
  };

  /// Allocates a new chunk from memory with size `allocation_size`.
  ///
  /// Internally, there are two cases:
  ///
  /// 1) The list of free chunks (`free_list_head`) has only one element.
  ///    This case happens when we initialize a new allocator, or when
  ///    all of the previously allocated chunks are still in use.
  ///
  ///    Example memory layout:
  ///
  ///    [   AllocatorHeader       | ChunkHeader ]
  ///         ..   free_list_head  ↑      next
  ///                   |__________↑       |____ NULL
  ///
  ///    In this case, the chunk in the free list is allocated to the user
  ///    and a new `ChunkHeader` is appended to the allocator's memory,
  ///    growing the memory if necessary.
  ///
  ///    [   AllocatorHeader       | ChunkHeader | ... | ChunkHeader2 ]
  ///         ..   free_list_head      (allocated)     ↑      next
  ///                   |______________________________↑       |____ NULL
  ///
  /// 2) The list of free chunks (`free_list_head`) has more than one element.
  ///
  ///    Example memory layout:
  ///
  ///    [   AllocatorHeader       | ChunkHeader1 | ... | ChunkHeader2 ]
  ///         ..   free_list_head  ↑       next         ↑       next
  ///                   |__________↑        |___________↑         |____ NULL
  ///
  ///    In this case, the first chunk in the free list is allocated to the
  ///    user, and the head of the list is updated to point to the next free
  ///    block.
  ///
  ///    [   AllocatorHeader       | ChunkHeader1 | ... | ChunkHeader2 ]
  ///         ..   free_list_head      (allocated)      ↑       next
  ///                   |_______________________________↑         |____ NULL
  ///
  public func allocate<M>(allocator: Allocator<M>) : (Allocator<M>, Address) {
    // Get the next available chunk.
    let chunk_addr = allocator.free_list_head;
    let chunk = loadChunkHeader(chunk_addr, allocator.memory);

    // The available chunk must not be allocated.
    if (chunk.allocated) { Debug.trap("Attempting to allocate an already allocated chunk."); };

    // Allocate the chunk.
    let updated_chunk = {
      magic = chunk.magic;
      version = chunk.version;
      allocated = true;
      _alignment = chunk._alignment;
      next = chunk.next;
    };
    var updated_memory = saveChunkHeader(updated_chunk, chunk_addr, allocator.memory);

    // Update the head of the free list.
    var free_list_head = allocator.free_list_head;
    if (chunk.next != NULL) {
      // The next chunk becomes the new head of the list.
      free_list_head := chunk.next;
    } else {
      // There is no next chunk. Shift everything by chunk size.
      free_list_head += chunkSize(allocator);
      // Write new chunk to that location.
      updated_memory := saveChunkHeader(initChunkHeader(), free_list_head, allocator.memory);
    };

    let updated_allocator = {
      header_addr = allocator.header_addr;
      allocation_size = allocator.allocation_size;
      num_allocated_chunks = allocator.num_allocated_chunks + 1;
      free_list_head = free_list_head;
      memory = updated_memory;
    };

    // Return updated allocator and the chunk's address offset by the chunk's header.
    (saveAllocator(updated_allocator), chunk_addr + sizeChunkHeader());
  };

  /// Deallocates a previously allocated chunk.
  public func deallocate<M>(allocator: Allocator<M>, address: Address) : Allocator<M> {
    let chunk_addr = address - sizeChunkHeader();
    let chunk = loadChunkHeader(chunk_addr, allocator.memory);

    // The available chunk must be allocated.
    if (not chunk.allocated) { Debug.trap("Attempting to deallocate a chunk that is not allocated."); };

    // Deallocate the chunk.
    let updated_chunk = {
      magic = chunk.magic;
      version = chunk.version;
      allocated = false;
      _alignment = chunk._alignment;
      next = allocator.free_list_head;
    };
    let updated_memory = saveChunkHeader(updated_chunk, chunk_addr, allocator.memory);

    // Update the head of the free list.
    let updated_allocator = {
      header_addr = allocator.header_addr;
      allocation_size = allocator.allocation_size;
      num_allocated_chunks = allocator.num_allocated_chunks - 1;
      free_list_head = chunk_addr;
      memory = updated_memory;
    };
    
    // Return the updated allocator
    saveAllocator(updated_allocator);
  };

  /// Saves the allocator to memory.
  public func saveAllocator<M>(allocator: Allocator<M>) : Allocator<M> {
    {
      header_addr = allocator.header_addr;
      allocation_size = allocator.allocation_size;
      num_allocated_chunks = allocator.num_allocated_chunks - 1;
      free_list_head = allocator.free_list_head;
      memory = allocator.memory.store(allocator.memory, allocator.header_addr, allocatorHeaderToAlignedStruct(getHeader(allocator)));
    };
  };

  // The full size of a chunk, which is the size of the header + the `allocation_size` that's
  // available to the user.
  public func chunkSize<M>(allocator: Allocator<M>) : Bytes {
    allocator.allocation_size + sizeChunkHeader();
  };

  func getHeader<M>(allocator: Allocator<M>) : AllocatorHeader{
    {
      magic = Text.encodeUtf8(ALLOCATOR_MAGIC);
      version = ALLOCATOR_LAYOUT_VERSION;
      _alignment = Blob.fromArray([0, 0, 0, 0]);
      allocation_size = allocator.allocation_size;
      num_allocated_chunks = allocator.num_allocated_chunks;
      free_list_head = allocator.free_list_head;
      _buffer = Blob.fromArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
    };
  };

  func allocatorHeaderToAlignedStruct(allocator_header: AllocatorHeader) : AlignedStruct {
    var buffer = Buffer.Buffer<Variant>(0);
    buffer.add(#Blob(allocator_header.magic));
    buffer.add(#Nat8(allocator_header.version));
    buffer.add(#Blob(allocator_header._alignment));
    buffer.add(#Nat64(allocator_header.allocation_size));
    buffer.add(#Nat64(allocator_header.num_allocated_chunks));
    buffer.add(#Nat64(allocator_header.free_list_head));
    buffer.add(#Blob(allocator_header._buffer));
    buffer.toArray();
  };

  func structToAllocatorHeader(struct: AlignedStruct) : AllocatorHeader {
    {
      magic =                switch(struct[0]) { case(#Blob(value))  { value; }; case(_) { Debug.trap("Unexpected variant type."); }; };
      version =              switch(struct[1]) { case(#Nat8(value))  { value; }; case(_) { Debug.trap("Unexpected variant type."); }; };
      _alignment =           switch(struct[2]) { case(#Blob(value))  { value; }; case(_) { Debug.trap("Unexpected variant type."); }; };
      allocation_size =      switch(struct[3]) { case(#Nat64(value)) { value; }; case(_) { Debug.trap("Unexpected variant type."); }; };
      num_allocated_chunks = switch(struct[4]) { case(#Nat64(value)) { value; }; case(_) { Debug.trap("Unexpected variant type."); }; };
      free_list_head =       switch(struct[5]) { case(#Nat64(value)) { value; }; case(_) { Debug.trap("Unexpected variant type."); }; };
      _buffer =              switch(struct[6]) { case(#Blob(value))  { value; }; case(_) { Debug.trap("Unexpected variant type."); }; };
    };
  };

  type ChunkHeader = {
    magic: Blob; // 3 bytes
    version: Nat8;
    allocated: Bool;
    // Empty space to memory-align the following fields.
    _alignment: Blob; // 3 bytes
    next: Address;
  };

  let CHUNK_HEADER_STRUCT_DEFINITION : AlignedStructDefinition = [
    #Blob(3), // magic
    #Nat8,    // version
    #Nat8,    // allocated
    #Blob(3), // _alignment
    #Nat64,   // next
  ];

  // Initializes an unallocated chunk that doesn't point to another chunk.
  func initChunkHeader() : ChunkHeader {
    {
      magic = Text.encodeUtf8(CHUNK_MAGIC);
      version = CHUNK_LAYOUT_VERSION;
      allocated = false;
      _alignment = Blob.fromArray([0, 0, 0]);
      next = NULL;
    };
  };

  func saveChunkHeader<M>(chunk_header: ChunkHeader, address: Address, memory: Memory<M>) : Memory<M> {
    memory.store(memory, address, chunkHeaderToAlignedStruct(chunk_header));
  };

  func loadChunkHeader<M>(address: Address, memory: Memory<M>) : ChunkHeader {
    let header = structToChunkHeader(memory.load(memory, address, CHUNK_HEADER_STRUCT_DEFINITION));
    if (header.magic != Text.encodeUtf8(CHUNK_MAGIC)) { Debug.trap("Bad magic."); };
    if (header.version != CHUNK_LAYOUT_VERSION) { Debug.trap("Unsupported version."); };
    
    header;
  };

  func sizeChunkHeader() : Nat64 {
    AlignedStruct.sizeDefinition(CHUNK_HEADER_STRUCT_DEFINITION);
  };

  func chunkHeaderToAlignedStruct(chunk_header: ChunkHeader) : AlignedStruct {
    var buffer = Buffer.Buffer<Variant>(0);
    // Convert bool to nat8
    var allocated_nat8 : Nat8 = 0;
    if (chunk_header.allocated) { allocated_nat8 := 1; };
    buffer.add(#Blob(chunk_header.magic));
    buffer.add(#Nat8(chunk_header.version));
    buffer.add(#Nat8(allocated_nat8));
    buffer.add(#Blob(chunk_header._alignment));
    buffer.add(#Nat64(chunk_header.next));
    // Return array
    buffer.toArray();
  };

  func structToChunkHeader(struct: AlignedStruct) : ChunkHeader {
    {
      magic      = switch(struct[0]){ case(#Blob(value))  { value; };      case(_) { Debug.trap("Unexpected variant type."); }; };
      version    = switch(struct[1]){ case(#Nat8(value))  { value; };      case(_) { Debug.trap("Unexpected variant type."); }; };
      allocated  = switch(struct[2]){ case(#Nat8(value))  { value == 1; }; case(_) { Debug.trap("Unexpected variant type."); }; };
      _alignment = switch(struct[3]){ case(#Blob(value))  { value; };      case(_) { Debug.trap("Unexpected variant type."); }; };
      next       = switch(struct[4]){ case(#Nat64(value)) { value; };      case(_) { Debug.trap("Unexpected variant type."); }; };
    };
  };

};