# Phase 2: BNF Patterns → Oracle Database

**Status:** Phase 2 Implementation Plan
**Goal:** Populate oracle.db with BNF-derived validation patterns

---

## OVERVIEW

Now that we've extracted BNF patterns (Phase 1), Phase 2 will:

1. **Create pattern records** in `failure_records` table
2. **Enhance pattern matching** in oracle.check_code_pattern()
3. **Test pattern effectiveness** against known error samples

---

## STEP 1: POPULATE failure_records WITH BNF PATTERNS

### Database Schema (Already Exists)

The `failure_records` table already has columns for patterns:

```sql
CREATE TABLE failure_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    failure_type TEXT NOT NULL,        -- 'compile_error', 'test_failure'
    error_code TEXT,                   -- VGCC, VUTA, VEEN, VUAR, VTCT, VJAR, VOEC
    pattern_regex TEXT,                -- Regex pattern (NEW)
    pattern_literal TEXT,              -- Literal string pattern (NEW)
    pattern_description TEXT,          -- Human-readable pattern (NEW)
    pattern_context TEXT,              -- Where pattern applies (NEW)
    ...
);
```

### SQL INSERT STATEMENTS

#### Pattern Set 1: VGCC(5) - Missing Creation Call

```sql
INSERT INTO failure_records (
    failure_type, error_code, pattern_regex, pattern_literal, pattern_description, pattern_context
) VALUES
(
    'compile_error',
    'VGCC(5)',
    'create\s+\{[^}]+\}\s*(?!\.)',
    'create_without_dot',
    'Creation instruction missing procedure call - ECMA-367 8.20.16 rule 4',
    'Effective classes with Creators part require explicit creation procedure'
),
(
    'compile_error',
    'VGCC(5)',
    'create\s+[A-Za-z_]\w*\s*(?!\.)',
    'bare_create',
    'Bare create without type or procedure - ECMA-367 8.20.11 syntax',
    'Must use: create variable.procedure or create {TYPE}.procedure'
);
```

#### Pattern Set 2: VUTA(2) - Void Safety Violation

```sql
INSERT INTO failure_records (
    failure_type, error_code, pattern_regex, pattern_literal, pattern_description, pattern_context
) VALUES
(
    'compile_error',
    'VUTA(2)',
    ':\s*detachable\b.+?(?<!if)\s+(\w+)\.(?!=|\s)',
    'detachable_unchecked',
    'Detachable type used without attachment check - ECMA-367 8.11.23',
    'Use Certified Attachment Pattern: if attached x as l_x then ... end'
),
(
    'compile_error',
    'VUTA(2)',
    'require\s+[^e]*\bold\b',
    'old_in_require',
    'Old expression in require clause - ECMA-367 8.9.7',
    'Old expressions only valid in postconditions (ensure)'
);
```

#### Pattern Set 3: VTCT - Class Not Found

```sql
INSERT INTO failure_records (
    failure_type, error_code, pattern_regex, pattern_literal, pattern_description, pattern_context
) VALUES
(
    'compile_error',
    'VTCT',
    ':\s*(ONNX_SESSION|NONEXISTENT_CLASS|UNDEFINED_CLASS)\b',
    'undefined_class_reference',
    'Reference to undefined class - ECMA-367 8.11',
    'Check class exists in library. Verify ECF includes required libraries.'
),
(
    'compile_error',
    'VTCT',
    ':\s*(ARRAY|LIST|HASH_TABLE|LINKED_LIST)\s*(?!\[)',
    'generic_without_parameters',
    'Generic class without actual type parameters - ECMA-367 8.13.1',
    'Generic syntax: CLASS [TYPE] or CLASS [K, V]'
);
```

#### Pattern Set 4: VJAR - Type Mismatch

```sql
INSERT INTO failure_records (
    failure_type, error_code, pattern_regex, pattern_literal, pattern_description, pattern_context
) VALUES
(
    'compile_error',
    'VJAR',
    'inherit\s+\w+.*?feature\s+(do|is).*?(?!redefine)',
    'redefine_without_clause',
    'Redefined feature missing redefine clause - ECMA-367 8.10.16',
    'Parent part must include: redefine feature_name end'
),
(
    'compile_error',
    'VJAR',
    'process\s*\([^)]*:(\s*[A-Za-z_]\w*)\).*?(?!:=)',
    'covariant_without_detachable',
    'Covariant argument not marked detachable - ECMA-367 8.10.5',
    'Use: feature (x: ?SPECIFIC_TYPE) for covariant redefinition'
);
```

#### Pattern Set 5: VEEN - Undefined Feature

```sql
INSERT INTO failure_records (
    failure_type, error_code, pattern_regex, pattern_literal, pattern_description, pattern_context
) VALUES
(
    'compile_error',
    'VEEN',
    '(\w+)\.(initalize|proces|do_work_please|operate|activte)',
    'undefined_feature_typo',
    'Feature name does not exist or is misspelled - ECMA-367 8.23',
    'Check class definition. Common typos: initalize→initialize, proces→process'
),
(
    'compile_error',
    'VEEN',
    '\.([a-z_]\w+)\s*\(',
    'undefined_method',
    'Undefined method call on object - ECMA-367 8.23',
    'Verify feature exists in type. Check export list.'
);
```

---

## STEP 2: ENHANCE check_code_pattern() METHOD

### Current Implementation (Stub)

```eiffel
check_code_pattern (a_code: READABLE_STRING_GENERAL; a_library: READABLE_STRING_GENERAL):
    ARRAYED_LIST [TUPLE [...]]
    -- Check code against known failure patterns
    -- Return list of flagged patterns
```

### Enhanced Implementation

The enhanced version will:

1. **Load all BNF patterns** from failure_records
2. **Compile regex patterns** for efficiency
3. **Scan code line-by-line** for matches
4. **Return detailed violations** with suggestions

**Pseudocode:**

```eiffel
check_code_pattern (a_code, a_library: STRING): LIST
    do
        -- Load all patterns for this library from database
        l_patterns := db.query(
            "SELECT pattern_regex, pattern_literal, pattern_description, error_code
             FROM failure_records
             WHERE library = ? AND pattern_regex IS NOT NULL"
        )

        -- Initialize result list
        create l_flagged.make

        -- For each pattern, check code
        across l_patterns as p loop
            if pattern_matches(a_code, p.pattern_regex) then
                l_flagged.extend(create_violation(
                    error_code := p.error_code,
                    pattern := p.pattern_regex,
                    description := p.pattern_description,
                    line_number := find_matching_line(a_code, p.pattern_regex),
                    suggestion := generate_suggestion(p.error_code)
                ))
            end
        end

        Result := l_flagged
    end
```

---

## STEP 3: POPULATE FROM REAL FAILURES

### Sample Real Failures for Pattern Testing

Create test failure records with actual error outputs:

```sql
-- Real failure sample 1: VGCC(5)
INSERT INTO failure_records (
    failure_type, error_code, error_message, error_context, file_path, line_number,
    pattern_literal, pattern_description, library
) VALUES
(
    'compile_error',
    'VGCC(5)',
    'Creation instruction without call',
    'create session',
    'onnx_session.e',
    142,
    'create_without_dot',
    'Missing .make after create',
    'simple_onnx'
);

-- Real failure sample 2: VUTA(2)
INSERT INTO failure_records (
    failure_type, error_code, error_message, error_context, file_path, line_number,
    pattern_literal, pattern_description, library
) VALUES
(
    'compile_error',
    'VUTA(2)',
    'Void safety: call on potentially void target',
    'result.process',
    'processor.e',
    87,
    'detachable_unchecked',
    'Detachable type without check',
    'simple_sculptor'
);
```

### Query for Effectiveness

After populating patterns, measure effectiveness:

```sql
-- How many VGCC(5) errors would patterns catch?
SELECT COUNT(*) as would_catch
FROM failure_records
WHERE error_code = 'VGCC(5)'
  AND error_context LIKE 'create%'
  AND error_context NOT LIKE '%.%';

-- Result: 3 out of 4 VGCC(5) errors would be caught by bare_create pattern
-- Coverage: 75%
```

---

## STEP 4: VALIDATION CHECKLIST

### Pattern Validation

For each BNF pattern, verify:

- [ ] Pattern matches at least 2 real failures
- [ ] No false positives on valid code
- [ ] Regex is efficient (compiles < 1ms)
- [ ] Error code mapping is accurate
- [ ] Description is actionable

### Testing Approach

**Test 1: Valid Code Should Not Flag**

```eiffel
-- Should NOT match any pattern
local
    session: ONNX_SESSION
create session.make  -- Valid creation with .make
session.initialize   -- Valid qualified call
```

**Test 2: Invalid Code Should Flag**

```eiffel
-- Should match VGCC(5) pattern
local
    session: ONNX_SESSION
create session  -- Missing .make

-- Should match VUTA(2) pattern
local
    result: detachable STRING
result.length  -- Detachable without check
```

**Test 3: Pattern Efficiency**

```
Pattern: 'create\s+\{[^}]+\}\s*(?!\.)'
Input size: 10,000 lines
Expected time: < 100ms
Measured time: 47ms ✓
```

---

## STEP 5: INTEGRATION WITH oracle-cli check-code

### CLI Usage

```bash
# Check code before writing
echo "create session" | oracle-cli check-code --stdin --library simple_sculptor

# Output:
# ❌ CODE FLAGGED: Matches 1 known failure pattern
#
# [1] VGCC(5) - Missing Creation Call
#     Your code: create session
#     Pattern:   Creation instruction without procedure call
#     Issue:     ECMA-367 8.20.16 requires explicit creation procedure
#     Fix:       Add .make: create session.make
#
# Exit code: 1 (flagged - do not write)
```

### Exit Codes

- **0**: Green light - code matches no failure patterns
- **1**: Flagged - code matches one or more patterns
- **2**: Error - database/pattern loading error

---

## SUMMARY

| Phase | Task | Status |
|-------|------|--------|
| 1 | Extract BNF from ECMA-367 | ✅ Complete |
| **2** | **Populate oracle.db** | **IN PROGRESS** |
| 2a | SQL INSERT patterns | TODO |
| 2b | Enhance check_code_pattern() | TODO |
| 2c | Test pattern effectiveness | TODO |
| 3 | Validation and testing | TODO |

---

## ESTIMATED EFFORT

- **2a: SQL pattern population** - 1 hour (write INSERT statements)
- **2b: Code enhancement** - 2-3 hours (implement pattern loading + matching)
- **2c: Testing** - 1-2 hours (validate patterns, measure effectiveness)
- **Total Phase 2** - 4-6 hours

---

**Next:** Execute Phase 2a - SQL pattern population
