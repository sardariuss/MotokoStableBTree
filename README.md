# MotokoStableBTree
https://forum.dfinity.org/t/icdevs-org-bounty-24-stablebtree-mokoko-up-to-10k/14867

## Todo
 - Verify the Address and Bytes types from the rust implementation do nothing else than trap on overflow
 - Shall the simple types (like Address, Bytes, BucketId) have their separate modules with equal operators etc.?
 - Think about the consequences of not having a template argument on <M: memory> on btreemap and memory manager
 - Can we use more than one MemoryManager with no side effets ?
 - Generation of documentation fails with Fatal error: exception (Invalid_argument "index out of bounds")
 - Make the equivalent of rust test writeAndReadRandomBytes in JS
 - Test the memory manager with stable memory
 - Find a way to make a test succeed on trap
 - use and object instead of record for stable memory?
 - check private/public functions, maybe remove getters/setter and expost members directly