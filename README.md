# MotokoStableBTree
https://forum.dfinity.org/t/icdevs-org-bounty-24-stablebtree-mokoko-up-to-10k/14867

## Usage

See singleBTree.mo and multipleBTrees.mo. U

## Limitations
 - The MemoryManager seems to significantly slow down the execution of the BTree functions.
 - At the moment there is no way to test that a function successfully traps, so these tests are commented out.
 - The generation of documentation fails with Fatal error: exception (Invalid_argument "index out of bounds").

## Todo
 - verify endianess
 - Make the equivalent of rust test writeAndReadRandomBytes in JS
 - Make a wrapper