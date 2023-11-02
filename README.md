# enroll-ec2-mac: Welcome!

enroll-ec2-mac is an AppleScript made to **automatically enroll** [Amazon Web Services Elastic Compute Cloud (EC2) Mac instances](https://aws.amazon.com/ec2/instance-types/mac/) into a **mobile device management (MDM)** solution. enroll-ec2-mac is made to ensure the MDM “pairing“ relationship isn't broken for MDM enrollment. Without that pairing, an EC2 Mac instance isn’t able to ”listen“ for new or updated profiles from the MDM server. enroll-ec2-mac performs all of this without any user interaction after AMI configuration (as per the instructions below). Included is a subroutine to automate the issuance and retrieval of **Jamf** enrollment profiles. 

---

#### Learn more about Amazon EC2 Mac instances [here!](https://github.com/aws-samples/amazon-ec2-mac-getting-started/tree/main/apps-and-scripts)

---

### enroll-ec2-mac retrieves a **secret** (credentials/passwords) stored in **AWS Secrets Manager**. 

Included are [AWS CloudFormation](https://aws.amazon.com/cloudformation/) and [HashiCorp Terraform](https://www.terraform.io/) templates to get these set up. Either of these will automate creating the AWS Secrets Manager secret, Identity and Access Management policy, role, and instance profile needed for enroll-ec2-mac to retrieve credentials. Alternatively, if using AWS Systems Manager Parameter Store instead, templates are also included, and a setting must be changed to match. Manual instructions to set up the secret are also included at the bottom of this page. 

---

### Credential Setup

1. Gather the appropriate **credentials** and store them in **AWS Secrets Manager.** If you're using one of the templates, you'll be prompted for each of these. The default secret ID in the script is `jamfSecret`, and requires 5 values for the following keys (with sample values below):
    1. `jamfServerDomain` `("jamfurl.jamfcloud.com")`
    2. `jamfEnrollmentUser` `("enrollmentUserExampleName")`
    3. `jamfEnrollmentPassword` `("enrollment3x4mplep455w0rd")`
        * This is an API client or user account in the **Jamf** console, and its role only requires **Create** permission for **Computer Invitations**.
        * If using Jamf API Client Credentials, fill the `jamfEnrollmentUser` field with the **Client ID** and `jamfEnrollmentPassword` with the **Client Secret**.
        * Additional permissions for Jamf account are required for other API features, such as preloading information and removing device records.
    4. `localAdmin` `("ec2-user")`
        1. The default is `ec2-user` unless a change is made outside of these instructions. Must be an administrator account.
    5. `localAdminPassword` `("l0c4l3x4mplep455w0rd")`
        1. Password for `localAdmin` administrator account.
        2. These credentials may be reset/cleared programmatically after enrollment completes.
2. Create AWS **Identity and Access Management (IAM) assets** to enable access to the above secret. The IAM policy, role, and instance profile (noted here as ㊙️🪪) are all automatically created with either template. See near the end for a sample manual policy.
    1. Attach this **㊙️🪪 IAM Instance Profile** to the instance you're starting. 

### AMI Setup

1. **Start** an EC2 Mac instance on a mac2 host from the Amazon-vended macOS AMI. 
    1. **Attach** the above **㊙️🪪 IAM Instance Profile** to the instance.
2. **Connect** via SSH, **enable** Screen Sharing/VNC, and **set** the admin password to match the one saved in the Secret.
    1. In a single line:` sudo /usr/bin/dscl . -passwd /Users/ec2-user 'l0c4l3x4mplep455w0rd' ; sudo launchctl enable system/com.apple.screensharing ; sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist`
3. **Connect** to the Mac **GUI** (via VNC or Screen Sharing) and **log in** with the above password.
3. Enable **Automatically log in as** for the current user in **System Settings -> Users & Groups.**
4. **Place** `enroll-ec2-mac.scpt` in `/Users/Shared`.
    1. Set the **secret ID** (either by name or with the complete [ARN](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference-arns.html)) by manually setting `MMSecret` in the script, or writing the ID to a plist with the below command. 
        - `defaults write /Library/Preferences/com.amazon.dsx.enroll-ec2-mac MMSecret "jamfSecret-YOUR-SECRET-ID"`, replacing what's in quotes with the ID or ARN of your secret.
        - *This secret is the one your  **㊙️🪪 IAM Instance Profile** can access.*
        - *Unable to use Secrets Manager? Options for using Parameter Store (with CloudFormation and Terraform templates) or statically setting the variables are commented in the script runtime.*
5. In **Terminal**, type the following command: 
    1. `osascript /Users/Shared/enroll-ec2-mac.scpt --setup`
    2. Note: if you aren't using DEPNotify (see below for why), add the `--no-screen` flag to deactivate.
           - e.g. `osascript /Users/Shared/enroll-ec2-mac.scpt --setup --no-screen`
    - *In the event the Jamf server credentials are incorrect, an error will appear halting this process. Correct these credentials to continue.*
6. **Follow the prompts** to enable Accessibility, App Management, and Disk Access permissions as needed. These will be enabled for the `osascript` process and may be reverted programmatically, included in the cleanup routines if `testFlag` is not set to `1`.
    1. After a short delay, enroll-ec2-mac will try to access all the permissions that it will need to during actual enrollment, but not performing all of the enrollment actions.
        - During this process, it is normal for the screen to flash a few times.
        - *Optional: if `useDEPNotify` is set to `false`, or the `--no-screen` flag is used, prompts for **App Management** will not appear and the screen will not flash. DEPNotify is used to keep users from interfering in the enrollment process, but is optional if automatic login is set on Apple silicon instances, since enrollment can transparently occur before a user logs in.*
    2. In the event of an error, click **Re-run** and respond to the prompts again.
    3. If a final prompt or error does not appear after some time (over 2 minutes), run the following command to reload the LaunchAgent and re-run the task:
        - `launchctl unload -w /Library/LaunchAgents/com.amazon.dsx.enroll-ec2-mac.startup.plist ; launchctl load -w /Library/LaunchAgents/com.amazon.dsx.enroll-ec2-mac.startup.plist`
7. Once you receive the below message, **click OK** and close Screen Sharing/VNC. ![A dialog box with a success message for enroll-ec2-mac.](SetupComplete.png)
        - **Make sure to click OK before creating your image.** If not, enroll-ec2-mac will re-attempt setup on subsequent runs until it's clicked.
9. Optional: **disable screen sharing** via the active SSH session.
    1. `sudo launchctl disable system/com.apple.screensharing ; sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.screensharing.plist`
10. [**Create an image**](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/creating-an-ami-ebs.html) from the running instance.
    1. Follow the linked instructions to **Create a Linux AMI from an instance** (instructions also cover macOS instances).
    2. Workflow was tested with **“No reboot”** enabled.
        - *Note: if the instance is rebooted or logged out after clicking OK,* **enrollment will occur.**
    3. Ensure “Delete on termination” is **unchecked** to keep the AMI after terminating the template instance.
11. When AMI moves from **Pending** to **Available**, launch a new instance with the AMI. 
    1. This process may take an hour or more.
    2. Ensure the newly launched instance has the appropriate **㊙️🪪 IAM instance profile** to retrieve the credentials.
12. When new instance is launched, it will enroll **automatically**, and without any further intervention. 
    1. Code in enroll-ec2-mac will auto-enable Screen Sharing when enrollment is complete, if desired.
    2. Cleanup code additionally is available to revoke permissions used for `osascript`.



### Troubleshooting

* The first spot to check during a script failure is the **㊙️🪪 IAM Instance Profile**: if the script hangs or crashes (any error regarding `“{{ }},{{ }}")`, it may not have access to the secrets it needs, or isn’t parsing them correctly. 
    * To test, in Terminal, manually check the secret (changing `jamfSecret` to the name or ARN of your secret):
        * `aws secretsmanager get-secret-value --secret-id jamfSecret --query SecretString`

---

## Settings


enroll-ec2-mac has some options to customize to suit your deployment. To set any of these preferences, type `defaults write com.amazon.dsx.enroll-ec2-mac `, the key, and the value. For example, to set your secret ID (the only required setting), the full command would be:

`defaults write com.amazon.dsx.enroll-ec2-mac MMSecret "jamfSecretID-GoesHere"` 

(replacing `"jamfSecretID-GoesHere"` with your secret ID or ARN)

- `MMSecret` is the ID of the secret for enroll-ec2-mac to read from. (default `jamfSecret`)
- `invitationID` is a value for the Jamf invitation ID (numeric string). By default this is read/generated via Jamf API, but can be manually set.
- - *Note: If an invitation ID is set, the Jamf API **will not be called.***
- `retrievalType` changes how the secret is read. By default, this is set to `SecretsManager` (AWS Secrets Manager), but may be set to `ParameterStore` (AWS Systems Manager Parameter Store). (default `SecretsManager`)
- `useDEPNotify` deactivates (if set to false) the DEPNotify UI that enroll-ec2-mac uses to shield the display from a user during enrollment. This is set to `false` when the `--no-screen` flag is used. (default `true`)
- `autoLogin` enables/disables automatic login of the stored user. This has not been reliably automated in some versions of macOS, and is still recommended as a manual step taken during setup regardless of this setting. (default `true`)

---

## Manual Configuration for AWS Secrets Manager & IAM

enroll-ec2-mac uses a single secret that contains 5 key/value pair entries: the Jamf URL (`jamfServerDomain`), API credentials (`jamfEnrollmentUser` & `jamfEnrollmentPassword`), and local admin credentials (`localAdmin` & `localAdminPassword`). The first three are required to generate the profile, and the final two to apply them to the Mac. Example values are in **Credential Setup** at the top of the page. The EC2 instance needs an appropriate **㊙️🪪 IAM instance profile** applied to itself to read these secrets, as well. 

The Jamf API client or user account for enroll-ec2-mac *only* requires the **Create** permission for **Computer Invitations**, and none else. See below for an example of an **㊙️🪪 IAM instance profile** including the appropriate access.

---

**Please ensure that you have replaced the ARN next to "Resource" with the full ARN of your secret.** If editing manually:
* replace **`⚠️⇢region-name`** with the appropriate **AWS region** (e.g. `us-east-1`).
* replace **`1111222233333`** with the appropriate **AWS account ID**.
* replace `jamfSecret` with **your** applicable **Secret ID**.


```
{
    "Version": "2012-10-17"
    "Statement": [
        {
            "Action": [
                "secretsmanager:ListSecrets",
                "secretsmanager:ListSecretVersionIds",
                "secretsmanager:GetSecretValue",
                "secretsmanager:GetResourcePolicy",
                "secretsmanager:GetRandomPassword",
                "secretsmanager:DescribeSecret"
            ],
            "Effect": "Allow",
            "Resource": "arn:aws:secretsmanager:⚠️⇢region-name:111122223333:secret:jamfSecret",
            "Sid": ""
        }
    ]
}
```

---

THERE IS NO WARRANTY FOR THE PROGRAM, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES PROVIDE THE PROGRAM “AS IS” WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM IS WITH YOU. SHOULD THE PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING, REPAIR OR CORRECTION.

---

*"There's no step 13!"*
