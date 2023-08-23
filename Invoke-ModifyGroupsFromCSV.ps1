function Invoke-ModifyGroupsFromCsv {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$CSVFILE,
        # Parameter help description
        [Parameter(Mandatory=$true)]
        [pscredential]
        $creds
    )
    
    process {
        try {
            $csvData = Import-CSV -Path $CSVFILE
        }
        catch {
            throw "Failed to import CSV file: $CSVFILE"
        }

        $invalidActions = @()
        foreach ($row in $csvData) {
            try {
                $user = Get-ADUser -Filter "EmployeeID -eq '$($row.TMID.trim())'" -ErrorAction Stop
                $group = Get-ADGroup -Filter "Name -eq '$($row.GroupName.trim())'" -ErrorAction Stop

                if ($user -eq $null) {
                    throw "User $($row.TMID) not found"
                }
                if ($group -eq $null) {
                    throw "Group $($row.GroupName) not found"
                }

                $InstructionSet = [PSCustomObject]@{
                    GroupName = $row.GroupName.trim()
                    TMID = $row.TMID.trim()
                    User = $user.SamAccountName
                    Group = $group.SamAccountName
                    Action = $row.Action.trim()
                }

                if ($user -and $group) {
                    switch ($InstructionSet.Action) {
                        "Add" {
                            Write-Verbose "Adding $($InstructionSet.User) to $($InstructionSet.Group)"
                            $parameters = @{
                                Identity = $InstructionSet.Group
                                Members = $InstructionSet.User
                            }
                            Add-ADGroupMember @parameters -Credential $creds
                            Write-Output "Added $($InstructionSet.User) to $($InstructionSet.Group) successfully" 
                        }
                        "Remove" {
                            Write-Verbose "Removing $($InstructionSet.User) from $($InstructionSet.Group)"
                            $parameters = @{
                                Identity = $InstructionSet.Group
                                Members = $InstructionSet.User
                                Confirm = $false
                            }
                            Remove-ADGroupMember @parameters -credential $creds
                            Write-Output "Removed $($InstructionSet.User) from $($InstructionSet.Group) successfully" 
                        }
                        default {
                            throw "Invalid action: $($InstructionSet.Action)"
                        }
                    }
                }
            }
            catch {
                $errorMessage = $_.Exception.Message
                Write-Error $errorMessage
                $invalidActions += $InstructionSet
                continue
            }
        }
        
        if ($invalidActions.Count -eq 0) {
            Write-Host "Script Completed Successfully with no errors" -ForegroundColor Green
        }
        else {
            Write-Host "Script Completed" -ForegroundColor Green
            Write-Warning "The following actions were unsuccessful:"
            $invalidActions | Format-Table
        }
    }
}

$CSVFILE = Read-Host "Enter the path to your csv file"
$credentials = Get-Credential

Invoke-ModifyGroupsFromCsv -CSVFILE $CSVFILE -creds $credentials