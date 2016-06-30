CABAL_VER_NUM := $(shell cabal --numeric-version)
CABAL_VER_MAJOR := $(shell echo $(CABAL_VER_NUM) | cut -f1 -d.)
CABAL_VER_MINOR := $(shell echo $(CABAL_VER_NUM) | cut -f2 -d.)
CABAL_GT_1_22 := $(shell [ $(CABAL_VER_MAJOR) -gt 1 -o \( $(CABAL_VER_MAJOR) -eq 1 -a $(CABAL_VER_MINOR) -ge 22 \) ] && echo true)

ifeq ($(CABAL_GT_1_22),true)
COVERAGE	= --enable-coverage
INIT_SANDBOX	= cabal sandbox init
IGNORE_SANDBOX	= --ignore-sandbox
REQUIRE_SANDBOX	= --require-sandbox
else
COVERAGE	= --enable-library-coverage
INIT_SANDBOX	= @echo "No sandbox support"
IGNORE_SANDBOX	=
REQUIRE_SANDBOX	=
endif

SOURCES	:= $(shell find src test-server test-tox -name "*.*hs")

ifneq ($(wildcard ../tox-spec/pandoc.mk),)
DOCS	:= ../tox-spec/spec.md
include ../tox-spec/pandoc.mk
endif


CABAL_INSTALL =								\
	cabal $(REQUIRE_SANDBOX) install				\
		--enable-tests						\
		--extra-include-dirs=$(HOME)/.cabal/extra-dist/include	\
		--extra-lib-dirs=$(HOME)/.cabal/extra-dist/lib		\
		aeson-0.11.1.4						\
		msgpack-haskell/msgpack/msgpack.cabal			\
		msgpack-haskell/msgpack-rpc/msgpack-rpc.cabal		\
		msgpack-haskell/msgpack-aeson/msgpack-aeson.cabal


all: check $(DOCS)


check: .build.stamp
	dist/build/test-server/test-server & echo $$! > .server.pid
	cabal $(REQUIRE_SANDBOX) test | grep -v '^Writing: '
	kill `cat .server.pid`
	rm .server.pid

repl: .build.stamp
	cabal $(REQUIRE_SANDBOX) repl

clean:
	cabal $(REQUIRE_SANDBOX) clean
	-test -f .server.pid && kill `cat .server.pid`
	rm -f $(wildcard .*.stamp) .server.pid


build: .build.stamp
.build.stamp: $(SOURCES) .configure.stamp .format.stamp .lint.stamp
	rm -f $(wildcard *.tix)
	cabal $(REQUIRE_SANDBOX) build
	@touch $@

configure: .configure.stamp
.configure.stamp: .libsodium.stamp .sandbox.stamp
	happy -v | grep "1.19" || cabal $(IGNORE_SANDBOX) install haskell-src-exts happy
	test -d msgpack-haskell || git clone https://github.com/iphydf/msgpack-haskell
	$(CABAL_INSTALL) --only-dependencies hstox.cabal
	$(CABAL_INSTALL)
	rm -rf msgpack-haskell
	cabal $(REQUIRE_SANDBOX) configure --enable-tests $(COVERAGE)
	cabal $(IGNORE_SANDBOX) install stylish-haskell hlint
	@touch $@

.sandbox.stamp:
	cabal $(IGNORE_SANDBOX) update
	$(INIT_SANDBOX)
	@touch $@

doc: $(DOCS)
../tox-spec/spec.md: src/Network/Tox.lhs $(shell find src -name "*.lhs") ../tox-spec/pandoc.mk .pandoc.stamp
	echo '% The Tox Reference' > $@
	echo '' >> $@
	pandoc $< $(PANDOC_ARGS)							\
		-f latex+lhs								\
		-t $(FORMAT)								\
		| perl -pe 'BEGIN{undef $$/} s/\`\`\` sourceCode\n.*?\`\`\`\n\n//sg'	\
		>> $@
	pandoc $(PANDOC_ARGS) -f $(FORMAT) -t $(FORMAT) $@ -o $@
	if which mdl; then $(MAKE) -C ../tox-spec check; fi
	if test -d ../toktok.github.io; then $(MAKE) -C ../toktok.github.io push; fi

pandoc: .pandoc.stamp
.pandoc.stamp:
	cabal $(IGNORE_SANDBOX) install pandoc
	@touch $@

libsodium: .libsodium.stamp
.libsodium.stamp: tools/install-libsodium
	$<
	@touch $@

format: .format.stamp
.format.stamp: $(SOURCES) .configure.stamp
	tools/format-haskell -i src
	@touch $@

lint: .lint.stamp
.lint.stamp: $(SOURCES) .configure.stamp
	hlint --cross src
	@touch $@
