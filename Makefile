GO=go

COMPILE=$(GO) build
LDFLAGS="-s -w"
BUILD_FLAGS=-x -v -ldflags $(LDFLAGS)

GLIDE=glide
VENDOR_DIR=vendor

LINT=golint
LINT_FLAGS=-set_exit_status

EXE=./bin/marlowc
MAIN=$(wildcard ./marlowc/main.go)

GOVER=gover
GOVER_REPORT=coverage.txt

LIB_DIR=./marlow
SRC_DIR=./marlowc
EXAMPLE_DIR=./examples

CYCLO=gocyclo
CYCLO_FLAGS=-over 15

MISSPELL=misspell

LIB_SRC=$(wildcard $(LIB_DIR)/**/*.go $(LIB_DIR)/*.go)
GO_SRC=$(wildcard $(MAIN) $(SRC_DIR)/**/*.go $(SRC_DIR)/*.go)

LIBRARY_EXAMPLE_DIR=$(EXAMPLE_DIR)/library
LIBRARY_EXAMPLE_MODEL_DIR=$(LIBRARY_EXAMPLE_DIR)/models
LIBRARY_EXAMPLE_EXE=$(LIBRARY_EXAMPLE_DIR)/library
LIBRARY_EXAMPLE_MAIN=$(wildcard $(LIBRARY_EXAMPLE_DIR)/main.go)
LIBRARY_EXAMPLE_SRC=$(wildcard $(LIBRARY_EXAMPLE_DIR)/**/*.go)
LIBRARY_EXAMPLE_OBJS=$(patsubst %.go,%.marlow.go,$(EXAMPLE_SRC))

VET=$(GO) vet
VET_FLAGS=

MAX_TEST_CONCURRENCY=1

TEST_VERBOSITY=-v
TEST_FLAGS=-covermode=atomic $(TEST_VERBOSITY) -coverprofile={{.Dir}}/.coverprofile
TEST_LIST_FMT='{{if len .TestGoFiles}}"go test {{.ImportPath}} $(TEST_FLAGS)"{{end}}'

LIBRARY_COVERAGE_OUTPUT_DIR=./dist/coverage
LIBRARY_EXAMPLE_COVERAGE_REPORT=$(LIBRARY_COVERAGE_OUTPUT_DIR)/library.coverage.txt
LIBRARY_EXAMPLE_COVERAGE_DISTRIBUTABLE=$(LIBRARY_COVERAGE_OUTPUT_DIR)/library.coverage.html
LIBRARY_EXAMPLE_TEST_FLAGS=-covermode=atomic $(TEST_VERBOSITY) -coverprofile=$(LIBRARY_EXAMPLE_COVERAGE_REPORT)

all: $(EXE)

$(EXE): $(VENDOR_DIR) $(GO_SRC) $(LIB_SRC)
	$(COMPILE) $(BUILD_FLAGS) -o $(EXE) $(MAIN)

lint: $(GO_SRC)
	$(LINT) $(LINT_FLAGS) $(LIB_DIR)/...
	$(LINT) $(LINT_FLAGS) $(MAIN)

test: $(GO_SRC) $(VENDOR_DIR) $(INTERCHANGE_OBJ) lint
	$(VET) $(VET_FLAGS) $(SRC_DIR)
	$(VET) $(VET_FLAGS) $(LIB_DIR)
	$(VET) $(VET_FLAGS) $(MAIN)
	$(CYCLO) $(CYCLO_FLAGS) $(LIB_SRC)
	$(MISSPELL) -error $(LIB_SRC) $(MAIN)
	$(GO) list -f $(TEST_LIST_FMT) $(LIB_DIR)/... | xargs -L 1 sh -c
	$(GOVER) $(LIB_DIR) $(GOVER_REPORT)

test-example: $(LIBRARY_EXAMPLE_SRC)
	mkdir -p $(LIBRARY_COVERAGE_OUTPUT_DIR)
	$(GO) run $(MAIN) -input=$(LIBRARY_EXAMPLE_MODEL_DIR)
	$(GO) test $(LIBRARY_EXAMPLE_TEST_FLAGS) -p=$(MAX_TEST_CONCURRENCY) $(LIBRARY_EXAMPLE_MODEL_DIR)
	$(GO) tool cover -html $(LIBRARY_EXAMPLE_COVERAGE_REPORT) -o $(LIBRARY_EXAMPLE_COVERAGE_DISTRIBUTABLE)
	$(VET) $(VET_FLAGS) $(LIBRARY_EXAMPLE_MODEL_DIR)

$(VENDOR_DIR):
	$(GO) get -v -u github.com/modocache/gover
	$(GO) get -v -u github.com/client9/misspell/cmd/misspell
	$(GO) get -v -u github.com/fzipp/gocyclo
	$(GO) get -v -u github.com/Masterminds/glide
	$(GO) get -v -u github.com/golang/lint/golint
	$(GLIDE) install

example: $(LIBRARY_EXAMPLE_SRC) $(LIBRARY_EXAMPLE_MAIN)
	$(GO) run $(MAIN) -input=$(LIBRARY_EXAMPLE_MODEL_DIR)
	$(GO) get -v github.com/mattn/go-sqlite3
	$(GO) install -v -x github.com/mattn/go-sqlite3
	$(COMPILE) $(BUILD_FLAGS) -o $(LIBRARY_EXAMPLE_EXE) $(LIBRARY_EXAMPLE_MAIN)

clean-example:
	rm -rf $(LIBRARY_EXAMPLE_OBJS)
	rm -rf $(LIBRARY_EXAMPLE_EXE)
	rm -rf $(LIBRARY_COVERAGE_OUTPUT_DIR)

clean: clean-example
	rm -rf $(COVERAGE_REPORT)
	rm -rf $(LINT_RESULT)
	rm -rf $(VENDOR_DIR)
	rm -rf $(EXE)
