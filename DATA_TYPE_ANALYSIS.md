# Data Type Conversion Issues and Recommendations

## Current Issues Identified

### 1. DateTime Parsing (CRITICAL)
**Problem**: Using `[DateTime]::Parse()` which is culture-dependent
```powershell
# Current code - culture dependent
$dataRow[$fieldName] = [DateTime]::Parse($value)
```

**Issues**:
- May interpret dates differently based on server locale
- Format "yyyy-mm-dd hh:mm:ss.mmm" might not parse correctly in all cultures
- Ambiguous dates (e.g., 01/02/2024) could be interpreted as Jan 2 or Feb 1

**Recommended Fix**: Use `ParseExact` with InvariantCulture
```powershell
$dataRow[$fieldName] = [DateTime]::ParseExact($value, "yyyy-MM-dd HH:mm:ss.fff", [System.Globalization.CultureInfo]::InvariantCulture)
```

### 2. Decimal/Money Parsing (HIGH)
**Problem**: Using `[Decimal]::Parse()` which is culture-dependent

**Issues**:
- Decimal separator varies by culture (. vs ,)
- Value "123.45" might be interpreted as "123,45" or fail entirely
- Thousands separators cause issues
- Currency symbols will cause parse failures

**Recommended Fix**: Use InvariantCulture
```powershell
$dataRow[$fieldName] = [Decimal]::Parse($value, [System.Globalization.CultureInfo]::InvariantCulture)
```

### 3. Integer Parsing with Decimals (MEDIUM)
**Problem**: `[Int32]::Parse()` fails if value has decimal point

**Issues**:
- Value "123.0" from database export will fail
- Value "123.00" will fail
- Need to handle decimal notation gracefully

**Recommended Fix**: Parse as decimal first, then convert
```powershell
$dataRow[$fieldName] = [Int32][Decimal]::Parse($value, [System.Globalization.CultureInfo]::InvariantCulture)
```

### 4. SMALLINT/TINYINT Range Issues (LOW)
**Problem**: Mapped to [System.Int32] which allows values outside valid range

**Issues**:
- SMALLINT: -32,768 to 32,767 (but Int32 allows -2.1B to 2.1B)
- TINYINT: 0 to 255 (but Int32 allows negative and much larger)
- SqlBulkCopy might accept invalid values

**Impact**: Low - SqlBulkCopy should catch range errors

### 5. FLOAT/REAL Type Mapping (MEDIUM)
**Problem**: FLOAT and REAL mapped to [System.Decimal] instead of floating-point types

**Issues**:
- FLOAT should map to [System.Double]
- REAL should map to [System.Single]
- Decimal has different precision characteristics
- Scientific notation (1.23E+10) may not parse correctly

**Recommended Fix**:
```powershell
"^FLOAT$|^DOUBLE.*" { return [System.Double] }
"^REAL$" { return [System.Single] }
"^DECIMAL.*|^NUMERIC.*|^MONEY$" { return [System.Decimal] }
```

### 6. NULL Handling (LOW)
**Problem**: Only checks for empty string or "NULL" (case-sensitive)

**Issues**:
- "null", "Null", "nULl" won't be recognized
- Whitespace-only strings treated as data
- "NA", "N/A" common in exports not handled

**Current Code**:
```powershell
if ([string]::IsNullOrEmpty($value) -or $value -eq "NULL")
```

**Recommended Fix**:
```powershell
if ([string]::IsNullOrWhiteSpace($value) -or $value -match '^(NULL|NA|N/A)$' -i)
```

### 7. CHAR vs VARCHAR (LOW)
**Problem**: CHAR fields should be right-padded with spaces

**Impact**: SqlBulkCopy should handle this, but may cause comparison issues

## Priority Recommendations

### MUST FIX (Production Issues Likely):
1. **DateTime parsing** - Use ParseExact with InvariantCulture
2. **Decimal parsing** - Use InvariantCulture

### SHOULD FIX (Edge Cases):
3. **Integer with decimals** - Handle "123.0" format
4. **FLOAT/REAL types** - Use proper floating-point types
5. **NULL handling** - Case-insensitive and whitespace handling

### NICE TO HAVE:
6. **SMALLINT/TINYINT** - Add range validation (probably not needed)
7. **Better error messages** - Show expected format in warnings

## Test Cases to Validate

```
DateTime:
- "2024-01-15 14:30:25.123" ✓
- "2024-01-15 14:30:25.0" ?
- "2024-01-15 14:30:25" (no milliseconds) ?
- "2024-1-5 9:5:5.5" (no leading zeros) ?

Decimal:
- "123.45" ✓
- "123.00" ?
- "123" ✓
- "-123.45" ✓
- "1234.56789" (many decimals) ?

Integer:
- "123" ✓
- "123.0" ✗ (WILL FAIL)
- "123.00" ✗ (WILL FAIL)
- "-123" ✓

Boolean:
- "1", "0" ✓ (FIXED)
- "TRUE", "FALSE" ✓ (FIXED)

NULL:
- "" ✓
- "NULL" ✓
- "null" ✗ (case sensitive)
- "   " (whitespace) ✗ (treated as data)
```
