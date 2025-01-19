# Porkbun Dynamic DNS Updater

This script automatically updates DNS records on Porkbun when your public IP address changes. It's designed to work with multiple domains and subdomains, making it ideal for managing dynamic DNS setups.

## Features

- Automatically detects changes in your public IP address
- Updates A records for multiple domains and subdomains on your Porkbun account. You do not have to define the list, it will simply scan through all domains on your account that you've enabled API access for.
- Handles API authentication and error reporting
- Logs all actions and errors for easy troubleshooting

## Prerequisites

- Bash shell
- `curl` and `jq` installed on your system
- Porkbun API access enabled for your domains
- API key and Secret key from Porkbun

## Setup

1. Clone or download the script to your desired location.
2. Make the script executable:
```chmod +x update_porkbun_dns.sh```
3. Edit the script and replace `YOUR_API_KEY` and `YOUR_SECRET_KEY` with your Porkbun API credentials.
4. Setup crontab AFTER you test the script. Example crontab which checks every 5 minutes.

   ```*/5 * * * * /root/update_porkbun_dns.sh >> /var/log/porkbun_dns_update.log 2>&1```

## Usage

Run the script manually or set it up as a cron job for automatic updates:

```./update_porkbun_dns.sh```


## How It Works

1. The script checks your current public IP address.
2. It compares this with the last known IP address stored in `.last_known_ip`.
3. If the IP has changed (or on first run):
   - It retrieves a list of all your domains from Porkbun.
   - For each domain, it fetches all DNS records.
   - It updates A records that match the old IP address to the new one.
4. The script logs all actions and errors to both the console and a log file.

## First Run Considerations

On the first run, the script creates a `.last_known_ip` file with your current public IP. This may not match existing DNS records. To ensure all records are updated correctly:

1. Run the script once to create the `.last_known_ip` file.
2. Check your Porkbun DNS records for the IP address currently set on domains/subdomains you wish to have updated.
3. Edit the `.last_known_ip` file and replace the content with the IP address from your DNS records.
4. Run the script again to update all matching records.

## Troubleshooting

- Check the log file (`/var/log/porkbun_dns_update.log`) for detailed information about each run.
- Ensure API access is enabled for all domains you want to update.
- Verify your API credentials are correct and have the necessary permissions.

## Limitations

- The script only updates A records. Other record types are not modified.
- It requires API access to be enabled for each domain on Porkbun.

## Contributing

Contributions to improve the script are welcome. Please submit pull requests or open issues on the project's GitHub page.
