# Vikunja deployment changes

This branch replaces the former Clienta application with Vikunja v2.8.0. The implementation is not yet applied or tested in AWS.

## Current implementation

- `scripts/package-app.ps1` verifies pinned Vikunja server and source archives and creates:
  - `build/vikunja-frontend.tar.gz` containing the built static browser assets, a pinned Nginx RPM, and Nginx configuration.
  - `build/vikunja-backend.tar.gz` containing the Vikunja binary, license, demo seeder, and seed data.
- The public ALB serves the static frontend target group by default and forwards `/api/*`, `/dav*`, and `/.well-known/caldav*` to the backend target group.
- Frontend and backend instances run in private application subnets in two Auto Scaling groups.
- RDS stores Vikunja accounts and project/task records. Both ASGs have a minimum and desired capacity of two and a maximum of four.
- A private S3 bucket holds deployment bundles and runtime configuration. The gateway endpoint permits only the required `GetObject` requests.
- Backend configuration enables public registration and connects to private MySQL. Vikunja file storage uses a dedicated private S3 bucket so uploaded attachments, avatars, backgrounds, and previews are shared across backend instances.

S3 stores the frontend deployment bundle and cannot execute Nginx itself. Frontend instances download the bundle, install the pinned Nginx RPM locally, and start Nginx through systemd.

## Validation

- Terraform formatting and validation pass.
- Seeder unit tests pass.
- Frontend packaging and backend packaging have been tested locally.
- AWS deployment, instance replacement, and load testing have not been performed.
