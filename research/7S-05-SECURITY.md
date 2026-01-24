# 7S-05: SECURITY - simple_oracle


**Date**: 2026-01-23

**BACKWASH** | Generated: 2026-01-23 | Library: simple_oracle

## Security Model

### Trust Boundary
- Local development tool
- Single user access
- No network exposure

### Threat Assessment

| Threat | Risk | Mitigation |
|--------|------|------------|
| Data tampering | Low | Local file permissions |
| Information disclosure | Low | Local access only |
| SQL injection | Low | Parameterized queries |
| Denial of service | Low | Local tool |
| Data loss | Medium | WAL mode, checkpoints |

## Access Control

### Database Access
- Single SQLite file on disk
- User file permissions apply
- No built-in authentication

### Query Safety
- All queries use parameterized bindings
- No raw string concatenation
- FTS5 queries sanitized

## Data Protection

### Database Files
- oracle.db in simple_oracle directory
- Memory database for performance
- WAL mode for durability

### Sensitive Data
- No credentials stored
- Source code not stored (metadata only)
- Event logs may contain paths

## Input Validation

### Query Strings
- Passed to FTS5 MATCH (safe)
- LIKE patterns constructed safely
- Parameters bound, not concatenated

### File Paths
- Validated by Eiffel file operations
- Existence checked before use

## Recommendations

1. **Backup oracle.db** - Contains development history
2. **File Permissions** - Restrict to user only
3. **No Sensitive Data** - Avoid storing credentials
4. **Regular Cleanup** - Prune old events periodically
