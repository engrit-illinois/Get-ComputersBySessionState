# Documentation home: https://github.com/engrit-illinois/Get-ComputersBySessionState
# By mseng3

function Get-ComputersBySessionState {

	param(
		# Name of computer
		# Use "*" as wildcard
		[Parameter(Mandatory=$true,Position=0)]
		[string]$ComputerNameQuery,
		
		[string]$OUDN,
		
		[switch]$Loud,
		
		[Parameter(Mandatory=$true,ParameterSetName="NoSessions")]
		[switch]$WithoutSessions,
		
		[Parameter(ParameterSetName="NoSessions")]
		[ValidateSet('Local','Remote','Disconnected',ignorecase=$true)]
		[string[]]$AlsoInclude,
		
		[Parameter(Mandatory=$true,ParameterSetName="All")]
		[switch]$All,
		
		# https://stackoverflow.com/questions/34000602/how-do-i-force-at-least-one-parameter-from-a-set-be-specified
		[Parameter(Mandatory=$true,ParameterSetName="SomeSessions")]
		[ValidateSet('Local','Remote','Disconnected',ignorecase=$true)]
		[string[]]$WithSessionTypes,
		
		[Parameter(Mandatory=$true,ParameterSetName="AnySessions")]
		[switch]$WithAnySessions,
		
		[Parameter(ParameterSetName="SomeSessions")]
		[Parameter(ParameterSetName="AnySessions")]
		[switch]$GetSessionsInstead,
		
		[int]$PingCount = 1
	)
	
	# -WithAnySessions is just a convenient alias for -WithSessionTypes Local,Remote,Disconnected
	if($WithAnySessions) {
		$WithSessionTypes = "Local","Remote","Disconnected"
	}
	
	# -All is just a convenient alias for -WithoutSessions -AlsoInclude Local,Remote,Disconnected
	if($All) {
		$WithoutSessions = $true
		$AlsoInclude = "Local","Remote","Disconnected"
	}

	function log {
		param (
			[string]$msg,
			[int]$level=0,
			[switch]$nots,
			[switch]$warn
		)
		
		if($Loud -or $warn) {
			for($i = 0; $i -lt $level; $i += 1) {
				$msg = "    $msg"
			}
			
			if(!$nots) {
				$ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
				$msg = "[$ts] $msg"
			}
			
			if($warn) {	Write-Warning $msg }
			else { Write-Host $msg }
			#$msg | Out-File $LOG -Append
		}
	}
	
	function Test-IncludeSessionType($type) {
		$includeType = $false
		
		# Make every member of $WithSessionTypes lowercase, so we can more easily check if $type is contained within it
		# Because we don't know what cases will be given
		$typeLower = $type.ToLower()
		if($WithSessionTypes) {
			$WithSessionTypesLower = $WithSessionTypes.ToLower()
		}
		if($AlsoInclude) {
			$AlsoIncludeLower = $AlsoInclude.ToLower()
		}
		
				
		# If we're only looking for computers with no sessions, then we want to track all of these sessions
		# So we know which computers to omit later
		if($WithoutSessions) {
			if(!$AlsoInclude) {
				$includeType = $true
			}
			# If this type if being excepted from "all computers withOUT sessions", we want to omit it here,
			# so that it doesn't get subtracted later
			else {
				if(@($AlsoIncludeLower).contains($typeLower)) {
					#$includeType = $false
				}
				else {
					$includeType = $true
				}
			}
		}
		# Otherwise if we're looking for computers WITH sessions, include them as necessary
		# so that they are included later
		elseif($WithSessionTypes) {
			if(@($WithSessionTypesLower).contains($typeLower)) {
				$includeType = $true
			}
		}
		else {
			throw "Logic error in Test-IncludeSessionsType!"
		}
		
		$includeType
	}
	
	function Filter-Sessions($sessions) {
		$filteredSessions = @()
		
		log "Iterating through sessions..." -level 2
		$i = 1
		foreach($session in $sessions) {
			log "Processing session #$i..." -level 3
			log "Computer: $($session.COMPUTER), SessionName: $($session.SESSIONNAME), User: $($session.USERNAME), ID: $($session.ID), State: $($session.STATE), Idle time: $($session."IDLE TIME"), Logon datetime: $($session."LOGON DATETIME"), Type: $($session.TYPE), Device: $($session.DEVICE)" -level 4
			
			# There are also usually 2 other default sessions, named "services", "rdp-tcp", which have no USERNAME, that we don't care about
			if(
				($session.SESSIONNAME -eq "services") -or
				($session.SESSIONNAME -eq "rdp-tcp") -or
				(($session.SESSIONNAME -eq "console") -and (!$session.USERNAME))
			) {
				log "This is the `"$($session.SESSIONNAME)`" session (a non-user session)." -level 4
			}
			# Apparently installations of Visual Studio cause a special session to be present
			# https://www.experts-exchange.com/questions/28484208/Query-session-shows-unknown-session-name-after-Visual-Studio-2013-install.html
			elseif($session.SESSIONNAME -eq "7a78855482a04...") {
				log "This is a weird session apparently caused by installations of Visual Studio." -level 4
			}
			# What we're left with, SHOULD only be active local login sessions and active or disconnected RDP sessions
			else {
				log "This appears to be either an active local session, or an active or disconnected remote session." -level 4

				# Active sessions
				if($session.SESSIONNAME) {
					if($session.SESSIONNAME -eq "console") {
						if($session.USERNAME) {
							log "This is a local (`"console`") session." -level 4
							if(Test-IncludeSessionType "local") {
								log "Given parameters specify that local sessions should be included." -level 4
								$filteredSessions += @($session)
							}
							else {
								log "Given parameters specify that local sessions should NOT be included." -level 4
							}
						}
					}
					elseif($session.SESSIONNAME -match "rdp-tcp#.+") {
						log "This is a remote (`"rdp-tcp#`") session." -level 4
						if(Test-IncludeSessionType "remote") {
							log "Given parameters specify that remote sessions should be included." -level 4
							$filteredSessions += @($session)
						}
						else {
							log "Given parameters specify that remote sessions should NOT be included." -level 4
						}
					}
					else {
						#throw "Unrecognized session type with session name: `"$($session.SESSIONNAME)`"!"
						# There's actually no need to crash out here. Just throw a warning and continue without adding this session to the list of filtered sessions.
						log "Unrecognized session type on computer `"$($session.COMPUTER)`" with session name: `"$($session.SESSIONNAME)`"!" -warn
					}
				}
				# Disconnected sessions
				else {
					if($session.STATE -eq "Disc") {
						log "This is a disconnected remote session." -level 5
						if(Test-IncludeSessionType "disconnected") {
							log "Given parameters specify that disconnected sessions should be included." -level 4
							$filteredSessions += @($session)
						}
						else {
							log "Given parameters specify that disconnected sessions should NOT be included." -level 4
						}
					}
					else {
						#throw "Unrecognized session type with no session name!"
						# There's actually no need to crash out here. Just throw a warning and continue without adding this session to the list of filtered sessions.
						log "Unrecognized session type on computer `"$($session.COMPUTER)`" with no session name!" -warn
					}
				}
			}
			log "Done processing session #$i." -level 3
			$i += 1
		}
		log "Done interating through sessions." -level 2
		
		$filteredSessions
	}
	
	function Deduplicate-Sessions($sessions) {
		# Get-Sessions now returns duplicate sessions for user sessions, due to polling with both `query session` and `query user`
		# Let's keep only the results from `query user`, since those include the "IDLE TIME" and "LOGON DATETIME" fields.
		
		$newSessions = @()
		
		# Get unique computer names
		$compNames = $sessions | Select -ExpandProperty COMPUTER | Select -Unique
		
		# For each computer
		$compNames | ForEach-Object {
			$compName = $_
			$compSessions = $sessions | Where { $_.COMPUTER -eq $compName }
			
			# Get all user sessions which have idle/logon time data
			$goodUserSessions = $compSessions | Where { ($_.USERNAME -ne $null) -and ($_."LOGON DATETIME" -ne $null) }
			
			# Remove identical user sessions which do not have idle/logon time data
			$goodUserSessions | ForEach-Object {
				$goodUserSession = $_
				$newCompSessions = $compSessions | Where { -not (($_.USERNAME -eq $goodUserSession.USERNAME) -and ($_."LOGON DATETIME" -eq "N/A")) }
			}
			
			$newSessions += @($newCompSessions)
		}
		
		$newSessions
	}
	
	function Get-CompsFromSessions($sessions) {
		$comps = @()
		foreach($session in $sessions) {
			$comps += @($session.COMPUTER)
		}
		# Remove duplicated
		$comps = $comps | Select -Unique
		$comps
	}
	
	function Get-CompsWithoutSessions($allComps, $compsWithSessions) {
		$compsWithoutSessions = $allComps | Where { $compsWithSessions -notcontains $_ }
		$compsWithoutSessions
	}
	
	function Order-Sessions($sessions) {
		$sessions | Sort COMPUTER | Select -Property COMPUTER,USERNAME,SESSIONNAME,STATE,ID,"IDLE TIME","LOGON DATETIME"
	}
	
	function Print-Sessions($sessions) {
		log " " -nots
		# The TYPE and DEVICE fields always seem to be empty, so omit them here, and reorgnaize the columns
		$sessions = $sessions | Format-Table -Property COMPUTER,USERNAME,SESSIONNAME,STATE,ID,"IDLE TIME","LOGON DATETIME"
		$sessions = ($sessions | Out-String).Trim()
		log $sessions -nots
		log " " -nots
	}
	
	function Process {
		if($OUDN) {
			if($Loud) {
				$sessions = Get-Sessions -ComputerNameQuery $ComputerNameQuery -PingCount $PingCount -OUDN $OUDN -Loud
			}
			else {
				$sessions = Get-Sessions -ComputerNameQuery $ComputerNameQuery -PingCount $PingCount -OUDN $OUDN
			}
		}
		else {
			if($Loud) {
				$sessions = Get-Sessions -ComputerNameQuery $ComputerNameQuery -PingCount $PingCount -Loud
			}
			else {
				$sessions = Get-Sessions -ComputerNameQuery $ComputerNameQuery -PingCount $PingCount
			}
		}
		$filteredSessions = Filter-Sessions $sessions
		$filteredSessions = Deduplicate-Sessions $filteredSessions
		$filteredSessions = Order-Sessions $filteredSessions
		
		if($GetSessionsInstead) {
			Print-Sessions $filteredSessions
			$filteredSessions
		}
		else {
			$compsWithSessions = Get-CompsFromSessions $filteredSessions
			if(!$WithoutSessions) {
				$comps = $compsWithSessions
			}
			else {
				$allComps = Get-CompsFromSessions $sessions
				$compsWithoutSessions = Get-CompsWithoutSessions $allComps $compsWithSessions
				$comps = $compsWithoutSessions
			}
			$comps
		}
	}
	
	Process
	
	log "EOF"
	log " " -nots
}