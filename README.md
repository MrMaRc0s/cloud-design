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

## Architecture (in progress)

Two developers own separate halves of the infrastructure on branches
`feat/edge-inventory` (networking, Cognito, API Gateway, `inventory-app`,
`inventory-database`) and `feat/platform-billing` (compute foundation,
`rabbit-queue`, `billing-database`, `billing-app`, observability). Only the
second half exists in Terraform so far; the sections below document it.

```
                        (not yet built - Developer A)
        client -> HTTPS API Gateway + Cognito -> private VPC Link
                                |
                                v
   +----------------------------------------------------------+
   |  ECS cluster (EC2 launch type, terraform/modules/         |
   |  compute-foundation) - shared by both developers          |
   |                                                            |
   |   api-gateway-app  --publishes-->  rabbit-queue  <--consumes-- billing-app
   |   (not yet built)      (this half)  [EFS-backed]   (this half)     |
   |                                                                    v
   |                                                            billing-database
   |                                                              [EFS-backed]
   +--------------------------------------------------------------------------+
```

### Compute foundation (`terraform/modules/compute-foundation`)

- ECS cluster on the **EC2 launch type**, not Fargate: an Auto Scaling
  Group of `t3.micro` instances (Free-Tier eligible) behind an ECS capacity
  provider with managed scaling and managed termination protection.
  Cheaper per compute-hour than Fargate; the cost is owning AMI updates
  (resolved via the SSM `amazon-linux-2023` ECS-optimized AMI parameter,
  not pinned by hand) and capacity planning ourselves.
- Instances have **no SSH**: no key pair, no port 22 security group rule,
  no public IP. Operator access is via AWS Systems Manager Session
  Manager only (`AmazonSSMManagedInstanceCore` on the instance role).
- ECR repository per owned image (`rabbit-queue`, `billing-app`,
  `billing-database`), vulnerability scan-on-push enabled, immutable tags.
- A shared ECS task execution role (ECR pull + CloudWatch Logs) and one
  empty per-service task role each, ready to gain least-privilege
  permissions as a service actually needs an AWS API.
- A private DNS namespace (`cloud-design.internal`) for internal service
  discovery — `billing-database.cloud-design.internal`,
  `rabbit-queue.cloud-design.internal`.
- **Known gap, not yet resolved**: the ECS instances need outbound access
  to the ECS control plane, ECR, and CloudWatch Logs (and SSM, since
  there's no SSH), and there is currently no NAT Gateway or VPC endpoint
  providing that path. This is a real functional blocker, not a cost nice-
  to-have — resolving it is networking's call (egress choice), but it
  gates whether this module's instances can register at all.

### Billing workloads (`terraform/modules/billing-workloads`)

Three ECS services, all `awsvpc` network mode, private subnets only, no
public IP:

- **`rabbit-queue`** — persistent storage is EFS (encrypted), not an
  instance-local volume, so data survives the Auto Scaling Group replacing
  the underlying EC2 instance, not just the task. A non-essential sidecar
  container in the same task (`rabbit-queue-bootstrap`) provisions the
  application user via the RabbitMQ Management HTTP API, since the custom
  image has no equivalent of the official image's
  `RABBITMQ_DEFAULT_USER`/`PASS`. It authenticates as `guest`, which
  RabbitMQ restricts to loopback by default — safe here specifically
  because "loopback" means "inside this same ECS task" in `awsvpc` mode,
  not reachable from anywhere else.

  The task pins `RABBITMQ_NODENAME=rabbit@localhost`. **This was a real bug
  found by testing, not a guess**: without it, RabbitMQ derives its node
  name from the container's hostname, which is random per task. Replacing
  the task then leaves the new one unable to find the old node's Mnesia
  directory, so it silently boots an *empty* database — confirmed locally,
  where the bootstrap user and a durable queue both vanished after a
  container swap. Re-tested after the fix: user, queue, and message all
  survived a full container replacement.

- **`billing-database`** — same EFS-backed persistence pattern, verified
  independently (no RabbitMQ-style node-identity issue here, but confirmed
  rather than assumed after getting burned once). AWS Backup's automatic
  EFS backups are enabled for this file system specifically (not
  `rabbit-queue`'s — queue contents are transient in-flight data, not
  something with a "backup and restore" story).

- **`billing-app`** — stateless consumer, connects to the other two by
  internal DNS, exposes port 8080 for health checks only (billing orders
  arrive exclusively via RabbitMQ, never HTTP).

Security groups are scoped per service (`billing-database` only reachable
from `billing-app`'s security group, `rabbit-queue` only from `billing-app`
plus whatever Developer A's `api-gateway-app` task security group gets
added at integration time), not just placed in a shared private subnet.

**Secrets**: usernames and passwords for `billing-database` and RabbitMQ
(shared with Developer A's `api-gateway-app`, which authenticates as the
same account to publish to the same queue) live in AWS Secrets Manager, not
Terraform. `compute-foundation` creates only the empty secret *containers*
(`aws_secretsmanager_secret`, no `aws_secretsmanager_secret_version`) —
real values are never written by Terraform, because even a value that never
appears in `.tf` source would still land in Terraform state the moment a
resource set it. Real values are populated separately, out-of-band, by
`scripts/put-secret-value.sh`, which reads a git-ignored local file (see
`.env.secrets.example`) and calls `aws secretsmanager put-secret-value`
directly — it must run once before the first task launch, since the ECS
task execution role fetches these values at container start via each task
definition's `secrets` block, and a task pointed at an empty secret won't
start.

### Observability (`terraform/modules/billing-workloads/observability.tf`)

- CloudWatch log group per container (4 total), 14-day retention, referenced
  directly by each task definition rather than relying on log-group
  auto-creation.
- Alarms, all publishing to one SNS topic: running-task-count and CPU for
  `billing-app` and `rabbit-queue`, plus a log-metric-filter-based
  error-rate alarm for `billing-app` (RabbitMQ's Erlang log format was
  judged too noisy for reliable pattern matching, so `rabbit-queue` relies
  on the running-task-count alarm as its health signal instead).
  `billing-database` gets a CPU alarm only — no storage alarm, since EFS
  scales storage automatically and has no "disk full" failure mode.
- One small CloudWatch dashboard (CPU, running tasks, error count).
- Backup/restore for billing data was **actually run**, not just declared:
  seeded rows into a local instance of `billing-database`, `pg_dump`'d,
  copied the dump out of the container (off-instance, as a real backup must
  be), `DROP TABLE`'d the data to genuinely destroy it, restored from the
  copied-out dump, and confirmed every row came back with the exact
  original values.

### Availability, stated plainly

- `rabbit-queue` and `billing-database` are both single-instance
  (`desired_count = 1`). Both *recover* after task replacement thanks to
  EFS-backed storage — proven locally, including the node-identity bug
  above — but neither is highly available: there is downtime during
  replacement, no clustering, no quorum, no failover. Do not read the
  recovery evidence above as an HA claim.
- `billing-app` is the one stateless service here. RabbitMQ's
  competing-consumers pattern makes it safe to run more than one instance
  against the same queue, so `desired_count` could be raised for real
  availability/throughput headroom without the single-writer constraint
  the two stateful services have — left at 1 for now pending budget.

### Failure-scenario evidence

Verified end-to-end locally (Docker network, all four images including
Developer A's unmodified `api-gateway-app`, no AWS required to prove the
application-level contract):

1. Stopped `billing-app`, `POST`ed an order to `api-gateway-app`'s
   `/api/billing` — got `200 OK`, `{"message":"Message posted"}`, and
   confirmed the message was actually sitting in the queue
   (`"messages":1`), not silently dropped.
2. Started `billing-app` — it processed the order within seconds
   (`Processed billing order 1` in its logs).
3. Queried `billing-database` directly: the row was present with the exact
   values from the original request (`user_id=42`, `number_of_items=3`,
   `total_amount=59.97`), and the queue was back to `"messages":0` —
   consumed exactly once, no duplication.

This used the same credentials and queue name
(`billing_service`/`billing_queue`) the Terraform modules use in AWS, so
the only thing that changes at real deployment is the transport (Docker
bridge network → private VPC + service discovery), not the contract being
proven here.

### Cleanup (this half)

Destroy roughly in reverse of apply. Neither of these has been applied yet
(everything above was validated locally, not against real AWS), but the
procedure is documented now rather than improvised later:

1. **`billing-workloads`** first — ECS services/tasks, EFS filesystems
   (rabbit-queue's and billing-database's), security groups, service
   discovery entries, CloudWatch log groups/alarms/dashboard, SNS topic.
2. **`compute-foundation`** next — ECS cluster, the Auto Scaling Group
   (terminates the EC2 instances), launch template, capacity provider, ECR
   repositories. ECR repos have `force_delete = true` specifically so a
   repo that still has images in it doesn't stop `destroy` partway through
   — without it, a non-empty repo fails and needs the images deleted
   manually before retrying.
3. **`bootstrap`** (the state bucket) last, and only when genuinely done
   with the whole exercise, not between ordinary work sessions — every
   other config depends on it for remote state once integration happens.

Known leftovers to check for even after `destroy` reports success:

- **AWS Backup recovery points** for billing-database's EFS filesystem —
  destroying the source file system does not delete existing backups; they
  keep costing (small amounts of) money until removed from the vault
  separately.
- **The state bucket's old object versions** — versioning is deliberately
  on and `force_destroy` deliberately isn't set on the bucket itself, so
  deleting it at the very end requires emptying all versions first. That's
  intentional friction against an accidental one-command wipe of shared
  state history, not an oversight.
- **CloudWatch Logs** should self-expire per each log group's
  `retention_in_days`, but worth a spot-check rather than assuming.

