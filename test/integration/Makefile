default:
	dfx stop
	dfx start --clean --background
	dfx deploy
	dfx generate
	npm install
	ic-repl testSingle.sh
	node testSingle.js
	ic-repl testMultiple.sh