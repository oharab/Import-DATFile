# Import-DATFile.Constants.ps1
# Configuration constants for the Import-DATFile system
# Centralizes magic numbers and configuration values for maintainability

# Bulk Copy Settings
$script:BULK_COPY_BATCH_SIZE = 10000
$script:BULK_COPY_TIMEOUT_SECONDS = 300

# SQL Command Settings
$script:SQL_COMMAND_TIMEOUT_SECONDS = 300

# Progress Reporting
$script:PROGRESS_REPORT_INTERVAL = 10000

# Display and Preview Settings
$script:PREVIEW_TEXT_LENGTH = 200

# Date and Time Formats
# Order matters - more specific formats should come first
$script:SUPPORTED_DATE_FORMATS = @(
    "yyyy-MM-dd HH:mm:ss.fff",
    "yyyy-MM-dd HH:mm:ss.ff",
    "yyyy-MM-dd HH:mm:ss.f",
    "yyyy-MM-dd HH:mm:ss",
    "yyyy-MM-dd"
)

# NULL Value Representations (case-insensitive)
$script:NULL_REPRESENTATIONS = @('NULL', 'NA', 'N/A')

# Boolean Value Mappings (case-insensitive)
$script:BOOLEAN_TRUE_VALUES = @('1', 'TRUE', 'YES', 'Y', 'T')
$script:BOOLEAN_FALSE_VALUES = @('0', 'FALSE', 'NO', 'N', 'F')

# Schema Name Validation Pattern
$script:SCHEMA_NAME_PATTERN = '^[a-zA-Z0-9_]+$'

# Export constants for use in other modules
Export-ModuleMember -Variable @(
    'BULK_COPY_BATCH_SIZE',
    'BULK_COPY_TIMEOUT_SECONDS',
    'SQL_COMMAND_TIMEOUT_SECONDS',
    'PROGRESS_REPORT_INTERVAL',
    'PREVIEW_TEXT_LENGTH',
    'SUPPORTED_DATE_FORMATS',
    'NULL_REPRESENTATIONS',
    'BOOLEAN_TRUE_VALUES',
    'BOOLEAN_FALSE_VALUES',
    'SCHEMA_NAME_PATTERN'
)
