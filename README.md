# Cloud Design

AWS deployment of the movie inventory and asynchronous billing platform built
in the previous CRUD Master, Play With Containers, and Orchestrator projects.

The repository currently contains the six tested container services. AWS
infrastructure is defined with Terraform and will be documented here as it is
implemented.

## Local prerequisites

- Docker
- Terraform
- AWS CLI v2

Cloud credentials, Terraform state, `.tfvars`, and application secrets must
never be committed.

