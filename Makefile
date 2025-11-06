-include .env

.PHONY: build install test

build:
	forge build

install:
	forge install

test:
	forge test -vvvv