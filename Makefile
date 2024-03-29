export IDRIS2 ?= idris2

lib_pkg = tls.ipkg

.PHONY: all
all: lib

.PHONY: clean-install
clean-install: clean install

.PHONY: clean-install-with-src
clean-install-with-src: clean install-with-src

.PHONY: lib
lib:
	${IDRIS2} --build ${lib_pkg}
	${MAKE} -C c

.PHONY: install
install:
	${IDRIS2} --install ${lib_pkg}
	${MAKE} -C c
	${MAKE} -C c install

.PHONY: install-with-src
install-with-src:
	${IDRIS2} --install-with-src ${lib_pkg}

.PHONY: clean
clean:
	${IDRIS2} --clean ${lib_pkg}
	${RM} -r build

.PHONY: test
test:
	${MAKE} -C tests/ test IDRIS2?=${IDRIS2}
