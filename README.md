# Summary

This script takes a string representing a computer name (or more usefully, a wildcarded computer name query), and outputs a string array of computer names which have login sessions matching the given filtering parameters.  

The intended use is to get a list of computers for use in running a command, where you only want to run the command on computers which have certain types of sessions. For example, if you want to reboot several machines, but only if they have no active user sessions.  

# Usage

Note: Internally, this module makes use of a second custom module called `Get-Sessions`, which simply retrieves all sessions from the computer using the builtin `query session` (a.k.a. `qwinsta`) command and returns them in a proper Powershell object. The `Get-ComputersBySessionState` module then filters those sessions based on the given parameters, and returns the computer names associated with the filtered sessions.  

1. Download `Get-Sessions.psm1` from https://github.com/engrit-illinois/Get-Sessions to `$HOME\Documents\WindowsPowerShell\Modules\Get-Sessions\Get-Sessions.psm1`
2. Download `Get-ComputersBySessionsState.psm1` to `$HOME\Documents\WindowsPowerShell\Modules\Get-ComputersBySessionState\Get-ComputersBySessionState.psm1`
3. Run it using the examples and documentation provided below

# Examples

### Returning computer names
- Get all computers named `computer-name-*` which have no non-system sessions (i.e. no active, remote, or disconnected remote sessions):
    - `Get-ComputersBySessionState -ComputerNameQuery "computer-name-*" -WithoutSessions`
- Get all computers named `computer-name-*` which have no non-system sessions, plus those which have one or more disconnected remote sessions:
    - `Get-ComputersBySessionState -ComputerNameQuery "computer-name-*" -WithoutSessions -AlsoInclude Disconnected`
- Get all computers named `computer-name-*` which have one or more local, remote, or disconnected remote sessions:
    - `Get-ComputersBySessionState -ComputerNameQuery "computer-name-*" -WithSessionTypes Local,Remote,Disconnected`
- Get all computers named `computer-name-*` which have one or more local or remote sessions, omitting those with disconnected remote sessions:
    - `Get-ComputersBySessionState -ComputerNameQuery "computer-name-*" -WithSessionTypes Local,Remote`

### Using returned computer names to pass to another command
- Get the model of all computers named `computer-name-*` which have one or more local sessions:
    - `Get-ComputersBySessionState -ComputerNameQuery "computer-name-*" -WithSessionTypes Local | ForEach-Object { (Get-CIMInstance -ComputerName $_ -Class "Win32_ComputerSystem").Model }`
- You can see how this might be used to, for example, reboot all computers named `computer-name-*` which have no sessions, one of the primary (and powerful) intended uses for this script:
    - `Get-ComputersBySessionState -ComputerNameQuery "computer-name-*" -WithoutSessions | Restart-Computer`
- To make sure it worked you could check the system boot time for those computers:
    - `Get-ComputersBySessionState -ComputerNameQuery "computer-name-*" -WithoutSessions | ForEach-Object { Invoke-Command -ComputerName $_ -ScriptBlock { Get-ComputerInfo } | Select CsName,OSLastBootUpTime }`
- And to make sure you didn't hose a bunch of active sessions, you could check the system boot time for the rest of the computers:
    - `Get-ComputersBySessionState -ComputerNameQuery "computer-name-*" -WithSessionTypes Local,Remote,Disconnected | ForEach-Object { Invoke-Command -ComputerName $_ -ScriptBlock { Get-ComputerInfo } | Select CsName,OSLastBootUpTime }`

### Misc
- By default the `-ComputerNameQuery` searches for computers in all of AD. To limit the search to a specific OU, specify an OU distinguished name using the `-OUDN` parameter:
    - `Get-ComputersBySessionState -ComputerNameQuery "computer-name-*" -WithoutSessions -OUDN "OU=Instructional,OU=Desktops,OU=Engineering,OU=Urbana,DC=ad,DC=uillinois,DC=edu"`
- If for whatever reason you want to return all computers that match the `-ComputerNameQuery`, regardless of their sessions, you can use:
    - `Get-ComputersBySessionState -ComputerNameQuery "computer-name-*" -WithoutSessions -AlsoInclude Local,Remote,Disconnected`
- To get the actual whole sessions, instead of just the computer names associated with the filtered sessions, you can use the `-GetSessionsInstead` switch:
    - `Get-ComputersBySessionState -ComputerNameQuery "computer-name-*" -WithSessionTypes Local,Remote,Disconnected -GetSessionsInstead | Format-Table`
- If you want to see the system sessions as well, instead of just the user sessions, you can use the `Get-Sessions` module instead:
    - `Get-Sessions -ComputerNameQuery "computer-name-*" | Format-Table`
- Also, just for convenience:
    - `-WithAnySessions` is an alias for `-WithSessionTypes Local,Remote,Disconnected`
    - `-All` is an alias for `-WithoutSessions -AlsoInclude Local,Remote,Disconnected`

# Parameters

### -ComputerNameQuery
Required string.  
A computer name (e.g. "computer-name-01"), or query string (e.g. "computer-name-*").  
Specifies the AD computer names which will be targeted.  

### -OUDN
Optional string.  
Specify an OU distinguished name to limit the computers polled to only those which exist within the given OU.  
If omitted, the entire AD is searched.  

### -WithoutSessions
Required switch if neither `-All`, nor `-WithSessionTypes` nor `-WithAnySessions` are specified.  
Specifies that only computers with no local, remote, or disconnected remote sessions will be returned.  

### -AlsoInclude \<sessiontype>\[,\<sessiontype>\[,\<sessiontype>]]
Optional switch, only if `-WithoutSessions` is specified.  
Specifies that, in additional to computers with no sessions, computers with the specified session types will also be returned.  
Valid session types are "Local", "Remote", and "Disconnected".  
The order in which session types are given does not matter.  
Sessions types may be given quoted or unquoted (e.g. `Local,Remote,Disconnected` or `"Local","Remote","Disconnected"`). While typing them unquoted, tab-completion may be utilized.  

### -All
Required switch if neither `-WithoutSessions`, nor `-WithSessionTypes` nor `-WithAnySessions` are specified.  
An alias for `-WithoutSessions -AlsoInclude Local,Remote,Disconnected`.  

### -WithSessionTypes \<sessiontype>\[,\<sessiontype>\[,\<sessiontype>]]
Required string array if neither `-WithoutSessions`, nor `-All`, nor `-WithAnySessions` are specified.  
Specifies that only computers with the specified session types will be returned.  
Valid session types are "Local", "Remote", and "Disconnected".  
The order in which session types are given does not matter.  
Sessions types may be given quoted or unquoted (e.g. `Local,Remote,Disconnected` or `"Local","Remote","Disconnected"`). While typing them unquoted, tab-completion may be utilized.  

### -WithAnySessions
Required switch if neither `-WithoutSessions`, nor `-All`, nor `-WithSessionTypes` are specified.  
An alias for `-WithSessionTypes Local,Remote,Disconnected`.  

### -GetSessionsInstead
Optional switch only if `-WithSessionTypes` or `-WithAnySessions` is specified.  
If specified, an array of session objects will be returned, instead of an array of computer name strings.  

### -Loud
Optional switch.  
If specified, outputs debug information to the screen. Does not affect the returned object.  
This gets passed through to the `Get-Sessions` cmdlet.  

### -PingCount
Optional integer.  
The number of times to ping a computer for the purposes of testing response, before querying the computer for session info.  
This gets passed through to the `Get-Sessions` cmdlet.  
Default is `1`.  

# Notes
- For the purposes of this script, there are 4 types of sessions:
    - "System" sessions: sessions which exist on all computers, but which do no correleate with a user login. These are ignored.
    - "Local" sessions: (a.k.a. "console") sessions representing a user who is logged into the machine locally (i.e. physically sitting at the machine). These include sessions where the user "locked" their session. There's no way to differentiate between these states, in this script's implementation.
    - "Remote" sessions: (a.k.a. "rdp-tcp") sessions representing a user who is actively logged in via a terminal (Remote Desktop) session.
    - "Disconnected" sessions: sessions representing a user who logged in via a terminal (Remote Desktop) session, but who disconnected from the session without logging out.
- By mseng3. See my other projects here: https://github.com/mmseng/code-compendium.
