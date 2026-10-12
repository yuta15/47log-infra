TERRAFORM ?= terraform
TFLINT ?= tflint

MODULE ?= frontend
MODULES := $(sort $(patsubst terraform/modules/%/,%,$(dir $(wildcard terraform/modules/*/*.tf))))
ifeq ($(strip $(MODULE)),all)
SELECTED_MODULES := $(MODULES)
else
SELECTED_MODULES := $(strip $(MODULE))
endif

ifeq ($(SELECTED_MODULES),)
$(error MODULEに対象モジュールまたはallを指定してください)
endif
ifneq ($(filter-out $(MODULES),$(SELECTED_MODULES)),)
$(error 不明なMODULE: $(filter-out $(MODULES),$(SELECTED_MODULES))。指定可能: $(MODULES) all)
endif

TERRAFORM_ENV_DIR := $(CURDIR)/terraform/environments/production
MODULE_DIRS := $(addprefix $(CURDIR)/terraform/modules/,$(SELECTED_MODULES))
TFLINT_CONFIG := $(CURDIR)/.tflint.hcl
export TFLINT_PLUGIN_DIR ?= $(CURDIR)/.tflint.d/plugins

.PHONY: fmt fmt-check lint-init tflint lint init validate test check

fmt:
	@set -e; cd "$(TERRAFORM_ENV_DIR)"; for module_dir in $(MODULE_DIRS); do \
		printf 'Format %s\n' "$$module_dir"; \
		$(TERRAFORM) fmt -recursive "$$module_dir"; \
	done

fmt-check:
	@set -e; cd "$(TERRAFORM_ENV_DIR)"; for module_dir in $(MODULE_DIRS); do \
		printf 'Check format %s\n' "$$module_dir"; \
		$(TERRAFORM) fmt -check -recursive "$$module_dir"; \
	done

lint-init:
	$(TFLINT) --init --config="$(TFLINT_CONFIG)"

tflint: lint-init
	@set -e; for module_dir in $(MODULE_DIRS); do \
		printf 'Lint %s\n' "$$module_dir"; \
		$(TFLINT) --chdir="$$module_dir" --config="$(TFLINT_CONFIG)"; \
	done

lint: fmt-check tflint

init:
	@set -e; cd "$(TERRAFORM_ENV_DIR)"; for module_dir in $(MODULE_DIRS); do \
		$(TERRAFORM) -chdir="$$module_dir" init -backend=false -input=false; \
	done

validate: init
	@set -e; cd "$(TERRAFORM_ENV_DIR)"; for module_dir in $(MODULE_DIRS); do \
		$(TERRAFORM) -chdir="$$module_dir" validate; \
	done

test: init
	@set -e; cd "$(TERRAFORM_ENV_DIR)"; for module_dir in $(MODULE_DIRS); do \
		$(TERRAFORM) -chdir="$$module_dir" test; \
	done

check: lint validate test
