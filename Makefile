.PHONY: build clean test package package-deb ui api statics requirements ui-requirements serve update-vendor internal/statics internal/migrations
PKGS := $(shell go list ./... | grep -v /vendor |grep -v lora-app-server/api | grep -v /migrations | grep -v /static | grep -v /ui)
VERSION := $(shell git describe --always)
GOOS ?= linux
GOARCH ?= amd64

build: ui/build internal/statics internal/migrations 
	@echo "Compiling source for $(GOOS) $(GOARCH)"
	@mkdir -p build
	@GOOS=$(GOOS) GOARCH=$(GOARCH) go build -ldflags "-X main.version=$(VERSION)" -o build/lora-app-server$(BINEXT) cmd/lora-app-server/main.go

clean:
	@echo "Cleaning up workspace"
	@rm -rf build dist internal/migrations internal/static ui/build static/static
	@rm -f static/index.html

test: internal/statics internal/migrations
	@echo "Running tests"
	@for pkg in $(PKGS) ; do \
		golint $$pkg ; \
	done
	@go vet $(PKGS)
	@go test -p 1 -v $(PKGS)

package: build
	@echo "Creating package for $(GOOS) $(GOARCH)"
	@rm -rf build dist/tar/$(VERSION)
	@mkdir -p dist/tar/$(VERSION)
	@cp build/* dist/tar/$(VERSION)
	@cd dist/tar/$(VERSION) && tar -pczf ../lora_app_server_$(VERSION)_$(GOOS)_$(GOARCH).tar.gz .
	@rm -rf dist/tar/$(VERSION)

package-deb:
	@cd packaging && TARGET=deb ./package.sh

ui/build:
	@echo "Building ui"
	@cd ui && npm run build
	@mv ui/build/* static

api:
	@echo "Generating API code from .proto files"
	@go generate api/api.go

internal/statics internal/migrations:
	@echo "Generating static files"
	@go generate cmd/lora-app-server/main.go

# shortcuts for development

requirements:
	@echo "Installing development tools"
	@go get -u github.com/golang/lint/golint
	@go get -u github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway
	@go get -u github.com/grpc-ecosystem/grpc-gateway/protoc-gen-swagger
	@go get -u github.com/golang/protobuf/protoc-gen-go
	@go get -u github.com/elazarl/go-bindata-assetfs/...
	@go get -u github.com/jteeuwen/go-bindata/...

ui-requirements:
	@echo "Installing UI requirements"
	@cd ui && npm install

serve: build
	@echo "Starting Lora App Server"
	./build/lora-app-server

update-vendor:
	@echo "Updating vendored packages"
	@govendor update +external

run-compose-test:
	docker-compose run --rm appserver make test
