default:
	dfx stop
	dfx start --clean --background
	dfx deploy singleBTree
	npm install
	node testSingle.js
	dfx deploy multipleBTrees
	ic-repl testMultiple.sh