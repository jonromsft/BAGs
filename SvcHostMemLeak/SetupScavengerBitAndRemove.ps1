function global:Get-MostExpensiveSvchost
{
    # Get the biggest svchost private working set
    ((Get-Counter "\Process(*)\Working Set - Private").CounterSamples | Where {$_.InstanceName -eq "svchost"} | Sort-Object -Property CookedValue -Descending | Select CookedValue -First 1).CookedValue
}

# 
# Script to repor scavenger bit policy installer memory
# 1. Add policies for the given list of domains.
# 2. Remove the policies which were added.
# 3. Keep repeating the process.
# 

function global:Run-ScavengerBitMemoryTest
{
    param(
        [int]$iterationCount,
        [int]$bytesGrowthThreshold
    )

    $maxPolicyAddRetryCount = 5
    $iteration = 0
    $originalMostExpensiveSvchost = Get-MostExpensiveSvchost
    $domainsToSetPolicyFor = gc .\ScavengerBitPolicyDomainsList.txt | where { -not ($_.StartsWith("#") -or $_.StartsWith(";")) }

    Write-Output "Running for $iterationCount iterations, allowing $bytesGrowthThreshold bytes of memory growth, starting at $originalMostExpensiveSvchost"

    for ($iteration = 0; $iteration -lt $iterationCount; $iteration++)
    {
        Write-Output "Iteration $iteration of $iterationCount"

        $namesOfPolicyToBeAdded = @()

        foreach ($domain in $domainsToSetPolicyFor)
        {
            $policyName = "Scavenger bit policy for " + ($domain -replace "://",  " ")
    
            $namesOfPolicyToBeAdded += $policyName

            if ((-not $domain.ToLower().StartsWith("http://")) -and (-not $domain.ToLower().StartsWith("https://")))
            {
                $domain = "http://$domain"
            }

            if (-not $domain.ToLower().EndsWith("/"))
            {
                $domain = "$domain/"
            }

            $URIToMatch = $domain
            $networkProfile = "Domain"
            $URIRecursiveCondition = $true
            $dscpValue = 8

            $filteredPolicy = Get-NetQosPolicy | where { $_.Name -eq $policyName }
            if ($filteredPolicy -ne $null)
            {
                # There exists a policy with the same name. Verify its settings.
                if (($filteredPolicy.NetworkProfile -eq $networkProfile) -and ($filteredPolicy.URI.OriginalString -eq $URIToMatch) -and ($filteredPolicy.URIRecursive -eq $URIRecursiveCondition) -and ($filteredPolicy.DSCPValue -eq $dscpValue))
                {
                    continue
                }
                else
                {
                    # remove the policy and suppress the confirmation request.
                    remove-netqospolicy $policyname -confirm:$false
                }
            }

            new-netqospolicy $policyName -URIMatchCondition $URIToMatch -NetworkProfile $networkProfile -URIRecursiveMatchCondition $URIRecursiveCondition -DSCPAction $dscpValue

            for ($i = 0; $i -lt $maxPolicyAddRetryCount; $i++)
            {
                $filteredPolicy = Get-NetQosPolicy | where { $_.Name -eq $policyName }
                if ($filteredPolicy -ne $null)
                {
                    break
                }

                # Add a delay to avoid rapid additions of policy
                Start-Sleep -Milliseconds 50
        
                # Retry adding the policy
                new-netqospolicy $policyName -URIMatchCondition $URIToMatch -NetworkProfile $networkProfile -URIRecursiveMatchCondition $URIRecursiveCondition -DSCPAction $dscpValue
            }

            # Add a delay to avoid rapid additions of policy
            Start-Sleep -Milliseconds 50
        }

        Start-Sleep -Milliseconds 50

        foreach ($policyName in $namesOfPolicyToBeAdded)
        {
            # remove the policy and suppress the confirmation request.
            remove-netqospolicy $policyname -confirm:$false
        }

        $newMostExpensiveSvchost = Get-MostExpensiveSvchost

        Write-Output "Original memory: $originalMostExpensiveSvchost"
        Write-Output "New memory: $newMostExpensiveSvchost"
        if ($newMostExpensiveSvchost -ge $originalMostExpensiveSvchost + $bytesGrowthThreshold)
        {
            Write-Output "Test FAILED!!!"
            exit 1
        }
    }

    Write-Output "Test Passed!"
    exit 0
}

$totalIterationsAllowed = 10
$allowedGrowthInBytes = 50 * 1024 * 1024
Run-ScavengerBitMemoryTest -iterationCount $totalIterationsAllowed -bytesGrowthThreshold $allowedGrowthInBytes