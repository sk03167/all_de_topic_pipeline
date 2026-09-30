LAB_DIR := infra/environments/lab-ec2
MSK_DIR := infra/environments/msk-later
VENV := .venv
PYTHON := $(VENV)/bin/python

.PHONY: setup setup-generator fmt lint test validate plan-lab apply-lab destroy-lab plan-msk

setup:

	python3 -m venv $(VENV)
	$(PYTHON) -m pip install --upgrade pip
	$(PYTHON) -m pip install -e ".[dev]"

setup-generator: setup

	$(PYTHON) -m pip install -e ".[generator]"

fmt:

	terraform -chdir=$(LAB_DIR) fmt -recursive
	terraform -chdir=$(MSK_DIR) fmt -recursive

lint:

	$(PYTHON) -m ruff check services/generator/src services/generator/tests pipelines/src pipelines/tests

validate: fmt

	terraform -chdir=$(LAB_DIR) init -backend=false
	terraform -chdir=$(LAB_DIR) validate
	$(PYTHON) -m compileall services/generator/src pipelines/src

test:

	$(PYTHON) -m pytest

plan-lab:

	terraform -chdir=$(LAB_DIR) init
	terraform -chdir=$(LAB_DIR) plan

apply-lab:

	terraform -chdir=$(LAB_DIR) apply

destroy-lab:

	terraform -chdir=$(LAB_DIR) destroy

plan-msk:

	terraform -chdir=$(MSK_DIR) init
	terraform -chdir=$(MSK_DIR) plan
