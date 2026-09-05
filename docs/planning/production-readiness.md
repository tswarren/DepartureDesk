# Production readiness

These settings are intentionally deferred until a hosting environment and
service providers are selected.

## Required before first deployment

- [ ] Select deployment platform and production image strategy
- [ ] Configure `DATABASE_URL`
- [ ] Configure `QUEUE_DATABASE_URL`
- [ ] Provide `RAILS_MASTER_KEY`
- [ ] Select durable Active Storage service
- [ ] Configure application host and mailer URL options
- [ ] Select and configure transactional email provider
- [ ] Select Action Cable adapter if real-time broadcasting is required
- [ ] Select shared cache adapter if production caching is required
- [ ] Configure allowed hosts and proxy/SSL behavior
- [ ] Configure log retention and error reporting
- [ ] Establish database backup and restoration procedures
- [ ] Establish uploaded-file backup and retention procedures
- [ ] Run production boot and asset-precompilation checks