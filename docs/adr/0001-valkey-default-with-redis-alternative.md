# ADR 0001: Default to Valkey with Redis Alternative

**Status:** Accepted

**Date:** 2024-12-22

**Decision Makers:** TYPO3 DDEV Skill Maintainers

**Tags:** #caching #infrastructure #licensing #future-proofing

---

## Context

### The Redis Licensing Change (March 2024)

Redis changed its license from BSD-3-Clause (open source) to a dual RSALv2/SSPLv1 license, which is NOT OSI-approved open source. This change:

- Restricts commercial use of Redis as a managed service
- Creates legal compliance concerns for cloud providers and hosting companies
- Prevents offering Redis-as-a-service without Redis Ltd licensing agreements

### The Valkey Fork (March 2024)

In response, the Linux Foundation launched Valkey, a fork of Redis 7.2.4, with backing from:

- Amazon Web Services (AWS)
- Google Cloud
- Oracle Cloud
- Ericsson
- Snap Inc.
- 40+ additional companies

Valkey maintains BSD-3-Clause licensing (true open source) and wire-protocol compatibility with Redis.

### Cloud Provider Adoption

**AWS ElastiCache** (October 2024):
- Added Valkey 7.2 support
- Added Valkey 8.0 support (November 2024)
- Pricing: 20% lower for node-based, 33% lower for serverless vs Redis
- Performance: Claims 230% higher throughput, 70% better latency (Valkey 8.0 vs 7.2)

**Industry Trajectory:**
- AWS MemoryDB supports Valkey
- Google Cloud and Oracle are Valkey project sponsors
- Economic pressure (20-33% cost savings) will drive hosting provider migration

### TYPO3 Caching Requirements

TYPO3's Redis cache backend uses basic operations:
- `GET`, `SET`, `DEL`, `EXPIRE` - Key-value operations
- `FLUSHDB` - Cache clearing
- `KEYS` pattern matching - Cache inspection

These operations are **identical** in Redis and Valkey (wire-protocol compatible). TYPO3 does not use advanced Redis features (Streams, JSON, Search, etc.).

### DDEV Development Environment Context

The TYPO3 DDEV Skill provides a reference implementation for local development environments. Developers using this skill:

- Test TYPO3 extensions locally before production deployment
- Do not control production infrastructure (clients/hosting providers do)
- Need development environments that match future production reality
- Benefit from faster Docker image pulls (smaller images = faster `ddev start`)

---

## Decision

**Default to Valkey 8-alpine for new TYPO3 DDEV projects, with Redis 7-alpine as a documented alternative.**

### Implementation Details

#### Default Configuration

```yaml
# .ddev/docker-compose.services.yaml (new projects)
services:
  valkey:
    container_name: ddev-${DDEV_SITENAME}-valkey
    image: valkey/valkey:8-alpine
    restart: unless-stopped
    ports:
      - "6379"
    volumes:
      - valkey-data:/data
    environment:
      - VALKEY_MAXMEMORY=256mb
      - VALKEY_MAXMEMORY_POLICY=allkeys-lru
    command: valkey-server --appendonly yes --maxmemory 256mb --maxmemory-policy allkeys-lru

volumes:
  valkey-data:
    name: "${DDEV_SITENAME}-valkey-data"
```

#### Alternative: Redis 7-alpine

```yaml
# Alternative for legacy production parity
services:
  redis:
    container_name: ddev-${DDEV_SITENAME}-redis
    image: redis:7-alpine
    # ... same configuration structure
```

#### Auto-Detection Logic

For existing projects with `.ddev/docker-compose.services.yaml`:
- **Preserve existing choice**: If Redis is detected, keep Redis
- **Preserve existing choice**: If Valkey is detected, keep Valkey
- **Inform user**: Log which cache service was detected and preserved

For new projects:
- **Default to Valkey 8-alpine**
- **Document Redis alternative**: Show how to switch in generated README
- **Provide rationale**: Explain why Valkey is the forward-looking choice

---

## Consequences

### Positive

✅ **Future-Proof Development Environments**
- Matches the production trajectory (AWS/Google/Oracle adoption)
- Prepares developers for 2025-2027 hosting landscape
- Reduces future migration friction when hosting providers switch

✅ **Cost Awareness**
- Educates developers about cost-effective infrastructure choices
- Aligns with hosting provider economic incentives (20-33% savings)
- Demonstrates modern cloud architecture patterns

✅ **True Open Source**
- BSD-3-Clause license with no commercial restrictions
- No legal compliance concerns for hosting providers
- Community-driven governance (Linux Foundation)

✅ **Smaller Docker Images**
- Valkey 8-alpine: **69.7 MB**
- Redis 8-alpine: 100 MB (30% larger)
- Redis 7-alpine: 60.6 MB
- Faster `ddev start` cycles during development

✅ **Drop-In Compatibility**
- Wire-protocol identical to Redis
- TYPO3's PHP redis extension works without modification
- Zero code changes required for TYPO3 extensions
- Easy rollback to Redis if needed (one-line change)

### Negative

⚠️ **Newer Codebase**
- Valkey fork is only 1 year old (since March 2024)
- Less Stack Overflow content compared to Redis
- Potential for undiscovered edge-case bugs

**Mitigation:**
- Based on Redis 7.2.4 (stable, battle-tested codebase)
- AWS/Google/Oracle using in production validates stability
- DDEV makes switching back to Redis trivial (one-line change)
- Redis documentation applies due to protocol compatibility

⚠️ **Learning Curve**
- Developers familiar with "Redis" terminology need to learn "Valkey"
- Some confusion about naming/branding

**Mitigation:**
- Comprehensive ADR and documentation explains context
- Clear instructions for both Valkey and Redis alternatives
- Educational opportunity to teach open source licensing issues

⚠️ **Current Production Mismatch**
- Some existing TYPO3 hosting environments still use Redis 7.x
- Development-production parity temporarily impacted

**Mitigation:**
- Redis 7-alpine documented as alternative for production parity
- Auto-detection preserves existing Redis choice in projects
- Easy to switch (one-line change in docker-compose)
- Trade-off: Match today's production vs prepare for tomorrow's

### Risks and Mitigations

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| Valkey compatibility issues with TYPO3 | Low | Very Low | Wire-protocol identical, PHP redis extension works transparently |
| Valkey bugs in production use | Medium | Low | AWS/Google production usage validates stability; easy rollback |
| Developer confusion/resistance | Low | Medium | Clear documentation, explain rationale, provide Redis alternative |
| Community backlash for being "too progressive" | Low | Low | Document decision thoroughly, auto-preserve existing choices |

---

## Alternatives Considered

### Alternative 1: Redis 7-alpine Default (Conservative)

**Reasoning:**
- Most existing TYPO3 hosting uses Redis 7.x
- Maximum development-production parity today
- Battle-tested, 15 years of production use
- Familiar to developers

**Rejected Because:**
- Optimizes for yesterday's production, not tomorrow's
- Ignores industry trajectory (AWS/Google/Oracle Valkey adoption)
- Creates educational debt (developers learn old patterns)
- Proprietary licensing creates compliance concerns
- Misses opportunity to lead the transition

### Alternative 2: Redis 8-alpine Default

**Reasoning:**
- Latest Redis version
- Performance improvements over Redis 7

**Rejected Because:**
- Proprietary licensing (same as Redis 7.4+)
- Larger image size (100 MB vs 69.7 MB Valkey)
- More expensive on cloud providers vs Valkey
- Not the strategic direction of major cloud platforms

### Alternative 3: No Caching Service by Default

**Reasoning:**
- Simpler default setup
- Developers add only if needed

**Rejected Because:**
- Redis/Valkey caching is common in TYPO3 production
- Reference implementation should include production-realistic services
- DDEV skill aims to provide complete development environment
- Adding later is more friction than having it by default

### Alternative 4: Offer Both Redis and Valkey as Equal Choices

**Reasoning:**
- Maximum flexibility
- No opinionated defaults

**Rejected Because:**
- Adds complexity to setup process
- Forces developers to make decision without context
- Reference implementations should have opinionated best practices
- Still need to pick ONE as default for generation
- Documentation burden increases (maintain two equal paths)

---

## References

### Technical Documentation

- [Valkey Official Site](https://valkey.io/)
- [Valkey GitHub Repository](https://github.com/valkey-io/valkey)
- [AWS ElastiCache for Valkey Announcement](https://aws.amazon.com/about-aws/whats-new/2024/10/amazon-elasticache-valkey/)
- [TYPO3 Redis Cache Backend Documentation](https://docs.typo3.org/m/typo3/reference-coreapi/main/en-us/ApiOverview/CachingFramework/Backends/Index.html)

### Benchmarks and Analysis

- AWS ElastiCache Valkey 8.0: 230% throughput improvement, 70% latency improvement vs Valkey 7.2
- AWS Cost Comparison: Valkey 20% cheaper (node-based), 33% cheaper (serverless) vs Redis
- Docker Image Sizes:
  - `valkey/valkey:8-alpine` - 69.7 MB
  - `redis:8-alpine` - 100 MB
  - `redis:7-alpine` - 60.6 MB

### Licensing

- Redis License Change: [Redis Announcement (March 2024)](https://redis.io/blog/redis-adopts-dual-source-available-licensing/)
- Valkey License: BSD-3-Clause (OSI-approved open source)
- Linux Foundation Valkey Announcement: [TechCrunch Article](https://techcrunch.com/2024/03/31/why-aws-google-and-oracle-are-backing-the-valkey-redis-fork/)

---

## Decision Rationale Summary

This decision is **strategic and forward-looking** rather than purely technical:

1. **Technical Equivalence**: For TYPO3 use cases, Redis and Valkey are functionally identical
2. **Strategic Positioning**: Major cloud providers (AWS, Google, Oracle) are adopting Valkey
3. **Economic Reality**: 20-33% cost savings will drive hosting provider migration
4. **Licensing Safety**: True open source (BSD-3) vs proprietary licensing concerns
5. **Educational Leadership**: Skill should teach future patterns, not legacy patterns
6. **Risk Mitigation**: Easy rollback, auto-preservation of existing choices, clear documentation

**The default to Valkey is a bet on the industry trajectory being correct, backed by Linux Foundation + AWS + Google + Oracle. The risk is minimal (easy rollback), and the educational benefit is high (teaching developers about open source licensing, cost-effective infrastructure, and future-proof choices).**

---

## Review and Updates

**Next Review Date:** 2025-06-01 (6 months)

**Trigger for Re-evaluation:**
- Major TYPO3 hosting providers publicly announce Redis-only support policies
- Valkey compatibility issues discovered affecting TYPO3
- Valkey project loses major sponsor backing
- Cloud provider pricing changes making Redis competitive again

**Success Metrics:**
- Developer feedback on Valkey default (GitHub issues, discussions)
- Number of projects switching from Valkey to Redis (indicates friction)
- Hosting provider announcements about Valkey adoption
- TYPO3 community discussion about cache backends

---

**Approved By:** TYPO3 DDEV Skill Project

**Implementation:** v2.0.0 (target release)
