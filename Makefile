# This Makefile ensures that the build is made out of source in a
# subdirectory called 'build' If it doesn't exist, it is created.
#
# This Makefile also contains delegation of the most common make commands
#
# If you have cmake installed you should be able to do:
#
#	make
#	make test
#	make install
#	make package
#
# That should build Cgreen in the build directory, run some tests,
# install it locally and generate a distributable package.

all: build/Makefile
	cd build; make

.PHONY:debug
debug: build
	cd build; cmake -DCMAKE_BUILD_TYPE:string=Debug ..; make

32bit: build
	-rm -rf build; mkdir build; cd build; cmake -DCMAKE_C_FLAGS="-m32" -DCMAKE_CXX_FLAGS="-m32" ..; make

.PHONY:test
test: build/Makefile
	cd build; make check

.PHONY:clean
clean: build/Makefile
	cd build; make clean

.PHONY:package
package: build/Makefile
	cd build; make package

.PHONY:install
install:
	cd build; make install


# This is kind of a hack to get a quicker and clearer feedback when
# developing Cgreen by allowing 'make unit'. Must be updated when new
# test libraries or output comparisons are added.

# Find out if 'uname -o' works, if it does - use it, otherwise use 'uname -s'
UNAMEOEXISTS=$(shell uname -o 1>&2 2>/dev/null; echo $$?)
ifeq ($(UNAMEOEXISTS),0)
  OS=$(shell uname -o)
else
  OS=$(shell uname -s)
endif

# Set prefix and suffix for shared libraries depending on platform
ifeq ($(OS),Darwin)
	PREFIX=lib
	SUFFIX=.dylib
else ifeq ($(OS),Cygwin)
	PREFIX=cyg
	SUFFIX=.dll
else
	PREFIX=lib
	SUFFIX=.so
endif

DIFF_TOOL=../../tools/cgreen_runner_output_diff
XML_DIFF_TOOL=../../tools/cgreen_xml_output_diff
DIFF_TOOL_ARGUMENTS = $(1)_tests \
	../../tests \
	$(1)_tests.expected

unit: build-it
	# Ensure the dynamic libraries can be found even on DLL-platforms without altering
	# user process PATH
	export PATH=$$PWD/build/src:"$$PATH" ; \
	SOURCEDIR=$$PWD/tests/ ; \
	cd build ; \
	tools/cgreen-runner -c `find tests -name $(PREFIX)cgreen_c_tests$(SUFFIX)` ; \
	r=$$((r + $$?)) ; \
	tools/cgreen-runner -c `find tests -name $(PREFIX)cgreen_cpp_tests$(SUFFIX)` ; \
	r=$$((r + $$?)) ; \
	tools/cgreen-runner -c `find tools/tests -name $(PREFIX)cgreen_runner_tests$(SUFFIX)` ; \
	r=$$((r + $$?)) ; \
	cd tests ; \
	$(XML_DIFF_TOOL) $(call DIFF_TOOL_ARGUMENTS,xml_output) ; \
	r=$$((r + $$?)) ; \
	$(DIFF_TOOL) $(call DIFF_TOOL_ARGUMENTS,assertion_messages) ; \
	r=$$((r + $$?)) ; \
	$(DIFF_TOOL) $(call DIFF_TOOL_ARGUMENTS,mock_messages) ; \
	r=$$((r + $$?)) ; \
	$(DIFF_TOOL) $(call DIFF_TOOL_ARGUMENTS,constraint_messages) ; \
	r=$$((r + $$?)) ; \
	$(DIFF_TOOL) $(call DIFF_TOOL_ARGUMENTS,custom_constraint_messages) ; \
	r=$$((r + $$?)) ; \
	$(DIFF_TOOL) $(call DIFF_TOOL_ARGUMENTS,ignore_messages) ; \
	r=$$((r + $$?)) ; \
	CGREEN_PER_TEST_TIMEOUT=1 $(DIFF_TOOL) $(call DIFF_TOOL_ARGUMENTS,failure_messages) ; \
	r=$$((r + $$?)) ; \
	exit $$r

.PHONY: doc
doc: build
	cd build; cmake -DCGREEN_WITH_HTML_DOCS:bool=TRUE ..; make; cmake -DCGREEN_WITH_HTML_DOCS:bool=False ..; echo open $(PWD)/build/doc/cgreen-guide-en.html

pdf: build
	cd build; cmake -DCGREEN_WITH_PDF_DOCS:bool=TRUE ..; make; cmake -DCGREEN_WITH_PDF_DOCS:bool=False ..; echo open $(PWD)/build/doc/cgreen-guide-en.pdf

chunked: doc
	asciidoctor-chunker build/doc/cgreen-guide-en.html -o docs
	echo open $(PWD)/docs/index.html

.PHONY:valgrind
valgrind: build-it
	> valgrind.log
	for lib in `ls build/tests/$(PREFIX)*_tests$(SUFFIX)` ; \
	do \
		LD_LIBRARY_PATH=build/src valgrind --leak-check=full build/tools/cgreen-runner $$lib >> valgrind.log 2>&1 ; \
	done
	grep " lost:" valgrind.log | grep -v " 0 bytes" | wc -l



############# Internal

build-it: build/Makefile
	make -C build

build:
	mkdir build

build/Makefile: build
	cd build; cmake $(ARCHS) ..

.SILENT:
