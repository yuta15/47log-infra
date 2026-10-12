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
DEVELOP_ENV_DIR := $(CURDIR)/terraform/environments/development
MODULE_DIRS := $(addprefix $(CURDIR)/terraform/modules/,$(SELECTED_MODULES))
TFLINT_CONFIG := $(CURDIR)/.tflint.hcl
export TFLINT_PLUGIN_DIR ?= $(CURDIR)/.tflint.d/plugins

.PHONY: fmt fmt-check lint-init tflint lint init validate test check develop develop-apply develop-push-image develop-destroy

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

develop: develop-apply
	$(MAKE) develop-push-image

develop-apply:
	@set -e; cd "$(DEVELOP_ENV_DIR)"; \
		$(TERRAFORM) init -lockfile=readonly; \
		$(TERRAFORM) apply --auto-approve

develop-destroy: SHELL := /bin/bash
develop-destroy:
	@set -euo pipefail; cd "$(DEVELOP_ENV_DIR)"; \
		$(TERRAFORM) init -lockfile=readonly; \
		if repository_url=$$($(TERRAFORM) output -json | jq -er '.repository_url.value // empty'); then \
			repository_name=$${repository_url#*/}; \
			registry=$${repository_url%%/*}; \
			region=$$(printf '%s' "$$registry" | cut -d. -f4); \
			image_digests=$$(aws ecr list-images --region "$$region" \
				--repository-name "$$repository_name" --output json | \
				jq -r '[.imageIds[].imageDigest] | unique[]'); \
			for digest in $$image_digests; do \
				aws ecr batch-delete-image --region "$$region" \
					--repository-name "$$repository_name" --image-ids "imageDigest=$$digest" \
					--query failures --output json | \
					jq -e 'if length == 0 then true else error(.[0].failureReason) end' > /dev/null; \
			done; \
		else \
			echo 'ECR output is unavailable; skipping image cleanup.'; \
		fi; \
		$(TERRAFORM) destroy --auto-approve

develop-push-image: SHELL := /bin/bash
develop-push-image:
	@set -euo pipefail; cd "$(DEVELOP_ENV_DIR)"; \
		repository_url=$$($(TERRAFORM) output -raw repository_url); \
		repository_name=$${repository_url#*/}; \
		registry=$${repository_url%%/*}; \
		region=$$(printf '%s' "$$registry" | cut -d. -f4); \
		image_exists=$$(aws ecr list-images --region "$$region" \
			--repository-name "$$repository_name" \
			--query 'contains(imageIds[].imageTag, `dummy-v1`)' --output json); \
		if [[ "$$image_exists" == true ]]; then \
			echo 'dummy-v1 already exists; skipping push.'; exit 0; \
		fi; \
		aws ecr get-login-password --region "$$region" | \
			docker login --username AWS --password-stdin "$$registry"; \
		docker buildx build --platform linux/amd64 --provenance=false --load \
			-t "$$repository_url:dummy-v1" "$(CURDIR)/docker/lambda-dummy"; \
		docker push "$$repository_url:dummy-v1"
