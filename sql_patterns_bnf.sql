-- ============================================================================
-- BNF Pattern Population for Oracle Gate
-- Date: 2026-02-01
-- ============================================================================

-- PATTERN SET 1: VGCC(5) - Missing Creation Call
INSERT INTO failure_records (
    failure_type, error_code, pattern_regex, pattern_literal,
    pattern_description, pattern_context, library, resolved
) VALUES
(
    'compile_error',
    'VGCC(5)',
    'create\s+\{[^}]+\}\s*(?!\.)',
    'create_without_dot',
    'Creation instruction missing procedure call - ECMA-367 8.20.16 rule 4',
    'Effective classes with Creators part require explicit creation procedure',
    'all_libraries',
    0
),
(
    'compile_error',
    'VGCC(5)',
    'create\s+[A-Za-z_]\w*\s*(?!\.)',
    'bare_create_var',
    'Bare create without type or procedure - ECMA-367 8.20.11 syntax',
    'Must use: create variable.procedure or create {TYPE}.procedure',
    'all_libraries',
    0
);

-- PATTERN SET 2: VUTA(2) - Void Safety Violation
INSERT INTO failure_records (
    failure_type, error_code, pattern_regex, pattern_literal,
    pattern_description, pattern_context, library, resolved
) VALUES
(
    'compile_error',
    'VUTA(2)',
    ':\s*detachable\b',
    'detachable_declared',
    'Detachable type declared - ECMA-367 8.11.19 (requires void check)',
    'Detachable must use Certified Attachment Pattern before qualified call',
    'all_libraries',
    0
),
(
    'compile_error',
    'VUTA(2)',
    'require\s+[^e]*\bold\b',
    'old_in_require',
    'Old expression in require clause - ECMA-367 8.9.7 VIOLATION',
    'Old expressions only valid in postconditions (ensure)',
    'all_libraries',
    0
);

-- PATTERN SET 3: VTCT - Class Not Found
INSERT INTO failure_records (
    failure_type, error_code, pattern_regex, pattern_literal,
    pattern_description, pattern_context, library, resolved
) VALUES
(
    'compile_error',
    'VTCT',
    ':\s*(ONNX_SESSION|NONEXISTENT_CLASS|UNDEFINED_CLASS)\b',
    'undefined_class',
    'Reference to undefined class - ECMA-367 8.11 TYPE RULE',
    'Check class exists in library. Verify ECF includes required libraries.',
    'all_libraries',
    0
),
(
    'compile_error',
    'VTCT',
    ':\s*(ARRAY|LIST|HASH_TABLE|LINKED_LIST)\s*(?!\[)',
    'generic_without_params',
    'Generic class without actual type parameters - ECMA-367 8.13.1',
    'Generic syntax: CLASS [TYPE] or CLASS [K, V]',
    'all_libraries',
    0
);

-- PATTERN SET 4: VJAR - Type Mismatch
INSERT INTO failure_records (
    failure_type, error_code, pattern_regex, pattern_literal,
    pattern_description, pattern_context, library, resolved
) VALUES
(
    'compile_error',
    'VJAR',
    'inherit\s+\w+.*?feature',
    'redefine_without_clause',
    'Redefined feature missing redefine clause - ECMA-367 8.10.16 RULE',
    'Parent part must include: redefine feature_name end',
    'all_libraries',
    0
);

-- PATTERN SET 5: VEEN - Undefined Feature
INSERT INTO failure_records (
    failure_type, error_code, pattern_regex, pattern_literal,
    pattern_description, pattern_context, library, resolved
) VALUES
(
    'compile_error',
    'VEEN',
    '\.([a-z_]\w+)\s*\(',
    'feature_call_undefined',
    'Feature name does not exist or is undefined - ECMA-367 8.23 CALL RULE',
    'Check class definition. Verify feature exists and is exported.',
    'all_libraries',
    0
);

-- PATTERN SET 6: VUEN - Unknown identifier
INSERT INTO failure_records (
    failure_type, error_code, pattern_regex, pattern_literal,
    pattern_description, pattern_context, library, resolved
) VALUES
(
    'compile_error',
    'VUEN',
    '[A-Za-z_]\w*\s*:=\s*',
    'assignment_to_unknown',
    'Assignment to undefined variable - ECMA-367 8.8.2 ENTITY DECLARATION',
    'Declare variable before assignment. Check spelling and scope.',
    'all_libraries',
    0
);

-- ============================================================================
-- END BNF Pattern Population
-- ============================================================================
