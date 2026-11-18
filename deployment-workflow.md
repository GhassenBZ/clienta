# Deployment workflow

This document explains how Vikunja is prepared locally and deployed to AWS.

## Overview

Vikunja has three main parts:

- the browser frontend, served by Nginx;
- the Vikunja API and application backend;
- MySQL RDS, which stores accounts, projects, tasks, and application records.

The public Application Load Balancer (ALB) receives browser traffic. It sends static page and asset requests to the frontend instances and API requests to the backend instances.

## 1. Prepare the application locally

The `scripts/package-app.ps1` script prepares the deployment:

1. Downloads the pinned Vikunja v2.8.0 server release.
2. Downloads the pinned Vikunja v2.8.0 source archive.
3. Verifies both downloads against fixed SHA-256 checksums.
4. Downloads a pinned Nginx 1.28.2 RPM for Amazon Linux 2023.
5. Installs the frontend dependencies and builds the Vikunja browser frontend.
6. Packages the static frontend, Nginx RPM, and Nginx configuration.
7. Packages the Vikunja server binary and demo seeding assets.

The process creates:

- `build/vikunja-frontend.tar.gz`
- `build/vikunja-backend.tar.gz`

The frontend bundle contains:

- Built HTML, JavaScript, CSS, and assets;
- Nginx configuration;
- the pinned Nginx RPM.

The backend bundle contains:

- the Vikunja executable;
- the Vikunja license;
- the demo seeder;
- the demo accounts and project/task data.

Building and packaging locally means EC2 instances do not need Node.js, pnpm, source control access, or a Go build toolchain during startup.

## 2. Store deployment artifacts in S3

Terraform creates a private, encrypted S3 artifact bucket. It uploads:

- `vikunja-frontend.tar.gz`;
- `vikunja-backend.tar.gz`;
- `vikunja-runtime.json`, containing database connection settings and a derived Vikunja signing secret.

S3 acts as a controlled handoff between the workstation and EC2. It is not Vikunja's uploaded-file storage in the current implementation.

Using prepared artifacts has several advantages:

- every instance receives the same frontend and backend version;
- downloaded files are verified by SHA-256;
- GitHub does not need to remain available during instance startup;
- private subnets do not need a NAT gateway for builds or release downloads;
- an upstream release or repository change cannot alter the deployment unexpectedly.

## 3. Provision AWS infrastructure

Terraform creates:

- a VPC and public/private subnets;
- public Application Load Balancer subnets;
- private application subnets;
- private RDS subnets;
- an internet-facing ALB;
- separate frontend and backend target groups;
- separate frontend and backend Auto Scaling groups;
- MySQL RDS;
- security groups;
- an S3 gateway endpoint.

Both ASGs currently have a minimum and desired capacity of two and a maximum of four. Frontend and backend instances have no public IP addresses.

## 4. Send browser traffic through the ALB

The public HTTP ALB accepts traffic on port 80.

It routes:

- `/` and static asset paths to Nginx frontend instances;
- `/api/*` to the Vikunja backend instances;
- `/dav*` to the Vikunja backend instances;
- `/.well-known/caldav*` to the Vikunja backend instances.

Frontend API calls retain the same browser origin, allowing the ALB to distinguish frontend pages from backend API requests.

## 5. Boot the frontend tier

When an Auto Scaling Group launches a frontend instance:

1. The instance downloads the frontend bundle from S3.
2. The launch script verifies the bundle with SHA-256.
3. The bundle is extracted to `/opt/vikunja/frontend`.
4. Static files are copied to `/var/www/vikunja`.
5. The pinned Nginx RPM is installed locally.
6. Nginx configuration is copied to `/etc/nginx/nginx.conf`.
7. `nginx.service` is enabled and started.

Nginx serves static files and returns HTTP 200 from `/health` for ALB health checks. It also falls back to `index.html` for browser routes used by the single-page frontend.

## 6. Boot the backend tier

When the backend Auto Scaling Group launches an instance:

1. The instance downloads the backend bundle from S3.
2. The launch script verifies it with SHA-256.
3. The bundle is extracted to `/opt/vikunja`.
4. The private runtime configuration is downloaded to `/etc/vikunja/config.yml`.
5. The runtime configuration is also checksum-verified.
6. Systemd starts Vikunja on port 8080.
7. The demo seed service starts after Vikunja becomes available.

The backend security group permits MySQL traffic only from backend instances to RDS.

## 7. Populate and use the database

RDS stores real Vikunja records:

- user accounts;
- password hashes;
- projects;
- tasks;
- Kanban buckets;
- labels;
- assignments;
- comments;
- other Vikunja application data.

The [seed-demo.py](vikunja/seed-demo.py) service:

1. waits for Vikunja's API;
2. creates demo accounts with the Vikunja CLI;
3. creates projects and tasks through the API;
4. adds buckets, labels, assignments, and comments;
5. checks existing records before creating duplicates.

This makes the demo accounts and project data real database records. They are not JavaScript-only mock records displayed by a separate frontend.

The seeder reruns when a backend instance starts, but it is intended to avoid duplicating existing records.

## 8. Handle application files

The Vikunja file-storage setting uses a private S3 upload bucket. The patched backend stores files under the `vikunja-files` base path and uses the EC2 instance role for AWS SDK credentials.

Vikunja's file backend is used for user-uploaded content such as:

- files attached directly to tasks;
- images pasted into task comments, which Vikunja uploads as task attachments;
- user-uploaded profile pictures or avatars;
- uploaded project background images;
- previews or cover images derived from task attachments and project backgrounds.

RDS stores file metadata and application relationships, while the actual file bytes and generated previews are stored in S3. Every backend instance reads and writes the same objects, so an attachment, uploaded avatar, or uploaded project background remains available when requests reach a different backend instance.

The separate artifact S3 bucket is for deployment files and runtime configuration. Vikunja's user-upload storage uses a separate private upload bucket.

## Making uploaded files available across every backend

Yes, Vikunja can store task attachments, uploaded avatars, uploaded project backgrounds, and their generated images in S3. This is the best storage design for the two-backend setup because all backend instances read and write the same objects.

The separate objects should not be mixed with the deployment bundle objects. The recommended design is:

- one private bucket for deployment artifacts;
- one private bucket for Vikunja uploads;
- a key prefix such as `vikunja-files/` for uploaded file bytes;
- public access blocked on the upload bucket;
- encryption enabled on the upload bucket;
- lifecycle or backup rules only if needed.

The implemented runtime configuration uses this structure:

```yaml
files:
  type: s3
  basepath: vikunja-files
  s3:
    endpoint: https://s3.us-east-1.amazonaws.com
    bucket: your-private-vikunja-upload-bucket
    region: us-east-1
    usepathstyle: false
```

No access key or secret key is present in the runtime configuration. The rebuilt backend uses the AWS SDK default credential chain, which resolves the temporary credentials from the EC2 instance profile.

The packaging script now:

1. downloads and verifies the Vikunja v2.8.0 source;
2. applies the reviewed instance-role patch;
3. removes the SQLite-only fingerprint branch that prevents a CGO-free Linux build;
4. cross-compiles the Linux AMD64 backend;
5. verifies and includes the rebuilt binary in `vikunja-backend.tar.gz`.

Terraform provides:

- a private upload bucket;
- bucket policy permissions for `PutObject`, `GetObject`, and `DeleteObject`;
- S3 gateway endpoint access for the `vikunja-files/*` prefix;
- S3 file configuration in the runtime object;
- no static S3 access credentials.

For this project, S3 with an instance-role-compatible Vikunja build is the cleanest solution. EFS is the simpler no-code-change fallback. The official binary alone cannot provide instance-role S3 access in v2.8.0.

