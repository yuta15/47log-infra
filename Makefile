TERRAFORM ?= terraform
TFLINT ?= tflint

FRONTEND_DIR := terraform/modules/frontend
TFLINT_CONFIG := $(CURDIR)/.tflint.hcl
export TFLINT_PLUGIN_DIR ?= $(CURDIR)/.tflint.d/plugins

.PHONY: fmt fmt-check lint-init tflint lint init validate test check

fmt:
	$(TERRAFORM) fmt -recursive $(FRONTEND_DIR)

fmt-check:
	$(TERRAFORM) fmt -check -recursive $(FRONTEND_DIR)

lint-init:
	$(TFLINT) --init --config="$(TFLINT_CONFIG)"

tflint: lint-init
	$(TFLINT) --chdir=$(FRONTEND_DIR) --config="$(TFLINT_CONFIG)"

lint: fmt-check tflint

init:
	$(TERRAFORM) -chdir=$(FRONTEND_DIR) init -backend=false -input=false

validate: init
	$(TERRAFORM) -chdir=$(FRONTEND_DIR) validate

test: init
	$(TERRAFORM) -chdir=$(FRONTEND_DIR) test

check: lint validate test
