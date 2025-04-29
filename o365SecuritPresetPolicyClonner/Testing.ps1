$obj = 1..10

$obj | ForEach-Object {
    Write-Host "The new number is $($_ *10)"
    Start-Sleep 1
}

$obj | ForEach-Object {
    Write-Information "The new number is $($_ *10)" -InformationAction Continue
    Start-Sleep 1
}


$obj | ForEach-Object {
    Write-Host "The new number is $($_ *10)" -
    Start-Sleep 1
}