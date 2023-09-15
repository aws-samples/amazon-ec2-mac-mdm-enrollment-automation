--LocalSecret

--The variables and the code below creates a plist to match the secret's format, and base64 encodes it to preserve characters. The secret "ID" if using this is the key for the plist, "jamfSecret" in the below code (and the default). Want to check if it's written? In Terminal:
--defaults read com.amazon.dsx.ec2.enrollment.automation 
--This should contain two entries when finished.

set jamfServerDomain to "myjamfinstance.jamfcloud.com"
set SDKUser to "myjamfusername"
set SDKPassword to "myjamfpassword"
tell application "System Events" to set localAdmin to (name of current user)
set adminPass to "mytempadmin"

set secretID to "jamfSecret"


set plistPayload to "\\\"{\\\"jamfServerDomain\\\":\\\"" & jamfServerDomain & "\\\",\\\"jamfEnrollmentUser\\\":\\\"" & SDKUser & "\\\",\\\"jamfEnrollmentPassword\\\":\\\"" & SDKPassword & "\\\",\\\"localAdmin\\\":\\\"" & localAdmin & "\\\",\\\"localAdminPassword\\\":\\\"" & adminPass & "\\\"}"
set plist64 to (do shell script "echo '" & plistPayload & "' | base64")
do shell script "defaults write com.amazon.dsx.ec2.enrollment.automation " & secretID & " '" & plist64 & "'"
set doneDialog to button returned of (display dialog "Credentials have been stored under key " & secretID & ". Be sure to add this key as the Secret ID to your deployment." buttons {"Copy ID", "Do It For Me", "OK"} default button "Do It For Me")
if doneDialog is "Do It For Me" then
	do shell script "defaults write com.amazon.dsx.ec2.enrollment.automation " & secretID & " " & plist64
	do shell script "defaults write com.amazon.dsx.ec2.enrollment.automation retrievalType plist"
else if doneDialog is "Copy ID" then
	set the clipboard to secretID
end if
