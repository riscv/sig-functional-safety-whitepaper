# Makefile for RISC-V Doc Template
#
# This work is licensed under the Creative Commons Attribution-ShareAlike 4.0
# International License. To view a copy of this license, visit
# http://creativecommons.org/licenses/by-sa/4.0/ or send a letter to
# Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
#
# SPDX-License-Identifier: CC-BY-SA-4.0
#
# Description:
#
# This Makefile is designed to automate the process of building and packaging
# the Doc Template for RISC-V Extensions.

DOCS := \
	fusa-whitepaper.adoc

DATE ?= $(shell date +%Y-%m-%d)
VERSION ?= v0.0.0
# Leaving the REVMARK unset will put the document in draft state and the
# background of the document will have a "DRAFT" image.
# By default a revision mark is added to the title page along the document
# version and the date.
# To avoid the revision mark to appear, for example for a final release, launch
# the Makefile with `NOREVMARK=1`. E.g.:
# ```NOREVMARK=1 make```
NOREVMARK ?=
DEFAULT_REVMARK := \
  This document is under development. Expect potential changes.
# The default revision mark is the string defined by DEFAULT_REVMARK.
# To use a different revision mark string set the `REVMARK` option when
# launching the Makefile. E.g.:
# ```REVMARK="Release for review"```
REVMARK ?=
# By default a "Draft" watermark is added to each page.
# To remove it launch the Makefile with `NODRAFTWATERMARK=1`. E.g.:
# ```NODRAFTWATERMARK=1 make```
NODRAFTWATERMARK ?=
# Enable/disable to build a version of the document with the old version
# of the recommendations section including gaps
# Default: disabled (0)
RECOMMENDATIONS_OLD ?= 0
# Enable/disable to build a version of the document with the new version
# of the recommendations section
# Default: enabled (1)
RECOMMENDATIONS_NEW ?= 1

DOCKER_IMG := riscvintl/riscv-docs-base-container-image:latest
ifneq ($(SKIP_DOCKER),true)
  DOCKER_IS_PODMAN = \
    $(shell ! docker -v 2>&1 | grep podman >/dev/null ; echo $$?)
  ifeq "$(DOCKER_IS_PODMAN)" "1"
    DOCKER_VOL_SUFFIX = :z
  endif

  DOCKER_CMD := \
    docker run --rm \
      -u `id -u`:`id -g` \
      -v ${PWD}:/build${DOCKER_VOL_SUFFIX} \
      -w /build \
      ${DOCKER_IMG} \
      /bin/sh -c
  DOCKER_QUOTE := "
endif

SRC_DIR := src
BUILD_DIR := build

DOCS_PDF := $(DOCS:%.adoc=%.pdf)
DOCS_HTML := $(DOCS:%.adoc=%.html)

XTRA_ADOC_OPTS :=
ASCIIDOCTOR_PDF := asciidoctor-pdf
ASCIIDOCTOR_HTML := asciidoctor
OPTIONS := --trace \
  -a compress \
  -a mathematical-format=svg \
  -a revnumber=${VERSION} \
  -a revdate=${DATE} \
  -a imagesoutdir=${BUILD_DIR}/images \
  -a pdf-fontsdir=docs-resources/fonts \
  -a pdf-theme=src/wp-theme.yml \
  $(XTRA_ADOC_OPTS) \
  -D ${BUILD_DIR} \
  --failure-level=ERROR
ifeq (${NOREVMARK},)
  $(info NOREVMARK = ${NOREVMARK})
  ifeq (${REVMARK},)
    REVMARK := ${DEFAULT_REVMARK}
  endif
  OPTIONS := ${OPTIONS} -a revremark='${REVMARK}'
else
  OPTIONS := ${OPTIONS} -a norevremark
endif
ifdef NODRAFTWATERMARK
  OPTIONS := ${OPTIONS} -a no-draft-watermark
endif
ifeq (${RECOMMENDATIONS_OLD},1)
  OPTIONS := ${OPTIONS} -a recommendations-old
endif
ifeq (${RECOMMENDATIONS_NEW},1)
  OPTIONS := ${OPTIONS} -a recommendations-new
endif
REQUIRES := --require=asciidoctor-bibtex \
  --require=asciidoctor-diagram \
  --require=asciidoctor-lists \
  --require=asciidoctor-mathematical

.PHONY: all build clean build-container build-no-container build-docs

all: build

build-docs: $(DOCS_PDF) $(DOCS_HTML)

vpath %.adoc $(SRC_DIR)

%.pdf: %.adoc
	$(DOCKER_CMD) $(DOCKER_QUOTE) $(ASCIIDOCTOR_PDF) $(OPTIONS) $(REQUIRES) $< $(DOCKER_QUOTE)

%.html: %.adoc
	$(DOCKER_CMD) $(DOCKER_QUOTE) $(ASCIIDOCTOR_HTML) $(OPTIONS) $(REQUIRES) $< $(DOCKER_QUOTE)

build:
	@echo "Checking if Docker is available..."
	@if command -v docker >/dev/null 2>&1 ; then \
		echo "Docker is available, building inside Docker container..."; \
		$(MAKE) build-container; \
	else \
		echo "Docker is not available, building without Docker..."; \
		$(MAKE) build-no-container; \
	fi
	@echo "Generated documents can be found in the '${BUILD_DIR}' folder."

build-container:
	@echo "Starting build inside Docker container..."
	$(MAKE) build-docs
	@echo "Build completed successfully inside Docker container."

build-no-container:
	@echo "Starting build..."
	$(MAKE) SKIP_DOCKER=true build-docs
	@echo "Build completed successfully."

# Update docker image to latest
docker-pull-latest:
	docker pull ${DOCKER_IMG}

clean:
	@echo "Cleaning up generated files..."
	rm -rf $(BUILD_DIR)
	@echo "Cleanup completed."
