#!/bin/sh

### User Data script to reset an administrator account for staging MDM enrollment.

stagingUser="mdm-staging-user"
stagingPassword=$(uuidgen)

# This password will need to by typed at loginwindow (not pasted).
# Uncommenting the line below will generate a shorter password (for testing purposes only).
# stagingPassword=$(openssl rand -hex 4)

stagingUID="1001"

### Fill in the below to match your Jamf enrollment credentials.
jamfURL="sample.jamfcloud.com"
jamfEnrollUser="enrollmentusername"
jamfEnrollPass="enrollmentuserpassword"

echo "$stagingPassword" | tee -i /Users/Shared/.stageHandCredential

# Creates the staging user, assigns them a password, elevates to admin, and creates home folder.
sudo /usr/sbin/sysadminctl -addUser $stagingUser -fullName $stagingUser -UID $stagingUID -GID 80 -shell /bin/zsh -password "$stagingPassword" -home /Users/$stagingUser -admin
sudo /usr/sbin/createhomedir -c -u $stagingUser 



# This plist is formatted to match what enroll-ec2-mac is expecting from a credentials payload.
plistPrimitive="\\\"{\\\"jamfServerDomain\\\":\\\"$jamfURL\\\",\\\"jamfEnrollmentUser\\\":\\\"$jamfEnrollUser\\\",\\\"jamfEnrollmentPassword\\\":\\\"$jamfEnrollPass\\\",\\\"localAdmin\\\":\\\"$stagingUser\\\",\\\"localAdminPassword\\\":\\\"$stagingPassword\\\"}"
plistPayload=$(echo "$plistPrimitive" | base64)

# Writes the plist to the $stagingUser's preferences (not needed if using retrievalPath).
defaults write /Users/$stagingUser/Library/Preferences/com.amazon.dsx.ec2.enrollment.automation retrievalType plist
defaults write /Users/$stagingUser/Library/Preferences/com.amazon.dsx.ec2.enrollment.automation jamfSecret "$plistPayload"
chown $stagingUID /Users/$stagingUser/Library/Preferences/com.amazon.dsx.ec2.enrollment.automation.plist


# Writes the plist preference to the default ec2-user, and the path to find the credentials if not using stagingUser user as interactive.
defaults write /Users/ec2-user/Library/Preferences/com.amazon.dsx.ec2.enrollment.automation retrievalType plist
defaults write /Users/ec2-user/Library/Preferences/com.amazon.dsx.ec2.enrollment.automation retrievalPath "/Users/$stagingUser/Library/Preferences/"
chown 501 /Users/ec2-user/Library/Preferences/com.amazon.dsx.ec2.enrollment.automation.plist

# Logs out ec2-user for interactive login for $stagingUser to show up in loginwindow (optional).
# sudo /usr/bin/killall -m loginwindow

# Turns on screen sharing if not already active.
sudo launchctl enable system/com.apple.screensharing ; sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist

# To reset password when launching subsequent instances:
# #!/bin/sh

# stagingUser="mdm-staging-user"
# stagingPassword=$(uuidgen)
# stagingHint="Generated"
# sudo sysadminctl -resetPasswordFor $stagingUser -newPassword $stagingPassword -passwordHint "$stagingHint"
# echo "$stagingPassword" | tee -i /Users/Shared/.stageHandCredential
