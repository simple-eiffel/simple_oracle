#!/bin/bash

# Oracle Gate Helper Script
# Purpose: Simplified oracle gate workflow for Eiffel code generation
# Usage: ./oracle-gate.sh check <code-file> <library>
#        ./oracle-gate.sh regenerate <code-file> <library>

ORACLE_CLI="/d/prod/simple_oracle/EIFGENs/simple_oracle_cli/W_code/simple_oracle.exe"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function: Check code against oracle
check_code() {
    local code_file=$1
    local library=$2

    if [ ! -f "$code_file" ]; then
        echo -e "${RED}Error: Code file not found: $code_file${NC}"
        return 1
    fi

    if [ -z "$library" ]; then
        echo -e "${RED}Error: Library name required${NC}"
        return 1
    fi

    echo -e "${YELLOW}Checking code against oracle patterns...${NC}"

    # Run oracle check
    "$ORACLE_CLI" check-code "$code_file" "$library" 2>&1 | grep -v "Thread exception" | grep -v "Class / Object" | grep -v "^---" | grep -v "^In thread"

    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ Code approved by oracle - safe to write${NC}"
        return 0
    else
        echo -e "${RED}✗ Code flagged by oracle - patterns detected${NC}"
        return 1
    fi
}

# Function: Check code from stdin
check_stdin() {
    local library=$1
    local temp_file="/tmp/oracle_check_$$.txt"

    if [ -z "$library" ]; then
        echo -e "${RED}Error: Library name required${NC}"
        return 1
    fi

    echo -e "${YELLOW}Checking stdin code against oracle patterns...${NC}"

    # Read stdin to temp file
    cat > "$temp_file"

    # Check the temp file
    "$ORACLE_CLI" check-code "$temp_file" "$library" 2>&1 | grep -v "Thread exception" | grep -v "Class / Object" | grep -v "^---" | grep -v "^In thread"

    local exit_code=$?

    # Clean up
    rm -f "$temp_file"

    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ Code approved by oracle - safe to write${NC}"
        return 0
    else
        echo -e "${RED}✗ Code flagged by oracle - patterns detected${NC}"
        return 1
    fi
}

# Function: Show available patterns
show_patterns() {
    echo "Available oracle patterns:"
    echo "  - VGCC(5): Missing creation call (.make)"
    echo "  - VUTA(2): Void safety violations"
    echo "  - VTCT: Undefined class references"
    echo "  - VJAR: Type mismatches and missing redefine"
    echo "  - VEEN: Undefined feature calls"
    echo "  - VUEN: Undefined variable assignments"
}

# Main
case "$1" in
    check)
        if [ "$2" = "-" ] || [ "$2" = "stdin" ]; then
            # Read from stdin
            check_stdin "$3"
        else
            # Check file
            check_code "$2" "$3"
        fi
        ;;
    patterns)
        show_patterns
        ;;
    help)
        echo "Oracle Gate Helper Script"
        echo ""
        echo "Usage:"
        echo "  ./oracle-gate.sh check <file> <library>     Check code file"
        echo "  ./oracle-gate.sh check stdin <library>      Check code from stdin"
        echo "  ./oracle-gate.sh patterns                   List available patterns"
        echo "  ./oracle-gate.sh help                       Show this help"
        echo ""
        echo "Example:"
        echo "  echo 'create session' | ./oracle-gate.sh check stdin simple_sculptor"
        echo ""
        echo "Integration:"
        echo "  CODE=\$(your_code_generator)"
        echo "  if echo \"\$CODE\" | ./oracle-gate.sh check stdin \$LIB; then"
        echo "      echo \"\$CODE\" > target_file.e"
        echo "  else"
        echo "      echo 'Regenerate code - oracle flagged patterns'"
        echo "  fi"
        ;;
    *)
        echo "Usage: ./oracle-gate.sh {check|patterns|help}"
        echo "Run './oracle-gate.sh help' for more information"
        exit 1
        ;;
esac
