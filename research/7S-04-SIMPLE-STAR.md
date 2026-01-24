# 7S-04: SIMPLE-STAR - simple_oracle

**BACKWASH** | Generated: 2026-01-23 | Library: simple_oracle

## Ecosystem Dependencies

### Required simple_* Libraries

| Library | Purpose | Version |
|---------|---------|---------|
| simple_sql | SQLite database access | latest |
| simple_time | Timestamps (SIMPLE_DATE_TIME) | latest |

### ISE Base Libraries Used

| Library | Purpose |
|---------|---------|
| base | Collections, strings, files |
| time | Time operations |

## Integration Points

### simple_sql Integration
- SIMPLE_SQL_DATABASE for both memory and disk
- Parameterized queries for safety
- FTS5 virtual table support

### simple_time Integration
- SIMPLE_DATE_TIME for timestamps
- ISO 8601 formatting

## Ecosystem Fit

### Category
Infrastructure / Development Intelligence

### Phase
Phase 4 - Production with active development

### Maturity
Production-ready

### Role in Ecosystem
- Central knowledge repository
- Development activity tracking
- AI context management
- Ecosystem metrics

## Consumers

### Claude Code Sessions
- Boot command for context restoration
- Query command for information
- Handoff command for session end
- Check command for guidance

### Automated Tools
- Ecosystem scanner
- DBC heatmap analyzer
- Source stats parser
- Process monitor

### Human Users
- Ecosystem statistics
- Library status
- Development metrics
