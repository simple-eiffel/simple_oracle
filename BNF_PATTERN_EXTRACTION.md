# BNF Pattern Extraction - Phase 1 Implementation

**Date:** 2026-02-01
**Status:** Phase 1 - Pattern Extraction IN PROGRESS
**Source:** ECMA-367 2nd Edition, June 2006
**Goal:** Extract BNF rules from standard, map to error codes, generate regex patterns

---

## EXECUTIVE SUMMARY

This document systematically extracts **BNF production rules** from ECMA-367 and converts them to **validation patterns** for the oracle gate. These patterns will catch compilation errors BEFORE code reaches the compiler.

**Three-Layer Strategy:**
1. **Literal Pattern Matching** (current) - Look for exact strings that cause errors
2. **BNF-Derived Syntactic Patterns** (this phase) - Validate code structure against grammar
3. **Semantic Patterns** (future) - Deep type/scope analysis

---

## PHASE 1A: CREATION INSTRUCTION PATTERNS

### Source: ECMA-367 Section 8.20.11 - Syntax: Creation instructions

**BNF Production Rules:**
```
Creation_instruction  = create [Explicit_creation_type] Creation_call
Explicit_creation_type = "{" Type "}"
Creation_call         = Variable [Explicit_creation_call]
Explicit_creation_call = "." Unqualified_call
```

**Semantic Rule (8.20.16 - Creation Instruction Properties):**

A Creation_instruction ci of creation type CT is valid only if:
1. BCT (base class of CT) is an effective class
2. If ci includes a Type part, it conforms to target type
3. If ci has no Creation_call, then BCT has no Creators part OR lists default_create
4. **If BCT has Creators part which doesn't list default_create, then ci MUST have a Creation_call**
5. If ci has Creation_call whose feature f is not default_create, BCT must list f as creation procedure
6. If ci has Creation_call, that call must be argument-valid

### INVALID PATTERNS - Compile Error VGCC(5)

**Error Code:** VGCC(5) - Missing creation call
**Description:** Creation instruction without procedure call

#### Pattern 1.1: Missing Creation Call (Most Common)

**BNF Violation:**
```
create variable  [NO DOT AND PROCEDURE CALL]
```

**Invalid Examples (will cause VGCC):**
```eiffel
create session           -- Missing .make or creation procedure
create obj               -- Bare creation without procedure call
create {MY_TYPE}         -- Type specified but missing .procedure
```

**Valid Examples:**
```eiffel
create session.make
create {ONNX_SESSION}.make
create obj.initialize
```

**Regex Pattern:**
```regex
create\s+\{[^}]+\}\s*(?!\.)
create\s+[A-Za-z_]\w*\s*(?!\.)
```

**Literal Pattern:**
```
pattern_type: regex
pattern_literal: "create" followed by type/variable but NO dot
pattern_description: "Creation instruction missing procedure call - from ECMA-367 8.20.16 rule 4"
pattern_context: "Effective classes with Creators part require explicit creation procedure"
```

#### Pattern 1.2: Type Mismatch in Creation

**BNF Violation:**
```
create [Explicit_creation_type] where type does NOT conform to target
```

**Invalid Examples:**
```eiffel
local
    session: MY_SESSION
create {OTHER_TYPE} session  -- Type {OTHER_TYPE} doesn't conform to MY_SESSION
```

**Regex Pattern:**
```regex
create\s+\{([^}]+)\}\s+([A-Za-z_]\w*)  -- Captures type and variable separately
```

**Literal Pattern:**
```
pattern_type: regex
pattern_literal: "create { TYPE }" where TYPE differs from variable declaration type
pattern_description: "Creation type must conform to target - from ECMA-367 8.20.16 rule 2"
pattern_context: "Type conformance checked during creation"
```

---

## PHASE 1B: VOID SAFETY PATTERNS

### Source: ECMA-367 Section 8.11 - Type-Safety (Void Safety)

**BNF Production Rules:**
```
Type = [Attachment_mark] Class_type
Attachment_mark = "?" | "!"
(No mark = same as "!")
```

**Semantic Rules (8.11.18-8.11.23):**
- Types are **attached by default** (no "?")
- Detachable types explicitly marked "?"
- Attached types guarantee non-void values
- Void calls on attached types = VUTA(2) error

### INVALID PATTERNS - Compile Error VUTA(2)

**Error Code:** VUTA(2) - Void safety violation - call on detachable
**Description:** Calling feature on variable that may be void

#### Pattern 2.1: Missing Void Check

**BNF Violation:**
```
Qualified_call target where typeof(target) is detachable but no check performed
```

**Invalid Examples:**
```eiffel
local
    session: detachable ONNX_SESSION
session.initialize  -- ERROR: session may be void

obj: ?MY_TYPE      -- detachable type
obj.do_something   -- ERROR: obj may be void without checking
```

**Valid Examples:**
```eiffel
local
    session: detachable ONNX_SESSION
do
    if attached session then
        session.initialize  -- Safe: checked for non-void
    end
end

if session /= Void then
    session.do_work  -- Safe: void-tested
end

local
    obj: ?MY_TYPE
if {obj: MY_TYPE} obj then  -- Object test
    obj.operate  -- Safe: confirmed attached
end
```

**Regex Pattern:**
```regex
\b([a-z_]\w*)\s*:\s*detachable\b  -- Capture detachable variable name
\b\1\s*\.(?!Void)                -- Reference to that variable without Void check
```

**Literal Pattern:**
```
pattern_type: regex
pattern_literal: detachable variable used without attachment check
pattern_description: "Detachable type requires void check before qualified call - from ECMA-367 8.11.23"
pattern_context: "Void-safety: detachable types must be checked with 'attached', '/= Void', or Object_test"
```

#### Pattern 2.2: Missing Attachment Check

**BNF Violation:**
```
Detachable_entity used in Qualified_call without Certified Attachment Pattern
```

**Invalid Examples:**
```eiffel
x: ?INTEGER
x + 1  -- ERROR: May be void

msg: ?STRING
if msg.length > 0 then  -- ERROR: Need attachment check first
```

**Valid Examples (Certified Attachment Patterns):**
```eiffel
if msg /= Void then
    if msg.length > 0 then  -- Safe within /= Void scope
end

if attached x as l_x then
    -- l_x is guaranteed attached in this scope
    l_x.do_operation
end
```

**Regex Pattern:**
```regex
\b\?\s*\w+.*?\bfeature_call  -- Detachable followed by feature call
```

**Literal Pattern:**
```
pattern_type: regex
pattern_literal: detachable type reference without attachment scope
pattern_description: "Must use CAP (Certified Attachment Pattern) before calling - from ECMA-367 8.11.30"
pattern_context: "Void-safe patterns: if != Void, if attached as, if {type} expr"
```

---

## PHASE 1C: FEATURE CALL PATTERNS

### Source: ECMA-367 Section 8.23 - Calls

**BNF Production Rules:**
```
Call = Qualified_call | Unqualified_call
Qualified_call = target "." feature_name [Actuals]
Unqualified_call = feature_name [Actuals]
```

**Semantic Rule (8.23.6-8.23.7):**
- Qualified call requires target to be **attached** type
- Feature must be **available to caller** (export list)
- Arguments must be **compatible** with formal parameters

### INVALID PATTERNS - Compile Error VEEN

**Error Code:** VEEN - Feature does not exist
**Description:** Calling undefined feature or misspelled name

#### Pattern 3.1: Reference to Undefined Feature

**Invalid Examples:**
```eiffel
session.initalize    -- Typo: should be "initialize"
obj.do_work_please   -- Feature not declared
result.get_items     -- Wrong method name for result type
```

**Valid Examples:**
```eiffel
session.initialize
session.setup
obj.do_work
```

**Regex Pattern:**
```regex
\b([A-Za-z_]\w+)\.([a-z_]\w+)  -- Capture type and feature separately
```

**Literal Pattern:**
```
pattern_type: literal (after type resolution)
pattern_literal: "feature_name" where feature is undefined for type
pattern_description: "Feature does not exist in class - from ECMA-367 8.23"
pattern_context: "Check class definition for feature name and spelling"
```

### INVALID PATTERNS - Compile Error VUAR(1)

**Error Code:** VUAR(1) - Type incompatibility in argument
**Description:** Actual argument doesn't conform to formal parameter

#### Pattern 3.2: Argument Type Mismatch

**Invalid Examples:**
```eiffel
do_operation ("string")       -- Expects INTEGER, got STRING
process_items (3.14)          -- Expects REAL_64, got REAL_32
handle_result ({STRING} "x")  -- Type cast to wrong type
```

**Valid Examples:**
```eiffel
do_operation (42)
process_items ({REAL_32} 3.14)  -- Explicit cast to match
handle_result ({INTEGER} my_int)
```

**Regex Pattern:**
```regex
\.([a-z_]\w+)\s*\(\s*  -- Feature call opening
([^)]*?\w)             -- Argument
\)                     -- Closing
```

**Literal Pattern:**
```
pattern_type: semantic (requires type inference)
pattern_literal: argument value that doesn't conform to parameter type
pattern_description: "Argument type must conform to parameter - from ECMA-367 8.23.7"
pattern_context: "Type compatibility checked at call site"
```

---

## PHASE 1D: TYPE DECLARATION PATTERNS

### Source: ECMA-367 Section 8.11 - Types

**BNF Production Rules:**
```
Type = [Attachment_mark] Class_type | Formal_generic | Anchored_type | Tuple_type
Class_type = Class_name [Actual_generics]
Formal_generic = Formal_generic_name [Constraint]
```

**Semantic Rule (8.11.1 - Type Semantics):**
- Class_type uses simple class names (ONNX_SESSION, STRING, INTEGER)
- Generic classes require actual type parameters: LIST [STRING]
- Formal generics require constraints if used in certain contexts

### INVALID PATTERNS - Compile Error VTCT

**Error Code:** VTCT - Class not found
**Description:** Reference to undefined class name

#### Pattern 4.1: Non-existent Class Reference

**Invalid Examples:**
```eiffel
local
    session: ONNX_SESSION    -- If class doesn't exist or not in library
    wrapper: SIMPLE_ONNX     -- Misspelled or not imported
    helper: HELP_CLASS       -- Class name typo
```

**Valid Examples:**
```eiffel
local
    session: MY_SESSION
    wrapper: SESSION_WRAPPER
    helper: HELPER_CLASS
```

**Literal Pattern:**
```
pattern_type: literal
pattern_literal: Class name that appears in type declaration but class is undefined
pattern_description: "Class does not exist or not in current library - from ECMA-367 8.11"
pattern_context: "Check class declaration, library imports in ECF"
```

#### Pattern 4.2: Generic Type Without Parameters

**Invalid Examples (Context-dependent):**
```eiffel
local
    items: ARRAY           -- ARRAY is generic, needs [TYPE]
    list: LIST             -- LIST is generic, needs [TYPE]
    table: HASH_TABLE      -- Needs [K, V]
```

**Valid Examples:**
```eiffel
local
    items: ARRAY [STRING]
    list: LIST [INTEGER]
    table: HASH_TABLE [STRING, ANY]
```

**Regex Pattern:**
```regex
:\s*(ARRAY|LIST|HASH_TABLE|ARRAYED_LIST|LINKED_LIST)\s*(?!\[)
```

**Literal Pattern:**
```
pattern_type: regex
pattern_literal: Generic class name without actual type parameters
pattern_description: "Generic class requires actual type parameters - from ECMA-367 8.13.1"
pattern_context: "Generic instantiation: CLASS [TYPE] or CLASS [K, V]"
```

---

## PHASE 1E: INHERITANCE AND REDECLARATION PATTERNS

### Source: ECMA-367 Section 8.6 - The Inheritance Relation

**BNF Production Rules:**
```
Inheritance_part = inherit Parent_list
Parent_list = {Parent }*
Parent = Class_name [Formal_generic] [Rename_clause] [Redefine_clause] ...
```

**Semantic Rule (8.6.8-8.6.13):**
- Each parent specifies inherited class
- Features may be **redefined** (change body)
- Features may be **renamed** (change name)
- Feature redefinition must have `redefine` clause

### INVALID PATTERNS - Compile Error VJGC / VJAR

**Error Code:** VJAR - Type mismatch in feature redefinition
**Description:** Redefined feature signature doesn't conform to inherited signature

#### Pattern 5.1: Covariant Argument Without Detachable

**Invalid Examples:**
```eiffel
class CHILD inherit PARENT
    redefine
        process
    end
    process (x: SPECIFIC_TYPE)  -- Covariant redefinition of process (x: GENERAL_TYPE)
end
```

**Valid Examples:**
```eiffel
-- Option 1: Keep same signature
process (x: GENERAL_TYPE)

-- Option 2: Make argument detachable (proper covariance)
process (x: ?SPECIFIC_TYPE)  -- Detachable makes it safe
```

**Literal Pattern:**
```
pattern_type: semantic
pattern_literal: redefined feature with covariant argument that is not detachable
pattern_description: "Covariant arguments must be detachable - from ECMA-367 8.10.5"
pattern_context: "Signature conformance requires ?T for covariant redefinition"
```

#### Pattern 5.2: Missing Redefine Clause

**Invalid Examples:**
```eiffel
class CHILD inherit PARENT
    feature
        parent_feature
            do
                -- New implementation
            end
    end
end
```

**Valid Examples:**
```eiffel
class CHILD inherit PARENT
    redefine
        parent_feature
    end
    feature
        parent_feature
            do
                -- New implementation
            end
    end
end
```

**Regex Pattern:**
```regex
inherit\s+\w+.*?feature\s+(do|is)  -- Feature after inherit without redefine
```

**Literal Pattern:**
```
pattern_type: regex
pattern_literal: Redefined feature without redefine clause in parent part
pattern_description: "Redefined feature must list in redefine clause - from ECMA-367 8.10.16"
pattern_context: "inherit ... redefine feature_name end"
```

---

## PHASE 1F: ASSERTION PATTERNS

### Source: ECMA-367 Section 8.9 - Correctness and Contracts

**BNF Production Rules:**
```
Assertion = {Assertion_clause}*
Assertion_clause = require | ensure | invariant
Old_expression = old expression
```

**Semantic Rule (8.9.8 - Old Expression):**
- `old` expressions only valid in **postconditions**
- Cannot appear in preconditions or invariants
- Must reference stable entities (attributes, function results)

### INVALID PATTERNS - Compile Error VOEC

**Error Code:** VOEC - Invalid old expression
**Description:** Using `old` outside postcondition

#### Pattern 6.1: Old in Precondition

**Invalid Examples:**
```eiffel
process (x: INTEGER)
    require
        valid: old x > 0  -- ERROR: 'old' not in postcondition
```

**Valid Examples:**
```eiffel
process (x: INTEGER)
    require
        valid: x > 0      -- OK: Direct check
    ensure
        changed: x > old x  -- OK: 'old' in postcondition
```

**Regex Pattern:**
```regex
require\s+[^e]*\bold\b  -- 'old' inside require clause
```

**Literal Pattern:**
```
pattern_type: regex
pattern_literal: 'old' expression in require or invariant
pattern_description: "Old expression only valid in postconditions - from ECMA-367 8.9.7"
pattern_context: "Use in postconditions: ensure result = old result + 1"
```

---

## EXTRACTION SUMMARY

| BNF Rule | Error Code | Pattern Type | Regex/Literal | Coverage |
|----------|-----------|--------------|---------------|----------|
| Creation_instruction | VGCC(5) | Regex | `create\s+\{?[^}]*\}?\s*(?!\.)` | Missing .procedure |
| Type Declaration | VUTA(2) | Regex | `detachable.*\.(?!\b(Void\|check)\b)` | Void without check |
| Qualified_call | VEEN | Literal | Feature name | Undefined feature |
| Type conformance | VUAR(1) | Semantic | Arg vs param | Type mismatch |
| Class reference | VTCT | Literal | Class name | Class not found |
| Generic class | VTCT | Regex | `(ARRAY\|LIST)\s*(?!\[)` | Missing generics |
| Redefinition | VJAR | Semantic | Signature | Wrong signature |
| Redefine clause | VJAR | Regex | `inherit.*feature.*(?!redefine)` | Missing redefine |
| Old expression | VOEC | Regex | `require\s+.*\bold\b` | Old outside ensure |

---

## NEXT STEPS

### Phase 1 (This Phase) - COMPLETE
✅ Extract BNF production rules from ECMA-367
✅ Map to error codes (VGCC, VUTA, VEEN, VUAR, VTCT, VJAR, VOEC)
✅ Generate regex patterns
✅ Document validation rules

### Phase 2 - Populate Oracle Database
- [ ] Create FAILURE_PATTERN_EXTRACTOR enhancements
- [ ] Add BNF patterns to failure_records table
- [ ] Test pattern matching against known failures

### Phase 3 - Validation & Testing
- [ ] Test against real Eiffel error samples
- [ ] Verify patterns catch errors BEFORE compile
- [ ] Measure false positive rate

---

## USAGE IN ORACLE GATE

Once Phase 2 is complete, these patterns will be used in `check_code_pattern()`:

```eiffel
check_code_pattern (a_code: STRING; a_library: STRING): LIST
    -- Check code against BNF-derived patterns
    -- Returns list of flagged patterns with explanations
end
```

**Example Output:**
```
Code flagged: 2 BNF pattern violations found

[1] VGCC Pattern Violation
    Issue: Creation instruction missing procedure call
    Location: create session
    Rule: ECMA-367 8.20.16 rule 4 - Effective classes with Creators part require explicit procedure
    Fix: change to: create session.make

[2] VUTA Pattern Violation
    Issue: Calling feature on potentially void object
    Location: result.process
    Type: detachable
    Rule: ECMA-367 8.11.23 - Detachable must use Certified Attachment Pattern
    Fix: Wrap in: if attached result then result.process end
```

---

**Document Version:** 1.0
**Last Updated:** 2026-02-01
**Status:** Ready for Phase 2 implementation
