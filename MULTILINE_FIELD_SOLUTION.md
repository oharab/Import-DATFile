# Multi-Line Field Handling

## Problem
The current code uses `Get-Content` which treats every newline as a record separator. If fields contain embedded carriage returns or newlines, the import will fail.

## Current Behavior
```powershell
$lines = Get-Content -Path $FilePath
foreach ($line in $lines) {
    $values = $line -split '\|'
    # This fails if a field spans multiple lines
}
```

## Solution Options

### Option 1: Quote-Aware Parsing (Best for CSV-like files)
If your .dat files use quotes around fields with newlines:
```
"ID001"|"John"|"123 Main St
Building A"|"City"|"12345"
```

Use CSV parser:
```powershell
$data = Import-Csv -Path $FilePath -Delimiter '|' -Header $headers
```

### Option 2: Read Raw and Smart Split (Best for database exports)
If your database exports escape newlines as literal \n or \r\n:
```
ID001|John|123 Main St\nBuilding A|City|12345
```

Current code will work fine - the \n is just text.

### Option 3: Field Count-Based Reconstruction (Complex but robust)
Read raw file and reconstruct records based on expected field count:
```powershell
# Read entire file as single string
$rawContent = [System.IO.File]::ReadAllText($FilePath)

# Split by pipe first, then reconstruct records
$allFields = $rawContent -split '\|'

# Group fields by expected count to rebuild records
$records = @()
$currentRecord = @()
foreach ($field in $allFields) {
    $currentRecord += $field
    if ($currentRecord.Count -eq $expectedFieldCount) {
        $records += ,@($currentRecord)
        $currentRecord = @()
    }
}
```

### Option 4: Custom Record Delimiter
If possible, modify the export to use a unique record delimiter that won't appear in data:
```
ID001|John|123 Main St
Building A|City|12345~~RECORD~~
ID002|Jane|456 Oak Ave|City2|67890~~RECORD~~
```

Then split on `~~RECORD~~` instead of newlines.

## Recommended Approach for This Codebase

Since the data is described as "database exports" that are pipe-separated, the most likely scenarios are:

1. **Newlines are escaped**: \n or \r\n appear as literal text (CURRENT CODE WORKS)
2. **No multi-line fields**: Database exports typically don't include actual newlines (CURRENT CODE WORKS)
3. **Actual embedded newlines**: Rare but possible (CURRENT CODE FAILS)

## Detection Strategy

Add detection logic to identify if this is an issue:
```powershell
# Count total pipes in file
$fileContent = Get-Content -Path $FilePath -Raw
$pipeCount = ($fileContent -split '\|').Count - 1

# Count lines
$lineCount = (Get-Content -Path $FilePath).Count

# Expected: (lineCount * (expectedFieldCount - 1)) pipes
# If pipe count matches, no multi-line fields
# If pipe count is higher, multi-line fields exist
```

## Immediate Workaround for Users

If import fails with field count mismatch and you suspect embedded newlines:

1. **Pre-process the data file**:
   ```powershell
   # Replace actual newlines within records with escaped version
   (Get-Content -Raw $file) -replace '([^\|])\r?\n([^\|])', '$1\n$2' | Set-Content $file
   ```

2. **Or remove embedded newlines**:
   ```powershell
   (Get-Content $file) -replace '\r?\n', ' ' | Set-Content $file
   ```

3. **Or use SQL to export without newlines**:
   ```sql
   SELECT REPLACE(REPLACE(field, CHAR(13), ' '), CHAR(10), ' ')
   ```
