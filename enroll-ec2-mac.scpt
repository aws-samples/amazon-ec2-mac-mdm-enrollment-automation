-- enroll-ec2-mac, an AppleScript workflow to enroll EC2 Mac instances into MDM.
-- Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
-- SPDX-License-Identifier: MIT-0

--This script requires permissions to run, and will prompt automatically as part of setup.

--Copy this script to /Users/Shared/ (or change the value of mmPath to match yours).

--To create the LaunchAgent and start the required permissions requests, run from Terminal as:
--osascript /Users/Shared/enroll-ec2-mac.scpt --setup

--To do the above and use DEPNotify, run:
--osascript /Users/Shared/enroll-ec2-mac.scpt --setup --with-screen

--Important: either set your secret name in the MMSecretVar subroutine below, or via the following CLI command:
--defaults write com.amazon.dsx.ec2.enrollment.automation MMSecret "jamfSecretID-GoesHere"

on MMSecretVar()
	try
		set MMSecret to (do shell script "defaults read com.amazon.dsx.ec2.enrollment.automation MMSecret")
	on error
		--Change what's in the quotes below to the name or ARN of your AWS Secrets Manager secret if coding in here.
		set MMSecret to "jamfSecret"
	end try
	return MMSecret
end MMSecretVar

on getInvitationID()
	--If manually setting an invitation ID, set here and use the following command to enable:
	--defaults write com.amazon.dsx.ec2.enrollment.automation invitationID "INVITATIONIDGOESHERE"
	try
		--If setting inline, uncomment the below and remove the defaults line.
		--set theInvitationID to ""
		try
			set theInvitationID to (do shell script "defaults read com.amazon.dsx.ec2.enrollment.automation invitationID")
		on error
			set theInvitationID to (do shell script "defaults read /Library/Preferences/com.amazon.dsx.ec2.enrollment.automation invitationID")
		end try
		get theInvitationID
	on error
		set theInvitationID to false
	end try
	return theInvitationID
end getInvitationID

--For adding "https://" and terminating "/" to URLs.
on tripleDouble(incomingURL)
	set incomingURL to (do shell script "echo " & quoted form of incomingURL & " | sed s/[^[:alnum:]%/:+._-]//g | xargs")
	set URLPrepend to "https://"
	if incomingURL does not contain URLPrepend then
		if incomingURL does not contain "http://" then
			if incomingURL does not contain "." then
				display dialog "Invalid URL"
			end if
			set outgoingURL to URLPrepend & incomingURL
		end if
	else
		set AppleScript's text item delimiters to "//"
		set outgoingURL to URLPrepend & (text item 2 of incomingURL)
		set AppleScript's text item delimiters to "//"
	end if
	if outgoingURL does not end with "/" then
		set outgoingURL to (outgoingURL & "/")
	end if
	return outgoingURL as string
end tripleDouble

on accountDriven(appleAccountIn, appleAccountPasswordIn, accountEnrollmentType)
	--Note: ADUE to be added at a later date.
	do shell script "open /System/Library/PreferencePanes/Profiles.prefPane"
	delay 1
	tell application "System Events" to tell process "System Settings"
		click button 1 of group 6 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1
		delay 2
		click button 1 of group 1 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1
		delay 0.5
		repeat
			try
				if (get value of static text 1 of sheet 1 of window 1) contains "remote management configuration" then
					exit repeat
				end if
			on error
				delay 0.5
			end try
		end repeat
		--await sign-in
		set value of text field 1 of group 1 of sheet 1 of sheet 1 of window 1 to appleAccountIn
		delay 0.5
		click button 1 of sheet 1 of sheet 1 of window 1
		--await pw or auth dialog
		repeat
			try
				if (get value of static text 1 of sheet 1 of sheet 1 of sheet 1 of window 1) contains "password" then
					set authPath to "Settings"
					exit repeat
				end if
			on error
				delay 0.5
			end try
			try
				if (get name of button 2 of sheet 1 of sheet 1 of window 1) contains "Browser" then
					set authPath to "Safari"
					exit repeat
				end if
			on error
				delay 0.5
			end try
		end repeat
		delay 0.5
		if authPath is "Settings" then
			set value of text field 1 of sheet 1 of sheet 1 of sheet 1 of window "Device Management" to appleAccountPasswordIn
			delay 0.5
			click button 2 of sheet 1 of sheet 1 of sheet 1 of window 1
			--await next step
		else if authPath is "Safari" then
			click button 2 of sheet 1 of sheet 1 of window 1
		end if
	end tell
	if authPath is "Safari" then
		--Safari template taken from Experience Jamf.
		tell application "System Events" to tell process "Safari"
			delay 2
			tell application "Safari" to activate
			repeat
				try
					if (get value of static text 1 of UI element 4 of group 4 of UI element 1 of scroll area 1 of group 1 of group 1 of tab group 1 of splitter group 1 of window 1) contains "Sign in" then
						exit repeat
					end if
				on error
					delay 0.5
				end try
			end repeat
			set value of text field 1 of group 7 of group 4 of UI element 1 of scroll area 1 of group 1 of group 1 of tab group 1 of splitter group 1 of window 1 to appleAccountIn
			delay 0.5
			click button 1 of group 4 of UI element 1 of scroll area 1 of group 1 of group 1 of tab group 1 of splitter group 1 of window 1
			delay 0.5
			repeat
				try
					if (get value of static text 1 of static text 1 of group 6 of group 4 of UI element 1 of scroll area 1 of group 1 of group 1 of tab group 1 of splitter group 1 of window 1) contains "Password" then
						exit repeat
					end if
				on error
					delay 0.5
				end try
			end repeat
			key code 48
			click text field 1 of group 7 of group 4 of UI element 1 of scroll area 1 of group 1 of group 1 of tab group 1 of splitter group 1 of window 1
			delay 0.5
			set the clipboard to appleAccountPasswordIn
			keystroke "v" using command down
			delay 0.5
			set the clipboard to null
			click button 1 of group 4 of UI element 1 of scroll area 1 of group 1 of group 1 of tab group 1 of splitter group 1 of window 1
			delay 2
		end tell
		tell application "System Events" to tell process "System Settings"
			repeat
				try
					if (get name of button 1 of sheet 1 of sheet 1 of window 1) contains "Sign in" then
						click button 1 of sheet 1 of sheet 1 of window 1
						exit repeat
					else
						delay 0.5
					end if
				on error
					delay 0.5
				end try
			end repeat
			delay 1
			repeat
				try
					click button 2 of group 4 of group 1 of UI element 1 of scroll area 1 of sheet 1 of sheet 1 of sheet 1 of window 1
					exit repeat
				on error
					delay 0.5
				end try
			end repeat
			delay 1
		end tell
		tell application "System Events" to tell process "Safari"
			--run it again
			tell application "Safari" to activate
			repeat
				try
					if (get value of static text 1 of UI element 4 of group 4 of UI element 1 of scroll area 1 of group 1 of group 1 of tab group 1 of splitter group 1 of window 1) contains "Sign in" then
						set value of text field 1 of group 7 of group 4 of UI element 1 of scroll area 1 of group 1 of group 1 of tab group 1 of splitter group 1 of window 1 to appleAccountIn
						exit repeat
					end if
				on error
					delay 0.5
				end try
			end repeat
			delay 0.5
			click button 1 of group 4 of UI element 1 of scroll area 1 of group 1 of group 1 of tab group 1 of splitter group 1 of window 1
			delay 0.5
			repeat
				try
					if (get value of static text 1 of static text 1 of group 6 of group 4 of UI element 1 of scroll area 1 of group 1 of group 1 of tab group 1 of splitter group 1 of window 1) contains "Password" then
						key code 48
						click text field 1 of group 7 of group 4 of UI element 1 of scroll area 1 of group 1 of group 1 of tab group 1 of splitter group 1 of window 1
						delay 0.5
						set the clipboard to appleAccountPasswordIn
						keystroke "v" using command down
						delay 0.5
						set the clipboard to null
						delay 0.5
						exit repeat
					end if
				on error
					delay 0.5
				end try
			end repeat
			click button 1 of group 4 of UI element 1 of scroll area 1 of group 1 of group 1 of tab group 1 of splitter group 1 of window 1
			delay 1
		end tell
		
		tell application "System Events" to tell process "System Settings"
			repeat
				try
					click button 1 of sheet 1 of sheet 1 of window 1
					exit repeat
				on error
					delay 0.5
				end try
			end repeat
			delay 1
		end tell
		--password here, flow returns to post-profile
	end if
end accountDriven

--Subroutine for retrieving region and credentials from AWS Secrets Manager.
on awsMD(MDPath)
	set sessionToken to (do shell script "curl -X PUT http://169.254.169.254/latest/api/token -s -H 'X-aws-ec2-metadata-token-ttl-seconds: 21600'")
	set MDReturn to (do shell script "curl -H 'X-aws-ec2-metadata-token: " & sessionToken & "' -s http://169.254.169.254/latest/meta-data/" & MDPath)
	return MDReturn
end awsMD

--The subroutine itself, called later as "my retrieveSecret("mySecretIdentifier")"
on retrieveSecret(secretRegion, secretID, secretQueryKey)
	set pathPossibilities to "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/opt/homebrew/sbin"
	--By default, uses AWS Secrets Manager to retrieve the secret. A preference can be set via terminal to change.
	--To use AWS Systems Manager Parameter Store:
	--defaults write com.amazon.dsx.ec2.enrollment.automation retrievalType ParameterStore
	try
		set retrievalType to (do shell script "defaults read com.amazon.dsx.ec2.enrollment.automation retrievalType")
	on error
		set retrievalType to "SecretsManager"
	end try
	if retrievalType contains "SecretsManager" then
		set secretReturn to (do shell script "PATH=" & pathPossibilities & " ; aws secretsmanager get-secret-value --region " & secretRegion & " --secret-id '" & secretID & "' --query SecretString")
	else if retrievalType contains "ParameterStore" then
		set secretReturn to (do shell script "PATH=" & pathPossibilities & " ; aws ssm get-parameter --region " & secretRegion & " --name " & secretID & " --with-decryption | grep 'Value'")
		set AppleScript's text item delimiters to "\"Value\":"
		set secretReturn to text item 2 of secretReturn
		set AppleScript's text item delimiters to ""
		
	else if retrievalType contains "plist" then
		try
			--Change the path below if storing plist in a spot other than the default users' ~/Library.
			set retrievalUser to "ec2-user"
			set retrievalPath to (do shell script "defaults read /Users/" & retrievalUser & "/Library/Preferences/com.amazon.dsx.ec2.enrollment.automation retrievalPath")
		on error
			set retrievalPath to ""
		end try
		set secretReturn to (do shell script "defaults read " & retrievalPath & "com.amazon.dsx.ec2.enrollment.automation " & secretID & "| base64 -d")
	end if
	set AppleScript's text item delimiters to "\"{\\\""
	set secretBlob to text item 2 of secretReturn
	if secretBlob contains "\\\",\\\"" then
		set multiSecret to {}
		set secretKeyList to {}
		set secretValueList to {}
		set AppleScript's text item delimiters to "\\\",\\\""
		repeat with i from 1 to (count text items of secretBlob)
			copy (text item i of secretBlob) to the end of multiSecret
		end repeat
		repeat with secretCount from 1 to (count multiSecret)
			set activeBlob to item secretCount of multiSecret
			set AppleScript's text item delimiters to "\\\":"
			set {secretKey, secretValue} to text items of activeBlob
			set AppleScript's text item delimiters to "\\\""
			set secretValue to text item 2 of secretValue
			if secretCount is equal to (count multiSecret) then
				set AppleScript's text item delimiters to "\\\"}"
				set secretValue to text item 1 of secretValue
			end if
			set AppleScript's text item delimiters to ""
			if secretQueryKey is not null then
				if secretKey is secretQueryKey then
					return secretValue
					exit repeat
				end if
			else
				copy secretKey to the end of secretKeyList
				copy secretValue to the end of secretValueList
			end if
		end repeat
		return {secretKeyList, secretValueList}
	else
		set AppleScript's text item delimiters to "\\\":"
		set {secretKey, secretValue} to text items of secretBlob
		set AppleScript's text item delimiters to "\\\"}"
		set secretValue to text item 1 of secretValue
		set AppleScript's text item delimiters to "\\\""
		set secretValue to text item 2 of secretValue
		set AppleScript's text item delimiters to ""
		return {secretKey, secretValue}
	end if
end retrieveSecret



--This subroutine checks if Accessibility permissions are in place.
on dsUIScriptEnable()
	set AppleScript's text item delimiters to "."
	set OSVersion to text item 1 of system version of (system info) as integer
	set AppleScript's text item delimiters to ""
	set self to name of current application
	tell application "System Events"
		set UIEnabledStatus to (get UI elements enabled)
	end tell
	if UIEnabledStatus is not true then
		if OSVersion is greater than or equal to 13 then
			set activeSettingsApp to "System Settings"
			if OSVersion is greater than or equal to 15 then
				display dialog "This script requires Accessibility permissions to function. After clicking OK on this message, please click Privacy & Security on the left side, then scroll down to Accessibility on the right side. Click the switch next to " & self & " on the right."
			else
				display dialog "This script requires Accessibility permissions to function. After clicking OK on this message, please click Accessibility on the right side (you may need to scroll down), and click the switch next to " & self & " on the right."
			end if
			do shell script "open /System/Library/PreferencePanes/Security.prefPane"
		else
			set activeSettingsApp to "System Preferences"
			display dialog "This script requires Accessibility permissions to function. After clicking OK on this message, please enter your password, click Accessibility on the left, and click the check box next to " & self & " on the right."
			do shell script "osascript -e 'tell application \"" & activeSettingsApp & "\" to activate'"
			do shell script "osascript -e 'tell application \"" & activeSettingsApp & "\" to reveal anchor \"Privacy\" of pane id \"com.apple.preference.security\""
			do shell script "osascript -e 'tell application \"" & activeSettingsApp & "\" to authorize pane id \"com.apple.preference.security\""
		end if
		repeat until UIEnabledStatus is true
			tell application "System Events"
				set UIEnabledStatus to (get UI elements enabled)
			end tell
			delay 10
		end repeat
		display notification "Thank you! " & self & " will now run."
	end if
end dsUIScriptEnable

--These subroutines check for UI elements, used in the runtime below.
on securityCheck()
	tell application "System Events" to tell process "SecurityAgent"
		repeat
			try
				set securityOverlay to get value of static text 2 of window 1
			end try
			if securityOverlay contains "enroll" then
				exit repeat
			else
				delay 0.2
			end if
		end repeat
	end tell
end securityCheck

on securityCheckVentura()
	tell application "System Events" to tell process "SecurityAgent"
		repeat
			try
				set securityOverlay to get value of static text 1 of window 1
			on error
				set securityOverlay to ""
			end try
			if securityOverlay contains "Profiles" then
				delay 0.1
				exit repeat
			else if securityOverlay contains "Device Management" then
				exit repeat
			else
				delay 0.1
			end if
		end repeat
	end tell
end securityCheckVentura

on windowSearch(targetWindowTitle, targetProcessName)
	tell application "System Events" to tell process targetProcessName
		repeat
			delay 0.2
			try
				set activeWindow to (name of window 1)
				if activeWindow contains targetWindowTitle then exit repeat
			on error
				delay 0.2
			end try
		end repeat
	end tell
end windowSearch

on elementCheck(elementValue, targetProcess)
	tell application "System Events" to tell process targetProcess
		repeat
			delay 0.1
			try
				set elementReturn to (get value of static text 1 of sheet 1 of window 1)
			on error
				set elementReturn to false
			end try
			if elementReturn contains elementValue then
				exit repeat
			end if
			if elementReturn contains "failed" then
				set elementReturn to false
				exit repeat
			end if
		end repeat
	end tell
	return elementReturn
end elementCheck


--Used to retrieve an up-to-date Jamf enrollment profile for the instance. If not using Jamf, you can leave this alone (as it won't be called) as long as the block below about Jamf enrollment is also commented out. The script expects the enrollment profile in /tmp/ as enrollmentProfile.mobileconfig in that case, so make sure one's there if so.
on jamfEnrollmentProfile(jamfInvitationID, jamfEnrollmentURL)
	set payloadUUID to (do shell script "uuidgen | tr [A-Z] [a-z]")
	set payloadIdentifier to (do shell script "uuidgen")
	set profileReturn to "<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"><plist version=\"1.0\"><dict><key>PayloadUUID</key><string>" & payloadUUID & "</string><key>PayloadOrganization</key><string>JAMF Software</string><key>PayloadVersion</key><integer>1</integer><key>PayloadIdentifier</key><string>" & payloadIdentifier & "</string><key>PayloadDescription</key><string>MDM Profile for mobile device management</string><key>PayloadType</key><string>Profile Service</string><key>PayloadDisplayName</key><string>MDM Profile</string><key>PayloadContent</key><dict><key>Challenge</key><string>" & jamfInvitationID & "</string><key>URL</key><string>" & jamfEnrollmentURL & "/enroll/profile</string><key>DeviceAttributes</key><array><string>UDID</string><string>PRODUCT</string><string>SERIAL</string><string>VERSION</string><string>DEVICE_NAME</string><string>COMPROMISED</string></array></dict></dict></plist>"
	return (profileReturn) as string
end jamfEnrollmentProfile

on jamfInventoryPreload(jamfServerContact, passedAuthToken, deviceSerial, attributeName, attributeValue)
	--Currently set to provide a single attribute, but can be expanded to any and all Inventory Preload fields.
	set preloadJSON to ("{\"serialNumber\": \"" & deviceSerial & "\",\"deviceType\": \"Computer\", \"extensionAttributes\": [    {      \"name\": \"" & attributeName & "\",      \"value\": \"" & attributeValue & "\"    }  ]}")
	set preloadReturn to (do shell script "curl -X POST " & jamfServerContact & "uapi/v2/inventory-preload/records -H 'accept: application/json' -H 'Content-Type: application/json' -H 'Authorization: Bearer " & passedAuthToken & "'  -d '" & preloadJSON & "'")
end jamfInventoryPreload

on authCallToken(jamfServer, APIName, APIPass)
	try
		--Attempts to connect via Jamf Client Credentials.
		set authCall to (do shell script "curl -X POST -H 'Content-Type: application/x-www-form-urlencoded' '" & jamfServer & "api/oauth/token' --data-urlencode 'client_id=" & APIName & "' --data-urlencode 'client_secret=" & APIPass & "' --data-urlencode 'grant_type=client_credentials'")
		set AppleScript's text item delimiters to "_token\":\""
		set transitionalToken to text item 2 of authCall
		set AppleScript's text item delimiters to "\",\"scope"
		set authToken to text item 1 of transitionalToken as string
	on error
		set authToken to "401 Unauthorized"
	end try
	try
		if authToken starts with "401" then
			--If previous fails, try to authenticate with username and password.
			set credential64 to (do shell script "printf '" & APIName & ":" & APIPass & "' | /usr/bin/iconv -t ISO-8859-1 | base64 -i -") --Thanks, Bill!
			set authCall to (do shell script "curl -X POST '" & jamfServer & "api/v1/auth/token' -H 'accept: application/json' -H 'Authorization: Basic " & credential64 & "'")
			set AppleScript's text item delimiters to ":"
			set transitionalToken to text item 2 of authCall
			set AppleScript's text item delimiters to "\",\"expires\""
			set authToken to text item 1 of transitionalToken as string
		end if
	on error
		set authToken to "401 Unauthorized"
	end try
	if authToken starts with "401" then
		--If previous fails, try to authenticate with username and password (older method).
		set authCall to (do shell script "curl -X POST --header 'Content-Type: application/json' --header 'Accept: application/json' '" & jamfServer & "uapi/auth/tokens' -ksu \"" & APIName & "\":\"" & APIPass & "\" | awk {'print $3'}")
		set AppleScript's text item delimiters to ","
		set {authToken, authTime} to text items of authCall
		set AppleScript's text item delimiters to ""
		set authToken to (do shell script " echo " & authToken & " | sed -e 's/^M//g'")
		set authToken to (characters 2 through end of authToken) as string
	end if
	return authToken
end authCallToken

on getKandjiProfile(kandjiDomain, kandjiRegion, kandjiBlueprintID, kandjiEnrollmentCode)
	set AppleScript's text item delimiters to ".kandji.io/"
	set kandjiPrefix to text item 1 of kandjiDomain
	set AppleScript's text item delimiters to ""
	set kandjiAPI to (kandjiPrefix & ".clients." & kandjiRegion & ".kandji.io/app/v1/mdm/enroll-ota/" & kandjiBlueprintID & "?code=" & kandjiEnrollmentCode & " -o /tmp/kandjiEncoded.plist") as string
	set base64JSONProfile to do shell script "curl " & kandjiAPI
	do shell script "/usr/bin/plutil -extract base64encodedProfile raw -o - /tmp/kandjiEncoded.plist | base64 -d > /tmp/enrollmentProfile.mobileconfig"
end getKandjiProfile

on fleetAuthToken(fleetServerIn, fleetAPIName, fleetAPIPass)
	--Attempts to connect via Fleet Credentials.
	set curlPath to "/opt/homebrew/opt/curl/bin/curl -k"
	set authToken to (do shell script curlPath & " -H 'Content-Type: application/json' -L '" & fleetServerIn & "/api/v1/fleet/login' --data-raw '{ \"email\": \"" & fleetAPIName & "\", \"password\": \"" & fleetAPIPass & "\"}' | grep 'token' | awk '{print $NF}' | tr -d '\"\\'")
	return authToken
end fleetAuthToken

on fleetEnrollment(fleetServerIn, fleetAPITokenIn)
	--If testing Fleet with a self-signed certificate, the Homebrew version of curl is required (with the -k flag).
	--set curlPath to "/opt/homebrew/opt/curl/bin/curl -k"
	set curlPath to "/usr/bin/curl"
	set profileXML to (do shell script curlPath & " -L '" & fleetServerIn & "/api/v1/fleet/enrollment_profiles/manual' -H 'Authorization: Bearer " & fleetAPITokenIn & "' > /tmp/enrollmentProfile.mobileconfig")
	return profileXML
end fleetEnrollment

--visiLog sends messages to DEPNotify to update visual status.
on visiLog(updateType, logMessage, privilegedName, privilegedPass)
	try
		--Will only write to DEPNotify.log if useDEPNotify flag is 1.
		set updateFlag to (do shell script "defaults read com.amazon.dsx.ec2.enrollment.automation useDEPNotify")
	on error
		set updateFlag to "0"
	end try
	if updateFlag is "1" then
		do shell script "echo '" & updateType & ": " & logMessage & "' >> /var/tmp/depnotify.log" user name privilegedName password privilegedPass with administrator privileges
	end if
end visiLog

--This subroutine is for auto-repairing Homebrew permissions for non-default admin users.
on brewPrivilegeRepair(architectureType, adminIn, passIn)
	if architectureType contains "ARM" then
		set brewPath to "/opt/homebrew"
	else
		set brewPath to "/usr/local/bin"
	end if
	do shell script "chown -R " & adminIn & " " & brewPath & " " & brewPath & "/Cellar " & brewPath & "/Frameworks " & brewPath & "/bin " & brewPath & "/etc " & brewPath & "/etc/bash_completion.d " & brewPath & "/include " & brewPath & "/lib " & brewPath & "/lib/pkgconfig " & brewPath & "/opt " & brewPath & "/sbin " & brewPath & "/share " & brewPath & "/share/doc " & brewPath & "/share/man " & brewPath & "/share/man/man1 " & brewPath & "/share/zsh " & brewPath & "/share/zsh/site-functions " & brewPath & "/var/homebrew/linked " & brewPath & "/var/homebrew/locks" user name adminIn password passIn with administrator privileges
	do shell script "chmod u+w " & brewPath & " " & brewPath & "/Cellar " & brewPath & "/Frameworks " & brewPath & "/bin " & brewPath & "/etc " & brewPath & "/etc/bash_completion.d " & brewPath & "/include " & brewPath & "/lib " & brewPath & "/lib/pkgconfig " & brewPath & "/opt " & brewPath & "/sbin " & brewPath & "/share " & brewPath & "/share/doc " & brewPath & "/share/man " & brewPath & "/share/man/man1 " & brewPath & "/share/zsh " & brewPath & "/share/zsh/site-functions " & brewPath & "/var/homebrew/linked " & brewPath & "/var/homebrew/locks" --user name adminIn password passIn with administrator privileges
end brewPrivilegeRepair

on clickCheck(prependPath)
	set appToCheck to "cliclick"
	set isAppInstalled to null
	--Including static check to prevent unneeded calls to homebrew.
	set preBinaryCheck to (do shell script "test -f /Users/Shared/._enroll-ec2-mac/" & appToCheck & " && echo '" & appToCheck & " successfully found' || echo '" & appToCheck & " not found'")
	if preBinaryCheck contains "successfully" then
		set isAppInstalled to true
	end if
	if isAppInstalled is not true then
		set binaryCheck to (do shell script "test -f /opt/homebrew/bin/" & appToCheck & " && echo '" & appToCheck & " successfully found' || echo '" & appToCheck & " not found'")
		if binaryCheck contains "successfully" then
			set isAppInstalled to true
		end if
		if isAppInstalled is not true then
			try
				set appCheckPath to do shell script prependPath & "which " & appToCheck
				set isAppInstalled to true
			on error
				try
					set appCheckPath to do shell script prependPath & "brew list"
				on error
					set isAppInstalled to false
					set appCheckPath to ""
				end try
				if appCheckPath does not contain appToCheck then
					set isAppInstalled to false
				else
					set isAppInstalled to true
				end if
			end try
		end if
	end if
	return isAppInstalled
end clickCheck

on jamfSignatureVerify(adminIn, passIn)
	try
		--This routine checks if renewing (removing/re-downloading) the current profile is necessary.
		set checkProfileValidity to (do shell script "/usr/local/bin/jamf policy > /tmp/jamfErrorCheck.txt ; cat /tmp/jamfErrorCheck.txt" user name adminIn password passIn with administrator privileges)
		
		--If policy is currently running (and no error is recorded), check again when it's likely to be done.
		if checkProfileValidity contains "have completed" then
			log "Waiting for Jamf agent to finish policy run…"
			delay 300
			set checkProfileValidity to (do shell script "/usr/local/bin/jamf policy > /tmp/jamfErrorCheck.txt ; cat /tmp/jamfErrorCheck.txt" user name adminIn password passIn with administrator privileges)
		end if
	on error
		--Any error to the command, this workflow considers it not needing a Jamf profile removed.
		set checkProfileValidity to null
	end try
	if checkProfileValidity contains "Device Signature Error" then
		return "No"
	else
		return "Yes"
	end if
end jamfSignatureVerify

on run argv
	
	--This block is here primarily for testing: if you just run enroll-ec2-mac, it will attempt to enroll (running without arguments).
	try
		get argv
	on error
		set argv to ""
	end try
	
	
	--To turn on DEPNotify screen: defaults write com.amazon.dsx.ec2.enrollment.automation useDEPNotify true
	--Or: use --with-screen option when running (will set the preference).
	--Override if installing DEPNotify in a different location. 
	
	if argv contains "--with-screen" then
		do shell script "defaults write com.amazon.dsx.ec2.enrollment.automation useDEPNotify true"
		delay 0.1
	end if
	if argv contains "--no-screen" then
		do shell script "defaults write com.amazon.dsx.ec2.enrollment.automation useDEPNotify false"
		delay 0.1
	end if
	
	if argv contains "--setup" then
		set argv to "--launchagent --run-agent"
	end if
	
	if argv contains "--restart-agent" then
		do shell script "launchctl unload -w /Library/LaunchAgents/com.amazon.dsx.ec2.enrollment.automation.startup.plist ; launchctl load -w /Library/LaunchAgents/com.amazon.dsx.ec2.enrollment.automation.startup.plist"
		return
	end if
	
	if argv contains "--stop-agent" then
		do shell script "launchctl unload -w /Library/LaunchAgents/com.amazon.dsx.ec2.enrollment.automation.startup.plist"
		return
	end if
	
	set appName to "enroll-ec2-mac"
	set jamfSecretID to my MMSecretVar()
	
	--By default, enroll-ec2-mac uses AWS Secrets manager to retrieve credentials for runtime.
	
	--Remember to set the ID of your secret in the MMSecretVar subroutine (or via the defaults write instruction) at the very top. See repository for CloudFormation and Terraform templates for IAM and Secrets Manager/Parameter Store entries.
	
	--BEGIN CREDENTIAL RETRIEVAL ROUTINES--
	
	try
		--Override the region that the secret is in by setting this preference (e.g. defaults write com.amazon.dsx.ec2.enrollment.automation secretRegion us-east-1). Otherwise, it's detected based on the current instance's metadata.
		set currentRegion to (do shell script "defaults read com.amazon.dsx.ec2.enrollment.automation secretRegion")
	on error
		set currentRegion to (my awsMD("placement/region"))
	end try
	set jamfServerDomain to my retrieveSecret(currentRegion, jamfSecretID, "jamfServerDomain")
	set SDKUser to my retrieveSecret(currentRegion, jamfSecretID, "jamfEnrollmentUser")
	set SDKPassword to my retrieveSecret(currentRegion, jamfSecretID, "jamfEnrollmentPassword")
	set localAdmin to my retrieveSecret(currentRegion, jamfSecretID, "localAdmin")
	set adminPass to my retrieveSecret(currentRegion, jamfSecretID, "localAdminPassword")
	
	set mdmServerDomain to jamfServerDomain
	
	--END CREDENTIAL RETRIEVAL ROUTINES--
	
	set pathPossibilities to "/Users/Shared/._enroll-ec2-mac:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/opt/homebrew/sbin:"
	set pathPrefix to "PATH=" & pathPossibilities & " ; "
	
	
	--Main settings retrieval starts here.
	
	--If using random-admin-credentials.sh for one-time credentials, the line below will update the password.
	try
		set adminPass to (do shell script "cat /Users/Shared/.stageHandCredential")
		set stageHand to "1"
	on error
		--If using a different administrator account to the one logging in, touch the file indicated below.
		try
			set adminSet to (do shell script "cat /Users/Shared/._enroll-ec2-mac/.userSetupComplete")
			set stageHand to "1"
		on error
			set stageHand to "0"
		end try
	end try
	
	--Path to the enroll-ec2-mac script.
	set mmPath to "/Users/Shared/"
	
	set DEPNotifyPath to mmPath & "._enroll-ec2-mac/"
	try
		do shell script "mkdir -p " & DEPNotifyPath
	end try
	try
		set useDEPNotifyPreference to (do shell script "defaults read com.amazon.dsx.ec2.enrollment.automation useDEPNotify")
	on error
		set useDEPNotifyPreference to "0"
	end try
	if useDEPNotifyPreference contains "1" then
		set useDEPNotify to true
	else if useDEPNotifyPreference contains "true" then
		set useDEPNotify to true
	else
		set useDEPNotify to false
	end if
	
	--Override this if using a different user to enroll than the one that's being automatically logged into, or if manually setting auto-login and timeout preferences.
	try
		set autoLogin to (do shell script "defaults read com.amazon.dsx.ec2.enrollment.automation autoLogin")
	on error
		set autoLogin to "1"
	end try
	
	set AppleScript's text item delimiters to "."
	set macOSMajor to text item 1 of system version of (system info) as integer
	set AppleScript's text item delimiters to ""
	set archType to CPU type of (system info)
	log "macOS " & macOSMajor
	
	if macOSMajor is greater than or equal to 13 then
		set settingsApp to "System Settings"
	else
		set settingsApp to "System Preferences"
	end if
	
	--Set to "" instead to enable auto-update of homebrew.
	set brewUpdateFlag to "export HOMEBREW_NO_AUTO_UPDATE=1 ; "
	
	
	if argv contains "--firstrun" then
		
		--Implementing as a variable to be optional.
		
		set progress description to "Setting up and checking permissions for " & appName & "…"
		log progress description
		set progress total steps to 7
		--firstRun argument for setup.
		
		if autoLogin is "1" then
			--Note: these are not always reliable. Most critical is setting auto-login if you'd like instances enrolled before the user is able to access the instance.
			--Set screen saver timeout.
			try
				do shell script "defaults -currentHost write com.apple.screensaver idleTime 0" user name localAdmin password adminPass with administrator privileges
			end try
			--Set AutoLogin (enabled by default).	
			try
				do shell script "sysadminctl -autologin set -userName " & localAdmin & " -password " & quoted form of adminPass user name localAdmin password adminPass with administrator privileges
			end try
		end if
		
		--Disables the Jamf VM flag, which separates records from MDM enrollments. Setting on both user and global levels.
		do shell script "defaults write /Library/Preferences/com.jamfsoftware.jamf is_virtual_machine 0" user name localAdmin password adminPass with administrator privileges
		do shell script "defaults write com.jamfsoftware.jamf is_virtual_machine 0"
		
		--Creates a directory that the Jamf binary needs to function on mac1 instances.
		try
			do shell script "mkdir -p /private/var/db/locationd" user name localAdmin password adminPass with administrator privileges
		end try
		try
			do shell script "chown _locationd:_locationd /private/var/db/locationd" user name localAdmin password adminPass with administrator privileges
		end try
		
		set runTotal to 0
		repeat
			set accessTotal to 0
			set progress completed steps to accessTotal
			--FirstRun routines make sure permissions are set and install the LaunchAgent. This is for administrative setup, but may not be necessary with a properly set AMI.
			try
				if useDEPNotify is true then
					do shell script "killall -m DEPNotify" user name localAdmin password adminPass with administrator privileges
				end if
			end try
			
			--Permissions for Ventura: Accessibility, App Management, control System Settings app
			set progress completed steps to accessTotal
			set progress additional description to "Running permissions checks…"
			log progress additional description
			
			--Authorizes Accessibility access for osascript/enroll-ec2-mac.
			try
				my dsUIScriptEnable()
				set accessTotal to (accessTotal + 1)
				set progress completed steps to accessTotal
			end try
			
			--Download and open DEPNotify to mask screen during actions (if enabled).
			--This needs to run twice in order to get the alert…it's primarily why the script contains the extra repeat for --firstrun.
			if useDEPNotify is true then
				try
					do shell script "curl -s https://files.jamfconnect.com/DEPNotify.zip > /tmp/DEPNotify.zip ; unzip -o /tmp/DEPNotify.zip -d " & DEPNotifyPath
					set accessTotal to (accessTotal + 1)
					set progress completed steps to accessTotal
				on error
					delay 1
					set openPrefFlag to button returned of (display dialog "App Management permissions are required for " & appName & " to run. Please grant them by clicking Allow in the notification (or, in System Settings ⤑ Privacy ⤑ App Management) and clicking the switch next to osascript." buttons {"Open System Settings", "OK"} default button "OK")
					if openPrefFlag is not "OK" then
						do shell script "open /System/Library/PreferencePanes/Security.prefPane"
						delay 10
					end if
					delay 2
				end try
				
				try
					do shell script DEPNotifyPath & "DEPNotify.app/Contents/MacOS/DEPNotify -fullScreen > /dev/null 2>&1 &"
					set accessTotal to (accessTotal + 1)
					set progress completed steps to accessTotal
				end try
				delay 0.5
				try
					do shell script "killall -m DEPNotify" user name localAdmin password adminPass with administrator privileges
					set accessTotal to (accessTotal + 1)
					set progress completed steps to accessTotal
				end try
			else
				set accessTotal to (accessTotal + 3)
				set progress completed steps to accessTotal
			end if
			
			try
				do shell script "open /System/Library/PreferencePanes/Profiles.prefPane"
				delay 0.5
				tell application "System Events" to tell process settingsApp to get name of window 1
				set accessTotal to (accessTotal + 1)
				set progress completed steps to accessTotal
			end try
			
			if macOSMajor is greater than or equal to 13 then
				set clickInstalled to my clickCheck(pathPrefix)
				tell application "System Events"
					if clickInstalled is not true then
						log "Preinstalling helper app…"
						try
							do shell script pathPrefix & brewUpdateFlag & "brew install cliclick"
						on error
							--If using a different user than default, change Homebrew ownership.
							my brewPrivilegeRepair(archType, localAdmin, adminPass)
							delay 0.5
							do shell script pathPrefix & brewUpdateFlag & "brew install cliclick"
						end try
						set accessTotal to (accessTotal + 1)
					else
						try
							tell application settingsApp to activate
							delay 2
							tell application "System Events" to tell process settingsApp to tell window 1
								set {xPosition, yPosition} to position
								set {xSize, ySize} to size
							end tell
							delay 0.5
							try
								do shell script pathPrefix & "cliclick dc:" & (xPosition + (xSize div 2)) & "," & (yPosition + (ySize div 2))
							on error
								do shell script pathPrefix & brewUpdateFlag & "brew install cliclick"
								do shell script pathPrefix & "cliclick dc:" & (xPosition + (xSize div 2)) & "," & (yPosition + (ySize div 2))
							end try
						end try
						set accessTotal to (accessTotal + 1)
					end if
				end tell
			else
				set accessTotal to (accessTotal + 1)
				set progress completed steps to accessTotal
			end if
			set runTotal to runTotal + 1
			if runTotal is greater than 2 then
				if accessTotal is not 6 then
					set accessErrorButton to button returned of (display dialog "All privileges not resolved." buttons {"Unload", "Reattempt"} default button "Reattempt")
					if accessErrorButton is "Unload" then
						try
							do shell script "launchctl unload -w /Library/LaunchAgents/com.amazon.dsx.ec2.enrollment.automation.startup.plist"
							delay 0.5
						end try
						return
					end if
				else
					tell application settingsApp to quit
					--removes firstrun flag from LaunchAgent after unload.
					set prepButton to button returned of (display dialog "First run successfully prepared! Click OK here, and then create an image (or reboot) for MDM enrollment." buttons {"Re-run Permissions", "OK"} default button "OK")
					if prepButton is "OK" then
						do shell script "sed -i '' '13d' /Library/LaunchAgents/com.amazon.dsx.ec2.enrollment.automation.startup.plist" user name localAdmin password adminPass with administrator privileges
						exit repeat
					end if
				end if
			end if
		end repeat
		
		return
	else if argv contains "--launchagent" then
		try
			do shell script "launchctl unload -w /Library/LaunchAgents/com.amazon.dsx.ec2.enrollment.automation.startup.plist" user name localAdmin password adminPass with administrator privileges
			delay 1
		end try
		--Raw XML to create LaunchAgent for firstRun.
		if argv contains "--no-first-run" then
			set firstRunOptionString to ""
		else
			set firstRunOptionString to "
                <string>--firstrun</string>"
		end if
		set launchAgentPlistXML to "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
        <key>KeepAlive</key>
        <false/>
        <key>Label</key>
        <string>com.amazon.dsx.ec2.enrollment.automation.startup</string>
        <key>ProgramArguments</key>
        <array>
                <string>/usr/bin/osascript</string>
                <string>" & mmPath & "enroll-ec2-mac.scpt</string>" & firstRunOptionString & "
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>StandardErrorPath</key>
        <string>/tmp/MMErrors.log</string>
        <key>StandardOutPath</key>
        <string>/tmp/MMOutput.log</string>
</dict>
</plist>"
		
		do shell script "echo '" & launchAgentPlistXML & "' > /Library/LaunchAgents/com.amazon.dsx.ec2.enrollment.automation.startup.plist" user name localAdmin password adminPass with administrator privileges
		
		
		do shell script "chown root:wheel /Library/LaunchAgents/com.amazon.dsx.ec2.enrollment.automation.startup.plist" user name localAdmin password adminPass with administrator privileges
		
		if argv contains "--run-agent" then
			log return & return
			log appName & " LaunchAgent installed successfully, running…"
			delay 0.5
			do shell script "launchctl unload -w /Library/LaunchAgents/com.amazon.dsx.ec2.enrollment.automation.startup.plist; launchctl load -w /Library/LaunchAgents/com.amazon.dsx.ec2.enrollment.automation.startup.plist"
		else
			log return & return
			log appName & " LaunchAgent installed successfully."
		end if
		
	else
		
		try
			set enrollmentCheckCLI to (do shell script "/usr/bin/profiles status -type enrollment | awk '/MDM/' | grep 'enrollment: Yes' " user name localAdmin password adminPass with administrator privileges)
		on error
			set enrollmentCheckCLI to null
		end try
		
		if enrollmentCheckCLI does not contain "Yes" then
			do shell script "open /System/Library/PreferencePanes/Profiles.prefPane"
			delay 2
			--check for enrollment message
			tell application "System Events" to tell process settingsApp
				try
					set managedStatus to (value of static text 1 of window 1)
				on error
					set managedStatus to "No"
				end try
				if managedStatus contains "Managed" then
					set enrollmentCheckAll to my jamfSignatureVerify(localAdmin, adminPass)
				else
					set managedStatus to "No"
					set enrollmentCheckAll to "No"
				end if
			end tell
		else
			--Secondary check for enrollment (uses Jamf binary to test communications).
			set enrollmentCheckAll to my jamfSignatureVerify(localAdmin, adminPass)
			log enrollmentCheckAll
		end if
		
		
		if enrollmentCheckAll does not contain "Yes" then
			try
				do shell script "rm -f /var/tmp/depnotify.log" user name localAdmin password adminPass with administrator privileges
			end try
			if useDEPNotify is true then
				--To use a custom logo with DEPNotify: 
				--defaults write com.amazon.dsx.ec2.enrollment.automation customLogo 1
				--defaults write com.amazon.dsx.ec2.enrollment.automation customLogoURL "https://…"
				try
					set customLogo to (do shell script "defaults read com.amazon.dsx.ec2.enrollment.automation customLogo")
				on error
					set customLogo to "0"
				end try
				
				
				if customLogo is "1" then
					try
						set customLogoURL to (do shell script "defaults read com.amazon.dsx.ec2.enrollment.automation customLogoURL")
					on error
						set customLogoURL to "https://d1.awsstatic.com/logos/Site-Merch_EC2-Mac_Editorial.1231c2e7720ac6bd5abb6d419dff0ad85bf95801.png"
					end try
					do shell script "curl -s " & customLogoURL & " > /tmp/logo.png"
					my visiLog("Command: Image", "/tmp/logo.png", localAdmin, adminPass)
				end if
				my visiLog("Command: MainTitle", appName, localAdmin, adminPass)
				my visiLog("Command: WindowStyle", "NotMovable", localAdmin, adminPass)
				my visiLog("Command: WindowStyle", "ActivateOnStep", localAdmin, adminPass)
				my visiLog("Command: MainText", "Now enrolling, please wait…", localAdmin, adminPass)
				my visiLog("Status", "Starting enrollment process…", localAdmin, adminPass)
				
				
			end if
			
			--Flag so that a cleanup doesn't happen if we're just testing.
			--When ready for production with cleanup, use "defaults read com.amazon.dsx.ec2.enrollment.automation prodFlag 1" to set.
			try
				set prodFlag to (do shell script "defaults read com.amazon.dsx.ec2.enrollment.automation prodFlag")
				get prodFlag
			on error
				set prodFlag to "0"
			end try
			
			--Set a management user here. A randomized UUID is chosen for a password.
			set managementUser to "_enroll-ec2-mac"
			set managementPass to (do shell script "uuidgen")
			
			--Checks for Accessibility privileges.
			my dsUIScriptEnable()
			
			--Download and open DEPNotify to mask screen during actions (if enabled).
			if useDEPNotify is true then
				do shell script "curl -s https://files.jamfconnect.com/DEPNotify.zip > /tmp/DEPNotify.zip ; unzip -o /tmp/DEPNotify.zip -d " & DEPNotifyPath
				do shell script DEPNotifyPath & "DEPNotify.app/Contents/MacOS/DEPNotify -fullScreen > /dev/null 2>&1 &"
				delay 0.5
			end if
			my visiLog("Status", ("macOS " & macOSMajor & " (" & archType & " architecture)."), localAdmin, adminPass)
			set enrollType to "mdm"
			if mdmServerDomain contains "kandji" then
				--------BEGIN KANDJI PROFILE ROUTINES--------
				--Note: currently there is not yet an out-of-contact profile check/remedy for Kandji.
				set kandjiServerAddress to (my tripleDouble(mdmServerDomain))
				--Kandji has two main tenants, US and EU. Script will use the same region as the Secret to set.
				if currentRegion contains "us" then
					set kandjiTenantRegion to "us-1"
				else if currentRegion contains "ca" then
					set kandjiTenantRegion to "us-1"
				else
					set kandjiTenantRegion to "eu-1"
				end if
				my getKandjiProfile(kandjiServerAddress, kandjiTenantRegion, SDKUser, SDKPassword)
				--------END KANDJI PROFILE ROUTINES--------
			else if mdmServerDomain contains "addigy" then
				--------BEGIN ADDIGY PROFILE ROUTINES--------
				--Note: currently there is not yet an out-of-contact profile check/remedy for Addigy.
				set addigyAddress to (my tripleDouble(mdmServerDomain))
				do shell script "curl " & addigyAddress & " -o /tmp/enrollmentProfile.mobileconfig"
				--------END ADDIGY PROFILE ROUTINES--------
			else if mdmServerDomain contains "fleet" then
				--If testing Fleet with a self-signed certificate, the Homebrew version of curl is required (with the -k flag).
				--do shell script pathPrefix & brewUpdateFlag & "brew install curl"
				set AppleScript's text item delimiters to "fleet-"
				set fleetAddress to text item 2 of mdmServerDomain
				set AppleScript's text item delimiters to ""
				set fleetAddress to (my tripleDouble(fleetAddress))
				if SDKUser is not "fleet-token" then
					set currentFleetToken to fleetAuthToken(fleetAddress, SDKUser, SDKPassword)
				else
					set currentFleetToken to SDKPassword
				end if
				my fleetEnrollment(fleetAddress, currentFleetToken)
				--------END FLEET PROFILE ROUTINES--------				
			else if mdmServerDomain contains "adde-mm" then
				--------BEGIN ADDE ROUTINES--------
				my accountDriven(SDKUser, SDKPassword, "device")
				set enrollType to "account"
				--------END ADDE ROUTINES--------
			else if mdmServerDomain contains "adue-mm" then
				--------BEGIN ADUE ROUTINES--------
				my accountDriven(SDKUser, SDKPassword, "user")
				set enrollType to "account"
				--------END ADUE ROUTINES--------
			else
				--------BEGIN JAMF PROFILE ROUTINES--------
				
				--Expiration date for the invitation. Set at 2 days in the command below, but may be set to anything desired.
				set expirationDate to (do shell script "date -v+2d +\"%Y-%m-%d %H:%M:%S\"")
				
				set profileSignatureCheck to jamfSignatureVerify(localAdmin, adminPass)
				
				--If currently enrolled, remove current profile.
				if profileSignatureCheck contains "No" then
					my visiLog("Status", ("Removing current, out-of-contact profile…"), localAdmin, adminPass)
					do shell script "/usr/local/bin/jamf removeMdmProfile" user name localAdmin password adminPass with administrator privileges
					--This delay is more of a safeguard, may be adjusted/removed depending on contextual operations (and incidental delays).
					delay 2
				end if
				
				
				set jamfServerAddress to (my tripleDouble(jamfServerDomain))
				
				--Initial check for an invitation code set inline or via plist.
				set invitationID to my getInvitationID()
				
				--If no invitation ID is found, call the Jamf API for a new one.
				if invitationID is false then
					try
						set currentAuthToken to (authCallToken(jamfServerAddress, SDKUser, SDKPassword))
					on error
						log "Error: Jamf credentials do not appear correct. Error below:" & return
						try
							log currentAuthToken
						end try
						return
					end try
					set invitationXML to "<computer_invitation><invitation_type>DEFAULT</invitation_type><expiration_date>" & expirationDate & "</expiration_date><ssh_username>" & managementUser & "</ssh_username><ssh_password>" & managementPass & "</ssh_password><multiple_users_allowed>false</multiple_users_allowed><create_account_if_does_not_exist>true</create_account_if_does_not_exist><hide_account>true</hide_account><lock_down_ssh></lock_down_ssh><enrolled_into_site><id></id><name></name></enrolled_into_site><keep_existing_site_membership></keep_existing_site_membership><site><id></id><name></name></site></computer_invitation>"
					
					set targetResponseCode to (do shell script "curl -sH \"Accept: application/xml\" -H \"Content-Type: application/xml\" -H \"Authorization: Bearer " & currentAuthToken & "\" " & jamfServerAddress & "JSSResource/computerinvitations/id/id0 -X POST -d '" & invitationXML & "'")
					
					set AppleScript's text item delimiters to "<invitation>"
					set invitationIDTransitory to text item 2 of targetResponseCode
					set AppleScript's text item delimiters to "</"
					set invitationID to text item 1 of invitationIDTransitory
					set AppleScript's text item delimiters to ""
				end if
				
				do shell script "echo " & quoted form of (my jamfEnrollmentProfile(invitationID, jamfServerAddress)) & " > /tmp/enrollmentProfile.mobileconfig"
				
				--Disable the auto-check for VMs, which separates profiles from agent enrollments (setting on both user and global levels for compatibility).
				do shell script "defaults write /Library/Preferences/com.jamfsoftware.jamf is_virtual_machine 0" user name localAdmin password adminPass with administrator privileges
				do shell script "defaults write com.jamfsoftware.jamf is_virtual_machine 0"
				
				--Inventory preload (optional, requires Create/Read/Update Inventory Preload API user permissions for Jamf account)
				--Activate with: defaults write com.amazon.dsx.ec2.enrollment.automation invPreload 1
				--Values can be set below inline (default is setting "Vendor" to "AWS" in Purchasing tab of Jamf device records.)
				try
					set invPreloadFlag to (do shell script "defaults read com.amazon.dsx.ec2.enrollment.automation invPreload")
					get invPreloadFlag
				on error
					set invPreloadFlag to "0"
				end try
				if invPreloadFlag is not "0" then
					set preloadFlag to "vendor"
					set preloadValue to "AWS"
					set enrollingSerial to (do shell script "system_profiler SPHardwareDataType | grep 'Serial Number (system)' | awk '{print $NF}'")
					my jamfInventoryPreload(jamfServerAddress, currentAuthToken, enrollingSerial, preloadFlag, preloadValue)
				end if
				--------END JAMF PROFILE ROUTINES--------
			end if
			--Opens the profile, bringing the UI notification up.
			if enrollType is not "account" then
				do shell script "open /tmp/enrollmentProfile.mobileconfig"
				delay 0.5
				my visiLog("Status", "Profile downloaded from management…", localAdmin, adminPass)
				
				--A "just in case," as System Preferences doesn't like to be already open to navigate to the pane.
				try
					tell application settingsApp to quit
					delay 0.5
					--my visiLog("QuitPreferences")
				end try
				try
					tell application "BluetoothSetupAssistant" to quit
					delay 0.5
					--my visiLog("QuitBTSetupAssistant")
				end try
				try
					do shell script "killall -m BluetoothSetupAssistant"
				end try
				
				--Opens the System Preferences app and navigates to the Profiles pane.
				do shell script "open /System/Library/PreferencePanes/Profiles.prefPane"
				if macOSMajor is 14 then
					my windowSearch("Privacy", settingsApp)
					tell application "System Events" to tell process settingsApp
						repeat with i from 1 to 10
							try
								set paneName to value of (attribute "AXEnabled" of button i of group 6 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window "Privacy & Security")
							on error
								try
									click button (i - 1) of group 6 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window "Privacy & Security"
								end try
								my windowSearch("Profiles", settingsApp)
								
								exit repeat
							end try
						end repeat
					end tell
				else if macOSMajor is 15 then
					delay 2
					repeat with sidebarSearch from 2 to 8
						try
							tell application "System Events" to tell process "System Settings"
								if (get value of static text 1 of UI element 1 of row sidebarSearch of outline 1 of scroll area 1 of group 1 of splitter group 1 of group 1 of window 1) contains "Profile" then
									set sidebarTarget to (UI element 1 of row sidebarSearch of outline 1 of scroll area 1 of group 1 of splitter group 1 of group 1 of window 1)
									exit repeat
								end if
							end tell
						end try
					end repeat
					delay 1
					tell application "System Events" to tell process "System Settings" to tell sidebarTarget
						set {xPosition, yPosition} to position
						set {xSize, ySize} to size
					end tell
					delay 0.5
					try
						do shell script pathPrefix & "cliclick dc:" & (xPosition + (xSize div 2)) & "," & (yPosition + (ySize div 2))
					end try
				else
					my windowSearch("Profiles", settingsApp)
				end if
				my visiLog("Status", "Starting enrollment…", localAdmin, adminPass)
				
				delay 0.5
				
				if macOSMajor is greater than or equal to 13 then
					--Ventura runtime starts here.
					tell application "System Events" to tell process settingsApp
						
						--Sequoia 15.2
						try
							delay 1
							click button 1 of group 6 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1
							delay 1
						end try
						
						repeat
							try
								get value of static text 1 of UI element 1 of row 2 of table 1 of scroll area 1 of group 1 of scroll area 1 of group 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1
								exit repeat
							on error
								try
									--Sonoma b1
									get value of static text 1 of group 1 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1
									exit repeat
								end try
								delay 0.2
							end try
						end repeat
						delay 0.2
						try
							set profileCell to row 2 of table 1 of scroll area 1 of group 1 of scroll area 1 of group 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1
						on error
							try
								--Sonoma b1
								set profileCell to row 2 of table 1 of scroll area 1 of group 2 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1
							on error
								--Sequoia 15.0
								set profileCell to row 2 of outline 1 of scroll area 1 of group 2 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1
							end try
						end try
						set {xPosition, yPosition} to position of profileCell
						set {xSize, ySize} to size of profileCell
						set clickInstalled to my clickCheck(pathPrefix)
						if clickInstalled is not true then
							my visiLog("Status", "Installing helper app…", localAdmin, adminPass)
							try
								do shell script pathPrefix & brewUpdateFlag & "brew install cliclick"
							on error
								--If using a different user than default, change Homebrew ownership.
								my brewPrivilegeRepair(archType, localAdmin, adminPass)
								delay 0.5
								do shell script pathPrefix & brewUpdateFlag & "brew install cliclick"
							end try
							my visiLog("Status", "Helper app installed, please wait…", localAdmin, adminPass)
						end if
						if useDEPNotify is true then
							do shell script "killall -m DEPNotify" user name localAdmin password adminPass with administrator privileges
						end if
						delay 0.2
						tell application settingsApp to activate
						do shell script pathPrefix & "cliclick dc:" & (xPosition + (xSize div 2)) & "," & (yPosition + (ySize div 2))
						delay 0.2
						if useDEPNotify is true then
							do shell script DEPNotifyPath & "DEPNotify.app/Contents/MacOS/DEPNotify -fullScreen > /dev/null 2>&1 &"
						end if
						my visiLog("Status", "Continuing enrollment process…", localAdmin, adminPass)
						repeat
							try
								click button 1 of group 1 of sheet 1 of window 1
								exit repeat
							on error
								delay 0.5
							end try
						end repeat
						delay 0.2
						my elementCheck("profile", "System Settings")
						my visiLog("Status", "Authorizing profile…", localAdmin, adminPass)
						delay 0.2
						--Additional button options due to multiple MDMs handling the acceptance window differently.
						try
							click button "Install" of sheet 1 of window 1
						on error
							my securityCheckVentura()
							delay 0.5
							try
								click button "Install" of sheet 1 of window 1
							on error
								try
									click button "Enroll" of sheet 1 of window 1
								end try
							end try
						end try
						delay 0.2
						set the clipboard to adminPass
						--Checks to make sure the security window appears before typing credentials.
						my securityCheckVentura()
						delay 1
						--Pastes the administrator password, then presses Return.
						keystroke "v" using command down
						delay 0.1
						if stageHand is "1" then
							key code 48 using shift down
							delay 0.1
							keystroke "a" using command down
							delay 0.1
							set the clipboard to localAdmin
							keystroke "v" using command down
							delay 0.1
						end if
						keystroke return
						--Immediately clear the clipboard of the password.
						set the clipboard to null
						delay 0.1
						set the clipboard to null
						my visiLog("Status", "Profile authorized, awaiting enrollment confirmation…", localAdmin, adminPass)
						repeat
							try
								set managedValidationText to (get value of static text 1 of group 1 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1)
							on error
								try
									set managedValidationText to (get value of static text 1 of group 1 of scroll area 1 of group 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1)
									
								on error
									set managedValidationText to ""
								end try
							end try
							if managedValidationText contains "managed" then
								do shell script "killall -m System\\ Settings" user name localAdmin password adminPass with administrator privileges
								exit repeat
							else
								delay 0.5
							end if
							try
								set enrollmentCLI to (do shell script "/usr/bin/profiles status -type enrollment | awk '/MDM/' | grep 'enrollment: Yes' ")
							on error
								set enrollmentCLI to null
							end try
							if enrollmentCLI contains "Yes" then
								do shell script "killall -m System\\ Settings" user name localAdmin password adminPass with administrator privileges
								exit repeat
							end if
						end repeat
					end tell
					
				else
					--macOS 12 and below use this set of instructions.
					tell application "System Events" to tell process "System Preferences"
						--Make sure the Install button is available before continuing.
						repeat
							if (exists button "Install…" of scroll area 1 of window 1) then
								exit repeat
							else
								delay 0.5
							end if
						end repeat
						--Clicks the first "Install…" button…
						my visiLog("Status", "Authorizing profile…", localAdmin, adminPass)
						click button "Install…" of scroll area 1 of window 1
						delay 0.2
						--Checks for the first prompt, containing the word "profile" means it's ready.
						my elementCheck("profile", "System Preferences")
						click button "Install" of sheet 1 of window 1
						delay 0.2
						--Checks for a string in the next prompt. 
						if (my elementCheck("Are you sure you want to install profile", "System Preferences")) is not false then
							click button "Install" of sheet 1 of window 1
						else
							display notification "Enrollment failed. Please check the profile and try again."
							error -128
						end if
						delay 0.2
						set the clipboard to adminPass
						--Checks to make sure the security window appears before typing credentials.
						my securityCheck()
						--Types the administrator password, then presses Return.
						keystroke "v" using command down
						delay 0.1
						if stageHand is "1" then
							key code 48 using shift down
							delay 0.1
							keystroke "a" using command down
							delay 0.1
							set the clipboard to localAdmin
							delay 0.1
							keystroke "v" using command down
							delay 0.1
						end if
						keystroke return
						--Immediately clear the clipboard of the password.
						set the clipboard to null
						delay 0.2
						set the clipboard to null
						keystroke return
						delay 0.2
						my visiLog("Status", "Profile authorized, awaiting enrollment confirmation…", localAdmin, adminPass)
						
						--Checks to make sure the enrollment completes by checking the field in the lower left corner for updates.
						repeat
							if (value of static text 1 of window 1) contains "managed" then
								do shell script "killall -m System\\ Preferences" user name localAdmin password adminPass with administrator privileges
								exit repeat
							else
								delay 0.5
							end if
							try
								set enrollmentCLI to (do shell script "/usr/bin/profiles status -type enrollment | awk '/MDM/' | grep 'enrollment: Yes' ")
							on error
								set enrollmentCLI to null
							end try
							if enrollmentCLI contains "Yes" then
								exit repeat
							end if
						end repeat
					end tell
				end if
			else
				tell application "System Events" to tell process settingsApp
					--Checks to make sure the security window appears before typing credentials.
					my securityCheckVentura()
					delay 0.5
					set the clipboard to adminPass
					delay 0.1
					tell application "System Events" to tell process "SecurityAgent"
						tell text field 2 of window 1
							set {xPosition, yPosition} to position
							set {xSize, ySize} to size
						end tell
						do shell script pathPrefix & "cliclick dc:" & (xPosition + (xSize div 2)) & "," & (yPosition + (ySize div 2))
					end tell
					delay 0.5
					--Pastes the administrator password, then presses Return.
					keystroke "v" using command down
					delay 0.1
					try
						if stageHand is "1" then
							key code 48 using shift down
							delay 0.1
							keystroke "a" using command down
							delay 0.1
							set the clipboard to localAdmin
							keystroke "v" using command down
							delay 0.1
						end if
					end try
					keystroke return
					--Immediately clear the clipboard of the password.
					delay 0.1
					set the clipboard to null
					delay 0.1
					set the clipboard to null
					my visiLog("Status", "Profile authorized, awaiting enrollment confirmation…", localAdmin, adminPass)
					repeat
						try
							set managedValidationText to (get value of static text 1 of group 1 of scroll area 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1)
						on error
							try
								set managedValidationText to (get value of static text 1 of group 1 of scroll area 1 of group 1 of group 1 of group 2 of splitter group 1 of group 1 of window 1)
								
							on error
								set managedValidationText to ""
							end try
						end try
						if managedValidationText contains "managed" then
							do shell script "killall -m System\\ Settings" user name localAdmin password adminPass with administrator privileges
							exit repeat
						else
							delay 0.5
						end if
						try
							set enrollmentCLI to (do shell script "/usr/bin/profiles status -type enrollment | awk '/MDM/' | grep 'enrollment: Yes' ")
						on error
							set enrollmentCLI to null
						end try
						if enrollmentCLI contains "Yes" then
							do shell script "killall -m System\\ Settings" user name localAdmin password adminPass with administrator privileges
							exit repeat
						end if
					end repeat
				end tell
			end if
			
			--Enable screen sharing for user to connect. May be embedded, but good for "access enabled after enrollment." This flow only works if the AMI is prepared with auto-login.
			do shell script "launchctl enable system/com.apple.screensharing" user name localAdmin password adminPass with administrator privileges
			do shell script "launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist" user name localAdmin password adminPass with administrator privileges
			
			if prodFlag is "1" then
				--Cleanup routines. The tccutil full resets are total due to "osascript" not being a valid bundle ID that tccutil understands. Could be overcome with a compiled AppleScript bundle, though…
				my visiLog("Command: DeterminateManual", "4", localAdmin, adminPass)
				my visiLog("Command: DeterminateManualStep", "4", localAdmin, adminPass)
				my visiLog("Command: MainText", "Cleaning up…", localAdmin, adminPass)
				do shell script "tccutil reset Accessibility" user name localAdmin password adminPass with administrator privileges
				if useDEPNotify is "1" then
					do shell script "tccutil reset SystemPolicyAppBundles" user name localAdmin password adminPass with administrator privileges
				end if
				do shell script "tccutil reset AppleEvents" user name localAdmin password adminPass with administrator privileges
				--Turn off auto-login for the user.
				try
					do shell script "sysadminctl -autologin off" user name localAdmin password adminPass with administrator privileges
				end try
				--Removes secret ID in plist.
				try
					do shell script "defaults delete com.amazon.dsx.ec2.enrollment.automation"
				end try
				do shell script "rm -rf /tmp/enrollmentProfile.mobileconfig" user name localAdmin password adminPass with administrator privileges
				do shell script pathPrefix & brewUpdateFlag & "brew uninstall cliclick"
				try
					do shell script "rm -rf " & DEPNotifyPath user name localAdmin password adminPass with administrator privileges
				end try
				--Optional: uncomment the block below to disassociate IAM instance profile and remove access to secrets. This action requires additional IAM permissions to function.
				(*
				set EC2InstanceID to (my awsMD("instance-id"))
				set IAMProfileAssocID to (do shell script "PATH=" & pathPossibilities & " ; aws ec2 describe-iam-instance-profile-associations --query 'IamInstanceProfileAssociations[].AssociationId' --output text --filters Name=instance-id,Values=" & EC2InstanceID)
				set IAMProfileDisassociationReturn to (do shell script "PATH=" & pathPossibilities & " ; aws ec2 disassociate-iam-instance-profile --association-id " & IAMProfileAssocID & " --query 'IamInstanceProfileAssociation.State' --output text")
				if IAMProfileDisassociationReturn contains "disassociating" then
					log "IAM instance profile disassociated."
				end if
				*)
				try
					do shell script "launchctl unload -w /Library/LaunchAgents/com.amazon.dsx.ec2.enrollment.automation.startup.plist" user name localAdmin password adminPass with administrator privileges
				end try
			else
				try
					do shell script "launchctl unload -w /Library/LaunchAgents/com.amazon.dsx.ec2.enrollment.automation.startup.plist" user name localAdmin password adminPass with administrator privileges
				end try
			end if
			--Optional: remove the LaunchAgent entirely.
			--do shell script "rm -f /Library/LaunchAgents/com.amazon.dsx.ec2.enrollment.automation.startup.plist" user name localAdmin password adminPass with administrator privileges
			--Optional: remove the script runtime entirely.
			--do shell script "rm -f /Users/Shared/enroll-ec2-mac.scpt" user name localAdmin password adminPass with administrator privileges
			--Optional: logout
			--tell application "Finder" to log out
			
			my visiLog("Command: DeterminateManual", "4", localAdmin, adminPass)
			my visiLog("Command: DeterminateManualStep", "4", localAdmin, adminPass)
			my visiLog("Command: MainText", "Enrollment successful!", localAdmin, adminPass)
			my visiLog("Status", "Click the Complete button below to continue.", localAdmin, adminPass)
			my visiLog("Command: ContinueButton", "Complete", localAdmin, adminPass)
			--Optional delay to show completion. May be removed safely.
			delay 10
			
		else
			delay 1
		end if
	end if
end run
