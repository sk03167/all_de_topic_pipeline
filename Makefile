LAB_DIR := infra/environments/lab-ec2
MSK_DIR := infra/environments/msk-later

.PHONY: fmt validate plan-lab apply-lab destroy-lab plan-msk test

fmt:

	terraform -chdir=$(LAB_DIR) fmt -recursive
	terraform -chdir=$(MSK_DIR) fmt -recursive

validate: fmt

	terraform -chdir=$(LAB_DIR) init -backend=false
	terraform -chdir=$(LAB_DIR) validate
	python3 -m compileall services/generator/src pipelines/src

test:

	python3 -m unittest discover -s services/generator/tests -v

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
