import requests
import getpass
import os
import yaml

def create_jira_ticket(base_url, project_key, issue_type, summary, description, token, custom_fields):
    # Construct the API endpoint URL
    url = f"{base_url}/rest/api/2/issue/"

    # Set the request headers
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}"
    }

    # Set the request payload
    payload = {
        "fields": {
            "project": {
                "key": project_key
            },
            "issuetype": {
                "name": issue_type
            },
            "summary": summary,
            "description": description
        }
    }

    no = {'no','n'} # for yes you can use {'yes','y', 'ye', ''}

    # Add custom fields
    for field, value in custom_fields.items():
        if field not in payload:
            choice = input(f"Default value for field {field} is {value}. Do you want to continue with this value? [Y/n]: ")
            if choice.lower() in no:
                value = input(f"Value you want to use for field {field}: ")
            payload["fields"][field] = value

    print(f"payload: {payload}")

    # Send the POST request to create the ticket
    response = requests.post(url, json=payload, headers=headers)

    # Check the response status code
    if response.status_code == 201:
        print(f"response: {response}")
        ticket_key = response.key
        jira_url = base_url + "/browse/" + ticket_key
        print("Jira ticket created successfully!", jira_url)
    else:
        print("Failed to create Jira ticket. Error:", response.text)

if __name__ == "__main__":
    # Load the YAML configuration file
    script_dir = os.path.dirname(os.path.realpath(__file__))
    config_path = os.path.join(script_dir, 'create-jira.yaml')

    with open(config_path, 'r') as file:
        print(f"Config: {file.read()}")
        file.seek(0)
        config = yaml.safe_load(file)

    # Get the values from config
    base_url = config['jira']['base_url']
    token = config['jira']['token']
    custom_fields = config['jira']['custom_fields']

    #print(f"Jira Base URL: {ba se_url}")
    #print(f"Jira Token: {token}")
    #print(f"Jira customfields: {custom_fields}")

    # Get the Jira project key from the user
    project_key = input("Enter the Jira project key: ")

    # Get the Jira issue type from the user
    issue_type = input("Enter the Jira issue type: ")

    # Get the Jira ticket summary from the user
    summary = input("Enter the Jira ticket summary: ")

    # Get the Jira ticket description from the user
    description = input("Enter the Jira ticket description: ")

    # Call the create_jira_ticket function
    create_jira_ticket(base_url, project_key, issue_type, summary, description, token, custom_fields)
