#!/bin/bash

# Configuration
BASE_URL="http://localhost:3000"
VALID_TOKEN="your_secure_token"
INVALID_TOKEN="invalid_token"
VERBOSE=false

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -v|--verbose) VERBOSE=true ;;
    *) echo "Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to print section header
print_header() {
  echo -e "\n${BLUE}$1${NC}\n"
}

# Function to print command preview
print_command() {
  echo -e "${YELLOW}Running: $1${NC}"
}

# Function to execute curl with optional verbose mode
run_curl() {
  local curl_cmd="$1"
  
  if [ "$VERBOSE" = true ]; then
    # Add --trace-ascii - to the curl command
    curl_cmd="${curl_cmd/curl/curl --trace-ascii -}"
  fi
  
  # Execute the command
  eval "$curl_cmd"
}

# Function to print test result
print_result() {
  local test_name=$1
  local status_code=$2
  local response=$3
  local expected_code=$4
  
  if [ "$status_code" -eq "$expected_code" ]; then
    echo -e "${GREEN}✓ PASS${NC} - $test_name (Status: $status_code)"
  else
    echo -e "${RED}✗ FAIL${NC} - $test_name (Status: $status_code, Expected: $expected_code)"
  fi
  echo "$response" | jq . 2>/dev/null || echo "$response"
  echo "-----------------------------------"
}

# Create a temporary directory for test files
mkdir -p test_files
echo "Test content" > test_files/test.txt

echo -e "${BLUE}Running tests with verbose mode: $VERBOSE${NC}"

# 🔐 Authentication Tests
print_header "🔐 Authentication Tests"

# Test: Reject requests with no Authorization header (401)
cmd="curl -s -w \"\n%{http_code}\" -X GET \"$BASE_URL/list\""
print_command "$cmd"
response=$(run_curl "$cmd")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')
print_result "Reject requests with no Authorization header" "$status_code" "$response_body" 401

# Test: Reject requests with invalid token (401)
cmd="curl -s -w \"\n%{http_code}\" -X GET \"$BASE_URL/list\" -H \"Authorization: Bearer $INVALID_TOKEN\""
print_command "$cmd"
response=$(run_curl "$cmd")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')
print_result "Reject requests with invalid token" "$status_code" "$response_body" 401

# Test: Accept requests with valid token
cmd="curl -s -w \"\n%{http_code}\" -X GET \"$BASE_URL/list\" -H \"Authorization: Bearer $VALID_TOKEN\""
print_command "$cmd"
response=$(run_curl "$cmd")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')
print_result "Accept requests with valid token" "$status_code" "$response_body" 200

# 🛡 Path Security Tests
print_header "🛡 Path Security Tests"

# Test: Reject folder creation with ../ (400)
cmd="curl -s -w \"\n%{http_code}\" -X POST \"$BASE_URL/mkdir\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\" \\
  -H \"Content-Type: application/json\" \\
  -d '{\"folder\": \"../test\"}'"
print_command "$cmd"
response=$(run_curl "$cmd")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')
print_result "Reject folder creation with ../" "$status_code" "$response_body" 400

# Test: Reject folder creation with leading . (400)
cmd="curl -s -w \"\n%{http_code}\" -X POST \"$BASE_URL/mkdir\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\" \\
  -H \"Content-Type: application/json\" \\
  -d '{\"folder\": \".hidden\"}'"
print_command "$cmd"
response=$(run_curl "$cmd")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')
print_result "Reject folder creation with leading ." "$status_code" "$response_body" 400

# Test: Reject folder creation with / or \ inside the name (400)
cmd="curl -s -w \"\n%{http_code}\" -X POST \"$BASE_URL/mkdir\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\" \\
  -H \"Content-Type: application/json\" \\
  -d '{\"folder\": \"test/folder\"}'"
print_command "$cmd"
response=$(run_curl "$cmd")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')
print_result "Reject folder creation with / inside the name" "$status_code" "$response_body" 400

# Test: Reject filename with ../ or path traversal (400)
cmd="curl -s -w \"\n%{http_code}\" -X POST \"$BASE_URL/upload\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\" \\
  -H \"Content-Type: application/json\" \\
  -d '{\"folder\": \"test-folder\", \"filename\": \"../test.txt\", \"base64\": \"VGVzdCBjb250ZW50\", \"expose\": true}'"
print_command "$cmd"
response=$(run_curl "$cmd")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')
print_result "Reject filename with ../ or path traversal" "$status_code" "$response_body" 400

# Test: Reject filename with leading . (400)
cmd="curl -s -w \"\n%{http_code}\" -X POST \"$BASE_URL/upload\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\" \\
  -H \"Content-Type: application/json\" \\
  -d '{\"folder\": \"test-folder\", \"filename\": \".hidden.txt\", \"base64\": \"VGVzdCBjb250ZW50\", \"expose\": true}'"
print_command "$cmd"
response=$(run_curl "$cmd")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')
print_result "Reject filename with leading ." "$status_code" "$response_body" 400

# 📤 Upload Endpoint Tests
print_header "📤 Upload Endpoint Tests"

# Test: Base64 upload works and returns correct URL
cmd="curl -s -w \"\n%{http_code}\" -X POST \"$BASE_URL/upload\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\" \\
  -H \"Content-Type: application/json\" \\
  -d '{\"folder\": \"test-upload\", \"filename\": \"test.txt\", \"base64\": \"VGVzdCBjb250ZW50\", \"expose\": true}'"
print_command "$cmd"
response=$(run_curl "$cmd")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')
print_result "Base64 upload works and returns correct URL" "$status_code" "$response_body" 200

# Test: Binary upload works with X-Folder, X-Filename, and X-Expose
cmd="curl -s -w \"\n%{http_code}\" -X POST \"$BASE_URL/upload\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\" \\
  -H \"Content-Type: application/octet-stream\" \\
  -H \"X-Folder: test-binary\" \\
  -H \"X-Filename: binary.txt\" \\
  -H \"X-Expose: true\" \\
  --data-binary @test_files/test.txt"
print_command "$cmd"
response=$(run_curl "$cmd")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')
print_result "Binary upload works with X-Folder, X-Filename, and X-Expose" "$status_code" "$response_body" 200

# Test: Binary upload fails if required headers are missing (400)
cmd="curl -s -w \"\n%{http_code}\" -X POST \"$BASE_URL/upload\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\" \\
  -H \"Content-Type: application/octet-stream\" \\
  -H \"X-Folder: test-binary\" \\
  --data-binary @test_files/test.txt"
print_command "$cmd"
response=$(run_curl "$cmd")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')
print_result "Binary upload fails if required headers are missing" "$status_code" "$response_body" 400

# Test: Upload auto-creates folder if missing
cmd="curl -s -w \"\n%{http_code}\" -X POST \"$BASE_URL/upload\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\" \\
  -H \"Content-Type: application/json\" \\
  -d '{\"folder\": \"auto-created\", \"filename\": \"test.txt\", \"base64\": \"VGVzdCBjb250ZW50\", \"expose\": false}'"
print_command "$cmd"
response=$(run_curl "$cmd")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')
print_result "Upload auto-creates folder if missing" "$status_code" "$response_body" 200

# Test: Upload exposes folder when expose: true
cmd="curl -s -w \"\n%{http_code}\" -X POST \"$BASE_URL/upload\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\" \\
  -H \"Content-Type: application/json\" \\
  -d '{\"folder\": \"exposed-folder\", \"filename\": \"test.txt\", \"base64\": \"VGVzdCBjb250ZW50\", \"expose\": true}'"
print_command "$cmd"
response=$(run_curl "$cmd")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')
print_result "Upload exposes folder when expose: true" "$status_code" "$response_body" 200

# 📂 Folder + File Operations Tests
print_header "📂 Folder + File Operations Tests"

# Test: Can create a folder via /mkdir (hidden)
cmd="curl -s -w \"\n%{http_code}\" -X POST \"$BASE_URL/mkdir\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\" \\
  -H \"Content-Type: application/json\" \\
  -d '{\"folder\": \"test-hidden\"}'"
print_command "$cmd"
response=$(run_curl "$cmd")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')
print_result "Can create a folder via /mkdir (hidden)" "$status_code" "$response_body" 200

# Test: Can create a folder via /mkdir (exposed)
cmd="curl -s -w \"\n%{http_code}\" -X POST \"$BASE_URL/mkdir\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\" \\
  -H \"Content-Type: application/json\" \\
  -d '{\"folder\": \"test-exposed\", \"expose\": true}'"
print_command "$cmd"
response=$(run_curl "$cmd")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')
print_result "Can create a folder via /mkdir (exposed)" "$status_code" "$response_body" 200

# Test: Can list all folders via /list
cmd="curl -s -w \"\n%{http_code}\" -X GET \"$BASE_URL/list\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\""
print_command "$cmd"
response=$(run_curl "$cmd")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')
print_result "Can list all folders via /list" "$status_code" "$response_body" 200

# Test: Can list folder contents via /list/:folder
cmd="curl -s -w \"\n%{http_code}\" -X GET \"$BASE_URL/list/test-upload\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\""
print_command "$cmd"
response=$(run_curl "$cmd")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')
print_result "Can list folder contents via /list/:folder" "$status_code" "$response_body" 200

# Test: Listing a non-existent folder returns 404
cmd="curl -s -w \"\n%{http_code}\" -X GET \"$BASE_URL/list/nonexistent-folder\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\""
print_command "$cmd"
response=$(run_curl "$cmd")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')
print_result "Listing a non-existent folder returns 404" "$status_code" "$response_body" 404

# Test: Can rename a file
# First upload a file to rename
upload_cmd="curl -s -X POST \"$BASE_URL/upload\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\" \\
  -H \"Content-Type: application/json\" \\
  -d '{\"folder\": \"rename-test\", \"filename\": \"original.txt\", \"base64\": \"VGVzdCBjb250ZW50\", \"expose\": true}'"
print_command "First: $upload_cmd"
run_curl "$upload_cmd > /dev/null"

# Then rename it
cmd="curl -s -w \"\n%{http_code}\" -X PATCH \"$BASE_URL/rename\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\" \\
  -H \"Content-Type: application/json\" \\
  -d '{\"type\": \"file\", \"folder\": \"rename-test\", \"filename\": \"original.txt\", \"newName\": \"renamed.txt\"}'"
print_command "Then: $cmd"
response=$(run_curl "$cmd")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')
print_result "Can rename a file" "$status_code" "$response_body" 200

# Test: Renaming a file with bad path returns 400
cmd="curl -s -w \"\n%{http_code}\" -X PATCH \"$BASE_URL/rename\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\" \\
  -H \"Content-Type: application/json\" \\
  -d '{\"type\": \"file\", \"folder\": \"rename-test\", \"filename\": \"renamed.txt\", \"newName\": \"../bad.txt\"}'"
print_command "$cmd"
response=$(run_curl "$cmd")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')
print_result "Renaming a file with bad path returns 400" "$status_code" "$response_body" 400

# Test: Can delete a file
cmd="curl -s -w \"\n%{http_code}\" -X DELETE \"$BASE_URL/delete/rename-test/renamed.txt\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\""
print_command "$cmd"
response=$(run_curl "$cmd")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')
print_result "Can delete a file" "$status_code" "$response_body" 200

# Test: Can delete a folder and all contents
cmd="curl -s -w \"\n%{http_code}\" -X DELETE \"$BASE_URL/delete/rename-test\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\""
print_command "$cmd"
response=$(run_curl "$cmd")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')
print_result "Can delete a folder and all contents" "$status_code" "$response_body" 200

# 🌐 Public File Access Tests
print_header "🌐 Public File Access Tests"

# Test: Uploaded and exposed file is served at /public/:folder/:filename
# First, create a file to test
upload_cmd="curl -s -X POST \"$BASE_URL/upload\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\" \\
  -H \"Content-Type: application/json\" \\
  -d '{\"folder\": \"public-test\", \"filename\": \"public.txt\", \"base64\": \"VGVzdCBjb250ZW50\", \"expose\": true}'"
print_command "First: $upload_cmd"
run_curl "$upload_cmd > /dev/null"

# Then try to access it
cmd="curl -s -w \"\n%{http_code}\" -X GET \"$BASE_URL/public/public-test/public.txt\""
print_command "Then: $cmd"
response=$(run_curl "$cmd")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')
if [ "$status_code" -eq 200 ] && [ "$response_body" = "Test content" ]; then
  echo -e "${GREEN}✓ PASS${NC} - Uploaded and exposed file is served at /public/:folder/:filename (Status: $status_code)"
else
  echo -e "${RED}✗ FAIL${NC} - Uploaded and exposed file is served at /public/:folder/:filename (Status: $status_code)"
fi
echo "Content: $response_body"
echo "-----------------------------------"

# Test: Accessing /public/../.env or similar is blocked or returns 404
cmd="curl -s -w \"\n%{http_code}\" -X GET \"$BASE_URL/public/../.env\""
print_command "$cmd"
response=$(run_curl "$cmd")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')
print_result "Accessing /public/../.env or similar is blocked or returns 404" "$status_code" "$response_body" 404

# Test: Accessing an unexposed file returns 404
# First, create an unexposed file (explicitly set expose to false)
upload_cmd="curl -s -X POST \"$BASE_URL/upload\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\" \\
  -H \"Content-Type: application/json\" \\
  -d '{\"folder\": \"private-test\", \"filename\": \"private.txt\", \"base64\": \"UHJpdmF0ZSBjb250ZW50\", \"expose\": false}'"
print_command "First: $upload_cmd"
run_curl "$upload_cmd > /dev/null"

# Then unexpose the folder to ensure it's in the private directory
unexpose_cmd="curl -s -X POST \"$BASE_URL/unexpose/private-test\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\""
print_command "Then: $unexpose_cmd"
run_curl "$unexpose_cmd > /dev/null"

# Then try to access it
cmd="curl -s -w \"\n%{http_code}\" -X GET \"$BASE_URL/public/private-test/private.txt\""
print_command "Finally: $cmd"
response=$(run_curl "$cmd")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')
print_result "Accessing an unexposed file returns 404" "$status_code" "$response_body" 404

# 🔄 Exposure Toggle Tests
print_header "🔄 Exposure Toggle Tests"

# Test: /expose/:folder makes an existing folder public
# First, create a hidden folder
create_cmd="curl -s -X POST \"$BASE_URL/mkdir\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\" \\
  -H \"Content-Type: application/json\" \\
  -d '{\"folder\": \"toggle-test\"}'"
print_command "First: $create_cmd"
run_curl "$create_cmd > /dev/null"

# Then expose it
cmd="curl -s -w \"\n%{http_code}\" -X POST \"$BASE_URL/expose/toggle-test\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\""
print_command "Then: $cmd"
response=$(run_curl "$cmd")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')
print_result "/expose/:folder makes an existing folder public" "$status_code" "$response_body" 200

# Test: /unexpose/:folder removes public access
cmd="curl -s -w \"\n%{http_code}\" -X POST \"$BASE_URL/unexpose/toggle-test\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\""
print_command "$cmd"
response=$(run_curl "$cmd")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')
print_result "/unexpose/:folder removes public access" "$status_code" "$response_body" 200

# Test: Listing a folder reflects correct visibility and url field in JSON
# First, expose the folder again
expose_cmd="curl -s -X POST \"$BASE_URL/expose/toggle-test\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\""
print_command "First: $expose_cmd"
run_curl "$expose_cmd > /dev/null"

# Then list it
cmd="curl -s -w \"\n%{http_code}\" -X GET \"$BASE_URL/list/toggle-test\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\""
print_command "Then: $cmd"
response=$(run_curl "$cmd")
status_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed '$d')
print_result "Listing a folder reflects correct visibility and url field in JSON" "$status_code" "$response_body" 200

# 📈 JSON Response Consistency Tests
print_header "📈 JSON Response Consistency Tests"

# Test: Every successful response includes required fields
echo "Checking JSON response consistency for successful requests..."
cmd="curl -s -X POST \"$BASE_URL/mkdir\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\" \\
  -H \"Content-Type: application/json\" \\
  -d '{\"folder\": \"json-test\"}'"
print_command "$cmd"
response=$(run_curl "$cmd")

# Check for required fields
has_status=$(echo "$response" | jq 'has("status")' 2>/dev/null)
has_action=$(echo "$response" | jq 'has("action")' 2>/dev/null)
has_visibility=$(echo "$response" | jq 'has("visibility")' 2>/dev/null)
has_url=$(echo "$response" | jq 'has("url")' 2>/dev/null)
has_folder=$(echo "$response" | jq 'has("folder")' 2>/dev/null)
has_file=$(echo "$response" | jq 'has("file")' 2>/dev/null)

if [ "$has_status" = "true" ] && [ "$has_action" = "true" ] && [ "$has_visibility" = "true" ] && [ "$has_url" = "true" ] && [ "$has_folder" = "true" ] && [ "$has_file" = "true" ]; then
  echo -e "${GREEN}✓ PASS${NC} - Every successful response includes required fields"
else
  echo -e "${RED}✗ FAIL${NC} - Missing required fields in successful response"
fi
echo "$response" | jq . 2>/dev/null || echo "$response"
echo "-----------------------------------"

# Test: Every error response includes required fields
echo "Checking JSON response consistency for error requests..."
cmd="curl -s -X GET \"$BASE_URL/list/nonexistent-folder-json-test\" \\
  -H \"Authorization: Bearer $VALID_TOKEN\""
print_command "$cmd"
response=$(run_curl "$cmd")

# Check for required fields
has_status=$(echo "$response" | jq 'has("status")' 2>/dev/null)
has_message=$(echo "$response" | jq 'has("message")' 2>/dev/null)

if [ "$has_status" = "true" ] && [ "$has_message" = "true" ]; then
  echo -e "${GREEN}✓ PASS${NC} - Every error response includes required fields"
else
  echo -e "${RED}✗ FAIL${NC} - Missing required fields in error response"
fi
echo "$response" | jq . 2>/dev/null || echo "$response"
echo "-----------------------------------"

# Clean up test files
rm -rf test_files

echo -e "\n${BLUE}All tests completed!${NC}"
