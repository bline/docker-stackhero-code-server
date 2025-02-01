# build.ps1
# Check if .env exists
if (-not (Test-Path ".env")) {
    Write-Host "You must create a .env file first. See .env.example file for a starting point"
    exit 1
}

# Function to expand environment variables in a string.
# This handles both ${VAR} and $VAR formats.
function Expand-EnvVariables {
    param (
        [string]$text
    )

    # Replace ${VAR} occurrences using .NET regex Replace
    $text = [regex]::Replace($text, '\$\{(\w+)\}', {
        param($match)
        $varName = $match.Groups[1].Value
        return [System.Environment]::GetEnvironmentVariable($varName)
    })

    # Replace $VAR occurrences using .NET regex Replace
    $text = [regex]::Replace($text, '\$(\w+)', {
        param($match)
        $varName = $match.Groups[1].Value
        return [System.Environment]::GetEnvironmentVariable($varName)
    })

    return $text
}

# Process the .env file line by line
Get-Content ".env" | ForEach-Object {
    $line = $_.Trim()
    # Skip empty lines or lines starting with '#'
    if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
        return
    }

    # Expand any environment variables in the line (if any)
    $expandedLine = Expand-EnvVariables -text $line

    # Expect the line to be in the form KEY=VALUE.
    $parts = $expandedLine.Split('=', 2)
    if ($parts.Length -eq 2) {
        $key   = $parts[0].Trim()
        $value = $parts[1].Trim()

        # Remove surrounding double quotes if present
        if ($value.StartsWith('"') -and $value.EndsWith('"')) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        # Only set the environment variable if the key is not empty.
        if (-not [string]::IsNullOrWhiteSpace($key)) {
            [System.Environment]::SetEnvironmentVariable($key, $value, "Process")
        }
        else {
            Write-Warning "Encountered a line with an empty key; skipping: '$line'"
        }
    }
    else {
        Write-Warning "Skipping invalid line: '$line'"
    }
}

# Set BUILD_DATE as an environment variable with the current date (YYYY-MM-DD).
[System.Environment]::SetEnvironmentVariable("BUILD_DATE", (Get-Date -Format "yyyy-MM-dd"), "Process")

# Check that the template file exists
if (-not (Test-Path "fly-template.toml")) {
    Write-Host "fly-template.toml not found"
    exit 1
}

# Read the fly-template.toml content as a single string
$templateContent = Get-Content "fly-template.toml" -Raw

# Replace any environment variable placeholders in the template
$substitutedContent = Expand-EnvVariables -text $templateContent

# Write the processed content to fly.toml
Set-Content "fly.toml" -Value $substitutedContent

# Determine which command to use for displaying fly.toml.
# On Windows, the bat utility is usually installed as 'bat'.
$bat = Get-Command "bat" -ErrorAction SilentlyContinue

Write-Host "Generated fly.toml`n"

if ($bat) {
    # Use bat with desired arguments if available
    & bat --paging=never --style=plain -f "fly.toml"
} else {
    # Otherwise, just output the file content
    Get-Content "fly.toml"
}

Write-Host "`nReady to flyctl deploy! 🚀"
