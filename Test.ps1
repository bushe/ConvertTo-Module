cls
$test="Function test-test {","Function test2","Function test3     "

ForEach ($t in $test)
{
    If ($t -match "(Function (?<FunctionName>.*) )|(Function (?<FunctionName>.*)$)")
    {
        Write-Warning ".$($Matches.FunctionName.Trim())."
    }
}