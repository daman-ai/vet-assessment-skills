# Lib-Dates.ps1 — the three derived dates on every marking record.
#
#   Date of assessment  marking date - 14 calendar days, rolled BACK to the
#                       nearest preceding working day if it lands on a weekend
#                       or a public holiday.
#   Feedback Given      the marking date.
#   Resubmission Due    5 business days forward from the marking date,
#                       excluding weekends and public holidays. N/A where the
#                       student is Competent.
#
# Every date is printed dd / mm / yyyy.
#
# These functions THROW outside the holiday table's years. They never degrade to
# a weekends-only calendar: a quietly skipped public holiday puts a wrong
# resubmission deadline on a signed student record, and nothing downstream
# would catch it.

$ErrorActionPreference = 'Stop'

$script:HolidayTable = $null
$script:HolidayYears = @()

function Import-PublicHolidays {
    param([string]$Path)
    if (-not $Path) { $Path = Join-Path $PSScriptRoot '..\assets\public-holidays.sa.json' }
    if (-not (Test-Path -LiteralPath $Path)) { throw "Public holiday table not found: $Path" }

    $json = Get-Content -Raw -Encoding UTF8 -LiteralPath $Path | ConvertFrom-Json
    $set = @{}
    $years = @()
    foreach ($prop in $json.holidays.PSObject.Properties) {
        $years += [int]$prop.Name
        foreach ($h in $prop.Value) { $set[$h.date] = $h.name }
    }
    $script:HolidayTable = $set
    $script:HolidayYears = $years | Sort-Object
    [pscustomobject]@{ Count = $set.Count; Years = $script:HolidayYears; Source = (Resolve-Path -LiteralPath $Path).Path }
}

function Assert-YearCovered {
    param([datetime]$Date)
    if (-not $script:HolidayTable) { [void](Import-PublicHolidays) }
    if ($script:HolidayYears -notcontains $Date.Year) {
        throw ("Public holiday table does not cover {0}. Covered: {1}. Add the year to assets/public-holidays.sa.json, verified against the state's gazetted list, before marking." -f $Date.Year, ($script:HolidayYears -join ', '))
    }
}

function Test-PublicHoliday {
    param([Parameter(Mandatory)][datetime]$Date)
    Assert-YearCovered $Date
    $script:HolidayTable.ContainsKey($Date.ToString('yyyy-MM-dd'))
}

function Get-HolidayName {
    param([Parameter(Mandatory)][datetime]$Date)
    Assert-YearCovered $Date
    $k = $Date.ToString('yyyy-MM-dd')
    if ($script:HolidayTable.ContainsKey($k)) { $script:HolidayTable[$k] } else { $null }
}

function Test-WorkingDay {
    param([Parameter(Mandatory)][datetime]$Date)
    if ($Date.DayOfWeek -eq [DayOfWeek]::Saturday -or $Date.DayOfWeek -eq [DayOfWeek]::Sunday) { return $false }
    -not (Test-PublicHoliday $Date)
}

function Get-WorkingDay {
    <#
      Rolls $Date to a working day. Default direction is backwards, which is what
      the Date of assessment rule asks for.
    #>
    param(
        [Parameter(Mandatory)][datetime]$Date,
        [ValidateSet('Back','Forward')][string]$Direction = 'Back'
    )
    $step = if ($Direction -eq 'Back') { -1 } else { 1 }
    $d = $Date
    $guard = 0
    while (-not (Test-WorkingDay $d)) {
        $d = $d.AddDays($step)
        if (++$guard -gt 30) { throw "Get-WorkingDay: no working day within 30 days of $($Date.ToString('yyyy-MM-dd'))." }
    }
    $d
}

function Add-BusinessDays {
    <#
      Counts $Days working days forward from $From, not counting $From itself.
      Five business days from a Wednesday marking date lands on the following
      Wednesday when no holiday intervenes.
    #>
    param(
        [Parameter(Mandatory)][datetime]$From,
        [Parameter(Mandatory)][int]$Days
    )
    if ($Days -lt 0) { throw "Add-BusinessDays: negative count ($Days)." }
    $d = $From
    $n = 0
    $guard = 0
    while ($n -lt $Days) {
        $d = $d.AddDays(1)
        if (Test-WorkingDay $d) { $n++ }
        if (++$guard -gt 400) { throw 'Add-BusinessDays: runaway loop.' }
    }
    $d
}

function Format-RecordDate {
    <# The house format. Every date on every record prints this way. #>
    param([Parameter(Mandatory)][datetime]$Date)
    $Date.ToString('dd / MM / yyyy')
}

function Get-MarkingDates {
    <#
      The whole date block for a marking run, derived once from the marking date
      and used by all three documents. Nothing downstream recomputes a date.
    #>
    param(
        [Parameter(Mandatory)][datetime]$MarkingDate,
        [int]$AssessmentOffsetDays = 14,
        [int]$ResubmissionBusinessDays = 5,
        [datetime]$ResultsEnteredDate
    )
    Assert-YearCovered $MarkingDate

    $rawAssessment = $MarkingDate.AddDays(-$AssessmentOffsetDays)
    $assessment    = Get-WorkingDay -Date $rawAssessment -Direction Back
    $resub         = Add-BusinessDays -From $MarkingDate -Days $ResubmissionBusinessDays
    if (-not $PSBoundParameters.ContainsKey('ResultsEnteredDate')) { $ResultsEnteredDate = $MarkingDate }

    [pscustomobject]@{
        MarkingDate           = $MarkingDate
        MarkingDateText       = Format-RecordDate $MarkingDate
        AssessmentDate        = $assessment
        AssessmentDateText    = Format-RecordDate $assessment
        AssessmentRolledBack  = ($assessment.Date -ne $rawAssessment.Date)
        AssessmentRollReason  = if ($assessment.Date -ne $rawAssessment.Date) {
                                    $n = Get-HolidayName $rawAssessment
                                    if ($n) { "$($rawAssessment.ToString('ddd dd MMM yyyy')) is $n" }
                                    else    { "$($rawAssessment.ToString('ddd dd MMM yyyy')) is a weekend" }
                                } else { $null }
        FeedbackGivenText     = Format-RecordDate $MarkingDate
        ResubmissionDue       = $resub
        ResubmissionDueText   = Format-RecordDate $resub
        ResultsEnteredText    = Format-RecordDate $ResultsEnteredDate
    }
}
